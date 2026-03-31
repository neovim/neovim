#pragma once

#include "nvim/api/private/defs.h"
#include "nvim/normal_defs.h"
#include "nvim/os/time_defs.h"

/// flags for do_put()
enum {
  PUT_FIXINDENT    = 1,   ///< make indent look nice
  PUT_CURSEND      = 2,   ///< leave cursor after end of new text
  PUT_CURSLINE     = 4,   ///< leave cursor on last line of new text
  PUT_LINE         = 8,   ///< put register as lines
  PUT_LINE_SPLIT   = 16,  ///< split line for linewise register
  PUT_LINE_FORWARD = 32,  ///< put linewise register below Visual sel.
  PUT_BLOCK_INNER  = 64,  ///< in block mode, do not add trailing spaces
};

/// Registers:
///      0 = register for latest (unnamed) yank
///   1..9 = registers '1' to '9', for deletes
/// 10..35 = registers 'a' to 'z'
///     36 = delete register '-'
///     37 = selection register '*'
///     38 = clipboard register '+'
enum {
  DELETION_REGISTER   = 36,
  NUM_SAVED_REGISTERS = 37,
  // The following registers should not be saved in ShaDa file:
  STAR_REGISTER       = 37,
  PLUS_REGISTER       = 38,
  NUM_REGISTERS       = 39,
};

/// Flags for get_reg_contents().
enum GRegFlags {
  kGRegNoExpr  = 1,  ///< Do not allow expression register.
  kGRegExprSrc = 2,  ///< Return expression itself for "=" register.
  kGRegList    = 4,  ///< Return list.
};

/// structure used by block_prep, op_delete and op_yank for blockwise operators
/// also op_change, op_shift, op_insert, op_replace - AKelly
struct block_def {
  int startspaces;           ///< 'extra' cols before first char
  int endspaces;             ///< 'extra' cols after last char
  int textlen;               ///< chars in block
  char *textstart;           ///< pointer to 1st char (partially) in block
  colnr_T textcol;           ///< index of chars (partially) in block
  colnr_T start_vcol;        ///< start col of 1st char wholly inside block
  colnr_T end_vcol;          ///< start col of 1st char wholly after block
  int is_short;              ///< true if line is too short to fit in block
  int is_MAX;                ///< true if curswant==MAXCOL when starting
  int is_oneChar;            ///< true if block within one character
  int pre_whitesp;           ///< screen cols of ws before block
  int pre_whitesp_c;         ///< chars of ws before block
  colnr_T end_char_vcols;    ///< number of vcols of post-block char
  colnr_T start_char_vcols;  ///< number of vcols of pre-block char
};

/// Definition of one register
typedef struct {
  String *y_array;          ///< Pointer to an array of Strings.
  size_t y_size;            ///< Number of lines in y_array.
  MotionType y_type;        ///< Register type
  colnr_T y_width;          ///< Register width (only valid for y_type == kBlockWise).
  Timestamp timestamp;      ///< Time when register was last modified.
  AdditionalData *additional_data;  ///< Additional data from ShaDa file.
} yankreg_T;

/// Modes for get_yank_register()
typedef enum {
  YREG_PASTE,
  YREG_YANK,
  YREG_PUT,
} yreg_mode_t;
