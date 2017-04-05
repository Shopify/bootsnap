#include <stdint.h>
#include "ruby.h"

#define GET_THREAD() \
  (RTYPEDDATA_DATA(rb_funcall(rb_cThread, rb_intern("current"), 0)))

#define GENSYM2(a, b) a ## b
#define GENSYM1(a, b) GENSYM2(a, b)
#define GENSYM(a)     GENSYM1(a, __COUNTER__)
#define SKIP_BYTES(n) uint8_t GENSYM(_a)[(n)]

/* Ruby 2.3.3 */
#define SIZEOF_CFP 64

struct rb_trace_arg_struct {
  SKIP_BYTES(1 * sizeof(void *));
  void *th;
  void *cfp;
  SKIP_BYTES(1 * sizeof(ID) + 3 * sizeof(VALUE) + sizeof(int));
  int lineno;
  VALUE path;
};

#include "ruby/debug.h"

typedef struct rb_thread_struct {
  SKIP_BYTES(32);
  VALUE *stack;
  size_t stack_size;
  void *cfp;
} rb_thread_t;

VALUE
lol(VALUE self, VALUE depth_v)
{
  Check_Type(depth_v, T_FIXNUM);
  off_t depth = (off_t)FIX2INT(depth_v);

  rb_thread_t *th = GET_THREAD();

  void * target_cfp = th->cfp + depth * SIZEOF_CFP;
  void * oldest_cfp = (void *)(th->stack + th->stack_size) - 2;

  if (target_cfp > oldest_cfp) rb_raise(rb_eArgError, "out of bounds");

  rb_trace_arg_t ta = {
    .path = Qundef,
    .th   = th,
    .cfp  = target_cfp,
  };
  rb_tracearg_path(&ta);

  return rb_ary_new3(2, ta.path, INT2NUM(ta.lineno));
}
