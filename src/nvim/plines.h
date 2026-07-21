#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/decoration.h"
#include "nvim/marktree_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

typedef bool CSType;

enum {
  kCharsizeRegular,
  kCharsizeFast,
};

/// Conceal-awareness spans two column domains:
///
/// - "vcol" (virtual column): position in the buffer's own coordinate space, as if nothing were
///   concealed. What most of this file computes and returns.
/// - "screen-layout column" ("scr_vcol" in charsize_regular()): "vcol" minus the cells hidden by
///   persistent (marktree) conceal so far on the line, tracked in "scr_vcol_offset" below.
///   'showbreak'/'breakindent'/'linebreak' row boundaries use it; 'tabstop' width does not, since
///   concealing text before a tab must not shrink the tab stop.
///
/// Callers keep "vcol" raw and let ConcealWalk maintain "scr_vcol_offset"; charsize_regular()
/// derives scr_vcol from the two.
///
/// Argument for char size functions.
typedef struct {
  win_T *win;
  char *line;                ///< Start of the line.

  bool use_tabstop;          ///< Use 'tabstop' instead of char2cells() for a TAB.
  int indent_width;          ///< Width of 'showbreak' and 'breakindent' on wrapped
                             ///< parts of lines, INT_MIN if not yet calculated.

  int virt_row;              ///< Row for virtual text, -1 if no virtual text.
  int cur_text_width_left;   ///< Width of virtual text left of cursor.
  int cur_text_width_right;  ///< Width of virtual text right of cursor.

  int max_head_vcol;         ///< See charsize_regular().
  int scr_vcol_offset;       ///< Cells hidden by conceal so far, 0 when not conceal-aware.
  MarkTreeIter iter[1];

  int row;                   ///< Buffer row (lnum - 1), or -1 for a bare string.
  bool maybe_conceal;        ///< Line may have persistent conceal hiding cells.
} CharsizeArg;

typedef struct {
  int width;
  int head;  ///< Size of 'breakindent' etc. before the character (included in width).
  int tail;  ///< Size of 'linebreak' after the character (included in width).
} CharSize;

/// Tracks conceal-hidden width in csarg->scr_vcol_offset while a caller walks a line's characters.
///
/// Usage: conceal_walk_start(), then per character (in buffer-column order): measure it, then
/// conceal_walk_advance() with its column and width. conceal_walk_end() when done.
typedef struct {
  DecorState state;
  bool active;
} ConcealWalk;

/// Resume point for extconceal_off_before(), so a caller querying one line at increasing positions
/// measures each character once instead of once per query. Zero-initialize per line; holds no
/// marktree iterator, so it stays valid while other conceal walks run.
typedef struct {
  colnr_T col;     ///< Bytes measured so far.
  int vcol;        ///< Virtual column at "col".
  colnr_T hidden;  ///< Cells hidden by conceal before "col".
} ConcealOffState;

#include "plines.h.generated.h"
#include "plines.h.inline.generated.h"

/// Get the number of cells taken up on the screen by the given character at vcol.
/// "csarg->cur_text_width_left" and "csarg->cur_text_width_right" are set
/// to the extra size for inline virtual text.
///
/// When "csarg->max_head_vcol" is positive, only count in "head" the size
/// of 'showbreak'/'breakindent' before "csarg->max_head_vcol".
/// When "csarg->max_head_vcol" is negative, only count in "head" the size
/// of 'showbreak'/'breakindent' before where cursor should be placed.
static inline CharSize win_charsize(CSType cstype, int vcol, char *ptr, int32_t chr,
                                    CharsizeArg *csarg)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE
{
  if (cstype == kCharsizeFast) {
    return charsize_fast(csarg, ptr, vcol, chr);
  } else {
    return charsize_regular(csarg, ptr, vcol, chr);
  }
}

/// @return true if conceal tracking is active for csarg's line (csarg->maybe_conceal).
static inline bool conceal_walk_start(CharsizeArg *csarg, ConcealWalk *walk)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  walk->active = linesize_conceal_start(csarg, &walk->state);
  csarg->scr_vcol_offset = 0;
  return walk->active;
}

/// Call once per character, right after measuring it, in increasing "col" order.
///
/// @return cells of "width" hidden by conceal for this character (0 if visible or inactive).
static inline int conceal_walk_advance(CharsizeArg *csarg, ConcealWalk *walk, int col, int width)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  if (!walk->active) {
    return 0;
  }
  int const hidden = linesize_conceal_hidden(csarg, &walk->state, col, width);
  csarg->scr_vcol_offset += hidden;
  return hidden;
}

static inline void conceal_walk_end(ConcealWalk *walk)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  if (walk->active) {
    linesize_conceal_end(&walk->state);
  }
}

/// Return the number of cells the string "s" will take on the screen,
/// taking into account the size of a tab.
///
/// @param s
///
/// @return Number of cells the string will take on the screen.
static inline int linetabsize_str(char *s)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE
{
  return linetabsize_col(0, s);
}

/// Like linetabsize_str(), but for a given window instead of the current one.
/// Doesn't count the size of 'listchars' "eol".
///
/// @param wp
/// @param line
/// @param len
///
/// @return Number of cells the string will take on the screen.
static inline int win_linetabsize(win_T *wp, linenr_T lnum, char *line, colnr_T len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE
{
  CharsizeArg csarg;
  CSType const cstype = init_charsize_arg(&csarg, wp, lnum, line);
  if (cstype == kCharsizeFast) {
    return linesize_fast(&csarg, 0, len);
  } else {
    return linesize_regular(&csarg, 0, len, false);
  }
}

/// Flags used by getvcol()
enum {
  GETVCOL_END_EXCL_LBR = 1,
};
