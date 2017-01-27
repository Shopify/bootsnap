#include "aot_compile_cache.h"
#include <sys/types.h>
#include <sys/xattr.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>
#include <utime.h>

/* 
 * TODO:
 * - test on linux or reject on non-darwin
 * - source files over 4GB will likely break things (meh)
 */

static VALUE rb_cAOTCompileCache;
static VALUE rb_cAOTCompileCache_Native;
static VALUE rb_eAOTCompileCache_Uncompilable;
static uint32_t current_ruby_revision;
static uint32_t current_compile_option_crc32 = 0;
static ID uncompilable;

struct xattr_key {
  uint8_t  version;
  uint32_t compile_option;
  uint32_t data_size;
  uint32_t ruby_revision;
  uint64_t mtime;
  uint64_t checksum;
} __attribute__((packed));

struct i2o_data {
  VALUE handler;
  VALUE input_data;
};

struct i2s_data {
  VALUE handler;
  VALUE input_data;
  VALUE pathval;
};

struct s2o_data {
  VALUE handler;
  VALUE storage_data;
};

static const uint8_t current_version = 9;
static const char * xattr_key_name = "com.shopify.AOTCacheKey";
static const size_t xattr_key_size = sizeof (struct xattr_key);
static const char * xattr_data_name = "com.apple.ResourceFork";

#ifdef __APPLE__
#define XATTR_TRAILER ,0,0
#else
#define XATTR_TRAILER
#endif

/* forward declarations */
static int aotcc_fetch_data(int fd, size_t size, VALUE handler, VALUE * storage_data, int * exception_tag);
static int aotcc_update_key(int fd, uint32_t data_size, uint64_t current_mtime, uint64_t current_checksum);
static int aotcc_open(const char * path, bool * writable);
static int aotcc_get_cache(int fd, struct xattr_key * key);
static size_t aotcc_read_contents(int fd, size_t size, char ** contents);
static int aotcc_close_and_unclobber_times(int * fd, const char * path, time_t atime, time_t mtime);
static VALUE aotcc_fetch(VALUE self, VALUE pathval, VALUE handler);
static VALUE aotcc_compile_option_crc32_set(VALUE self, VALUE crc32val);
static VALUE prot_exception_for_errno(VALUE err);
static VALUE prot_input_to_output(VALUE arg);
static void aotcc_input_to_output(VALUE handler, VALUE input_data, VALUE * output_data, int * exception_tag);
static VALUE prot_input_to_storage(VALUE arg);
static int aotcc_input_to_storage(VALUE handler, VALUE input_data, VALUE pathval, VALUE * storage_data);
static VALUE prot_storage_to_output(VALUE arg);
static int aotcc_storage_to_output(VALUE handler, VALUE storage_data, VALUE * output_data);
static int logging_enabled();

void
Init_aot_compile_cache(void)
{
  rb_cAOTCompileCache = rb_define_class("AOTCompileCache", rb_cObject);
  rb_cAOTCompileCache_Native = rb_define_module_under(rb_cAOTCompileCache, "Native");
  current_ruby_revision = FIX2INT(rb_const_get(rb_cObject, rb_intern("RUBY_REVISION")));

  rb_eAOTCompileCache_Uncompilable = rb_define_class_under(rb_cAOTCompileCache, "Uncompilable", rb_eStandardError);

  uncompilable = rb_intern("__aotcc_uncompilable__");

  rb_define_module_function(rb_cAOTCompileCache_Native, "fetch", aotcc_fetch, 2);
  rb_define_module_function(rb_cAOTCompileCache_Native, "compile_option_crc32=", aotcc_compile_option_crc32_set, 1);
}

static VALUE
aotcc_compile_option_crc32_set(VALUE self, VALUE crc32val)
{
  Check_Type(crc32val, T_FIXNUM);
  current_compile_option_crc32 = FIX2UINT(crc32val);
  return Qnil;
}

#define CHECKED(ret, func) \
  do { if ((int)(ret) == -1) FAIL((func), errno); } while(0);

#define FAIL(func, err) \
  do { \
    int state; \
    exception = rb_protect(prot_exception_for_errno, INT2FIX(err), &state); \
    if (state) exception = rb_eStandardError; \
    goto fail; \
  } while(0);

#define PROT_CHECK(body) \
  do { \
    (body); \
    if (exception_tag != 0) goto raise; \
  } while (0);

#define SUCCEED(final) \
  do { \
    output_data = final; \
    goto cleanup; \
  } while(0);

static VALUE
aotcc_fetch(VALUE self, VALUE pathval, VALUE handler)
{
  const char * path;

  VALUE exception;
  int exception_tag;

  int fd, ret;
  bool valid_cache;
  bool writable;
  uint32_t data_size;
  uint64_t current_checksum;
  struct xattr_key cache_key;
  struct stat statbuf;
  char * contents;

  VALUE input_data;   /* data read from source file, e.g. YAML or ruby source */
  VALUE storage_data; /* compiled data, e.g. msgpack / binary iseq */
  VALUE output_data;  /* return data, e.g. ruby hash or loaded iseq */

  /* don't leak memory */
#define return   error!
#define rb_raise error!

  output_data = Qnil;
  contents = 0;

  Check_Type(pathval, T_STRING);
  path = RSTRING_PTR(pathval);

  CHECKED(fd          = aotcc_open(path, &writable),     "open");
  CHECKED(              fstat(fd, &statbuf),             "fstat");
  CHECKED(valid_cache = aotcc_get_cache(fd, &cache_key), "fgetxattr");

  if (valid_cache && cache_key.mtime == (uint64_t)statbuf.st_mtime) {
    ret = aotcc_fetch_data(fd, (size_t)cache_key.data_size, handler, &output_data, &exception_tag);
    /* TODO: if the value was gone, recover gracefully */
    PROT_CHECK((void)0);
    CHECKED(ret, "fgetxattr/fetch-data");
    if (!NIL_P(output_data)) {
      SUCCEED(output_data);
    }
    valid_cache = false;
  }

  CHECKED(aotcc_read_contents(fd, statbuf.st_size, &contents), "read") /* contents must be xfree'd */
  current_checksum = (uint64_t)crc32(contents, statbuf.st_size);

  if (valid_cache && current_checksum == cache_key.checksum) {
    ret = aotcc_fetch_data(fd, (size_t)cache_key.data_size, handler, &output_data, &exception_tag);
    /* TODO: if the value was gone, recover gracefully */
    PROT_CHECK((void)0);
    CHECKED(ret, "fgetxattr/fetch-data");
    if (!NIL_P(output_data)) {
      if (writable) {
        CHECKED(aotcc_update_key(fd, (uint32_t)statbuf.st_size, statbuf.st_mtime, current_checksum), "fsetxattr");
        CHECKED(aotcc_close_and_unclobber_times(&fd, path, statbuf.st_atime, statbuf.st_mtime), "close/utime");
      }
      SUCCEED(output_data);
    }
    valid_cache = false;
  }

  input_data = rb_str_new(contents, statbuf.st_size);

  if (!writable) {
    PROT_CHECK(aotcc_input_to_output(handler, input_data, &output_data, &exception_tag));
    SUCCEED(output_data);
  }

  /* mtime and checksum both mismatched, or the cache was invalid/absent */
  PROT_CHECK(exception_tag = aotcc_input_to_storage(handler, input_data, pathval, &storage_data));
  if (storage_data == uncompilable) {
    PROT_CHECK(aotcc_input_to_output(handler, input_data, &output_data, &exception_tag));
    SUCCEED(output_data);
  }

  if (!RB_TYPE_P(storage_data, T_STRING)) {
    goto invalid_type_storage_data;
  }

  /* xattrs can't exceed 64MB */
  if (RB_TYPE_P(storage_data, T_STRING) && RSTRING_LEN(storage_data) > 64 * 1024 * 1024) {
    if (logging_enabled()) {
      fprintf(stderr, "[OPT_AOT_LOG] warning: compiled artifact is over 64MB, which is too large to store in an xattr.%s\n", path);
    }
    PROT_CHECK(aotcc_input_to_output(handler, input_data, &output_data, &exception_tag));
    SUCCEED(output_data);
  }

  data_size = (uint32_t)RSTRING_LEN(storage_data);

  CHECKED(aotcc_update_key(fd, data_size, statbuf.st_mtime, current_checksum), "fsetxattr");
  CHECKED(fsetxattr(fd, xattr_data_name, RSTRING_PTR(storage_data), (size_t)data_size XATTR_TRAILER), "fsetxattr");
  CHECKED(aotcc_close_and_unclobber_times(&fd, path, statbuf.st_atime, statbuf.st_mtime), "close/utime");
  PROT_CHECK(exception_tag = aotcc_storage_to_output(handler, storage_data, &output_data));
  /* TODO: input_to_output if storage_data is nil */
  SUCCEED(output_data);

#undef return
#undef rb_raise
#define CLEANUP \
  if (contents != 0) xfree(contents); \
  if (fd > 0) close(fd);

cleanup:
  CLEANUP;
  return output_data;
fail:
  CLEANUP;
  rb_exc_raise(exception);
  __builtin_unreachable();
invalid_type_storage_data:
  CLEANUP;
  Check_Type(storage_data, T_STRING);
  __builtin_unreachable();
raise:
  CLEANUP;
  rb_jump_tag(exception_tag);
  __builtin_unreachable();
}

static int
aotcc_fetch_data(int fd, size_t size, VALUE handler, VALUE * output_data, int * exception_tag)
{
  int ret;
  ssize_t nbytes;
  void * xattr_data;
  VALUE storage_data;

  *output_data = Qnil;
  *exception_tag = 0;

  xattr_data = ALLOC_N(uint8_t, size);
  nbytes = fgetxattr(fd, xattr_data_name, xattr_data, size XATTR_TRAILER);
  if (nbytes == -1) {
    ret = -1;
    goto done;
  }
  if (nbytes != (ssize_t)size) {
    errno = EIO; /* lies but whatever */
    ret = -1;
    goto done;
  }
  storage_data = rb_str_new(xattr_data, nbytes);
  ret = aotcc_storage_to_output(handler, storage_data, output_data);
  if (ret != 0) {
    *exception_tag = ret;
    errno = 0;
  }
done:
  xfree(xattr_data);
  return ret;
}

static int
aotcc_update_key(int fd, uint32_t data_size, uint64_t current_mtime, uint64_t current_checksum)
{
  struct xattr_key xattr_key;

  xattr_key = (struct xattr_key){
    .version        = current_version,
    .data_size      = data_size,
    .compile_option = current_compile_option_crc32,
    .ruby_revision  = current_ruby_revision,
    .mtime          = current_mtime,
    .checksum       = current_checksum,
  };

  return fsetxattr(fd, xattr_key_name, &xattr_key, (size_t)xattr_key_size XATTR_TRAILER);
}

/*
 * Open the file O_RDWR if possible, or O_RDONLY if that throws EACCES.
 * Set +writable+ to indicate which mode was used.
 */
static int
aotcc_open(const char * path, bool * writable)
{
  int fd;

  *writable = true;
  fd = open(path, O_RDWR);
  if (fd == -1 && errno == EACCES) {
    *writable = false;
    if (logging_enabled()) {
      fprintf(stderr, "[OPT_AOT_LOG] warning: unable to cache because no write permission to %s\n", path);
    }
    fd = open(path, O_RDONLY);
  }
  return fd;
}

/*
 * Fetch the cache key from the relevant xattr into +key+.
 * Returns:
 *   0:  invalid/no cache
 *   1:  valid cache
 *   -1: fgetxattr failed, errno is set
 */
static int
aotcc_get_cache(int fd, struct xattr_key * key)
{
  ssize_t nbytes;

  nbytes = fgetxattr(fd, xattr_key_name, (void *)key, xattr_key_size XATTR_TRAILER);
  if (nbytes == -1 && errno != ENOATTR) {
    return -1;
  }

  return (nbytes == (ssize_t)xattr_key_size && \
      key->version == current_version && \
      key->compile_option == current_compile_option_crc32 && \
      key->ruby_revision == current_ruby_revision);
}

/*
 * Read an entire file into a char*
 * contents must be freed with xfree() when done.
 */
static size_t
aotcc_read_contents(int fd, size_t size, char ** contents)
{
  *contents = ALLOC_N(char, size);
  return read(fd, *contents, size);
}

static int
aotcc_close_and_unclobber_times(int * fd, const char * path, time_t atime, time_t mtime)
{
  struct utimbuf times = {
    .actime = atime,
    .modtime = mtime,
  };
  if (close(*fd) == -1) {
    return -1;
  }
  *fd = 0;
  return utime(path, &times);
}

static VALUE
prot_exception_for_errno(VALUE err)
{
  if (err != INT2FIX(0)) {
    VALUE mErrno = rb_const_get(rb_cObject, rb_intern("Errno"));
    VALUE constants = rb_funcall(mErrno, rb_intern("constants"), 0);
    VALUE which = rb_funcall(constants, rb_intern("[]"), 1, err);
    return rb_funcall(mErrno, rb_intern("const_get"), 1, which);
  }
  return rb_eStandardError;
}

static VALUE
prot_input_to_output(VALUE arg)
{
  struct i2o_data * data = (struct i2o_data *)arg;
  return rb_funcall(data->handler, rb_intern("input_to_output"), 1, data->input_data);
}

static void
aotcc_input_to_output(VALUE handler, VALUE input_data, VALUE * output_data, int * exception_tag)
{
  struct i2o_data i2o_data = {
    .handler    = handler,
    .input_data = input_data,
  };
  *output_data = rb_protect(prot_input_to_output, (VALUE)&i2o_data, exception_tag);
}

static VALUE
try_input_to_storage(VALUE arg)
{
  struct i2s_data * data = (struct i2s_data *)arg;
  return rb_funcall(data->handler, rb_intern("input_to_storage"), 2, data->input_data, data->pathval);
}

static VALUE
rescue_input_to_storage(VALUE arg)
{
  return uncompilable;
}

static VALUE
prot_input_to_storage(VALUE arg)
{
  struct i2s_data * data = (struct i2s_data *)arg;
  return rb_rescue2(
      try_input_to_storage, (VALUE)data,
      rescue_input_to_storage, Qnil,
      rb_eAOTCompileCache_Uncompilable, 0);
}

static int
aotcc_input_to_storage(VALUE handler, VALUE input_data, VALUE pathval, VALUE * storage_data)
{
  int state;
  struct i2s_data i2s_data = {
    .handler    = handler,
    .input_data = input_data,
    .pathval    = pathval,
  };
  *storage_data = rb_protect(prot_input_to_storage, (VALUE)&i2s_data, &state);
  return state;
}

static VALUE
prot_storage_to_output(VALUE arg)
{
  struct s2o_data * data = (struct s2o_data *)arg;
  return rb_funcall(data->handler, rb_intern("storage_to_output"), 1, data->storage_data);
}

static int
aotcc_storage_to_output(VALUE handler, VALUE storage_data, VALUE * output_data)
{
  int state;
  struct s2o_data s2o_data = {
    .handler      = handler,
    .storage_data = storage_data,
  };
  *output_data = rb_protect(prot_storage_to_output, (VALUE)&s2o_data, &state);
  return state;
}

/* default yes, no if "0" */
static int
logging_enabled()
{
  char * log = getenv("OPT_AOT_LOG");
  if (log == 0) {
    return 1;
  } else if (log[0] == '0') {
    return 0;
  } else {
    return 1;
  }
}
