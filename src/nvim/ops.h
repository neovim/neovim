#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/api/private/defs.h"
#include "nvim/ascii_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/extmark_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/normal_defs.h"
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/os/time_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

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

/// Operator IDs; The order must correspond to opchars[] in ops.c!
enum {
  OP_NOP          = 0,   ///< no pending operation
  OP_DELETE       = 1,   ///< "d"  delete operator
  OP_YANK         = 2,   ///< "y"  yank operator
  OP_CHANGE       = 3,   ///< "c"  change operator
  OP_LSHIFT       = 4,   ///< "<"  left shift operator
  OP_RSHIFT       = 5,   ///< ">"  right shift operator
  OP_FILTER       = 6,   ///< "!"  filter operator
  OP_TILDE        = 7,   ///< "g~" switch case operator
  OP_INDENT       = 8,   ///< "="  indent operator
  OP_FORMAT       = 9,   ///< "gq" format operator
  OP_COLON        = 10,  ///< ":"  colon operator
  OP_UPPER        = 11,  ///< "gU" make upper case operator
  OP_LOWER        = 12,  ///< "gu" make lower case operator
  OP_JOIN         = 13,  ///< "J"  join operator, only for Visual mode
  OP_JOIN_NS      = 14,  ///< "gJ"  join operator, only for Visual mode
  OP_ROT13        = 15,  ///< "g?" rot-13 encoding
  OP_REPLACE      = 16,  ///< "r"  replace chars, only for Visual mode
  OP_INSERT       = 17,  ///< "I"  Insert column, only for Visual mode
  OP_APPEND       = 18,  ///< "A"  Append column, only for Visual mode
  OP_FOLD         = 19,  ///< "zf" define a fold
  OP_FOLDOPEN     = 20,  ///< "zo" open folds
  OP_FOLDOPENREC  = 21,  ///< "zO" open folds recursively
  OP_FOLDCLOSE    = 22,  ///< "zc" close folds
  OP_FOLDCLOSEREC = 23,  ///< "zC" close folds recursively
  OP_FOLDDEL      = 24,  ///< "zd" delete folds
  OP_FOLDDELREC   = 25,  ///< "zD" delete folds recursively
  OP_FORMAT2      = 26,  ///< "gw" format operator, keeps cursor pos
  OP_FUNCTION     = 27,  ///< "g@" call 'operatorfunc'
  OP_NR_ADD       = 28,  ///< "<C-A>" Add to the number or alphabetic character
  OP_NR_SUB       = 29,  ///< "<C-X>" Subtract from the number or alphabetic character
};

/// Flags for get_reg_contents().
enum GRegFlags {
  kGRegNoExpr  = 1,  ///< Do not allow expression register.
  kGRegExprSrc = 2,  ///< Return expression itself for "=" register.
  kGRegList    = 4,  ///< Return list.
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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ops.h.generated.h"
# include "ops.h.inline.generated.h"
#endif

/// Convert register name into register index
///
/// @param[in]  regname  Register name.
///
/// @return Index in y_regs array or -1 if register name was not recognized.
static inline int op_reg_index(const int regname)
  FUNC_ATTR_CONST
{
  if (ascii_isdigit(regname)) {
    return regname - '0';
  } else if (ASCII_ISLOWER(regname)) {
    return CHAR_ORD_LOW(regname) + 10;
  } else if (ASCII_ISUPPER(regname)) {
    return CHAR_ORD_UP(regname) + 10;
  } else if (regname == '-') {
    return DELETION_REGISTER;
  } else if (regname == '*') {
    return STAR_REGISTER;
  } else if (regname == '+') {
    return PLUS_REGISTER;
  } else {
    return -1;
  }
}

/// @see get_yank_register
/// @return  true when register should be inserted literally
/// (selection or clipboard)
static inline bool is_literal_register(const int regname)
  FUNC_ATTR_CONST
{
  return regname == '*' || regname == '+';
}

EXTERN LuaRef repeat_luaref INIT( = LUA_NOREF);  ///< LuaRef for "."
