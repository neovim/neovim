#pragma once

#include <stdbool.h>

#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

// Values for cmd_flags.
#define NV_NCH      0x01            // May need to get a second char.
#define NV_NCH_NOP  (0x02|NV_NCH)   // Get second char when no operator pending.
#define NV_NCH_ALW  (0x04|NV_NCH)   // Always get a second char.
#define NV_LANG     0x08            // Second char needs language adjustment.
#define NV_SS       0x10            // May start selection.
#define NV_SSS      0x20            // May start selection with shift modifier.
#define NV_STS      0x40            // May stop selection without shift modif.
#define NV_RL       0x80            // 'rightleft' modifies command.
#define NV_KEEPREG  0x100           // Don't clear regname.
#define NV_NCW      0x200           // Not allowed in command-line window.
#define NV_NCH_ARG  0x400           // Second char is a typed operand (mark/reg name), not part of
                                    // the name (see NV_LANG for f/t/r).
#define NV_MOTION   0x800           // Cursor-relative motion.
#define NV_JUMP     0x1000          // Absolute motion, target independent of the cursor ("G").

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
  bool restore_cursor;     ///< restore cursor after yank

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

/// A Visual selection's mode and extent (line/column span, not absolute positions), so an
/// equal-sized region can be re-applied starting at the cursor: {count}v reselect.
typedef struct {
  int mode;             ///< 'v', 'V', or Ctrl-V
  linenr_T line_count;  ///< number of lines
  colnr_T vcol;         ///< number of cols or end column (MAXCOL: to end of line)
} VisualExtent;

/// Visual/Select mode state, as one global "group" (Visual).
typedef struct {
  pos_T start;            ///< Start position of the active Visual selection.
  bool active;            ///< Whether Visual mode is active.
  bool select;            ///< Whether Select mode is active.
  int select_reg;         ///< Register name for Select mode.
  bool select_exclu_adj;  ///< Cursor was incremented during exclusive selection.
  int restart_select;     ///< Restart Select mode when next cmd finished.
  int reselect;           ///< Restart the selection after a Select-mode mapping or menu.
  int mode;               ///< Type of Visual mode: 'v', 'V', Ctrl-V.
  VisualExtent resel;     ///< Previous Visual area's extent, for {count}v reselect.
} VisualState;

/// Visual area. The region when Visual mode ended, or the active region (visualinfo()).
typedef struct {
  pos_T vi_start;       ///< Start pos.
  pos_T vi_end;         ///< End position.
  int vi_mode;          ///< Visual.mode.
  colnr_T vi_curswant;  ///< MAXCOL from w_curswant.
} visualinfo_T;

/// Replacement for nchar used by nv_replace().
enum {
  REPLACE_CR_NCHAR  = -1,
  REPLACE_NL_NCHAR  = -2,
};

enum { SHOWCMD_COLS = 10, };  ///< columns needed by shown command
enum { SHOWCMD_BUFLEN = SHOWCMD_COLS + 1 + 30, };
