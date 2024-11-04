#pragma once

#include <stdbool.h>

#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

/// Motion types, used for operators and for yank/delete registers.
///
/// The three valid numerical values must not be changed, as they
/// are used in external communication and serialization.
typedef enum {
  kMTCharWise = 0,     ///< character-wise movement/register
  kMTLineWise = 1,     ///< line-wise movement/register
  kMTBlockWise = 2,    ///< block-wise movement/register
  kMTUnknown = -1,     ///< Unknown or invalid motion type
} MotionType;

/// Arguments for operators.
typedef struct {
  int op_type;             ///< current pending operator type
  int regname;             ///< register to use for the operator
  MotionType motion_type;  ///< type of the current cursor motion
  int motion_force;        ///< force motion type: 'v', 'V' or CTRL-V
  bool use_reg_one;        ///< true if delete uses reg 1 even when not
                           ///< linewise
  bool inclusive;          ///< true if char motion is inclusive (only
                           ///< valid when motion_type is kMTCharWise)
  bool end_adjusted;       ///< backuped b_op_end one char (only used by
                           ///< do_format())
  pos_T start;             ///< start of the operator
  pos_T end;               ///< end of the operator
  pos_T cursor_start;      ///< cursor position before motion for "gw"

  linenr_T line_count;     ///< number of lines from op_start to op_end (inclusive)
  bool empty;              ///< op_start and op_end the same (only used by op_change())
  bool is_VIsual;          ///< operator on Visual area
  colnr_T start_vcol;      ///< start col for block mode operator
  colnr_T end_vcol;        ///< end col for block mode operator
  int prev_opcount;        ///< ca.opcount saved for K_EVENT
  int prev_count0;         ///< ca.count0 saved for K_EVENT
  bool excl_tr_ws;         ///< exclude trailing whitespace for yank of a block
} oparg_T;

/// Arguments for Normal mode commands.
typedef struct {
  oparg_T *oap;     ///< Operator arguments
  int prechar;      ///< prefix character (optional, always 'g')
  int cmdchar;      ///< command character
  int nchar;        ///< next command character (optional)
  char nchar_composing[MAX_SCHAR_SIZE];  ///< next char with composing chars (optional)
  int nchar_len;    ///< len of nchar_composing (when zero, use nchar instead)
  int extra_char;   ///< yet another character (optional)
  int opcount;      ///< count before an operator
  int count0;       ///< count before command, default 0
  int count1;       ///< count before command, default 1
  int arg;          ///< extra argument from nv_cmds[]
  int retval;       ///< return: CA_* values
  char *searchbuf;  ///< return: pointer to search pattern or NULL
} cmdarg_T;

/// values for retval:
enum {
  CA_COMMAND_BUSY  = 1,  ///< skip restarting edit() once
  CA_NO_ADJ_OP_END = 2,  ///< don't adjust operator end
};

/// Replacement for nchar used by nv_replace().
enum {
  REPLACE_CR_NCHAR  = -1,
  REPLACE_NL_NCHAR  = -2,
};

enum { SHOWCMD_COLS = 10, };  ///< columns needed by shown command
enum { SHOWCMD_BUFLEN = SHOWCMD_COLS + 1 + 30, };
