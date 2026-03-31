#pragma once

#include "nvim/autocmd_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Values for in_cinkeys()
enum {
  KEY_OPEN_FORW = 0x101,
  KEY_OPEN_BACK = 0x102,
  KEY_COMPLETE  = 0x103,  ///< end of completion
};

/// Values for change_indent()
enum {
  INDENT_SET = 1,  ///< set indent
  INDENT_INC = 2,  ///< increase indent
  INDENT_DEC = 3,  ///< decrease indent
};

/// flags for beginline()
enum {
  BL_WHITE = 1,  ///< cursor on first non-white in the line
  BL_SOL   = 2,  ///< use 'sol' option
  BL_FIX   = 4,  ///< don't leave cursor on a NUL
};

/// flags for insertchar()
enum {
  INSCHAR_FORMAT   = 1,   ///< force formatting
  INSCHAR_DO_COM   = 2,   ///< format comments
  INSCHAR_CTRLV    = 4,   ///< char typed just after CTRL-V
  INSCHAR_NO_FEX   = 8,   ///< don't use 'formatexpr'
  INSCHAR_COM_LIST = 16,  ///< format comments with list/2nd line indent
};

#include "edit.h.generated.h"
