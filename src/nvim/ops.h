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
#include "nvim/register_defs.h"
#include "nvim/types_defs.h"

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

#include "ops.h.generated.h"
#include "ops.h.inline.generated.h"

EXTERN LuaRef repeat_luaref INIT( = LUA_NOREF);  ///< LuaRef for "."
