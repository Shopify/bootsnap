#include "aot_compile_cache.h"
#include <sys/types.h>
#include <sys/xattr.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>


VALUE rb_cAOTCompileCache;
VALUE rb_cAOTCompileCache_Native;

static VALUE
aotcc_close(VALUE self, VALUE fdval)
{
  close(FIX2INT(fdval));
  return Qnil;
}

static VALUE
aotcc_fmtime(VALUE self, VALUE fdval)
{
  int fd;
  int ret;
  struct stat buf;

  fd = FIX2INT(fdval);

  ret = fstat(fd, &buf);

  if (ret == -1) {
    rb_raise(rb_eStandardError, "fstat64 failed with errno=%d", errno);
    __builtin_unreachable();
  }

  return INT2FIX((uint32_t)buf.st_mtime);
}

#define STACKABLE_DATA 32

static VALUE
aotcc_fgetxattr(VALUE self, VALUE fdval, VALUE attrval, VALUE sizeval)
{
  int fd;
  const char *attr;
  char sdata[STACKABLE_DATA];
  void *data;
  size_t size;
  ssize_t bytes;
  VALUE value;

  fd   = FIX2INT(fdval);
  attr = (const char *)RSTRING_PTR(attrval);
  size = FIX2INT(sizeval);

  if (size > STACKABLE_DATA) {
    data = malloc(size);
  } else {
    data = &sdata;
  }

#ifdef __APPLE__
  bytes = fgetxattr(fd, attr, data, size, 0, 0);
#else
  bytes = fgetxattr(fd, attr, data, size);
#endif

  if (bytes == -1) {
    if (size > STACKABLE_DATA) {
      free((void *)data);
    }
    if (errno == ENOATTR) {
      return Qnil;
    }
    rb_raise(rb_eStandardError, "fgetxattr failed with errno=%d", errno);
    __builtin_unreachable();
  }

  // TODO: if bytes != size, raise or something
  value = rb_str_new(data, size);

  if (size > STACKABLE_DATA) {
    free((void *)data);
  }
  return value;
}

static VALUE
aotcc_fsetxattr(VALUE self, VALUE fdval, VALUE attrval, VALUE dataval)
{
  int fd;
  const char *attr;
  const void *data;
  size_t size;
  int ret;

  fd   = FIX2INT(fdval);
  attr = (const char *)RSTRING_PTR(attrval);
  data = (const void *)RSTRING_PTR(dataval);
  size = RSTRING_LEN(dataval);

#ifdef __APPLE__
  ret = fsetxattr(fd, attr, data, size, 0, 0);
#else
  ret = fsetxattr(fd, attr, data, size, 0);
#endif

  if (ret == -1) {
    rb_raise(rb_eStandardError, "fsetxattr failed with errno=%d", errno);
    __builtin_unreachable();
  }

  return Qnil;
}

void
Init_aot_compile_cache(void)
{
  rb_cAOTCompileCache = rb_define_class("AOTCompileCache", rb_cObject);
  rb_cAOTCompileCache_Native = rb_define_module_under(rb_cAOTCompileCache, "Native");

  rb_define_module_function(
      rb_cAOTCompileCache_Native, "close", aotcc_close, 1);

  rb_define_module_function(
      rb_cAOTCompileCache_Native, "fmtime", aotcc_fmtime, 1);

  rb_define_module_function(
      rb_cAOTCompileCache_Native, "fgetxattr", aotcc_fgetxattr, 3);

  rb_define_module_function(
      rb_cAOTCompileCache_Native, "fsetxattr", aotcc_fsetxattr, 3);
}
