#ifndef NVIM_OPS_H
#define NVIM_OPS_H

#include "nvim/func_attr.h"
#include "nvim/types.h"

/* flags for do_put() */
#define PUT_FIXINDENT   1       /* make indent look nice */
#define PUT_CURSEND     2       /* leave cursor after end of new text */
#define PUT_CURSLINE    4       /* leave cursor on last line of new text */
#define PUT_LINE        8       /* put register as lines */
#define PUT_LINE_SPLIT  16      /* split line for linewise register */
#define PUT_LINE_FORWARD 32     /* put linewise register below Visual sel. */

/*
 * Operator IDs; The order must correspond to opchars[] in ops.c!
 */
#define OP_NOP          0       /* no pending operation */
#define OP_DELETE       1       /* "d"  delete operator */
#define OP_YANK         2       /* "y"  yank operator */
#define OP_CHANGE       3       /* "c"  change operator */
#define OP_LSHIFT       4       /* "<"  left shift operator */
#define OP_RSHIFT       5       /* ">"  right shift operator */
#define OP_FILTER       6       /* "!"  filter operator */
#define OP_TILDE        7       /* "g~" switch case operator */
#define OP_INDENT       8       /* "="  indent operator */
#define OP_FORMAT       9       /* "gq" format operator */
#define OP_COLON        10      /* ":"  colon operator */
#define OP_UPPER        11      /* "gU" make upper case operator */
#define OP_LOWER        12      /* "gu" make lower case operator */
#define OP_JOIN         13      /* "J"  join operator, only for Visual mode */
#define OP_JOIN_NS      14      /* "gJ"  join operator, only for Visual mode */
#define OP_ROT13        15      /* "g?" rot-13 encoding */
#define OP_REPLACE      16      /* "r"  replace chars, only for Visual mode */
#define OP_INSERT       17      /* "I"  Insert column, only for Visual mode */
#define OP_APPEND       18      /* "A"  Append column, only for Visual mode */
#define OP_FOLD         19      /* "zf" define a fold */
#define OP_FOLDOPEN     20      /* "zo" open folds */
#define OP_FOLDOPENREC  21      /* "zO" open folds recursively */
#define OP_FOLDCLOSE    22      /* "zc" close folds */
#define OP_FOLDCLOSEREC 23      /* "zC" close folds recursively */
#define OP_FOLDDEL      24      /* "zd" delete folds */
#define OP_FOLDDELREC   25      /* "zD" delete folds recursively */
#define OP_FORMAT2      26      /* "gw" format operator, keeps cursor pos */
#define OP_FUNCTION     27      /* "g@" call 'operatorfunc' */



/* ops.c */
int get_op_type(int char1, int char2);
int op_on_lines(int op);
int get_op_char(int optype);
int get_extra_op_char(int optype);
void op_shift(oparg_T *oap, int curs_top, int amount);
void shift_line(int left, int round, int amount, int call_changed_bytes);
void op_reindent(oparg_T *oap, int (*how)(void));
int get_expr_register(void);
void set_expr_line(char_u *new_line);
char_u *get_expr_line(void);
char_u *get_expr_line_src(void);
int valid_yank_reg(int regname, int writing);
void get_yank_register(int regname, int writing);
void *get_register(int name, int copy) FUNC_ATTR_NONNULL_RET;
void put_register(int name, void *reg);
int yank_register_mline(int regname);
int do_record(int c);
int do_execreg(int regname, int colon, int addcr, int silent);
int insert_reg(int regname, int literally);
int get_spec_reg(int regname, char_u **argp, int *allocated, int errmsg);
int cmdline_paste_reg(int regname, int literally, int remcr);
int op_delete(oparg_T *oap);
int op_replace(oparg_T *oap, int c);
void op_tilde(oparg_T *oap);
int swapchar(int op_type, pos_T *pos);
void op_insert(oparg_T *oap, long count1);
int op_change(oparg_T *oap);
void init_yank(void);
void clear_registers(void);
int op_yank(oparg_T *oap, int deleting, int mess);
void do_put(int regname, int dir, long count, int flags);
void adjust_cursor_eol(void);
int preprocs_left(void);
int get_register_name(int num);
void ex_display(exarg_T *eap);
int do_join(long count,
            int insert_space,
            int save_undo,
            int use_formatoptions,
            bool setmark);
void op_format(oparg_T *oap, int keep_cursor);
void op_formatexpr(oparg_T *oap);
int fex_format(linenr_T lnum, long count, int c);
void format_lines(linenr_T line_count, int avoid_fex);
int paragraph_start(linenr_T lnum);
int do_addsub(int command, linenr_T Prenum1);
int read_viminfo_register(vir_T *virp, int force);
void write_viminfo_registers(FILE *fp);
char_u get_reg_type(int regname, long *reglen);
char_u *get_reg_contents(int regname, int allowexpr, int expr_src);
void write_reg_contents(int name, char_u *str, int maxlen,
                        int must_append);
void write_reg_contents_ex(int name, char_u *str, int maxlen,
                           int must_append, int yank_type,
                           long block_len);
void clear_oparg(oparg_T *oap);
void cursor_pos_info(void);

#endif /* NVIM_OPS_H */
