#ifndef NEOVIM_NORMAL_H
#define NEOVIM_NORMAL_H

#include "pos.h"

/*
 * Arguments for operators.
 */
typedef struct oparg_S {
  int op_type;                  /* current pending operator type */
  int regname;                  /* register to use for the operator */
  int motion_type;              /* type of the current cursor motion */
  int motion_force;             /* force motion type: 'v', 'V' or CTRL-V */
  int use_reg_one;              /* TRUE if delete uses reg 1 even when not
                                   linewise */
  int inclusive;                /* TRUE if char motion is inclusive (only
                                   valid when motion_type is MCHAR */
  int end_adjusted;             /* backuped b_op_end one char (only used by
                                   do_format()) */
  pos_T start;                  /* start of the operator */
  pos_T end;                    /* end of the operator */
  pos_T cursor_start;           /* cursor position before motion for "gw" */

  long line_count;              /* number of lines from op_start to op_end
                                   (inclusive) */
  int empty;                    /* op_start and op_end the same (only used by
                                   do_change()) */
  int is_VIsual;                /* operator on Visual area */
  int block_mode;               /* current operator is Visual block mode */
  colnr_T start_vcol;           /* start col for block mode operator */
  colnr_T end_vcol;             /* end col for block mode operator */
  long prev_opcount;            /* ca.opcount saved for K_CURSORHOLD */
  long prev_count0;             /* ca.count0 saved for K_CURSORHOLD */
} oparg_T;

/*
 * Arguments for Normal mode commands.
 */
typedef struct cmdarg_S {
  oparg_T     *oap;             /* Operator arguments */
  int prechar;                  /* prefix character (optional, always 'g') */
  int cmdchar;                  /* command character */
  int nchar;                    /* next command character (optional) */
  int ncharC1;                  /* first composing character (optional) */
  int ncharC2;                  /* second composing character (optional) */
  int extra_char;               /* yet another character (optional) */
  long opcount;                 /* count before an operator */
  long count0;                  /* count before command, default 0 */
  long count1;                  /* count before command, default 1 */
  int arg;                      /* extra argument from nv_cmds[] */
  int retval;                   /* return: CA_* values */
  char_u      *searchbuf;       /* return: pointer to search pattern or NULL */
} cmdarg_T;

/* values for retval: */
#define CA_COMMAND_BUSY     1   /* skip restarting edit() once */
#define CA_NO_ADJ_OP_END    2   /* don't adjust operator end */

void init_normal_cmds(void);
void normal_cmd(oparg_T *oap, int toplevel);
void do_pending_operator(cmdarg_T *cap, int old_col, int gui_yank);
int do_mouse(oparg_T *oap, int c, int dir, long count, int fixindent);
void check_visual_highlight(void);
void end_visual_mode(void);
void reset_VIsual_and_resel(void);
void reset_VIsual(void);
int find_ident_under_cursor(char_u **string, int find_type);
int find_ident_at_pos(win_T *wp, linenr_T lnum, colnr_T startcol,
                      char_u **string,
                      int find_type);
void clear_showcmd(void);
int add_to_showcmd(int c);
void add_to_showcmd_c(int c);
void push_showcmd(void);
void pop_showcmd(void);
void do_check_scrollbind(int check);
void check_scrollbind(linenr_T topline_diff, long leftcol_diff);
int find_decl(char_u *ptr, int len, int locally, int thisblock,
              int searchflags);
void scroll_redraw(int up, long count);
void do_nv_ident(int c1, int c2);
int get_visual_text(cmdarg_T *cap, char_u **pp, int *lenp);
void start_selection(void);
void may_start_select(int c);

#endif /* NEOVIM_NORMAL_H */
