// plines.c: calculate the vertical and horizontal size of text in a window

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/api/extmark.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/decoration_provider.h"
#include "nvim/diff.h"
#include "nvim/drawscreen.h"
#include "nvim/fold.h"
#include "nvim/globals.h"
#include "nvim/indent.h"
#include "nvim/macros_defs.h"
#include "nvim/mark_defs.h"
#include "nvim/marktree.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/types_defs.h"

#include "plines.c.generated.h"

/// Functions calculating horizontal size of text, when displayed in a window.

/// Return the number of cells the first char in "p" will take on the screen,
/// taking into account the size of a tab.
/// Also see getvcol()
///
/// @param p
/// @param col
///
/// @return Number of cells.
///
/// @see charsize_nowrap()
int win_chartabsize(win_T *wp, char *p, colnr_T col)
{
  buf_T *buf = wp->w_buffer;
  if (*p == TAB && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
    return tabstop_padding(col, buf->b_p_ts, buf->b_p_vts_array);
  }
  return ptr2cells(p);
}

/// Like linetabsize_str(), but "s" starts at virtual column "startvcol".
///
/// @param startvcol
/// @param s
///
/// @return Number of cells the string will take on the screen.
int linetabsize_col(int startvcol, char *s)
{
  CharsizeArg csarg;
  CSType const cstype = init_charsize_arg(&csarg, curwin, 0, s);
  if (cstype == kCharsizeFast) {
    return linesize_fast(&csarg, startvcol, MAXCOL);
  } else {
    return linesize_regular(&csarg, startvcol, MAXCOL, false);
  }
}

/// Return the number of cells line "lnum" of window "wp" will take on the
/// screen, taking into account the size of a tab and inline virtual text.
/// Doesn't count the size of 'listchars' "eol".
int linetabsize(win_T *wp, linenr_T lnum)
{
  return win_linetabsize(wp, lnum, ml_get_buf(wp->w_buffer, lnum), MAXCOL);
}

/// Like linetabsize(), but counts the size of 'listchars' "eol".
int linetabsize_eol(win_T *wp, linenr_T lnum)
{
  return linetabsize(wp, lnum)
         + ((wp->w_p_list && wp->w_p_lcs_chars.eol != NUL) ? 1 : 0);
}

static const uint32_t inline_filter[kMTMetaCount] = {[kMTMetaInline] = kMTFilterSelect };

/// Prepare the structure passed to charsize functions.
///
/// "line" is the start of the line.
/// When "lnum" is zero do not use inline virtual text.
CSType init_charsize_arg(CharsizeArg *csarg, win_T *wp, linenr_T lnum, char *line)
{
  csarg->win = wp;
  csarg->line = line;
  csarg->max_head_vcol = 0;
  csarg->cur_text_width_left = 0;
  csarg->cur_text_width_right = 0;
  csarg->virt_row = -1;
  csarg->indent_width = INT_MIN;
  csarg->use_tabstop = !wp->w_p_list || wp->w_p_lcs_chars.tab1;
  csarg->row = lnum > 0 ? lnum - 1 : -1;

  if (lnum > 0) {
    if (marktree_itr_get_filter(wp->w_buffer->b_marktree, lnum - 1, 0, lnum, 0,
                                inline_filter, csarg->iter)) {
      csarg->virt_row = lnum - 1;
    }
  }

  // A line whose cells may be hidden by conceal must use the regular path so that
  // linesize_regular() can compute the conceal-aware screen-layout width. The cursor line reveals
  // conceal unless 'concealcursor' applies. Conceal may come from the marktree or be materialised
  // on demand by an `_on_conceal` decoration provider (see decor_conceal_materialise()).
  csarg->maybe_conceal = csarg->row >= 0 && wp->w_p_cole > 0
                         && (wp->w_buffer->b_marktree->n_keys > 0
                             || decor_has_conceal_providers())
                         && !(wp == curwin && lnum == wp->w_cursor.lnum
                              && !conceal_cursor_line(wp));

  if (csarg->virt_row >= 0 || csarg->maybe_conceal
      || (wp->w_p_wrap && (wp->w_p_lbr || wp->w_p_bri || *get_showbreak_value(wp) != NUL))) {
    return kCharsizeRegular;
  } else {
    return kCharsizeFast;
  }
}

/// Get the number of cells taken up on the screen for the given arguments.
/// "csarg->cur_text_width_left" and "csarg->cur_text_width_right" are set
/// to the extra size for inline virtual text.
///
/// When "csarg->max_head_vcol" is positive, only count in "head" the size
/// of 'showbreak'/'breakindent' before "csarg->max_head_vcol".
/// When "csarg->max_head_vcol" is negative, only count in "head" the size
/// of 'showbreak'/'breakindent' before where cursor should be placed.
CharSize charsize_regular(CharsizeArg *csarg, char *const cur, colnr_T const vcol,
                          int32_t const cur_char)
{
  csarg->cur_text_width_left = 0;
  csarg->cur_text_width_right = 0;

  win_T *wp = csarg->win;
  buf_T *buf = wp->w_buffer;
  char *line = csarg->line;
  bool const use_tabstop = cur_char == TAB && csarg->use_tabstop;
  int mb_added = 0;

  bool has_lcs_eol = wp->w_p_list && wp->w_p_lcs_chars.eol != NUL;

  // First get normal size, without 'linebreak' or inline virtual text
  int size;
  int is_doublewidth = false;
  if (use_tabstop) {
    size = tabstop_padding(vcol, buf->b_p_ts, buf->b_p_vts_array);
  } else if (*cur == NUL) {
    // 1 cell for EOL list char (if present), as opposed to the two cell ^@
    // for a NUL character in the text.
    size = has_lcs_eol ? 1 : 0;
  } else if (cur_char < 0) {
    size = kInvalidByteCells;
  } else {
    size = ptr2cells(cur);
    is_doublewidth = size == 2 && cur_char >= 0x80;
  }

  if (csarg->virt_row >= 0) {
    int tab_size = size;
    int col = (int)(cur - line);
    while (true) {
      MTKey mark = marktree_itr_current(csarg->iter);
      if (mark.pos.row != csarg->virt_row || mark.pos.col > col) {
        break;
      } else if (mark.pos.col == col) {
        if (!mt_invalid(mark) && ns_in_win(mark.ns, wp)) {
          DecorInline decor = mt_decor(mark);
          DecorVirtText *vt = decor.ext ? decor.data.ext.vt : NULL;
          while (vt) {
            if (!(vt->flags & kVTIsLines) && vt->pos == kVPosInline) {
              if (mt_right(mark)) {
                csarg->cur_text_width_right += vt->width;
              } else {
                csarg->cur_text_width_left += vt->width;
              }
              size += vt->width;
              if (use_tabstop) {
                // tab size changes because of the inserted text
                size -= tab_size;
                tab_size = tabstop_padding(vcol + size, buf->b_p_ts, buf->b_p_vts_array);
                size += tab_size;
              }
            }
            vt = vt->next;
          }
        }
      }
      marktree_itr_next_filter(wp->w_buffer->b_marktree, csarg->iter, csarg->virt_row + 1, 0,
                               inline_filter);
    }
  }

  if (is_doublewidth && wp->w_p_wrap && in_win_border(wp, vcol + size - 2)) {
    // Count the ">" in the last column.
    size++;
    mb_added = 1;
  }

  char *const sbr = get_showbreak_value(wp);

  // May have to add something for 'breakindent' and/or 'showbreak'
  // string at the start of a screen line.
  int head = mb_added;
  // When "size" is 0, no new screen line is started.
  if (size > 0 && wp->w_p_wrap && (*sbr != NUL || wp->w_p_bri)) {
    int col_off_prev = win_col_off(wp);
    int width2 = wp->w_view_width - col_off_prev + win_col_off2(wp);
    colnr_T wcol = vcol + col_off_prev;
    colnr_T max_head_vcol = csarg->max_head_vcol;
    int added = 0;

    // cells taken by 'showbreak'/'breakindent' before current char
    int head_prev = 0;
    if (wcol >= wp->w_view_width) {
      wcol -= wp->w_view_width;
      col_off_prev = wp->w_view_width - width2;
      if (wcol >= width2 && width2 > 0) {
        wcol %= width2;
      }
      head_prev = csarg->indent_width;
      if (head_prev == INT_MIN) {
        head_prev = 0;
        if (*sbr != NUL) {
          head_prev += vim_strsize(sbr);
        }
        if (wp->w_p_bri) {
          head_prev += get_breakindent_win(wp, line);
        }
        csarg->indent_width = head_prev;
      }
      if (wcol < head_prev) {
        head_prev -= wcol;
        wcol += head_prev;
        added += head_prev;
        if (max_head_vcol <= 0 || vcol < max_head_vcol) {
          head += head_prev;
        }
      } else {
        head_prev = 0;
      }
      wcol += col_off_prev;
    }

    if (wcol + size > wp->w_view_width) {
      // cells taken by 'showbreak'/'breakindent' halfway current char
      int head_mid = csarg->indent_width;
      if (head_mid == INT_MIN) {
        head_mid = 0;
        if (*sbr != NUL) {
          head_mid += vim_strsize(sbr);
        }
        if (wp->w_p_bri) {
          head_mid += get_breakindent_win(wp, line);
        }
        csarg->indent_width = head_mid;
      }
      if (head_mid > 0) {
        // Calculate effective window width.
        int prev_rem = wp->w_view_width - wcol;
        int width = width2 - head_mid;

        if (width <= 0) {
          width = 1;
        }
        // Divide "size - prev_rem" by "width", rounding up.
        int cnt = (size - prev_rem + width - 1) / width;
        added += cnt * head_mid;

        if (max_head_vcol == 0 || vcol + size + added < max_head_vcol) {
          head += cnt * head_mid;
        } else if (width2 > 0 && max_head_vcol > vcol + head_prev + prev_rem) {
          head += (max_head_vcol - (vcol + head_prev + prev_rem)
                   + width2 - 1) / width2 * head_mid;
        } else if (max_head_vcol < 0) {
          int off = mb_added + virt_text_cursor_off(csarg, *cur == NUL);
          if (off >= prev_rem) {
            if (size > off) {
              head += (1 + (off - prev_rem) / width) * head_mid;
            } else {
              head += (off - prev_rem + width - 1) / width * head_mid;
            }
          }
        }
      }
    }

    size += added;
  }

  int size_before_lbr = size;
  bool need_lbr = false;
  // If 'linebreak' set check at a blank before a non-blank if the line
  // needs a break here.
  if (wp->w_p_lbr && wp->w_p_wrap && wp->w_view_width != 0
      && vim_isbreak((uint8_t)cur[0]) && !vim_isbreak((uint8_t)cur[1])) {
    char *t = csarg->line;
    while (vim_isbreak((uint8_t)t[0])) {
      t++;
    }
    // 'linebreak' is only needed when not in leading whitespace.
    need_lbr = cur >= t;
  }
  if (need_lbr) {
    char *s = cur;
    // Count all characters from first non-blank after a blank up to next
    // non-blank after a blank.
    int numberextra = win_col_off(wp);
    colnr_T col_adj = size - 1;
    colnr_T colmax = (colnr_T)(wp->w_view_width - numberextra - col_adj);
    if (vcol >= colmax) {
      colmax += col_adj;
      int n = colmax + win_col_off2(wp);
      if (n > 0) {
        colmax += (((vcol - colmax) / n) + 1) * n - col_adj;
      }
    }

    colnr_T vcol2 = vcol;
    while (true) {
      char *ps = s;
      MB_PTR_ADV(s);
      int c = (uint8_t)(*s);
      if (!(c != NUL
            && (vim_isbreak(c) || vcol2 == vcol || !vim_isbreak((uint8_t)(*ps))))) {
        break;
      }

      vcol2 += win_chartabsize(wp, s, vcol2);
      if (vcol2 >= colmax) {  // doesn't fit
        size = colmax - vcol + col_adj;
        break;
      }
    }
  }

  int tail = size - size_before_lbr;

  return (CharSize){ .width = size, .head = head, .tail = tail };
}

/// Like charsize_regular(), except it doesn't handle inline virtual text,
/// 'linebreak', 'breakindent' or 'showbreak'.
/// Handles normal characters, tabs and wrapping.
/// This function is always inlined.
///
/// @see charsize_regular
/// @see charsize_fast
static inline CharSize charsize_fast_impl(win_T *const wp, const char *cur, bool use_tabstop,
                                          colnr_T const vcol, int32_t const cur_char)
  FUNC_ATTR_PURE FUNC_ATTR_ALWAYS_INLINE
{
  // A tab gets expanded, depending on the current column
  if (cur_char == TAB && use_tabstop) {
    return (CharSize){
      .width = tabstop_padding(vcol, wp->w_buffer->b_p_ts,
                               wp->w_buffer->b_p_vts_array)
    };
  } else {
    int width;
    if (cur_char < 0) {
      width = kInvalidByteCells;
    } else {
      // TODO(bfredl): perf: often cur_char is enough at this point to determine width.
      // we likely want a specialized version of utf_ptr2StrCharInfo also determining
      // the ptr2cells width at the same time without any extra decoding. (also applies
      // to charsize_regular and charsize_nowrap)
      width = ptr2cells(cur);
    }

    // If a double-width char doesn't fit at the end of a line, it wraps to the next line,
    // and the last column displays a '>'.
    if (width == 2 && cur_char >= 0x80 && wp->w_p_wrap && in_win_border(wp, vcol)) {
      return (CharSize){ .width = 3, .head = 1 };
    } else {
      return (CharSize){ .width = width };
    }
  }
}

/// Like charsize_regular(), except it doesn't handle inline virtual text,
/// 'linebreak', 'breakindent' or 'showbreak'.
/// Handles normal characters, tabs and wrapping.
/// Can be used if CSType is kCharsizeFast.
///
/// @see charsize_regular
CharSize charsize_fast(CharsizeArg *csarg, const char *cur, colnr_T vcol, int32_t cur_char)
  FUNC_ATTR_PURE
{
  return charsize_fast_impl(csarg->win, cur, csarg->use_tabstop, vcol, cur_char);
}

/// Get the number of cells taken up on the screen at given virtual column.
///
/// @see win_chartabsize()
int charsize_nowrap(buf_T *buf, const char *cur, bool use_tabstop, colnr_T vcol, int32_t cur_char)
{
  if (cur_char == TAB && use_tabstop) {
    return tabstop_padding(vcol, buf->b_p_ts, buf->b_p_vts_array);
  } else if (cur_char < 0) {
    return kInvalidByteCells;
  } else {
    return ptr2cells(cur);
  }
}

/// Check that virtual column "vcol" is in the rightmost column of window "wp".
///
/// @param  wp    window
/// @param  vcol  column number
static bool in_win_border(win_T *wp, colnr_T vcol)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  if (wp->w_view_width == 0) {
    // there is no border
    return false;
  }
  int width1 = wp->w_view_width - win_col_off(wp);  // width of first line (after line number)

  if ((int)vcol < width1 - 1) {
    return false;
  }

  if ((int)vcol == width1 - 1) {
    return true;
  }
  int width2 = width1 + win_col_off2(wp);  // width of further lines

  if (width2 <= 0) {
    return false;
  }
  return (vcol - width1) % width2 == width2 - 1;
}

/// Set up per-line persistent-conceal tracking for the screen-layout width.
///
/// Only persistent marktree conceal is considered (no decoration providers are invoked), which
/// keeps plines_win_nofold() in sync with win_line(): win_line() only reflows non-ephemeral
/// conceal (see decor_state.conceal_persistent).
///
/// @return true if conceal tracking is active for this line.
static bool linesize_conceal_start(CharsizeArg *csarg, DecorState *state)
{
  if (!csarg->maybe_conceal) {
    return false;
  }
  // Let `_on_conceal` providers materialise this row's conceal into the marktree first, so the
  // scan below sees provider (e.g. tree-sitter) conceal the same way as non-provider conceal.
  decor_conceal_materialise(csarg->win, csarg->row);
  // The call above may invoke a decoration-provider (Lua) callback that mutates the buffer (e.g.
  // nvim_buf_set_extmark()), which can flush memline's single-line read cache and free the line
  // buffer that "csarg->line" (fetched by the caller before this ran) points into. Refresh it so
  // callers that read csarg->line only after this returns (see linesize_regular(),
  // conceal_off_before(), scol_to_col()) don't read freed memory. ml_get_buf() is a cheap no-op
  // re-read when the row is still the cached one.
  csarg->line = ml_get_buf(csarg->win->w_buffer, csarg->row + 1);
  *state = (DecorState){ 0 };
  if (decor_redraw_reset(csarg->win, state) == 0) {
    return false;
  }
  decor_redraw_line(csarg->win, csarg->row, state);
  return true;
}

/// @return number of cells at buffer column "col" hidden by persistent conceal (0 if visible).
static int linesize_conceal_hidden(CharsizeArg *csarg, DecorState *state, int col, int width)
{
  decor_redraw_col(csarg->win, col, -1, false, state, MAXCOL);
  if (state->conceal == 0) {
    return 0;
  }
  // Mirror win_line()'s fully-hidden ("is_concealing") chars: a concealed cell is hidden unless it
  // is the region start showing a replacement char. At 'conceallevel' 1 a replacement (the custom
  // cchar, or else a default space) is always shown; at level 2 only a custom cchar is shown;
  // level 3 always hides.
  bool const replacement = state->conceal == 2
                           && (state->conceal_char != 0 || csarg->win->w_p_cole == 1)
                           && csarg->win->w_p_cole != 3;
  return replacement ? 0 : width;
}

static void linesize_conceal_end(DecorState *state)
{
  kv_destroy(state->ranges_i);
  kv_destroy(state->slots);
}

/// Number of screen cells hidden by persistent conceal strictly before buffer byte "len" on line
/// "lnum" of window "wp". This is the offset between a position's virtual column and its
/// screen-layout column: screen_col = virtual_col - conceal_off_before().
///
/// Returns 0 when conceal cannot apply to the line (no 'conceallevel', no conceal marks, or the
/// line is the cursor line revealed by 'concealcursor'), so callers degrade to conceal-neutral
/// behavior. Only persistent (marktree) conceal is considered, matching win_line()'s reflow and
/// plines_win_nofold()'s screen width.
int conceal_off_before(win_T *wp, linenr_T lnum, colnr_T len)
{
  CharsizeArg csarg;
  init_charsize_arg(&csarg, wp, lnum, ml_get_buf(wp->w_buffer, lnum));

  DecorState conceal_state;
  if (!linesize_conceal_start(&csarg, &conceal_state)) {
    return 0;
  }
  // Read csarg.line only now: linesize_conceal_start() may have run decor_conceal_materialise(),
  // which can invoke a Lua callback that frees the line buffer a pointer captured before that
  // call would point into; linesize_conceal_start() refreshes csarg.line when this happens.
  char *const line = csarg.line;

  int hidden = 0;
  int vcol = 0;
  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  while (ci.ptr - line < len && *ci.ptr != NUL) {
    CharSize cs = charsize_regular(&csarg, ci.ptr, vcol, ci.chr.value);
    hidden += linesize_conceal_hidden(&csarg, &conceal_state, (int)(ci.ptr - line), cs.width);
    vcol += cs.width;
    ci = utfc_next(ci);
  }

  linesize_conceal_end(&conceal_state);
  return hidden;
}

/// Convert a screen-layout column "scol" to a buffer byte column on line "lnum" of window "wp",
/// accounting for cells hidden by persistent conceal. This is the inverse of conceal_off_before()
/// and the screen-aware analog of mouse.c's vcol2col(): it walks the line accumulating displayed
/// (screen) width, stepping over fully-hidden characters without consuming the target.
///
/// When conceal cannot apply (see conceal_off_before()), this behaves exactly like the virtual
/// walk. Sets "*coladdp" (if non-NULL) to the overshoot past the last visible column, as vcol2col()
/// does, for 'virtualedit'.
colnr_T scol_to_col(win_T *wp, linenr_T lnum, colnr_T scol, colnr_T *coladdp)
{
  CharsizeArg csarg;
  CSType const cstype = init_charsize_arg(&csarg, wp, lnum, ml_get_buf(wp->w_buffer, lnum));

  DecorState conceal_state;
  bool const conceal = linesize_conceal_start(&csarg, &conceal_state);
  // Read csarg.line only now: linesize_conceal_start() may have run decor_conceal_materialise(),
  // which can invoke a Lua callback that frees the line buffer a pointer captured before that
  // call would point into; linesize_conceal_start() refreshes csarg.line when this happens.
  char *const line = csarg.line;

  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  int cur_vcol = 0;  // virtual column, needed for TAB width
  int cur_scol = 0;  // screen column, compared against the target
  while (cur_scol < scol && *ci.ptr != NUL) {
    int const w = win_charsize(cstype, cur_vcol, ci.ptr, ci.chr.value, &csarg).width;
    int const hidden = conceal
                       ? linesize_conceal_hidden(&csarg, &conceal_state, (int)(ci.ptr - line), w)
                       : 0;
    if (hidden == 0) {
      if (cur_scol + w > scol) {
        break;  // target falls within this visible character
      }
      cur_scol += w;
    }
    cur_vcol += w;
    ci = utfc_next(ci);
  }

  if (conceal) {
    linesize_conceal_end(&conceal_state);
  }

  if (coladdp != NULL) {
    *coladdp = scol - cur_scol;
  }
  return (colnr_T)(ci.ptr - line);
}

/// Screen-layout width of line "lnum" in window "wp": like linetabsize(), but
/// excluding cells hidden by persistent conceal. Equals linetabsize() when
/// nothing on the line is concealed.
int win_screen_linewidth(win_T *wp, linenr_T lnum)
{
  char *const line = ml_get_buf(wp->w_buffer, lnum);
  CharsizeArg csarg;
  CSType const cstype = init_charsize_arg(&csarg, wp, lnum, line);
  if (cstype == kCharsizeFast) {
    return linesize_fast(&csarg, 0, MAXCOL);
  }
  return linesize_regular(&csarg, 0, MAXCOL, true);
}

/// Calculate virtual column until the given "len".
///
/// @param csarg    Argument to charsize functions.
/// @param vcol_arg Starting virtual column.
/// @param len      First byte of the end character, or MAXCOL.
/// @param screen   When true, exclude concealed cells to get the screen-layout width.
///
/// @return virtual column before the character at "len",
///         or full size of the line if "len" is MAXCOL.
int linesize_regular(CharsizeArg *const csarg, int vcol_arg, colnr_T const len, bool screen)
{
  int64_t vcol = vcol_arg;

  DecorState conceal_state;
  bool const conceal = screen && linesize_conceal_start(csarg, &conceal_state);
  // Read csarg->line only now: linesize_conceal_start() may have run decor_conceal_materialise(),
  // which can invoke a Lua callback that frees the line buffer a pointer captured before that
  // call would point into; linesize_conceal_start() refreshes csarg->line when this happens.
  char *const line = csarg->line;

  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  while (ci.ptr - line < len && *ci.ptr != NUL) {
    CharSize cs = charsize_regular(csarg, ci.ptr, vcol_arg, ci.chr.value);
    int const hidden = conceal
                       ? linesize_conceal_hidden(csarg, &conceal_state,
                                                 (int)(ci.ptr - line), cs.width)
                       : 0;
    vcol += cs.width - hidden;
    ci = utfc_next(ci);
    if (vcol > MAXCOL) {
      vcol_arg = MAXCOL;
      break;
    } else {
      vcol_arg = (int)vcol;
    }
  }

  if (conceal) {
    linesize_conceal_end(&conceal_state);
  }

  // Check for inline virtual text after the end of the line.
  if (len == MAXCOL && csarg->virt_row >= 0 && *ci.ptr == NUL) {
    int head = charsize_regular(csarg, ci.ptr, vcol_arg, ci.chr.value).head;
    vcol += csarg->cur_text_width_left + csarg->cur_text_width_right + head;
    vcol_arg = vcol > MAXCOL ? MAXCOL : (int)vcol;
  }

  return vcol_arg;
}

/// Like linesize_regular(), but can be used when CSType is kCharsizeFast.
///
/// @see linesize_regular
int linesize_fast(CharsizeArg const *const csarg, int vcol_arg, colnr_T const len)
{
  win_T *const wp = csarg->win;
  bool const use_tabstop = csarg->use_tabstop;

  char *const line = csarg->line;
  int64_t vcol = vcol_arg;

  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  while (ci.ptr - line < len && *ci.ptr != NUL) {
    vcol += charsize_fast_impl(wp, ci.ptr, use_tabstop, vcol_arg, ci.chr.value).width;
    ci = utfc_next(ci);
    if (vcol > MAXCOL) {
      vcol_arg = MAXCOL;
      break;
    } else {
      vcol_arg = (int)vcol;
    }
  }

  return vcol_arg;
}

/// Get how many virtual columns inline virtual text should offset the cursor.
///
/// @param csarg   should contain information stored by charsize_regular()
///                about widths of left and right gravity virtual text
/// @param on_NUL  whether this is the end of the line
static int virt_text_cursor_off(const CharsizeArg *csarg, bool on_NUL)
{
  int off = 0;
  if (!on_NUL || !(State & MODE_NORMAL)) {
    off += csarg->cur_text_width_left;
  }
  if (!on_NUL && (State & MODE_NORMAL)) {
    off += csarg->cur_text_width_right;
  }
  return off;
}

/// Get virtual column number of pos.
///  start: on the first position of this character (TAB, ctrl)
/// cursor: where the cursor is on this character (first char, except for TAB)
///    end: on the last position of this character (TAB, ctrl)
///
/// When 'linebreak' follows this character, "end" is set to the position before
/// 'linebreak' if "flags" contains GETVCOL_END_EXCL_LBR, otherwise it's set to
/// the end of 'linebreak'.
///
/// This is used very often, keep it fast!
///
/// @param wp
/// @param pos
/// @param start
/// @param cursor
/// @param end
/// @param flags
void getvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor, colnr_T *end, int flags)
{
  char *const line = ml_get_buf(wp->w_buffer, pos->lnum);  // start of the line
  colnr_T const end_col = pos->col;

  CharsizeArg csarg;
  bool on_NUL = false;
  CSType const cstype = init_charsize_arg(&csarg, wp, pos->lnum, line);
  csarg.max_head_vcol = -1;

  colnr_T vcol = 0;
  CharSize char_size;
  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  if (cstype == kCharsizeFast) {
    bool const use_tabstop = csarg.use_tabstop;
    while (true) {
      if (*ci.ptr == NUL) {
        // if cursor is at NUL, it is treated like 1 cell char
        char_size = (CharSize){ .width = 1 };
        break;
      }
      char_size = charsize_fast_impl(wp, ci.ptr, use_tabstop, vcol, ci.chr.value);
      StrCharInfo const next = utfc_next(ci);
      if (next.ptr - line > end_col) {
        break;
      }
      ci = next;
      vcol += char_size.width;
    }
  } else {
    while (true) {
      char_size = charsize_regular(&csarg, ci.ptr, vcol, ci.chr.value);
      // make sure we don't go past the end of the line
      if (*ci.ptr == NUL) {
        // NUL at end of line only takes one column unless there is virtual text
        char_size.width = 1 + csarg.cur_text_width_left + csarg.cur_text_width_right;
        on_NUL = true;
        break;
      }
      StrCharInfo const next = utfc_next(ci);
      if (next.ptr - line > end_col) {
        break;
      }
      ci = next;
      vcol += char_size.width;
    }
  }

  if (*ci.ptr == NUL && end_col < MAXCOL && end_col > ci.ptr - line) {
    pos->col = (colnr_T)(ci.ptr - line);
  }

  int incr = char_size.width;
  int head = char_size.head;
  int tail = char_size.tail;

  if (start != NULL) {
    *start = vcol + head;
  }
  if (end != NULL) {
    *end = vcol + incr - (flags & GETVCOL_END_EXCL_LBR ? tail : 0) - 1;
  }
  if (cursor != NULL) {
    if (ci.chr.value == TAB
        && (State & MODE_NORMAL)
        && !wp->w_p_list
        && !virtual_active(wp)
        && !(Visual.active && ((*p_sel == 'e') || ltoreq(*pos, Visual.start)))) {
      // TODO(zeertzjq): subtracting "tail" may lead to better cursor position
      *cursor = vcol + incr - 1;  // cursor at end
    } else {
      vcol += virt_text_cursor_off(&csarg, on_NUL);
      *cursor = vcol + head;  // cursor at start
    }
  }
}

/// Get virtual cursor column in the current window, pretending 'list' is off.
///
/// @param posp
///
/// @return The virtual cursor column.
colnr_T getvcol_nolist(pos_T *posp)
{
  int list_save = curwin->w_p_list;
  colnr_T vcol;

  curwin->w_p_list = false;
  if (posp->coladd) {
    getvvcol(curwin, posp, NULL, &vcol, NULL, 0);
  } else {
    getvcol(curwin, posp, NULL, &vcol, NULL, 0);
  }
  curwin->w_p_list = list_save;
  return vcol;
}

/// Get virtual column in virtual mode.
///
/// @param wp
/// @param pos
/// @param start
/// @param cursor
/// @param end
/// @param flags
void getvvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor, colnr_T *end, int flags)
{
  colnr_T col;

  if (virtual_active(wp)) {
    // For virtual mode, only want one value
    getvcol(wp, pos, &col, NULL, NULL, flags);

    colnr_T coladd = pos->coladd;
    colnr_T endadd = 0;

    // Cannot put the cursor on part of a wide character.
    char *ptr = ml_get_buf(wp->w_buffer, pos->lnum);

    if (pos->col < ml_get_buf_len(wp->w_buffer, pos->lnum)) {
      int c = utf_ptr2char(ptr + pos->col);
      if ((c != TAB) && vim_isprintc(c)) {
        endadd = (colnr_T)(ptr2cells(ptr + pos->col) - 1);
        if (coladd > endadd) {
          endadd = 0;  // past end of line
        } else {
          coladd = 0;
        }
      }
    }
    col += coladd;

    if (start != NULL) {
      *start = col;
    }
    if (cursor != NULL) {
      *cursor = col;
    }
    if (end != NULL) {
      *end = col + endadd;
    }
  } else {
    getvcol(wp, pos, start, cursor, end, flags);
  }
}

/// Get the leftmost and rightmost virtual column of pos1 and pos2.
/// Used for Visual block mode.
///
/// @param wp
/// @param pos1
/// @param pos2
/// @param left
/// @param right
/// @param flags
void getvcols(win_T *wp, pos_T *pos1, pos_T *pos2, colnr_T *left, colnr_T *right, int flags)
{
  colnr_T from1;
  colnr_T from2;
  colnr_T to1;
  colnr_T to2;

  if (lt(*pos1, *pos2)) {
    getvvcol(wp, pos1, &from1, NULL, &to1, flags);
    getvvcol(wp, pos2, &from2, NULL, &to2, flags);
  } else {
    getvvcol(wp, pos2, &from1, NULL, &to1, flags);
    getvvcol(wp, pos1, &from2, NULL, &to2, flags);
  }

  if (from2 < from1) {
    *left = from2;
  } else {
    *left = from1;
  }

  if (to2 > to1) {
    if ((*p_sel == 'e') && (from2 - 1 >= to1)) {
      *right = from2 - 1;
    } else {
      *right = to2;
    }
  } else {
    *right = to1;
  }
}

/// Functions calculating vertical size of text when displayed inside a window.
/// Calls horizontal size functions defined above.

/// Check if there may be filler lines anywhere in window "wp".
bool win_may_fill(win_T *wp)
{
  return ((wp->w_p_diff && diffopt_filler())
          || buf_meta_total(wp->w_buffer, kMTMetaLines));
}

/// Return the number of filler lines above "lnum".
///
/// @param wp
/// @param lnum
///
/// @return Number of filler lines above lnum
int win_get_fill(win_T *wp, linenr_T lnum)
{
  return decor_virt_lines(wp, lnum - 1, lnum, NULL, NULL, true) + diff_check_fill(wp, lnum);
}

/// Return the number of window lines occupied by buffer line "lnum".
/// Includes any filler lines.
///
/// @param limit_winheight  when true limit to window height
int plines_win(win_T *wp, linenr_T lnum, bool limit_winheight)
{
  // Check for filler lines above this buffer line.
  return plines_win_nofill(wp, lnum, limit_winheight) + win_get_fill(wp, lnum);
}

/// Return the number of window lines occupied by buffer line "lnum".
/// Does not include filler lines.
///
/// @param limit_winheight  when true limit to window height
int plines_win_nofill(win_T *wp, linenr_T lnum, bool limit_winheight)
{
  if (decor_conceal_line(wp, lnum - 1, false)) {
    return 0;
  }

  if (!wp->w_p_wrap) {
    return 1;
  }

  if (wp->w_view_width == 0) {
    return 1;
  }

  // Folded lines are handled just like an empty line.
  if (lineFolded(wp, lnum)) {
    return 1;
  }

  const int lines = plines_win_nofold(wp, lnum);
  if (limit_winheight && lines > wp->w_view_height) {
    return wp->w_view_height;
  }
  return lines;
}

/// Number of screen rows that "col" screen cells of text occupy in window "wp"
/// under 'wrap', accounting for the 'number'/'foldcolumn' offsets on the first
/// and subsequent screen rows.
static int win_text_width_to_plines(win_T *wp, int64_t col)
{
  int width = wp->w_view_width - win_col_off(wp);
  if (width <= 0) {
    return 32000;  // bigger than the number of screen lines
  }
  if (col <= width) {
    return 1;
  }
  col -= width;
  width += win_col_off2(wp);
  const int64_t lines = (col + (width - 1)) / width + 1;
  return (lines > 0 && lines <= INT_MAX) ? (int)lines : INT_MAX;
}

/// Get number of window lines physical line "lnum" will occupy in window "wp".
/// Does not care about folding, 'wrap' or filler lines.
int plines_win_nofold(win_T *wp, linenr_T lnum)
{
  char *s = ml_get_buf(wp->w_buffer, lnum);
  CharsizeArg csarg;
  CSType const cstype = init_charsize_arg(&csarg, wp, lnum, s);
  if (*s == NUL && csarg.virt_row < 0) {
    return 1;  // be quick for an empty line
  }

  int64_t col;
  if (cstype == kCharsizeFast) {
    col = linesize_fast(&csarg, 0, MAXCOL);
  } else {
    col = linesize_regular(&csarg, 0, MAXCOL, true);
  }

  // If list mode is on, then the '$' at the end of the line may take up one
  // extra column.
  if (wp->w_p_list && wp->w_p_lcs_chars.eol != NUL) {
    col += 1;
  }

  return win_text_width_to_plines(wp, col);
}

/// Whether buffer line "lnum" occupies a different number of screen rows in
/// window "wp" when its intra-line conceal is applied versus revealed. Moving
/// the cursor onto/off such a line reveals or conceals it (unless
/// 'concealcursor' applies), which shifts the layout of the lines below, so the
/// whole window must be redrawn instead of incrementally scrolled (otherwise
/// the TUI's scroll optimisation leaves stale cells). Only meaningful with
/// 'wrap' and 'conceallevel' >= 2; whole-line conceal ('conceal_lines') is
/// handled separately via decor_conceal_line().
bool conceal_line_changes_height(win_T *wp, linenr_T lnum)
{
  if (!wp->w_p_wrap || wp->w_p_cole < 2 || wp->w_view_width == 0
      || lnum < 1 || lnum > wp->w_buffer->b_ml.ml_line_count) {
    return false;
  }
  if (!(wp->w_buffer->b_marktree->n_keys > 0 || decor_has_conceal_providers())) {
    return false;
  }

  char *const line = ml_get_buf(wp->w_buffer, lnum);
  int const extra = (wp->w_p_list && wp->w_p_lcs_chars.eol != NUL) ? 1 : 0;

  // Revealed width: screen == false ignores conceal entirely (conceal-neutral).
  CharsizeArg csarg;
  init_charsize_arg(&csarg, wp, lnum, line);
  int64_t const revealed = linesize_regular(&csarg, 0, MAXCOL, false) + extra;

  // Concealed width: force conceal evaluation regardless of whether this is
  // the revealed cursor line, so we compare the two states of the same line.
  init_charsize_arg(&csarg, wp, lnum, line);
  csarg.maybe_conceal = true;
  int64_t const concealed = linesize_regular(&csarg, 0, MAXCOL, true) + extra;

  if (revealed == concealed) {
    return false;  // nothing on the line is actually concealed
  }
  return win_text_width_to_plines(wp, revealed) != win_text_width_to_plines(wp, concealed);
}

/// Like plines_win(), but only reports the number of physical screen lines
/// used from the start of the line to the given column number.
int plines_win_col(win_T *wp, linenr_T lnum, long column)
{
  // Check for filler lines above this buffer line.
  int lines = win_get_fill(wp, lnum);

  if (!wp->w_p_wrap) {
    return lines + 1;
  }

  if (wp->w_view_width == 0) {
    return lines + 1;
  }

  char *line = ml_get_buf(wp->w_buffer, lnum);

  CharsizeArg csarg;
  CSType const cstype = init_charsize_arg(&csarg, wp, lnum, line);

  colnr_T vcol = 0;
  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  if (cstype == kCharsizeFast) {
    bool const use_tabstop = csarg.use_tabstop;
    while (*ci.ptr != NUL && --column >= 0) {
      vcol += charsize_fast_impl(wp, ci.ptr, use_tabstop, vcol, ci.chr.value).width;
      ci = utfc_next(ci);
    }
  } else {
    while (*ci.ptr != NUL && --column >= 0) {
      vcol += charsize_regular(&csarg, ci.ptr, vcol, ci.chr.value).width;
      ci = utfc_next(ci);
    }
  }

  // If current char is a TAB, and the TAB is not displayed as ^I, and we're not
  // in MODE_INSERT state, then col must be adjusted so that it represents the
  // last screen position of the TAB.  This only fixes an error when the TAB
  // wraps from one screen line to the next (when 'columns' is not a multiple
  // of 'ts') -- webb.
  colnr_T col = vcol;
  if (ci.chr.value == TAB && (State & MODE_NORMAL) && csarg.use_tabstop) {
    col += win_charsize(cstype, col, ci.ptr, ci.chr.value, &csarg).width - 1;
  }

  // Add column offset for 'number', 'relativenumber', 'foldcolumn', etc.
  int width = wp->w_view_width - win_col_off(wp);
  if (width <= 0) {
    return 9999;
  }

  lines += 1;
  if (col > width) {
    lines += (col - width) / (width + win_col_off2(wp)) + 1;
  }
  return lines;
}

/// Get the number of screen lines buffer line "lnum" will take in window "wp".
/// This takes care of both folds and topfill.
///
/// XXX: Because of topfill, this only makes sense when lnum >= wp->w_topline.
///
/// @param[in]  wp               window the line is in
/// @param[in]  lnum             line number
/// @param[out] nextp            if not NULL, the last line of a fold
/// @param[out] foldedp          if not NULL, whether lnum is on a fold
/// @param[in]  cache            whether to use the window's cache for folds
/// @param[in]  limit_winheight  when true limit to window height
///
/// @return the total number of screen lines
int plines_win_full(win_T *wp, linenr_T lnum, linenr_T *const nextp, bool *const foldedp,
                    const bool cache, const bool limit_winheight)
{
  bool folded = hasFoldingWin(wp, lnum, &lnum, nextp, cache, NULL);
  if (foldedp != NULL) {
    *foldedp = folded;
  }

  int filler_lines = lnum == wp->w_topline ? wp->w_topfill : win_get_fill(wp, lnum);

  if (decor_conceal_line(wp, lnum - 1, false)) {
    return filler_lines;
  }

  return (folded ? 1 : plines_win_nofill(wp, lnum, limit_winheight)) + filler_lines;
}

/// Return number of window lines a physical line range will occupy in window "wp".
/// Takes into account folding, 'wrap', topfill and filler lines beyond the end of the buffer.
///
/// XXX: Because of topfill, this only makes sense when first >= wp->w_topline.
///
/// @param first  first line number
/// @param last   last line number
/// @param max    number of lines to limit the height to
///
/// @see win_text_height
int plines_m_win(win_T *wp, linenr_T first, linenr_T last, int max)
{
  int count = 0;

  while (first <= last && count < max) {
    linenr_T next = first;
    count += plines_win_full(wp, first, &next, NULL, false, false);
    first = next + 1;
  }
  if (first == wp->w_buffer->b_ml.ml_line_count + 1) {
    count += win_get_fill(wp, first);
  }
  return MIN(max, count);
}

/// Return total number of physical and filler lines in a physical line range.
/// Doesn't treat a fold as a single line or consider a wrapped line multiple lines,
/// unlike plines_m_win() or win_text_height().
///
/// Mainly used for calculating scrolling offsets.
int plines_m_win_fill(win_T *wp, linenr_T first, linenr_T last)
{
  int count = last - first + 1 + decor_virt_lines(wp, first - 1, last, NULL, NULL, false);

  if (diffopt_filler()) {
    for (int lnum = first; lnum <= last; lnum++) {
      // Note: this also considers folds (no filler lines inside folds).
      int n = diff_check_fill(wp, lnum);
      count += MAX(n, 0);
    }
  }

  return MAX(count, 0);
}

/// Get the number of screen lines a range of text will take in window "wp".
///
/// @param[in] start_lnum    Starting line number, 1-based inclusive.
/// @param[in] start_vcol    >= 0: Starting virtual column index on "start_lnum",
///                                0-based inclusive, rounded down to full screen lines.
///                          < 0:  Count a full "start_lnum", including filler lines above.
/// @param[in,out] end_lnum  Ending line number, 1-based inclusive. Set to last line for
///                          which the height is calculated (smaller if "max" is reached).
/// @param[in,out] end_vcol  >= 0: Ending virtual column index on "end_lnum",
///                                0-based exclusive, rounded up to full screen lines.
///                          < 0:  Count a full "end_lnum", not including filler lines below.
///                          Set to the number of columns in "end_lnum" to reach "max".
/// @param[in] max           Don't calculate the height for lines beyond the line where "max"
///                          height is reached.
/// @param[out] fill         If not NULL, set to the number of filler lines in the range.
int64_t win_text_height(win_T *const wp, const linenr_T start_lnum, const int64_t start_vcol,
                        linenr_T *const end_lnum, int64_t *const end_vcol, int64_t *const fill,
                        int64_t const max)
{
  int width1 = wp->w_view_width - win_col_off(wp);
  int width2 = width1 + win_col_off2(wp);
  width1 = MAX(width1, 0);
  width2 = MAX(width2, 0);
  int64_t height_sum_fill = 0;
  int64_t height_cur_nofill = 0;
  int64_t height_sum_nofill = 0;
  linenr_T lnum = start_lnum;
  linenr_T cur_lnum = lnum;
  bool cur_folded = false;

  if (start_vcol >= 0) {
    linenr_T lnum_next = lnum;
    cur_folded = hasFolding(wp, lnum, &lnum, &lnum_next);
    height_cur_nofill = plines_win_nofill(wp, lnum, false);
    height_sum_nofill += height_cur_nofill;
    const int64_t row_off = (start_vcol < width1 || width2 <= 0)
                            ? 0
                            : 1 + (start_vcol - width1) / width2;
    height_sum_nofill -= MIN(row_off, height_cur_nofill);
    lnum = lnum_next + 1;
  }

  while (lnum <= *end_lnum && height_sum_nofill + height_sum_fill < max) {
    linenr_T lnum_next = lnum;
    cur_folded = hasFolding(wp, lnum, &lnum, &lnum_next);
    height_sum_fill += win_get_fill(wp, lnum);
    height_cur_nofill = plines_win_nofill(wp, lnum, false);
    height_sum_nofill += height_cur_nofill;
    cur_lnum = lnum;
    lnum = lnum_next + 1;
  }

  int64_t vcol_end = *end_vcol;
  bool use_vcol = vcol_end >= 0 && lnum > *end_lnum;
  if (use_vcol) {
    height_sum_nofill -= height_cur_nofill;
    const int64_t row_off = vcol_end == 0
                            ? 0
                            : (vcol_end <= width1 || width2 <= 0)
                            ? 1
                            : 1 + (vcol_end - width1 + width2 - 1) / width2;
    height_sum_nofill += MIN(row_off, height_cur_nofill);
  }

  if (cur_folded) {
    vcol_end = 0;
  } else {
    int linesize = linetabsize_eol(wp, cur_lnum);
    vcol_end = MIN(use_vcol ? vcol_end : INT64_MAX, linesize);
  }

  int64_t overflow = height_sum_nofill + height_sum_fill - max;
  if (overflow > 0 && width2 > 0 && vcol_end > width2) {
    vcol_end -= (vcol_end - width1) % width2 + (overflow - 1) * width2;
  }

  *end_lnum = cur_lnum;
  *end_vcol = vcol_end;
  if (fill != NULL) {
    *fill = height_sum_fill;
  }
  return height_sum_fill + height_sum_nofill;
}

/// Return the maximum display width of lines "first" through "last".
///
/// @param max  stop measuring once this width is reached
///
/// @return  maximum display width, capped at "max"
int win_max_displaywidth(win_T *wp, linenr_T first, linenr_T last, int max)
{
  int width = 0;
  for (linenr_T lnum = first; lnum <= last && width < max; lnum++) {
    width = MAX(width, linetabsize(wp, lnum));
  }
  return MIN(max, width);
}
