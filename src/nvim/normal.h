#ifndef NVIM_NORMAL_H
#define NVIM_NORMAL_H

#include "nvim/pos.h"
#include "nvim/buffer_defs.h"  // for win_T

/* Values for find_ident_under_cursor() */
#define FIND_IDENT      1       /* find identifier (word) */
#define FIND_STRING     2       /* find any string (WORD) */
#define FIND_EVAL       4       /* include "->", "[]" and "." */

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


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "normal.h.generated.h"
#endif
#endif  // NVIM_NORMAL_H
