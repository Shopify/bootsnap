#include "bootsnap.h"

typedef struct rb_iseq_location_struct {
  VALUE path;
  VALUE absolute_path;
  VALUE base_label;
  VALUE label;
  VALUE first_lineno;
} rb_iseq_location_t;

struct iseq_line_info_entry {
  unsigned int position;
  unsigned int line_no;
};

struct rb_iseq_constant_body {
  uint8_t type; /* discarded info */
  unsigned int stack_max;
  unsigned int local_size;
  unsigned int iseq_size;
  const VALUE *iseq_encoded;
  uint8_t flags; /* discarded info */
  unsigned int size;
  int lead_num;
  int opt_num;
  int rest_start;
  int post_start;
  int post_num;
  int block_start;
  const VALUE *opt_table;
  void *keyword;
  rb_iseq_location_t location;
  const struct iseq_line_info_entry *line_info_table;
  const ID *local_table;
  const struct iseq_catch_table *catch_table;
  const struct rb_iseq_struct *parent_iseq;
  struct rb_iseq_struct *local_iseq;
  union iseq_inline_storage_entry *is_entries;
  struct rb_call_info *ci_entries;
  struct rb_call_cache *cc_entries;
  VALUE mark_ary;
  unsigned int local_table_size;
  unsigned int is_size;
  unsigned int ci_size;
  unsigned int ci_kw_size;
  unsigned int line_info_size;
}; /* MANY things inlined/elided in this definition */

typedef struct rb_iseq_struct {
  VALUE flags;
  VALUE reserved1;
  struct rb_iseq_constant_body *body;

  /* ... (truncated) ... */
} rb_iseq_t;

typedef struct rb_control_frame_struct {
  const VALUE *pc;
  VALUE *sp;
  const void *iseq;
  VALUE flag;
  VALUE self;
  VALUE *ep;
  const void *block_iseq;
  VALUE proc;
} rb_control_frame_t; /* pretty much accurate definition */

typedef struct rb_thread_struct {
  void *list_node_next; /* (inlined) */
  void *list_node_prev; /* (inlined) */
  VALUE self;
  void *vm; /* (voided type) */

  VALUE *stack;
  size_t stack_size;
  rb_control_frame_t *cfp;

  /* ... (truncated) ... */
} rb_thread_t;

static rb_thread_t *
get_thread()
{
  VALUE th_v;
  th_v = rb_funcall(rb_cThread, rb_intern("current"), 0);
  return RTYPEDDATA_DATA(th_v);
}

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

static VALUE
handle_iseq(rb_control_frame_t *cfp)
{
  const rb_iseq_t *iseq = cfp->iseq;
  VALUE path = iseq->body->location.path;
  int lineno = get_line_no(iseq, cfp->pc - iseq->body->iseq_encoded);
  VALUE ary = rb_ary_new2(2);
  rb_ary_push(ary, path);
  rb_ary_push(ary, INT2NUM(lineno));
  return ary;
}

static VALUE
handle_cfunc(rb_control_frame_t *cfp)
{
  return ID2SYM(rb_intern("cfunc"));
}

#define CFUNC_TYPE 0x61
#define TYPE_MASK  (~(~(VALUE)0<<8))

VALUE
lol(VALUE self, VALUE depth_v)
{
  Check_Type(depth_v, T_FIXNUM);
  off_t depth = (off_t)FIX2INT(depth_v);

  rb_thread_t *th = get_thread();

  /*                <- first cfp (end control frame)
   *  top frame (dummy)
   *  top frame (dummy)
   *  top frame     <- oldest_cfp
   *  top frame
   *  ...
   *  2nd frame     <- lev:0
   *  current frame <- th->cfp, newest_cfp
   */

  rb_control_frame_t *oldest_cfp = ((rb_control_frame_t *)((th)->stack + (th)->stack_size)) - 2;
  rb_control_frame_t *newest_cfp = th->cfp;
  rb_control_frame_t *cfp = newest_cfp + depth;

  if (cfp > oldest_cfp)
    rb_raise(rb_eArgError, "out of bounds");

  if (cfp->iseq) {
    if (cfp->pc) {
      return handle_iseq(cfp);
    }
  } else if ((cfp->flag & TYPE_MASK) == CFUNC_TYPE) {
    return handle_cfunc(cfp);
  }

  return Qnil;
}






