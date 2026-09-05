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

typedef struct {
  DecorState anchor;
  DecorState next;
  DecorState width;
  bool anchor_initialized;
  bool anchor_active;
  bool next_initialized;
  bool next_active;
  bool width_initialized;
  bool width_active;
  bool next_cached;
  int next_start;
  int next_end;
  int next_char;
  int word_start;  ///< Next word already reached by the width lookahead.
} LinebreakState;

/// Raw virtual-column queries disable "maybe_conceal", including conceal-dependent wrap prefixes.
/// Screen walks instead place prefixes at displayed row boundaries. Their "vcol" still includes
/// hidden source cells for tab sizing; subtracting "scr_vcol_offset" gives the displayed column.
///
/// Argument for char size functions.
typedef struct {
  win_T *win;
  char *line;                ///< Start of the line.

  bool use_tabstop;          ///< Use 'tabstop' instead of char2cells() for a TAB.
  int indent_width;          ///< Width of 'showbreak' and 'breakindent' on wrapped
                             ///< parts of lines, INT_MIN if not yet calculated.

  int virt_row;              ///< Row for virtual text, -1 if no virtual text.
  bool skip_cur_text;        ///< Don't count inline text at the measured character or advance iter.
                             ///< A CharsizeArg with this set cannot be reused for a later character.
  int cur_text_width_left;   ///< Width of virtual text left of cursor.
  int cur_text_width_right;  ///< Width of virtual text right of cursor.

  int max_head_vcol;         ///< See charsize_regular().
  int scr_vcol_offset;       ///< Source cells minus displayed cells so far.
  MarkTreeIter iter[1];

  int row;                   ///< Buffer row (lnum - 1), or -1 for a bare string.
  bool maybe_conceal;        ///< Line may have persistent conceal hiding cells.
  DecorState *conceal_state;  ///< Current character's persistent conceal, if walking a line.
  LinebreakState *linebreak_state;  ///< Monotonic conceal lookahead state, if walking a line.
} CharsizeArg;

typedef struct {
  int width;
  int body;  ///< Character and inline virtual text, excluding wrap prefixes and linebreak tail.
  int head;  ///< Size of 'breakindent' etc. before the character (included in width).
  int tail;  ///< Size of 'linebreak' after the character (included in width).
  bool linebreak;  ///< This character ends a break run followed by a word.
} CharSize;

/// Tracks conceal-hidden width in csarg->scr_vcol_offset while a caller walks a line's characters.
///
/// Usage: conceal_walk_start(), then per character (in buffer-column order): measure it, then
/// conceal_walk_advance() with its column and size. conceal_walk_end() when done.
typedef struct {
  DecorState state;
  LinebreakState linebreak;
  bool active;
} ConcealWalk;

/// Resume point for extconceal_off_before(). Zero-initialize per line and release with
/// extconceal_off_end() when finished or when callbacks change the marktree.
typedef struct {
  CharsizeArg csarg;
  ConcealWalk walk;
  colnr_T col;     ///< Bytes measured so far.
  int vcol;        ///< Virtual column at "col".
  bool initialized;
  bool provider_ready;  ///< Provider conceal is already in the marktree.
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

/// May run an `_on_conceal` callback that frees the line buffer, so re-read csarg->line after this
/// call; it is refreshed here.
///
/// @return true if conceal tracking is active for csarg's line (csarg->maybe_conceal).
static inline bool conceal_walk_start(CharsizeArg *csarg, ConcealWalk *walk)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  walk->linebreak = (LinebreakState){ 0 };
  csarg->linebreak_state = &walk->linebreak;
  walk->active = linesize_conceal_start(csarg, &walk->state);
  csarg->conceal_state = walk->active ? &walk->state : NULL;
  csarg->scr_vcol_offset = 0;
  return walk->active;
}

/// Call once per character, right after measuring it, in increasing "col" order.
///
/// @return cells of "cs.body" hidden by conceal for this character (0 if visible or inactive).
static inline int conceal_walk_advance(CharsizeArg *csarg, ConcealWalk *walk, int col, CharSize cs)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  if (!walk->active) {
    return 0;
  }
  int const hidden = linesize_conceal_hidden(csarg, &walk->state, col, cs.body);
  csarg->scr_vcol_offset += hidden;
  return hidden;
}

static inline void conceal_walk_end(CharsizeArg *csarg, ConcealWalk *walk)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  linebreak_state_end(&walk->linebreak);
  if (csarg->linebreak_state == &walk->linebreak) {
    csarg->linebreak_state = NULL;
  }
  if (walk->active) {
    linesize_conceal_end(&walk->state);
  }
  csarg->conceal_state = NULL;
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
  GETVCOL_CONCEAL = 2,  ///< Internal layout column: wrap prefixes follow persistent conceal.
};
