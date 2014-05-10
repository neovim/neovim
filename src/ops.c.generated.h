static long line_count_info(char_u *line, long *wc, long *cc,
                            long limit,
                            int eol_size);
static void reverse_line(char_u *s);
static int swapchars(int op_type, pos_T *pos, int length);
static int fmt_check_par(linenr_T, int *, char_u **, int do_comments);
static int same_leader(linenr_T lnum, int, char_u *, int, char_u *);
static int ends_in_white(linenr_T lnum);
static void str_to_reg(struct yankreg *y_ptr, int type, char_u *str,
                       long len,
                       long blocklen);
static void block_prep(oparg_T *oap, struct block_def *, linenr_T, int);
static char_u   *skip_comment(char_u *line, int process,
                              int include_space,
                              int *is_comment);
static void dis_msg(char_u *p, int skip_esc);
static void yank_copy_line(struct block_def *bd, long y_idx);
static void free_yank_all(void);
static void free_yank(long);
static void mb_adjust_opend(oparg_T *oap);
static void stuffescaped(char_u *arg, int literally);
static int put_in_typebuf(char_u *s, int esc, int colon,
                          int silent);
static void put_reedit_in_typebuf(int silent);
static int stuff_yank(int, char_u *);
static void block_insert(oparg_T *oap, char_u *s, int b_insert,
                         struct block_def*bdp);
static void shift_block(oparg_T *oap, int amount);
