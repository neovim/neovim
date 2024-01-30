#pragma once

#include <stdbool.h>

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Values for file_name_in_line()
enum {
  FNAME_MESS  = 1,   ///< give error message
  FNAME_EXP   = 2,   ///< expand to path
  FNAME_HYP   = 4,   ///< check for hypertext link
  FNAME_INCL  = 8,   ///< apply 'includeexpr'
  FNAME_REL   = 16,  ///< ".." and "./" are relative to the (current)
                     ///< file instead of the current directory
  FNAME_UNESC = 32,  ///< remove backslashes used for escaping
};

/// arguments for win_split()
enum {
  WSP_ROOM    = 0x01,   ///< require enough room
  WSP_VERT    = 0x02,   ///< split/equalize vertically
  WSP_HOR     = 0x04,   ///< equalize horizontally
  WSP_TOP     = 0x08,   ///< window at top-left of shell
  WSP_BOT     = 0x10,   ///< window at bottom-right of shell
  WSP_HELP    = 0x20,   ///< creating the help window
  WSP_BELOW   = 0x40,   ///< put new window below/right
  WSP_ABOVE   = 0x80,   ///< put new window above/left
  WSP_NEWLOC  = 0x100,  ///< don't copy location list
  WSP_NOENTER = 0x200,  ///< don't enter the new window
};

enum {
  MIN_COLUMNS = 12,   ///< minimal columns for screen
  MIN_LINES   = 2,    ///< minimal lines for screen
  STATUS_HEIGHT = 1,  ///< height of a status line under a window
};

enum {
  /// Lowest number used for window ID. Cannot have this many windows per tab.
  LOWEST_WIN_ID = 1000,
};

EXTERN int tabpage_move_disallowed INIT( = 0);  ///< moving tabpages around disallowed

/// Set to true if 'cmdheight' was explicitly set to 0.
EXTERN bool p_ch_was_zero INIT( = false);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "window.h.generated.h"
#endif
