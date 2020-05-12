#ifndef NVIM_OPS_H
#define NVIM_OPS_H

#include <stdbool.h>

#include "nvim/macros.h"
#include "nvim/ascii.h"
#include "nvim/types.h"
#include "nvim/eval/typval.h"
#include "nvim/os/time.h"
#include "nvim/normal.h" // for MotionType and oparg_T
#include "nvim/ex_cmds_defs.h" // for exarg_T

typedef int (*Indenter)(void);

/* flags for do_put() */
#define PUT_FIXINDENT    1      /* make indent look nice */
#define PUT_CURSEND      2      /* leave cursor after end of new text */
#define PUT_CURSLINE     4      /* leave cursor on last line of new text */
#define PUT_LINE         8      /* put register as lines */
#define PUT_LINE_SPLIT   16     /* split line for linewise register */
#define PUT_LINE_FORWARD 32     /* put linewise register below Visual sel. */

/*
 * Registers:
 *      0 = register for latest (unnamed) yank
 *   1..9 = registers '1' to '9', for deletes
 * 10..35 = registers 'a' to 'z'
 *     36 = delete register '-'
 *     37 = selection register '*'
 *     38 = clipboard register '+'
 */
#define DELETION_REGISTER 36
#define NUM_SAVED_REGISTERS 37
// The following registers should not be saved in ShaDa file:
#define STAR_REGISTER 37
#define PLUS_REGISTER 38
#define NUM_REGISTERS 39

// Operator IDs; The order must correspond to opchars[] in ops.c!
#define OP_NOP          0       // no pending operation
#define OP_DELETE       1       // "d"  delete operator
#define OP_YANK         2       // "y"  yank operator
#define OP_CHANGE       3       // "c"  change operator
#define OP_LSHIFT       4       // "<"  left shift operator
#define OP_RSHIFT       5       // ">"  right shift operator
#define OP_FILTER       6       // "!"  filter operator
#define OP_TILDE        7       // "g~" switch case operator
#define OP_INDENT       8       // "="  indent operator
#define OP_FORMAT       9       // "gq" format operator
#define OP_COLON        10      // ":"  colon operator
#define OP_UPPER        11      // "gU" make upper case operator
#define OP_LOWER        12      // "gu" make lower case operator
#define OP_JOIN         13      // "J"  join operator, only for Visual mode
#define OP_JOIN_NS      14      // "gJ"  join operator, only for Visual mode
#define OP_ROT13        15      // "g?" rot-13 encoding
#define OP_REPLACE      16      // "r"  replace chars, only for Visual mode
#define OP_INSERT       17      // "I"  Insert column, only for Visual mode
#define OP_APPEND       18      // "A"  Append column, only for Visual mode
#define OP_FOLD         19      // "zf" define a fold
#define OP_FOLDOPEN     20      // "zo" open folds
#define OP_FOLDOPENREC  21      // "zO" open folds recursively
#define OP_FOLDCLOSE    22      // "zc" close folds
#define OP_FOLDCLOSEREC 23      // "zC" close folds recursively
#define OP_FOLDDEL      24      // "zd" delete folds
#define OP_FOLDDELREC   25      // "zD" delete folds recursively
#define OP_FORMAT2      26      // "gw" format operator, keeps cursor pos
#define OP_FUNCTION     27      // "g@" call 'operatorfunc'
#define OP_NR_ADD       28      // "<C-A>" Add to the number or alphabetic
                                // character (OP_ADD conflicts with Perl)
#define OP_NR_SUB       29      // "<C-X>" Subtract from the number or
                                // alphabetic character

/// Flags for get_reg_contents().
enum GRegFlags {
  kGRegNoExpr  = 1,  ///< Do not allow expression register.
  kGRegExprSrc = 2,  ///< Return expression itself for "=" register.
  kGRegList    = 4   ///< Return list.
};

/// Definition of one register
typedef struct yankreg {
  char_u **y_array;   ///< Pointer to an array of line pointers.
  size_t y_size;      ///< Number of lines in y_array.
  MotionType y_type;  ///< Register type
  colnr_T y_width;    ///< Register width (only valid for y_type == kBlockWise).
  Timestamp timestamp;  ///< Time when register was last modified.
  dict_T *additional_data;  ///< Additional data from ShaDa file.
} yankreg_T;

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
    return CharOrdLow(regname) + 10;
  } else if (ASCII_ISUPPER(regname)) {
    return CharOrdUp(regname) + 10;
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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ops.h.generated.h"
#endif
#endif  // NVIM_OPS_H
