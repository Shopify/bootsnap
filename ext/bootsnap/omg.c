#include "ruby.h"

#define GENSYM_CONCAT(name, salt) name ## salt
#define GENSYM2(name, salt)       GENSYM_CONCAT(name, salt)
#define GENSYM(name)              GENSYM2(name, __LINE__)
#define SKIP_BYTES(n)             uint8_t GENSYM(_a)[(n)]

typedef struct rb_iseq_location_struct {
  VALUE path;
  SKIP_BYTES(24);
  VALUE first_lineno;
} rb_iseq_location_t;

struct iseq_line_info_entry {
  unsigned int position;
  unsigned int line_no;
};

struct rb_iseq_constant_body {
  SKIP_BYTES(13);
  const VALUE *iseq_encoded;
  SKIP_BYTES(46);
  rb_iseq_location_t location;
  const struct iseq_line_info_entry *line_info_table;
  SKIP_BYTES(80);
  unsigned int line_info_size;
};

typedef struct rb_iseq_struct {
  SKIP_BYTES(16);
  struct rb_iseq_constant_body *body;
  /* ... (truncated) ... */
} rb_iseq_t;

typedef struct rb_control_frame_struct {
  const VALUE *pc;
  SKIP_BYTES(8);
  const void *iseq;
  SKIP_BYTES(40);
} rb_control_frame_t; /* can't truncate because we need size */

typedef struct rb_thread_struct {
  SKIP_BYTES(16);
  VALUE self;
  SKIP_BYTES(8);
  VALUE *stack;
  size_t stack_size;
  rb_control_frame_t *cfp;
  /* ... (truncated) ... */
} rb_thread_t;

static unsigned int
get_line_no(const rb_iseq_t *iseq, size_t pos)
{
  size_t i = 0, size = iseq->body->line_info_size;
  const struct iseq_line_info_entry *table = iseq->body->line_info_table;

  if (pos > 0)   pos--;
  if (size == 0) return 0;
  if (size == 1) return (&table[0])->line_no;

  for (i = 1; i < size; i++) {
    if (table[i].position == pos) {
      return (&table[i])->line_no;
    }
    if (table[i].position > pos) {
      return (&table[i-1])->line_no;
    }
  }

  return (&table[i-1])->line_no;
}

#define GET_THREAD() \
  (RTYPEDDATA_DATA(rb_funcall(rb_cThread, rb_intern("current"), 0)))

VALUE
lol(VALUE self, VALUE depth_v)
{
  Check_Type(depth_v, T_FIXNUM);
  off_t depth = (off_t)FIX2INT(depth_v);

  rb_thread_t *th = GET_THREAD();

  rb_control_frame_t *oldest_cfp = ((rb_control_frame_t *)((th)->stack + (th)->stack_size)) - 2;
  rb_control_frame_t *newest_cfp = th->cfp;
  rb_control_frame_t *cfp = newest_cfp + depth;

  VALUE path   = Qnil;
  VALUE lineno = INT2NUM(0);

  if (cfp > oldest_cfp) rb_raise(rb_eArgError, "out of bounds");
  if (cfp->iseq && cfp->pc) {
    const rb_iseq_t *iseq = cfp->iseq;
    path = iseq->body->location.path;
    lineno = INT2NUM(get_line_no(iseq, cfp->pc - iseq->body->iseq_encoded));
  }
  return rb_ary_new3(2, path, lineno);
}
