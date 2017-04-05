#include "bootsnap.h"
#include <sys/types.h>
#include <sys/xattr.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>
#include <utime.h>

#ifdef __APPLE__
// Used for the OS Directives to define the os_version constant
#include <Availability.h>
#define _ENOATTR ENOATTR
#else
#define _ENOATTR ENODATA
#endif

/* 
 * TODO:
 * - test on linux or reject on non-darwin
 * - source files over 4GB will likely break things (meh)
 */

static VALUE rb_mBootsnap;
static VALUE rb_mBootsnap_CompileCache;
static VALUE rb_mBootsnap_CompileCache_Native;
static VALUE rb_eBootsnap_CompileCache_Uncompilable;
static uint32_t current_ruby_revision;
static uint32_t current_compile_option_crc32 = 0;
static ID uncompilable;

struct stats {
  uint64_t hit;
  uint64_t unwritable;
  uint64_t uncompilable;
  uint64_t miss;
  uint64_t fail;
  uint64_t retry;
};
static struct stats stats = {
  .hit = 0,
  .unwritable = 0,
  .uncompilable = 0,
  .miss = 0,
  .fail = 0,
  .retry = 0,
};

struct xattr_key {
  uint8_t  version;
  uint8_t  os_version;
  uint32_t compile_option;
  uint32_t data_size;
  uint32_t ruby_revision;
  uint64_t mtime;
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

static const uint8_t current_version = 11;
static const char * xattr_key_name = "user.aotcc.key";
static const char * xattr_data_name = "user.aotcc.value";
static const size_t xattr_key_size = sizeof (struct xattr_key);

#ifdef __MAC_10_15 // Mac OS 10.15 (future)
static const int os_version = 15;
#elif __MAC_10_14 // Mac OS 10.14 (future)
static const int os_version = 14;
#elif __MAC_10_13 // Mac OS 10.13 (future)
static const int os_version = 13;
#elif __MAC_10_12 // Mac OS X Sierra
static const int os_version = 12;
#elif __MAC_10_11 // Mac OS X El Capitan
static const int os_version = 11;
# else
static const int os_version = 0;
#endif

#ifdef __APPLE__
#define GETXATTR_TRAILER ,0,0
#define SETXATTR_TRAILER ,0
#define REMOVEXATTR_TRAILER ,0
#else
#define GETXATTR_TRAILER
#define SETXATTR_TRAILER
#define REMOVEXATTR_TRAILER
#endif

/* forward declarations */
static int bs_fetch_data(int fd, size_t size, VALUE handler, VALUE * storage_data, int * exception_tag);
static int bs_update_key(int fd, uint32_t data_size, uint64_t current_mtime);
static int bs_open(const char * path, bool * writable);
static int bs_get_cache(int fd, struct xattr_key * key);
static size_t bs_read_contents(int fd, size_t size, char ** contents);
static int bs_close_and_unclobber_times(int * fd, const char * path, time_t atime, time_t mtime);
static VALUE bs_fetch(VALUE self, VALUE pathval, VALUE handler);
static VALUE bs_compile_option_crc32_set(VALUE self, VALUE crc32val);
static VALUE prot_exception_for_errno(VALUE err);
static VALUE prot_input_to_output(VALUE arg);
static void bs_input_to_output(VALUE handler, VALUE input_data, VALUE * output_data, int * exception_tag);
static VALUE prot_input_to_storage(VALUE arg);
static int bs_input_to_storage(VALUE handler, VALUE input_data, VALUE pathval, VALUE * storage_data);
static VALUE prot_storage_to_output(VALUE arg);
static int bs_storage_to_output(VALUE handler, VALUE storage_data, VALUE * output_data);
static int logging_enabled();
static VALUE bs_stats(VALUE self);

void
Init_bootsnap(void)
{
  rb_mBootsnap = rb_define_module("Bootsnap");
  rb_mBootsnap_CompileCache = rb_define_module_under(rb_mBootsnap, "CompileCache");
  rb_mBootsnap_CompileCache_Native = rb_define_module_under(rb_mBootsnap_CompileCache, "Native");
  rb_eBootsnap_CompileCache_Uncompilable = rb_define_class_under(rb_mBootsnap_CompileCache, "Uncompilable", rb_eStandardError);
  current_ruby_revision = FIX2INT(rb_const_get(rb_cObject, rb_intern("RUBY_REVISION")));

  uncompilable = rb_intern("__bootsnap_uncompilable__");

  rb_define_module_function(rb_mBootsnap_CompileCache_Native, "fetch", bs_fetch, 2);
  rb_define_module_function(rb_mBootsnap_CompileCache_Native, "stats", bs_stats, 0);
  rb_define_module_function(rb_mBootsnap_CompileCache_Native, "compile_option_crc32=", bs_compile_option_crc32_set, 1);
}

static VALUE
bs_stats(VALUE self)
{
  VALUE ret = rb_hash_new();
  rb_hash_aset(ret, ID2SYM(rb_intern("hit")), INT2NUM(stats.hit));
  rb_hash_aset(ret, ID2SYM(rb_intern("miss")), INT2NUM(stats.miss));
  rb_hash_aset(ret, ID2SYM(rb_intern("unwritable")), INT2NUM(stats.unwritable));
  rb_hash_aset(ret, ID2SYM(rb_intern("uncompilable")), INT2NUM(stats.uncompilable));
  rb_hash_aset(ret, ID2SYM(rb_intern("fail")), INT2NUM(stats.fail));
  rb_hash_aset(ret, ID2SYM(rb_intern("retry")), INT2NUM(stats.retry));
  return ret;
}

static VALUE
bs_compile_option_crc32_set(VALUE self, VALUE crc32val)
{
  Check_Type(crc32val, T_FIXNUM);
  current_compile_option_crc32 = FIX2UINT(crc32val);
  return Qnil;
}

#define CHECK_C(ret, func) \
  do { if ((int)(ret) == -1) FAIL((func), errno); } while(0);

#define FAIL(func, err) \
  do { \
    int state; \
    exception = rb_protect(prot_exception_for_errno, INT2FIX(err), &state); \
    if (state) exception = rb_eStandardError; \
    goto fail; \
  } while(0);

#define CHECK_RB0() \
  do { if (exception_tag != 0) goto raise; } while (0);

#define CHECK_RB(body) \
  do { (body); CHECK_RB0(); } while (0);

#define SUCCEED(final) \
  do { \
    output_data = final; \
    goto cleanup; \
  } while(0);

static VALUE
bs_fetch(VALUE self, VALUE pathval, VALUE handler)
{
  const char * path;

  VALUE exception;
  int exception_tag;

  int fd, ret, retry;
  bool valid_cache;
  bool writable;
  uint32_t data_size;
  struct xattr_key cache_key;
  struct stat statbuf;
  char * contents;

  VALUE input_data;   /* data read from source file, e.g. YAML or ruby source */
  VALUE storage_data; /* compiled data, e.g. msgpack / binary iseq */
  VALUE output_data;  /* return data, e.g. ruby hash or loaded iseq */

  /* don't leak memory */
#define return   error!
#define rb_raise error!

  retry = 0;
begin:
  output_data = Qnil;
  contents = 0;

  /* Blow up if we can't turn our argument into a char* */
  Check_Type(pathval, T_STRING);
  path = RSTRING_PTR(pathval);

  /* open the file, get its mtime and read the cache key xattr */
  CHECK_C(fd          = bs_open(path, &writable),     "open");
  CHECK_C(              fstat(fd, &statbuf),             "fstat");
  CHECK_C(valid_cache = bs_get_cache(fd, &cache_key), "fgetxattr");

  /* `valid_cache` is true if the cache key isn't trivially invalid, e.g. built
   * with a different RUBY_REVISION */
  if (valid_cache && cache_key.mtime == (uint64_t)statbuf.st_mtime) {
    /* if the mtimes match, assume the cache is valid. fetch the cached data. */
    ret = bs_fetch_data(fd, (size_t)cache_key.data_size, handler, &output_data, &exception_tag);
    if (ret == -1 && errno == _ENOATTR) {
      /* the key was present, but the data was missing. remove the key, and
       * start over */
      CHECK_C(fremovexattr(fd, xattr_key_name REMOVEXATTR_TRAILER), "fremovexattr");
      goto retry;
    }
    CHECK_RB0();
    CHECK_C(ret, "fgetxattr/fetch-data");
    if (!NIL_P(output_data)) {
      stats.hit++;
      SUCCEED(output_data); /* this is the fast-path to shoot for */
    }
    valid_cache = false; /* invalid cache; we'll want to regenerate it */
  }

  /* read the contents of the file and crc32 it to compare with the cache key */
  CHECK_C(bs_read_contents(fd, statbuf.st_size, &contents), "read") /* contents must be xfree'd */

  /* we need to pass this char* to ruby-land */
  input_data = rb_str_new_static(contents, statbuf.st_size);

  /* if we didn't have write permission to the file, bail now -- everything
   * that follows is about generating and writing the cache. Let's just convert
   * the input format to the output format and return */
  if (!writable) {
    stats.unwritable++;
    CHECK_RB(bs_input_to_output(handler, input_data, &output_data, &exception_tag));
    SUCCEED(output_data);
  }

  /* Now, we know we have write permission, and can update the xattrs.
   * Additionally, we know the cache is currently missing or absent, and needs
   * to be updated. */
  stats.miss++;

  /* First, convert the input format to the storage format by calling into the
   * handler. */
  CHECK_RB(exception_tag = bs_input_to_storage(handler, input_data, pathval, &storage_data));
  if (storage_data == uncompilable) {
    /* The handler can raise Bootsnap::CompileCache::Uncompilable. When it does this,
     * we just call the input_to_output handler method, bypassing the storage format. */
    CHECK_RB(bs_input_to_output(handler, input_data, &output_data, &exception_tag));
    stats.uncompilable++;
    SUCCEED(output_data);
  }

  /* we can only really write strings to xattrs */
  if (!RB_TYPE_P(storage_data, T_STRING)) {
    goto invalid_type_storage_data;
  }

  /* xattrs can't exceed 64MB */
  if (RB_TYPE_P(storage_data, T_STRING) && RSTRING_LEN(storage_data) > 64 * 1024 * 1024) {
    if (logging_enabled()) {
      fprintf(stderr, "[OPT_AOT_LOG] warning: compiled artifact is over 64MB, which is too large to store in an xattr.%s\n", path);
    }
    CHECK_RB(bs_input_to_output(handler, input_data, &output_data, &exception_tag));
    SUCCEED(output_data);
  }

  data_size = (uint32_t)RSTRING_LEN(storage_data);

  /* update the cache, but don't leave it in an invalid state even briefly: remove the key first. */
  fremovexattr(fd, xattr_key_name REMOVEXATTR_TRAILER);
  CHECK_C(fsetxattr(fd, xattr_data_name, RSTRING_PTR(storage_data), (size_t)data_size, 0 SETXATTR_TRAILER), "fsetxattr");
  CHECK_C(bs_update_key(fd, data_size, statbuf.st_mtime), "fsetxattr");

  /* updating xattrs bumps mtime, so we set them back after */
  CHECK_C(bs_close_and_unclobber_times(&fd, path, statbuf.st_atime, statbuf.st_mtime), "close/utime");

  /* convert the data we just stored into the output format */
  CHECK_RB(exception_tag = bs_storage_to_output(handler, storage_data, &output_data));

  /* if the storage data was broken, remove the cache and run input_to_output */
  if (output_data == Qnil) {
    /* deletion here is best effort; no need to fail if it does */
    fremovexattr(fd, xattr_key_name REMOVEXATTR_TRAILER);
    fremovexattr(fd, xattr_data_name REMOVEXATTR_TRAILER);
    CHECK_RB(bs_input_to_output(handler, input_data, &output_data, &exception_tag));
  }

  SUCCEED(output_data);

#undef return
#undef rb_raise
#define CLEANUP \
  if (contents != 0) xfree(contents); \
  if (fd > 0) close(fd);

  __builtin_unreachable();
cleanup:
  CLEANUP;
  return output_data;
fail:
  CLEANUP;
  stats.fail++;
  rb_exc_raise(exception);
  __builtin_unreachable();
invalid_type_storage_data:
  CLEANUP;
  stats.fail++;
  Check_Type(storage_data, T_STRING);
  __builtin_unreachable();
retry:
  CLEANUP;
  stats.retry++;
  if (retry == 1) {
    rb_raise(rb_eRuntimeError, "internal error in bootsnap");
    __builtin_unreachable();
  }
  retry = 1;
  goto begin;
raise:
  CLEANUP;
  stats.fail++;
  rb_jump_tag(exception_tag);
  __builtin_unreachable();
}

static int
bs_fetch_data(int fd, size_t size, VALUE handler, VALUE * output_data, int * exception_tag)
{
  int ret;
  ssize_t nbytes;
  void * xattr_data;
  VALUE storage_data;

  *output_data = Qnil;
  *exception_tag = 0;

  xattr_data = ALLOC_N(uint8_t, size);
  nbytes = fgetxattr(fd, xattr_data_name, xattr_data, size GETXATTR_TRAILER);
  if (nbytes == -1) {
    ret = -1;
    goto done;
  }
  if (nbytes != (ssize_t)size) {
    errno = EIO; /* lies but whatever */
    ret = -1;
    goto done;
  }
  storage_data = rb_str_new_static(xattr_data, nbytes);
  ret = bs_storage_to_output(handler, storage_data, output_data);
  if (ret != 0) {
    *exception_tag = ret;
    errno = 0;
  }
done:
  xfree(xattr_data);
  return ret;
}

static int
bs_update_key(int fd, uint32_t data_size, uint64_t current_mtime)
{
  struct xattr_key xattr_key;

  xattr_key = (struct xattr_key){
    .version        = current_version,
    .os_version     = os_version,
    .data_size      = data_size,
    .compile_option = current_compile_option_crc32,
    .ruby_revision  = current_ruby_revision,
    .mtime          = current_mtime,
  };

  return fsetxattr(fd, xattr_key_name, &xattr_key, (size_t)xattr_key_size, 0 SETXATTR_TRAILER);
}

/*
 * Open the file O_RDWR if possible, or O_RDONLY if that throws EACCES.
 * Set +writable+ to indicate which mode was used.
 */
static int
bs_open(const char * path, bool * writable)
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
bs_get_cache(int fd, struct xattr_key * key)
{
  ssize_t nbytes;

  nbytes = fgetxattr(fd, xattr_key_name, (void *)key, xattr_key_size GETXATTR_TRAILER);
  if (nbytes == -1 && errno != _ENOATTR) {
    return -1;
  }

  return (nbytes == (ssize_t)xattr_key_size && \
      key->version == current_version && \
      key->os_version == os_version && \
      key->compile_option == current_compile_option_crc32 && \
      key->ruby_revision == current_ruby_revision);
}

/*
 * Read an entire file into a char*
 * contents must be freed with xfree() when done.
 */
static size_t
bs_read_contents(int fd, size_t size, char ** contents)
{
  *contents = ALLOC_N(char, size);
  return read(fd, *contents, size);
}

static int
bs_close_and_unclobber_times(int * fd, const char * path, time_t atime, time_t mtime)
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
bs_input_to_output(VALUE handler, VALUE input_data, VALUE * output_data, int * exception_tag)
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
      rb_eBootsnap_CompileCache_Uncompilable, 0);
}

static int
bs_input_to_storage(VALUE handler, VALUE input_data, VALUE pathval, VALUE * storage_data)
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
bs_storage_to_output(VALUE handler, VALUE storage_data, VALUE * output_data)
{
  int state;
  struct s2o_data s2o_data = {
    .handler      = handler,
    .storage_data = storage_data,
  };
  *output_data = rb_protect(prot_storage_to_output, (VALUE)&s2o_data, &state);
  return state;
}

/* default no if empty, yes if present, no if "0" */
static int
logging_enabled()
{
  char * log = getenv("OPT_AOT_LOG");
  if (log == 0) {
    return 0;
  } else if (log[0] == '0') {
    return 0;
  } else {
    return 1;
  }
}
