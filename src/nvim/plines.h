#pragma once

#include <stdbool.h>
#include <stdint.h>  // IWYU pragma: keep

#include "nvim/marktree_defs.h"
#include "nvim/mbyte_defs.h"
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"

typedef bool CSType;

enum {
  kCharsizeRegular,
  kCharsizeFast,
};

/// Argument for char size functions.
typedef struct {
  win_T *win;
  char *line;                ///< start of the line

  bool use_tabstop;          ///< use tabstop for tab insted of counting it as ^I
  int indent_width;          ///< width of showbreak and breakindent on wrapped lines
                             ///  INT_MIN if not yet calculated

  int virt_row;              ///< line number, -1 if no virtual text
  int cur_text_width_left;   ///< width of virtual text left of cursor
  int cur_text_width_right;  ///< width of virtual text right of cursor

  int max_head_vcol;         ///< see charsize_regular()
  MarkTreeIter iter[1];
} CharsizeArg;

typedef struct {
  int width;
  int head;  // size of breakindent etc. before the character (included in width)
} CharSize;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "plines.h.generated.h"
#endif

static inline CharSize win_charsize(CSType cstype, int vcol, char *ptr, int32_t chr,
                                    CharsizeArg *csarg)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_ALWAYS_INLINE;

/// Get the number of cells taken up on the screen by the given character at vcol.
/// "arg->cur_text_width_left" and "arg->cur_text_width_right" are set
/// to the extra size for inline virtual text.
///
/// When "arg->max_head_vcol" is positive, only count in "head" the size
/// of 'showbreak'/'breakindent' before "arg->max_head_vcol".
/// When "arg->max_head_vcol" is negative, only count in "head" the size
/// of 'showbreak'/'breakindent' before where cursor should be placed.
static inline CharSize win_charsize(CSType cstype, int vcol, char *ptr, int32_t chr,
                                    CharsizeArg *csarg)
{
  if (cstype == kCharsizeFast) {
    return charsize_fast(csarg, vcol, chr);
  } else {
    return charsize_regular(csarg, ptr, vcol, chr);
  }
}

static inline int linetabsize_str(char *s)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_ALWAYS_INLINE;

/// Return the number of characters the string 's' will take on the screen,
/// taking into account the size of a tab.
///
/// @param s
///
/// @return Number of characters the string will take on the screen.
static inline int linetabsize_str(char *s)
{
  return linetabsize_col(0, s);
}

static inline int win_linetabsize(win_T *wp, linenr_T lnum, char *line, colnr_T len)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_ALWAYS_INLINE;

/// Like linetabsize_str(), but for a given window instead of the current one.
///
/// @param wp
/// @param line
/// @param len
///
/// @return Number of characters the string will take on the screen.
static inline int win_linetabsize(win_T *wp, linenr_T lnum, char *line, colnr_T len)
{
  CharsizeArg csarg;
  CSType const cstype = init_charsize_arg(&csarg, wp, lnum, line);
  if (cstype == kCharsizeFast) {
    return linesize_fast(&csarg, 0, len);
  } else {
    return linesize_regular(&csarg, 0, len);
  }
}
