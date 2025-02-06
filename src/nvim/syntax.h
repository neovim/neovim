#pragma once

#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/syntax_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

enum {
  HL_CONTAINED         = 0x01,     ///< not used on toplevel
  HL_TRANSP            = 0x02,     ///< has no highlighting
  HL_ONELINE           = 0x04,     ///< match within one line only
  HL_HAS_EOL           = 0x08,     ///< end pattern that matches with $
  HL_SYNC_HERE         = 0x10,     ///< sync point after this item (syncing only)
  HL_SYNC_THERE        = 0x20,     ///< sync point at current line (syncing only)
  HL_MATCH             = 0x40,     ///< use match ID instead of item ID
  HL_SKIPNL            = 0x80,     ///< nextgroup can skip newlines
  HL_SKIPWHITE         = 0x100,    ///< nextgroup can skip white space
  HL_SKIPEMPTY         = 0x200,    ///< nextgroup can skip empty lines
  HL_KEEPEND           = 0x400,    ///< end match always kept
  HL_EXCLUDENL         = 0x800,    ///< exclude NL from match
  HL_DISPLAY           = 0x1000,   ///< only used for displaying, not syncing
  HL_FOLD              = 0x2000,   ///< define fold
  HL_EXTEND            = 0x4000,   ///< ignore a keepend
  HL_MATCHCONT         = 0x8000,   ///< match continued from previous line
  HL_TRANS_CONT        = 0x10000,  ///< transparent item without contains arg
  HL_CONCEAL           = 0x20000,  ///< can be concealed
  HL_CONCEALENDS       = 0x40000,  ///< can be concealed
  HL_INCLUDED_TOPLEVEL = 0x80000,  ///< toplevel item in included syntax, allowed by contains=TOP
};

#define SYN_GROUP_STATIC(s) syn_check_group(S_LEN(s))

/// Array of highlight definitions, used for unit testing
extern const char *const highlight_init_cmdline[];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "syntax.h.generated.h"
#endif
