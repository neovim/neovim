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
#include "nvim/grid.h"
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
int win_chartabsize(win_T *wp, const char *p, colnr_T col)
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
    return linesize_regular(&csarg, startvcol, MAXCOL);
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

/// Whether extmark-conceal may hide cells on line `lnum` of `wp` (see has_extconceal()), and
/// 'concealcursor' does not reveal the line. Cheap: does not walk the marktree.
bool line_has_extconceal(win_T *wp, linenr_T lnum)
{
  return lnum > 0 && has_extconceal(wp) && !conceal_cursor_reveals_line(wp, lnum);
}

/// Whether extmark-conceal (see CharsizeArg.extconceal_off), including marks an `_on_conceal`
/// provider adds on demand, may change the layout of `wp`.
bool has_extconceal(win_T *wp)
{
  return wp->w_p_wrap && wp->w_p_cole > 0
         && (buf_meta_total(wp->w_buffer, kMTMetaConceal) > 0
             || wp->w_buffer->b_conceal_providers > 0);
}

/// Prepare the structure passed to charsize functions.
///
/// "line" is the start of the line.
/// When "lnum" is zero do not use inline virtual text.
/// Does not apply extmark-conceal (see init_charsize_arg_extconceal()).
CSType init_charsize_arg(CharsizeArg *csarg, win_T *wp, linenr_T lnum, char *line)
{
  csarg->win = wp;
  csarg->line = line;
  csarg->max_head_vcol = 0;
  csarg->extconceal_off = 0;
  csarg->cur_text_width_left = 0;
  csarg->cur_text_width_right = 0;
  csarg->virt_row = -1;
  csarg->skip_cur_text = false;
  csarg->indent_width = INT_MIN;
  csarg->use_tabstop = !wp->w_p_list || wp->w_p_lcs_chars.tab1;
  csarg->extconceal = NULL;

  if (lnum > 0) {
    if (marktree_itr_get_filter(wp->w_buffer->b_marktree, lnum - 1, 0, lnum, 0,
                                inline_filter, csarg->iter)) {
      csarg->virt_row = lnum - 1;
    }
  }

  if (csarg->virt_row >= 0
      || (wp->w_p_wrap && (wp->w_p_lbr || wp->w_p_bri || *get_showbreak_value(wp) != NUL))) {
    return kCharsizeRegular;
  } else {
    return kCharsizeFast;
  }
}

/// Like init_charsize_arg(), but extmark-conceal hides cells (see CharsizeArg.extconceal_off).
/// Collects the conceal of line `lnum` into `spans` (free with kv_destroy()), after running its
/// `_on_conceal` provider, which may free the line buffer: read the line from `csarg->line`.
CSType init_charsize_arg_extconceal(CharsizeArg *csarg, win_T *wp, linenr_T lnum,
                                    ConcealSpans *spans)
  FUNC_ATTR_NONNULL_ALL
{
  *spans = (ConcealSpans)KV_INITIAL_VALUE;
  if (line_has_extconceal(wp, lnum)) {
    decor_providers_invoke_conceal(wp, lnum - 1, false);
    conceal_spans_collect(wp, lnum - 1, ml_get_buf_len(wp->w_buffer, lnum), spans);
  }
  CSType const cstype = init_charsize_arg(csarg, wp, lnum, ml_get_buf(wp->w_buffer, lnum));
  if (kv_size(*spans) == 0) {
    return cstype;
  }
  csarg->extconceal = spans;
  return kCharsizeRegular;
}

/// Like init_charsize_arg(), but do not count inline virtual text at the measured character.
/// The 'linebreak' lookahead can still use "virt_row", without initializing "iter".
CSType init_charsize_arg_skip_cur_text(CharsizeArg *csarg, win_T *wp, linenr_T lnum, char *line)
{
  CSType cstype = init_charsize_arg(csarg, wp, 0, line);
  csarg->skip_cur_text = true;
  if (lnum > 0 && buf_meta_total(wp->w_buffer, kMTMetaInline) > 0) {
    csarg->virt_row = lnum - 1;
    cstype = kCharsizeRegular;
  }
  return cstype;
}

/// Total width of inline virtual text at buffer column "col" of row "row", advancing "iter".
/// Call with non-decreasing "col", like the walks in charsize_regular().
static int inline_virt_text_width(win_T *wp, MarkTreeIter *iter, int row, int col)
{
  buf_T *const buf = wp->w_buffer;
  int width = 0;
  while (true) {
    MTKey mark = marktree_itr_current(iter);
    if (mark.pos.row != row || mark.pos.col > col) {
      break;
    } else if (mark.pos.col == col && !mt_invalid(mark) && ns_in_win(mark.ns, wp)) {
      DecorInline decor = mt_decor(mark);
      DecorVirtText *vt = decor.ext ? decor.data.ext.vt : NULL;
      while (vt) {
        if (!(vt->flags & kVTIsLines) && vt->pos == kVPosInline) {
          width += vt->width;
        }
        vt = vt->next;
      }
    }
    marktree_itr_next_filter(buf->b_marktree, iter, row + 1, 0, inline_filter);
  }
  return width;
}

/// Collects the extmark-conceal of row `row` (`len` bytes) into `spans`, without invoking
/// `_on_conceal`.
void conceal_spans_collect(win_T *wp, int row, int len, ConcealSpans *spans)
{
  if (!decor_row_has_conceal(wp, row)) {
    return;
  }
  DecorState state = { .conceal_only = true };
  decor_redraw_reset(wp, &state);
  decor_redraw_line(wp, row, &state);
  // The state holds from `col` through `state.col_last`; include the NUL, which a multiline mark
  // can conceal.
  for (int col = 0; col <= len; col = state.col_last + 1) {
    decor_redraw_col(wp, col, -1, false, &state, len);
    if (state.conceal == 0) {
      continue;
    }
    // A continuation (no replacement of its own) extends the previous span.
    ConcealSpan *const last = kv_size(*spans) > 0 ? &kv_last(*spans) : NULL;
    if (state.conceal == 1 && last != NULL && last->end_col == col) {
      last->end_col = state.col_last + 1;
    } else {
      kv_push(*spans, ((ConcealSpan){
        .start_col = col,
        .end_col = state.col_last + 1,
        .replacement = decor_conceal_char(wp, &state),
      }));
    }
  }
  decor_state_free(&state);
}

/// @return The span of `spans` containing byte `col`, or NULL.
static const ConcealSpan *conceal_span_at(const ConcealSpans *spans, int col)
{
  size_t lo = 0;
  size_t hi = kv_size(*spans);
  while (lo < hi) {
    size_t const mid = lo + (hi - lo) / 2;
    const ConcealSpan *const span = &kv_A(*spans, mid);
    if (col < span->start_col) {
      hi = mid;
    } else if (col >= span->end_col) {
      lo = mid + 1;
    } else {
      return span;
    }
  }
  return NULL;
}

/// @return Replacement shown for the character at byte `col` of `span`, or NUL when hidden.
static schar_T conceal_span_char(const ConcealSpan *span, int col)
{
  return span->start_col == col ? span->replacement : NUL;
}

/// @return Cells of the character's own `width` at byte `col` hidden by `span` (may be NULL).
static int conceal_span_hidden(const ConcealSpan *span, int col, int width)
{
  if (span == NULL) {
    return 0;
  }
  schar_T const replacement = conceal_span_char(span, col);
  if (replacement == NUL) {
    return width;
  }
  return width - schar_cells(replacement);
}

/// @return First displayed byte of the character at byte `col` of csarg's line (see
///         CharsizeArg.extconceal): a replacement or the text itself. NUL if hidden.
int conceal_disp_byte(const CharsizeArg *csarg, int col)
{
  const ConcealSpan *const span = csarg->extconceal != NULL
                                  ? conceal_span_at(csarg->extconceal, col) : NULL;
  if (span == NULL) {
    return (uint8_t)csarg->line[col];
  }
  schar_T const replacement = conceal_span_char(span, col);
  if (replacement == NUL) {
    return NUL;
  }
  char buf[MAX_SCHAR_SIZE];
  schar_get(buf, replacement);
  return (uint8_t)buf[0];
}

/// @return First displayed byte at or after byte `col` of csarg's line (see conceal_disp_byte()).
///         NUL if the rest of the line is hidden.
static int conceal_next_byte(const CharsizeArg *csarg, int col)
{
  for (const char *p = csarg->line + col; *p != NUL; p += utfc_ptr2len(p)) {
    int const c = conceal_disp_byte(csarg, (int)(p - csarg->line));
    if (c != NUL) {
      return c;
    }
  }
  return NUL;
}

/// Get the number of cells taken up on the screen for the given arguments.
/// "csarg->cur_text_width_left" and "csarg->cur_text_width_right" are set
/// to the extra size for inline virtual text.
///
/// When "csarg->max_head_vcol" is positive, only count in "head" the size
/// of 'showbreak'/'breakindent' before "csarg->max_head_vcol".
/// When "csarg->max_head_vcol" is negative, only count in "head" the size
/// of 'showbreak'/'breakindent' before where cursor should be placed.
CharSize charsize_regular(CharsizeArg *csarg, const char *cur, colnr_T const vcol,
                          int32_t const cur_char, int mb_width)
{
  csarg->cur_text_width_left = 0;
  csarg->cur_text_width_right = 0;

  win_T *wp = csarg->win;
  buf_T *buf = wp->w_buffer;
  char *line = csarg->line;
  bool const use_tabstop = cur_char == TAB && csarg->use_tabstop;
  int mb_added = 0;

  // See CharsizeArg.extconceal_off.
  colnr_T const disp_vcol = vcol - (colnr_T)csarg->extconceal_off;

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
    size = mb_width;
    is_doublewidth = size == 2 && cur_char >= 0x80;
  }

  if (csarg->virt_row >= 0 && !csarg->skip_cur_text) {
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

  // Cells of this character that extmark-conceal hides, and the character 'linebreak' checks.
  int const body = size;
  int hidden = 0;
  int lbr_char = (uint8_t)cur[0];
  const ConcealSpans *const spans = csarg->extconceal;
  if (spans != NULL) {
    int const col = (int)(cur - line);
    int const own = body - csarg->cur_text_width_left - csarg->cur_text_width_right;
    const ConcealSpan *const span = conceal_span_at(spans, col);
    if (span != NULL) {
      hidden = conceal_span_hidden(span, col, own);
      schar_T const replacement = conceal_span_char(span, col);
      is_doublewidth = replacement != NUL && schar_cells(replacement) == 2;
      lbr_char = replacement == NUL ? NUL : schar_get_first_codepoint(replacement);
    } else if (use_tabstop) {
      hidden = MIN(-csarg->extconceal_off, own - 1);  // See CharSize.hidden.
    }
  }
  size -= hidden;

  if (is_doublewidth && wp->w_p_wrap && in_win_border(wp, disp_vcol + size - 2)) {
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
    colnr_T wcol = disp_vcol + col_off_prev;
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
        if (max_head_vcol <= 0 || disp_vcol < max_head_vcol) {
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

        if (max_head_vcol == 0 || disp_vcol + size + added < max_head_vcol) {
          head += cnt * head_mid;
        } else if (width2 > 0 && max_head_vcol > disp_vcol + head_prev + prev_rem) {
          head += (max_head_vcol - (disp_vcol + head_prev + prev_rem)
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
      && lbr_char > 0 && lbr_char < 256 && vim_isbreak(lbr_char)) {
    int const next_col = (int)(cur - line) + utfc_ptr2len(cur);
    // A byte hidden by extmark-conceal never reaches the screen, so the run of 'breakat'
    // characters ends at the next displayed byte.
    int const next_c = conceal_next_byte(csarg, next_col);
    if (!vim_isbreak((uint8_t)next_c)) {
      char *t = csarg->line;
      while (vim_isbreak((uint8_t)t[0])) {
        t++;
      }
      // 'linebreak' is only needed when not in leading whitespace.
      need_lbr = cur >= t;
    }
  }
  if (need_lbr) {
    const char *s = cur;
    // Count all characters from first non-blank after a blank up to next
    // non-blank after a blank.
    int numberextra = win_col_off(wp);
    colnr_T col_adj = size - 1;
    colnr_T colmax = (colnr_T)(wp->w_view_width - numberextra - col_adj);
    if (disp_vcol >= colmax) {
      colmax += col_adj;
      int n = colmax + win_col_off2(wp);
      if (n > 0) {
        colmax += (((disp_vcol + col_adj - colmax) / n) + 1) * n - col_adj;
      }
    }
    // Inline virtual text widens the word, so count it like the loop above does for one
    // character. Needs its own iterator, since this looks ahead of "csarg->iter".
    MarkTreeIter virt_iter[1];
    int has_virt = csarg->virt_row < 0 ? 0 : -1;  // -1: not sought yet
    // Cells hidden since the previous TAB (see CharSize.hidden).
    int lbr_off = csarg->extconceal_off + hidden;
    // Measure from raw vcols once extmark-conceal separates them from displayed vcols.
    bool use_raw_width = lbr_off != 0;
    colnr_T raw_vcol2 = vcol + body;
    colnr_T vcol2 = disp_vcol;
    bool prev_break = true;
    while (true) {
      MB_PTR_ADV(s);
      int c = (uint8_t)(*s);
      if (c == NUL) {
        break;
      }

      int const col = (int)(s - line);
      if (has_virt < 0) {
        has_virt = marktree_itr_get_filter(buf->b_marktree, csarg->virt_row, col,
                                           csarg->virt_row + 1, 0, inline_filter, virt_iter);
      }
      int const virt_width = has_virt
                             ? inline_virt_text_width(wp, virt_iter, csarg->virt_row, col) : 0;

      // Size at the raw vcol (where TABs get their tab stops), and the size this walk counts.
      int const raw_w = spans == NULL ? 0
                                      : *s == TAB && csarg->use_tabstop
                        ? tabstop_padding(raw_vcol2 + virt_width, buf->b_p_ts, buf->b_p_vts_array)
                        : win_chartabsize(wp, s, raw_vcol2);
      int w = use_raw_width ? raw_w : win_chartabsize(wp, s, vcol2 + virt_width);

      const ConcealSpan *const span = spans != NULL ? conceal_span_at(spans, col) : NULL;
      int lookahead_hidden = conceal_span_hidden(span, col, w);
      // From the first hidden cell on, size at raw vcols, so a later TAB counts what it absorbs.
      if (!use_raw_width && lookahead_hidden != 0) {
        use_raw_width = true;
        if (*s == TAB && csarg->use_tabstop) {
          lookahead_hidden += raw_w - w;
          w = raw_w;
        }
      }
      if (use_raw_width && *s == TAB && csarg->use_tabstop && span == NULL) {
        lookahead_hidden = MIN(-lbr_off, w - 1);  // See CharSize.hidden.
      }
      lbr_off += lookahead_hidden;
      raw_vcol2 += raw_w + virt_width;

      // A fully hidden character takes no cell: it neither ends nor widens the word.
      if (w == lookahead_hidden && virt_width == 0) {
        continue;
      }

      // A replacement, not its source, decides whether this is a break character.
      schar_T const replacement = span != NULL ? conceal_span_char(span, col) : NUL;
      if (replacement != NUL) {
        c = schar_get_first_codepoint(replacement);
      }
      bool const is_break = c < 256 && vim_isbreak(c);
      // The word ends where the next one starts, after break characters.
      if (!is_break && prev_break && vcol2 != disp_vcol) {
        break;
      }
      prev_break = is_break;
      vcol2 += w + virt_width - lookahead_hidden;
      if (vcol2 >= colmax) {  // doesn't fit
        size = colmax - disp_vcol + col_adj;
        break;
      }
    }
  }

  int tail = size - size_before_lbr;

  csarg->extconceal_off += hidden;
  return (CharSize){
    .width = size + hidden,
    .body = body,
    .head = head,
    .tail = tail,
    .linebreak = need_lbr,
    .hidden = hidden,
  };
}

/// Like charsize_regular(), except it doesn't handle inline virtual text,
/// 'linebreak', 'breakindent' or 'showbreak'.
/// Handles normal characters, tabs and wrapping.
/// This function is always inlined.
///
/// @see charsize_regular
/// @see charsize_fast
static inline CharSize charsize_fast_impl(win_T *const wp, const char *cur, bool use_tabstop,
                                          colnr_T const vcol, int32_t const cur_char, int mb_width)
  FUNC_ATTR_PURE FUNC_ATTR_ALWAYS_INLINE
{
  // A tab gets expanded, depending on the current column
  if (cur_char == TAB && use_tabstop) {
    int const width = tabstop_padding(vcol, wp->w_buffer->b_p_ts, wp->w_buffer->b_p_vts_array);
    return (CharSize){ .width = width, .body = width };
  } else {
    int width;
    if (cur_char < 0) {
      width = kInvalidByteCells;
    } else {
      // TODO(bfredl): perf: often cur_char is enough at this point to determine width.
      // we likely want a specialized version of utf_ptr2StrCharInfo also determining
      // the ptr2cells width at the same time without any extra decoding. (also applies
      // to charsize_regular and charsize_nowrap)
      width = mb_width;
    }

    // If a double-width char doesn't fit at the end of a line, it wraps to the next line,
    // and the last column displays a '>'.
    if (width == 2 && cur_char >= 0x80 && wp->w_p_wrap && in_win_border(wp, vcol)) {
      return (CharSize){ .width = 3, .body = 2, .head = 1 };
    } else {
      return (CharSize){ .width = width, .body = width };
    }
  }
}

/// Like charsize_regular(), except it doesn't handle inline virtual text,
/// 'linebreak', 'breakindent' or 'showbreak'.
/// Handles normal characters, tabs and wrapping.
/// Can be used if CSType is kCharsizeFast.
///
/// @see charsize_regular
CharSize charsize_fast(CharsizeArg *csarg, const char *cur, colnr_T vcol, int32_t cur_char,
                       int mb_width)
  FUNC_ATTR_PURE
{
  return charsize_fast_impl(csarg->win, cur, csarg->use_tabstop, vcol, cur_char, mb_width);
}

/// Get the number of cells taken up on the screen at given virtual column.
///
/// @see win_chartabsize()
int charsize_nowrap(buf_T *buf, const char *cur, bool use_tabstop, colnr_T vcol, int32_t cur_char,
                    int mb_width)
{
  if (cur_char == TAB && use_tabstop) {
    return tabstop_padding(vcol, buf->b_p_ts, buf->b_p_vts_array);
  } else if (cur_char < 0) {
    return kInvalidByteCells;
  } else {
    return mb_width;
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

/// Converts the displayed cell at `disp_vcol` (see CharsizeArg.extconceal_off) to its raw vcol.
/// MAXCOL stays MAXCOL.
colnr_T disp_vcol2vcol(win_T *wp, linenr_T lnum, colnr_T disp_vcol)
{
  return disp_vcol == MAXCOL
         ? MAXCOL : (colnr_T)MIN(extconceal_vcol_map(wp, lnum, disp_vcol, false, true), MAXCOL - 1);
}

/// Converts the raw cell at `vcol` to its displayed vcol (see disp_vcol2vcol()).
colnr_T vcol2disp_vcol(win_T *wp, linenr_T lnum, colnr_T vcol)
{
  return vcol == MAXCOL
         ? MAXCOL : (colnr_T)MIN(extconceal_vcol_map(wp, lnum, vcol, true, true), MAXCOL - 1);
}

/// Like linetabsize(), but excludes cells hidden by extmark-conceal.
int linetabsize_disp(win_T *wp, linenr_T lnum)
{
  CharsizeArg csarg;
  ConcealSpans spans;
  CSType const cstype = init_charsize_arg_extconceal(&csarg, wp, lnum, &spans);
  int const size = cstype == kCharsizeFast ? linesize_fast(&csarg, 0, MAXCOL)
                                           : linesize_regular(&csarg, 0, MAXCOL);
  kv_destroy(spans);
  return size;
}

/// Like linetabsize_disp(), but counts the size of 'listchars' "eol".
int linetabsize_disp_eol(win_T *wp, linenr_T lnum)
{
  return linetabsize_disp(wp, lnum)
         + ((wp->w_p_list && wp->w_p_lcs_chars.eol != NUL) ? 1 : 0);
}

/// Maps `target` on line `lnum` between raw and displayed vcols (see CharsizeArg.extconceal_off).
///
/// @param to_disp  Map raw to displayed, else displayed to raw.
/// @param cell     `target` is a cell (stays in its character), else the boundary before it.
static int64_t extconceal_vcol_map(win_T *wp, linenr_T lnum, int64_t target, bool to_disp,
                                   bool cell)
{
  if (target < (cell ? 0 : 1) || !line_has_extconceal(wp, lnum)) {
    return target;
  }

  CharsizeArg csarg;
  ConcealSpans spans;
  init_charsize_arg_extconceal(&csarg, wp, lnum, &spans);
  if (kv_size(spans) == 0) {
    return target;
  }
  char *const line = csarg.line;

  // Walk the line in both layouts, `rawarg` without extmark-conceal and `csarg` with it, counting
  // positions of `target`'s kind in `from` and of the other kind in `to`.
  CharsizeArg rawarg;
  init_charsize_arg(&rawarg, wp, lnum, line);
  int64_t raw_vcol = 0;
  int64_t vcol = 0;
  int64_t from = 0;
  int64_t to = 0;
  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  while ((from < target || !to_disp) && *ci.ptr != NUL) {
    ClusterInfo const cli = utf_ClusterInfo(ci);
    CharSize const raw = charsize_regular(&rawarg, ci.ptr, (colnr_T)raw_vcol, ci.chr.value,
                                          cli.cells);
    CharSize const cs = charsize_regular(&csarg, ci.ptr, (colnr_T)vcol, ci.chr.value,
                                         cli.cells);
    int const hidden = cs.hidden;
    int const from_width = to_disp ? raw.width : cs.width - hidden;
    int const to_width = to_disp ? cs.width - hidden : raw.width;

    // The whole character comes before `target`.
    if (target - from >= from_width) {
      from += from_width;
      to += to_width;
      raw_vcol += raw.width;
      vcol += cs.width;
      ci = cli.next;
      continue;
    }

    // A TAB undoes hidden cells at its start (see CharSize.hidden): align its cells at the end.
    bool const tab_end = ci.chr.value == TAB && csarg.use_tabstop
                         && conceal_span_at(&spans, (int)(ci.ptr - line)) == NULL;
    // Map within the character, part by part: wrap prefix, its own cells, 'linebreak' tail.
    int const own_raw = raw.body - rawarg.cur_text_width_left - rawarg.cur_text_width_right;
    int const own_cs = cs.body - csarg.cur_text_width_left - csarg.cur_text_width_right;
    int const raw_parts[] = { raw.width - raw.tail - own_raw, own_raw, raw.tail };
    int const disp_parts[] = {
      cs.width - cs.tail - own_cs, own_cs - hidden, cs.tail,
    };
    const int *const from_parts = to_disp ? raw_parts : disp_parts;
    const int *const to_parts = to_disp ? disp_parts : raw_parts;
    int64_t const to_start = to;
    int64_t remaining = target - from;
    for (int i = 0; i < 3; i++) {
      if (remaining < from_parts[i]) {
        to += i == 1 && tab_end ? MAX(remaining + to_parts[i] - from_parts[i], 0)
                                : MIN(remaining, to_parts[i]);
        break;
      }
      remaining -= from_parts[i];
      to += to_parts[i];
    }
    if (cell && to_width > 0) {
      // Like :syntax conceal, a replacement stands for the last cell of its source.
      to = !to_disp && hidden > 0 ? to_start + to_width - 1 : MIN(to, to_start + to_width - 1);
    }
    from = target;
    break;
  }

  kv_destroy(spans);
  // Past the end of the line, positions map one to one.
  return to + target - from;
}

/// Calculate virtual column until the given "len".
///
/// @param csarg    Argument to charsize functions.
/// @param vcol_arg Starting virtual column.
/// @param len      First byte of the end character, or MAXCOL.
///
/// @return virtual column before the character at "len",
///         or full size of the line if "len" is MAXCOL.
///         Excludes cells hidden by extmark-conceal (see init_charsize_arg_extconceal()).
int linesize_regular(CharsizeArg *const csarg, int vcol_arg, colnr_T const len)
{
  int64_t vcol = vcol_arg;
  // Characters are sized at their raw vcol; only the returned width omits hidden cells.
  int64_t raw_vcol = vcol_arg;

  char *const line = csarg->line;

  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  while (ci.ptr - line < len && *ci.ptr != NUL) {
    ClusterInfo cli = utf_ClusterInfo(ci);
    CharSize cs = charsize_regular(csarg, ci.ptr, (colnr_T)raw_vcol, ci.chr.value, cli.cells);
    vcol += cs.width - cs.hidden;
    raw_vcol += cs.width;
    ci = cli.next;
    if (vcol > MAXCOL) {
      vcol_arg = MAXCOL;
      break;
    } else {
      vcol_arg = (int)vcol;
    }
  }

  // Check for inline virtual text after the end of the line.
  if (len == MAXCOL && csarg->virt_row >= 0 && *ci.ptr == NUL) {
    int head = charsize_regular(csarg, ci.ptr, (colnr_T)raw_vcol, ci.chr.value, 0).head;
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
    ClusterInfo cli = utf_ClusterInfo(ci);
    vcol += charsize_fast_impl(wp, ci.ptr, use_tabstop, vcol_arg, ci.chr.value, cli.cells).width;
    ci = cli.next;
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
  colnr_T const end_col = pos->col;

  CharsizeArg csarg;
  bool on_NUL = false;
  ConcealSpans spans = KV_INITIAL_VALUE;
  CSType const cstype = flags & GETVCOL_DISP
                        ? init_charsize_arg_extconceal(&csarg, wp, pos->lnum, &spans)
                        : init_charsize_arg(&csarg, wp, pos->lnum,
                                            ml_get_buf(wp->w_buffer, pos->lnum));
  csarg.max_head_vcol = -1;
  char *const line = csarg.line;

  colnr_T vcol = 0;
  // Cells hidden before the character, to get displayed vcols (see CharsizeArg.extconceal_off).
  int off = 0;
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
      ClusterInfo cli = utf_ClusterInfo(ci);
      char_size = charsize_fast_impl(wp, ci.ptr, use_tabstop, vcol, ci.chr.value, cli.cells);
      StrCharInfo const next = cli.next;
      if (next.ptr - line > end_col) {
        break;
      }
      ci = next;
      vcol += char_size.width;
    }
  } else {
    while (true) {
      ClusterInfo cli = utf_ClusterInfo(ci);
      off = csarg.extconceal_off;
      char_size = charsize_regular(&csarg, ci.ptr, vcol, ci.chr.value, cli.cells);
      // make sure we don't go past the end of the line
      if (*ci.ptr == NUL) {
        // NUL at end of line only takes one column unless there is virtual text
        char_size.width = 1 + csarg.cur_text_width_left + csarg.cur_text_width_right;
        char_size.hidden = 0;
        on_NUL = true;
        break;
      }
      StrCharInfo const next = cli.next;
      if (next.ptr - line > end_col) {
        break;
      }
      ci = next;
      vcol += char_size.width;
    }
  }
  // The cursor sits at the end of a TAB, unless extmark-conceal hides or replaces the TAB.
  bool const concealed = conceal_span_at(&spans, (int)(ci.ptr - line)) != NULL;
  kv_destroy(spans);

  if (*ci.ptr == NUL && end_col < MAXCOL && end_col > ci.ptr - line) {
    pos->col = (colnr_T)(ci.ptr - line);
  }

  int incr = char_size.width;
  int head = char_size.head;
  int tail = char_size.tail;

  if (start != NULL) {
    *start = vcol + head - off;
  }
  if (end != NULL) {
    *end = vcol + incr - char_size.hidden - (flags & GETVCOL_END_EXCL_LBR ? tail : 0) - 1 - off;
  }
  if (cursor != NULL) {
    if (ci.chr.value == TAB
        && !concealed
        && (State & MODE_NORMAL)
        && !wp->w_p_list
        && !virtual_active(wp)
        && !(Visual.active && ((*p_sel == 'e') || ltoreq(*pos, Visual.start)))) {
      // TODO(zeertzjq): subtracting "tail" may lead to better cursor position
      *cursor = vcol + incr - char_size.hidden - 1 - off;  // cursor at end
    } else {
      vcol += virt_text_cursor_off(&csarg, on_NUL);
      *cursor = vcol + head - off;  // cursor at start
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

/// Get number of window lines physical line "lnum" will occupy in window "wp".
/// Does not care about folding, 'wrap' or filler lines.
int plines_win_nofold(win_T *wp, linenr_T lnum)
{
  CharsizeArg csarg;
  ConcealSpans spans;
  CSType const cstype = init_charsize_arg_extconceal(&csarg, wp, lnum, &spans);
  if (*csarg.line == NUL && csarg.virt_row < 0) {
    kv_destroy(spans);
    return 1;  // be quick for an empty line
  }

  int64_t col;
  if (cstype == kCharsizeFast) {
    col = linesize_fast(&csarg, 0, MAXCOL);
  } else {
    col = linesize_regular(&csarg, 0, MAXCOL);
  }
  kv_destroy(spans);

  // If list mode is on, then the '$' at the end of the line may take up one
  // extra column.
  if (wp->w_p_list && wp->w_p_lcs_chars.eol != NUL) {
    col += 1;
  }

  // Add column offset for 'number', 'relativenumber' and 'foldcolumn'.
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

/// Like plines_win(), but only reports the number of physical screen lines
/// used from the start of the line to the given byte column.
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

  CharsizeArg csarg;
  ConcealSpans spans;
  CSType const cstype = init_charsize_arg_extconceal(&csarg, wp, lnum, &spans);
  char *const line = csarg.line;

  // TABs are sized at their raw vcol, as in linesize_regular().
  colnr_T vcol = 0;
  colnr_T raw_vcol = 0;
  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  if (cstype == kCharsizeFast) {
    bool const use_tabstop = csarg.use_tabstop;
    while (*ci.ptr != NUL && ci.ptr < line + column) {
      ClusterInfo cli = utf_ClusterInfo(ci);
      vcol += charsize_fast_impl(wp, ci.ptr, use_tabstop, vcol, ci.chr.value, cli.cells).width;
      ci = cli.next;
    }
    raw_vcol = vcol;
  } else {
    while (*ci.ptr != NUL && ci.ptr < line + column) {
      ClusterInfo cli = utf_ClusterInfo(ci);
      CharSize const cs = charsize_regular(&csarg, ci.ptr, raw_vcol, ci.chr.value, cli.cells);
      int const hidden = cs.hidden;
      vcol += cs.width - hidden;
      raw_vcol += cs.width;
      ci = cli.next;
    }
  }
  // If current char is a TAB, and the TAB is not displayed as ^I, and we're not
  // in MODE_INSERT state, then col must be adjusted so that it represents the
  // last screen position of the TAB.  This only fixes an error when the TAB
  // wraps from one screen line to the next (when 'columns' is not a multiple
  // of 'ts') -- webb.
  colnr_T col = vcol;
  if (ci.chr.value == TAB && (State & MODE_NORMAL) && csarg.use_tabstop) {
    CharSize const cs = win_charsize(cstype, raw_vcol, ci.ptr, ci.chr.value, &csarg, 1);
    int const hidden = cs.hidden;
    col += MAX(cs.width - hidden - 1, 0);
  }
  kv_destroy(spans);

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
/// @param[in] vcol_is_disp  `start_vcol` and `end_vcol` are displayed vcols (see
///                          CharsizeArg.extconceal_off), else raw vcols.
/// @param[out] fill         If not NULL, set to the number of filler lines in the range.
int64_t win_text_height(win_T *const wp, const linenr_T start_lnum, const int64_t start_vcol,
                        linenr_T *const end_lnum, int64_t *const end_vcol, int64_t *const fill,
                        int64_t const max, bool const vcol_is_disp)
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
    // Rows are counted in displayed vcols.
    int64_t const start_disp = !vcol_is_disp && !cur_folded
                               ? extconceal_vcol_map(wp, lnum, start_vcol, true, false)
                               : start_vcol;
    const int64_t row_off = (start_disp < width1 || width2 <= 0)
                            ? 0
                            : 1 + (start_disp - width1) / width2;
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
    int64_t const end_disp = !vcol_is_disp && !cur_folded
                             ? extconceal_vcol_map(wp, cur_lnum, vcol_end, true, false)
                             : vcol_end;
    const int64_t row_off = end_disp == 0
                            ? 0
                            : (end_disp <= width1 || width2 <= 0)
                            ? 1
                            : 1 + (end_disp - width1 + width2 - 1) / width2;
    height_sum_nofill += MIN(row_off, height_cur_nofill);
  }

  if (cur_folded) {
    vcol_end = 0;
  } else {
    int linesize = vcol_is_disp ? linetabsize_disp_eol(wp, cur_lnum)
                                : linetabsize_eol(wp, cur_lnum);
    vcol_end = MIN(use_vcol ? vcol_end : INT64_MAX, linesize);
  }

  // Cut the end back to the row that reaches `max`, in displayed vcols, and report it in the kind
  // of vcols the caller passed.
  int64_t overflow = height_sum_nofill + height_sum_fill - max;
  if (overflow > 0 && width2 > 0) {
    int64_t end_disp = vcol_is_disp ? vcol_end : extconceal_vcol_map(wp, cur_lnum, vcol_end, true,
                                                                     false);
    if (end_disp > width2) {
      end_disp -= (end_disp - width1) % width2 + (overflow - 1) * width2;
      vcol_end = vcol_is_disp ? end_disp : extconceal_vcol_map(wp, cur_lnum, end_disp, false,
                                                               false);
    }
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
