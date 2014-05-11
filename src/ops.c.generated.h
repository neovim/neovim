#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void shift_block(oparg_T *oap, int amount);
static void block_insert(oparg_T *oap, char_u *s, int b_insert, struct block_def *bdp);
static int stuff_yank(int regname, char_u *p);
static void put_reedit_in_typebuf(int silent);
static int put_in_typebuf(char_u *s, int esc, int colon, int silent);
static void stuffescaped(char_u *arg, int literally);
static void mb_adjust_opend(oparg_T *oap);
static inline void pchar(pos_T lp, int c);
static int swapchars(int op_type, pos_T *pos, int length);
static void free_yank(long n);
static void free_yank_all(void);
static void yank_copy_line(struct block_def *bd, long y_idx);
static void dis_msg(char_u *p, int skip_esc);
static char_u *skip_comment(char_u *line, int process, int include_space, int *is_comment);
static int same_leader(linenr_T lnum, int leader1_len, char_u *leader1_flags, int leader2_len, char_u *leader2_flags);
static int ends_in_white(linenr_T lnum);
static int fmt_check_par(linenr_T lnum, int *leader_len, char_u **leader_flags, int do_comments);
static void block_prep(oparg_T *oap, struct block_def *bdp, linenr_T lnum, int is_del);
static void reverse_line(char_u *s);
static void str_to_reg(struct yankreg *y_ptr, int yank_type, char_u *str, long len, long blocklen);
static long line_count_info(char_u *line, long *wc, long *cc, long limit, int eol_size);
#include "func_attr.h"
