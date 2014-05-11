#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int no_Magic(int x);
static int toggle_Magic(int x);
static int re_multi_type(int c);
static int backslash_trans(int c);
static int get_char_class(char_u **pp);
static void init_class_tab(void);
static int get_equi_class(char_u **pp);
static void reg_equi_class(int c);
static int get_coll_element(char_u **pp);
static void get_cpo_flags(void);
static char_u *skip_anyof(char_u *p);
static regprog_T *bt_regcomp(char_u *expr, int re_flags);
static void bt_regfree(regprog_T *prog);
static void regcomp_start(char_u *expr, int re_flags);
static char_u *reg(int paren, int *flagp);
static char_u *regbranch(int *flagp);
static char_u *regconcat(int *flagp);
static char_u *regpiece(int *flagp);
static char_u *regatom(int *flagp);
static int use_multibytecode(int c);
static char_u *regnode(int op);
static void regc(int b);
static void regmbc(int c);
static void reginsert(int op, char_u *opnd);
static void reginsert_nr(int op, long val, char_u *opnd);
static void reginsert_limits(int op, long minval, long maxval, char_u *opnd);
static char_u *re_put_long(char_u *p, long_u val);
static void regtail(char_u *p, char_u *val);
static void regoptail(char_u *p, char_u *val);
static void initchr(char_u *str);
static void save_parse_state(parse_state_T *ps);
static void restore_parse_state(parse_state_T *ps);
static int peekchr(void);
static void skipchr(void);
static void skipchr_keepstart(void);
static int getchr(void);
static void ungetchr(void);
static int gethexchrs(int maxinputlen);
static int getdecchrs(void);
static int getoctchrs(void);
static int coll_get_char(void);
static int read_limits(long *minval, long *maxval);
static char_u *reg_getline(linenr_T lnum);
static int bt_regexec_nl(regmatch_T *rmp, char_u *line, colnr_T col, _Bool line_lbr);
static long bt_regexec_both(char_u *line, colnr_T col, proftime_T *tm);
static reg_extmatch_T *make_extmatch(void);
static long regtry(bt_regprog_T *prog, colnr_T col);
static int reg_prev_class(void);
static int reg_match_visual(void);
static int regmatch(char_u *scan);
static regitem_T *regstack_push(regstate_T state, char_u *scan);
static void regstack_pop(char_u **scan);
static int regrepeat(char_u *p, long maxcount);
static char_u *regnext(char_u *p);
static int prog_magic_wrong(void);
static void cleanup_subexpr(void);
static void cleanup_zsubexpr(void);
static void save_subexpr(regbehind_T *bp);
static void restore_subexpr(regbehind_T *bp);
static void reg_nextline(void);
static void reg_save(regsave_T *save, garray_T *gap);
static void reg_restore(regsave_T *save, garray_T *gap);
static int reg_save_equal(regsave_T *save);
static void save_se_multi(save_se_T *savep, lpos_T *posp);
static void save_se_one(save_se_T *savep, char_u **pp);
static int re_num_cmp(long_u val, char_u *scan);
static int match_with_backref(linenr_T start_lnum, colnr_T start_col, linenr_T end_lnum, colnr_T end_col, int *bytelen);
static void mb_decompose(int c, int *c1, int *c2, int *c3);
static int cstrncmp(char_u *s1, char_u *s2, int *n);
static char_u *cstrchr(char_u *s, int c);
static int vim_regsub_both(char_u *source, char_u *dest, int copy, int magic, int backslash);
static char_u *reg_getline_submatch(linenr_T lnum);
#include "func_attr.h"
