// drawline.c: Functions for drawing window lines on the screen.
// This is the middle level, drawscreen.c is the top and grid.c the lower level.

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/cursor_shape.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/decoration_provider.h"
#include "nvim/diff.h"
#include "nvim/drawline.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/fold.h"
#include "nvim/fold_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/insexpand.h"
#include "nvim/mark_defs.h"
#include "nvim/marktree_defs.h"
#include "nvim/match.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/os_defs.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/quickfix.h"
#include "nvim/sign_defs.h"
#include "nvim/spell.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/statusline.h"
#include "nvim/statusline_defs.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"

#define MB_FILLER_CHAR '<'  // character used when a double-width character doesn't fit.

/// structure with variables passed between win_line() and other functions
typedef struct {
  const linenr_T lnum;       ///< line number to be drawn
  const foldinfo_T foldinfo;  ///< fold info for this line

  const int startrow;        ///< first row in the window to be drawn
  int row;                   ///< row in the window, excl w_winrow

  colnr_T vcol;              ///< virtual column, before wrapping
  int col;                   ///< visual column on screen, after wrapping
  int boguscols;             ///< nonexistent columns added to "col" to force wrapping
  int old_boguscols;         ///< bogus boguscols
  int vcol_off_co;           ///< offset for concealed characters

  int off;                   ///< offset relative start of line

  int cul_attr;              ///< set when 'cursorline' active
  int line_attr;             ///< attribute for the whole line
  int line_attr_lowprio;     ///< low-priority attribute for the line
  int sign_num_attr;         ///< line number attribute (sign numhl)
  int prev_num_attr;         ///< previous line's number attribute (sign numhl)
  int sign_cul_attr;         ///< cursorline sign attribute (sign culhl)

  int fromcol;               ///< start of inverting
  int tocol;                 ///< end of inverting

  colnr_T vcol_sbr;          ///< virtual column after showbreak
  bool need_showbreak;       ///< overlong line, skipping first x chars

  int char_attr;             ///< attributes for next character

  int n_extra;               ///< number of extra bytes
  int n_attr;                ///< chars with special attr
  char *p_extra;             ///< string of extra chars, plus NUL, only used
                             ///< when sc_extra and sc_final are NUL
  int extra_attr;            ///< attributes for p_extra
  schar_T sc_extra;          ///< extra chars, all the same
  schar_T sc_final;          ///< final char, mandatory if set

  bool extra_for_extmark;    ///< n_extra set for inline virtual text

  char extra[11];            ///< must be as large as transchar_charbuf[] in charset.c

  hlf_T diff_hlf;            ///< type of diff highlighting

  int n_virt_lines;          ///< nr of virtual lines
  int n_virt_below;          ///< nr of virtual lines belonging to previous line
  int filler_lines;          ///< nr of filler lines to be drawn
  int filler_todo;           ///< nr of filler lines still to do + 1
  SignTextAttrs sattrs[SIGN_SHOW_MAX];  ///< sign attributes for the sign column
  /// do consider wrapping in linebreak mode only after encountering
  /// a non whitespace char
  bool need_lbr;

  VirtText virt_inline;
  size_t virt_inline_i;
  HlMode virt_inline_hl_mode;

  bool reset_extra_attr;

  int skip_cells;            ///< nr of cells to skip for w_leftcol
                             ///< or w_skipcol or concealing
  int skipped_cells;         ///< nr of skipped cells for virtual text
                             ///< to be added to wlv.vcol later

  int *color_cols;           ///< if not NULL, highlight colorcolumn using according columns array
} winlinevars_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "drawline.c.generated.h"
#endif

static char *extra_buf = NULL;
static size_t extra_buf_size = 0;

static char *get_extra_buf(size_t size)
{
  size = MAX(size, 64);
  if (extra_buf_size < size) {
    xfree(extra_buf);
    extra_buf = xmalloc(size);
    extra_buf_size = size;
  }
  return extra_buf;
}

#ifdef EXITFREE
void drawline_free_all_mem(void)
{
  xfree(extra_buf);
}
#endif

/// Advance wlv->color_cols if not NULL
static void advance_color_col(winlinevars_T *wlv, int vcol)
{
  if (wlv->color_cols) {
    while (*wlv->color_cols >= 0 && vcol > *wlv->color_cols) {
      wlv->color_cols++;
    }
    if (*wlv->color_cols < 0) {
      wlv->color_cols = NULL;
    }
  }
}

/// Used when 'cursorlineopt' contains "screenline": compute the margins between
/// which the highlighting is used.
static void margin_columns_win(win_T *wp, int *left_col, int *right_col)
{
  // cache previous calculations depending on w_virtcol
  static int saved_w_virtcol;
  static win_T *prev_wp;
  static int prev_width1;
  static int prev_width2;
  static int prev_left_col;
  static int prev_right_col;

  int cur_col_off = win_col_off(wp);
  int width1 = wp->w_view_width - cur_col_off;
  int width2 = width1 + win_col_off2(wp);

  if (saved_w_virtcol == wp->w_virtcol && prev_wp == wp
      && prev_width1 == width1 && prev_width2 == width2) {
    *right_col = prev_right_col;
    *left_col = prev_left_col;
    return;
  }

  *left_col = 0;
  *right_col = width1;

  if (wp->w_virtcol >= (colnr_T)width1 && width2 > 0) {
    *right_col = width1 + ((wp->w_virtcol - width1) / width2 + 1) * width2;
  }
  if (wp->w_virtcol >= (colnr_T)width1 && width2 > 0) {
    *left_col = (wp->w_virtcol - width1) / width2 * width2 + width1;
  }

  // cache values
  prev_left_col = *left_col;
  prev_right_col = *right_col;
  prev_wp = wp;
  prev_width1 = width1;
  prev_width2 = width2;
  saved_w_virtcol = wp->w_virtcol;
}

/// Put a single char from an UTF-8 buffer into a line buffer.
///
/// If `*pp` is a double-width char and only one cell is left, emit a space,
/// and don't advance *pp
///
/// Handles composing chars
static int line_putchar(buf_T *buf, const char **pp, schar_T *dest, int maxcells, int vcol)
{
  // Caller should handle overwriting the right half of a double-width char.
  assert(dest[0] != 0);

  const char *p = *pp;
  int cells = utf_ptr2cells(p);
  int c_len = utfc_ptr2len(p);
  assert(maxcells > 0);
  if (cells > maxcells) {
    dest[0] = schar_from_ascii(' ');
    return 1;
  }

  if (*p == TAB) {
    cells = tabstop_padding(vcol, buf->b_p_ts, buf->b_p_vts_array);
    cells = MIN(cells, maxcells);
  }

  // When overwriting the left half of a double-width char, clear the right half.
  if (cells < maxcells && dest[cells] == 0) {
    dest[cells] = schar_from_ascii(' ');
  }
  if (*p == TAB) {
    for (int c = 0; c < cells; c++) {
      dest[c] = schar_from_ascii(' ');
    }
  } else {
    int u8c;
    dest[0] = utfc_ptr2schar(p, &u8c);
    if (cells > 1) {
      dest[1] = 0;
    }
  }

  *pp += c_len;
  return cells;
}

static void draw_virt_text(win_T *wp, buf_T *buf, int col_off, int *end_col, int win_row)
{
  DecorState *const state = &decor_state;
  int const max_col = wp->w_view_width;
  int right_pos = max_col;
  bool const do_eol = state->eol_col > -1;

  int const end = state->current_end;
  int *const indices = state->ranges_i.items;
  DecorRangeSlot *const slots = state->slots.items;

  /// Total width of all virtual text with "eol_right_align" alignment
  int totalWidthOfEolRightAlignedVirtText = 0;

  for (int i = 0; i < end; i++) {
    DecorRange *item = &slots[indices[i]].range;
    if (!(item->start_row == state->row && decor_virt_pos(item))) {
      continue;
    }

    DecorVirtText *vt = NULL;
    if (item->kind == kDecorKindVirtText) {
      assert(item->data.vt);
      vt = item->data.vt;
    }
    if (decor_virt_pos(item) && item->draw_col == -1) {
      bool updated = true;
      VirtTextPos pos = decor_virt_pos_kind(item);

      if (do_eol && pos == kVPosEndOfLineRightAlign) {
        int eolOffset = 0;
        if (totalWidthOfEolRightAlignedVirtText == 0) {
          // Look ahead to the remaining decor items
          for (int j = i; j < end; j++) {
            /// A future decor to be handled in this function's call
            DecorRange *lookaheadItem = &slots[indices[j]].range;

            if (lookaheadItem->start_row != state->row
                || !decor_virt_pos(lookaheadItem)
                || lookaheadItem->draw_col != -1) {
              continue;
            }

            /// The Virtual Text of the decor item we're looking ahead to
            DecorVirtText *lookaheadVt = NULL;
            if (item->kind == kDecorKindVirtText) {
              assert(item->data.vt);
              lookaheadVt = item->data.vt;
            }

            if (decor_virt_pos_kind(lookaheadItem) == kVPosEndOfLineRightAlign) {
              // An extra space is added for single character spacing in EOL alignment
              totalWidthOfEolRightAlignedVirtText += (lookaheadVt->width + 1);
            }
          }

          // Remove one space from the total width since there's no single space after the last entry
          totalWidthOfEolRightAlignedVirtText--;

          if (totalWidthOfEolRightAlignedVirtText <= (right_pos - state->eol_col)) {
            eolOffset = right_pos - totalWidthOfEolRightAlignedVirtText - state->eol_col;
          }
        }

        item->draw_col = state->eol_col + eolOffset;
      } else if (pos == kVPosRightAlign) {
        right_pos -= vt->width;
        item->draw_col = right_pos;
      } else if (pos == kVPosEndOfLine && do_eol) {
        item->draw_col = state->eol_col;
      } else if (pos == kVPosWinCol) {
        item->draw_col = MAX(col_off + vt->col, 0);
      } else {
        updated = false;
      }
      if (updated && (item->draw_col < 0 || item->draw_col >= wp->w_view_width)) {
        // Out of window, don't draw at all.
        item->draw_col = INT_MIN;
      }
    }
    if (item->draw_col < 0) {
      continue;
    }
    if (item->kind == kDecorKindUIWatched) {
      // send mark position to UI
      WinExtmark m = { (NS)item->data.ui.ns_id, item->data.ui.mark_id, win_row, item->draw_col };
      kv_push(win_extmark_arr, m);
    }
    if (vt) {
      int vcol = item->draw_col - col_off;
      int col = draw_virt_text_item(buf, item->draw_col, vt->data.virt_text,
                                    vt->hl_mode, max_col, vcol, 0);
      if (do_eol && ((vt->pos == kVPosEndOfLine) || (vt->pos == kVPosEndOfLineRightAlign))) {
        state->eol_col = col + 1;
      }
      *end_col = MAX(*end_col, col);
    }
    if (!vt || !(vt->flags & kVTRepeatLinebreak)) {
      item->draw_col = INT_MIN;  // deactivate
    }
  }
}

static int draw_virt_text_item(buf_T *buf, int col, VirtText vt, HlMode hl_mode, int max_col,
                               int vcol, int skip_cells)
{
  const char *virt_str = "";
  int virt_attr = 0;
  size_t virt_pos = 0;

  while (col < max_col) {
    if (skip_cells >= 0 && *virt_str == NUL) {
      if (virt_pos >= kv_size(vt)) {
        break;
      }
      virt_attr = 0;
      virt_str = next_virt_text_chunk(vt, &virt_pos, &virt_attr);
      if (virt_str == NULL) {
        break;
      }
    }
    // Skip cells in the text.
    while (skip_cells > 0 && *virt_str != NUL) {
      int c_len = utfc_ptr2len(virt_str);
      int cells = *virt_str == TAB
                  ? tabstop_padding(vcol, buf->b_p_ts, buf->b_p_vts_array)
                  : utf_ptr2cells(virt_str);
      skip_cells -= cells;
      vcol += cells;
      virt_str += c_len;
    }
    // If a double-width char or TAB doesn't fit, pad with spaces.
    const char *draw_str = skip_cells < 0 ? " " : virt_str;
    if (*draw_str == NUL) {
      continue;
    }
    assert(skip_cells <= 0);
    int attr;
    bool through = false;
    if (hl_mode == kHlModeCombine) {
      attr = hl_combine_attr(linebuf_attr[col], virt_attr);
    } else if (hl_mode == kHlModeBlend) {
      through = (*draw_str == ' ');
      attr = hl_blend_attrs(linebuf_attr[col], virt_attr, &through);
    } else {
      attr = virt_attr;
    }
    schar_T dummy[2] = { schar_from_ascii(' '), schar_from_ascii(' ') };
    int maxcells = max_col - col;
    // When overwriting the right half of a double-width char, clear the left half.
    if (!through && linebuf_char[col] == 0) {
      assert(col > 0);
      linebuf_char[col - 1] = schar_from_ascii(' ');
      // Clear the right half as well for the assertion in line_putchar().
      linebuf_char[col] = schar_from_ascii(' ');
    }
    int cells = line_putchar(buf, &draw_str, through ? dummy : &linebuf_char[col],
                             maxcells, vcol);
    for (int c = 0; c < cells; c++) {
      linebuf_attr[col] = attr;
      col++;
    }
    if (skip_cells < 0) {
      skip_cells++;
    } else {
      vcol += cells;
      virt_str = draw_str;
    }
  }
  return col;
}

// TODO(bfredl): integrate with grid.c linebuf code? madness?
static void draw_col_buf(win_T *wp, winlinevars_T *wlv, const char *text, size_t len, int attr,
                         const colnr_T *fold_vcol, bool inc_vcol)
{
  const char *ptr = text;
  while (ptr < text + len && wlv->off < wp->w_view_width) {
    int cells = line_putchar(wp->w_buffer, &ptr, &linebuf_char[wlv->off],
                             wp->w_view_width - wlv->off, wlv->off);
    int myattr = attr;
    if (inc_vcol) {
      advance_color_col(wlv, wlv->vcol);
      if (wlv->color_cols && wlv->vcol == *wlv->color_cols) {
        myattr = hl_combine_attr(win_hl_attr(wp, HLF_MC), myattr);
      }
    }
    for (int c = 0; c < cells; c++) {
      linebuf_attr[wlv->off] = myattr;
      linebuf_vcol[wlv->off] = inc_vcol ? wlv->vcol++ : fold_vcol ? *(fold_vcol++) : -1;
      wlv->off++;
    }
  }
}

static void draw_col_fill(winlinevars_T *wlv, schar_T fillchar, int width, int attr)
{
  for (int i = 0; i < width; i++) {
    linebuf_char[wlv->off] = fillchar;
    linebuf_attr[wlv->off] = attr;
    wlv->off++;
  }
}

/// Return true if CursorLineSign highlight is to be used.
bool use_cursor_line_highlight(win_T *wp, linenr_T lnum)
{
  return wp->w_p_cul
         && lnum == wp->w_cursorline
         && (wp->w_p_culopt_flags & kOptCuloptFlagNumber);
}

/// Setup for drawing the 'foldcolumn', if there is one.
static void draw_foldcolumn(win_T *wp, winlinevars_T *wlv)
{
  int fdc = compute_foldcolumn(wp, 0);
  if (fdc > 0) {
    int attr = win_hl_attr(wp, use_cursor_line_highlight(wp, wlv->lnum) ? HLF_CLF : HLF_FC);
    fill_foldcolumn(wp, wlv->foldinfo, wlv->lnum, attr, fdc, &wlv->off, NULL, NULL);
  }
}

/// Draw the foldcolumn or fill "out_buffer". Assume monocell characters.
///
/// @param fdc  Current width of the foldcolumn
/// @param[out] wlv_off  Pointer to linebuf offset, incremented for default column
/// @param[out] out_buffer  Char array to fill, only used for 'statuscolumn'
/// @param[out] out_vcol  vcol array to fill, only used for 'statuscolumn'
void fill_foldcolumn(win_T *wp, foldinfo_T foldinfo, linenr_T lnum, int attr, int fdc, int *wlv_off,
                     colnr_T *out_vcol, schar_T *out_buffer)
{
  bool closed = foldinfo.fi_level != 0 && foldinfo.fi_lines > 0;
  int level = foldinfo.fi_level;

  // If the column is too narrow, we start at the lowest level that
  // fits and use numbers to indicate the depth.
  int first_level = MAX(level - fdc - closed + 1, 1);
  int closedcol = MIN(fdc, level);

  for (int i = 0; i < fdc; i++) {
    schar_T symbol = 0;
    if (i >= level) {
      symbol = schar_from_ascii(' ');
    } else if (i == closedcol - 1 && closed) {
      symbol = wp->w_p_fcs_chars.foldclosed;
    } else if (foldinfo.fi_lnum == lnum && first_level + i >= foldinfo.fi_low_level) {
      symbol = wp->w_p_fcs_chars.foldopen;
    } else if (first_level == 1) {
      symbol = wp->w_p_fcs_chars.foldsep;
    } else if (first_level + i <= 9) {
      symbol = schar_from_ascii('0' + first_level + i);
    } else {
      symbol = schar_from_ascii('>');
    }

    int vcol = i >= level ? -1 : (i == closedcol - 1 && closed) ? -2 : -3;
    if (out_buffer) {
      out_vcol[i] = vcol;
      out_buffer[i] = symbol;
    } else {
      linebuf_vcol[*wlv_off] = vcol;
      linebuf_attr[*wlv_off] = attr;
      linebuf_char[(*wlv_off)++] = symbol;
    }
  }
}

/// Get information needed to display the sign in line "wlv->lnum" in window "wp".
/// If "nrcol" is true, the sign is going to be displayed in the number column.
/// Otherwise the sign is going to be displayed in the sign column. If there is no
/// sign, draw blank cells instead.
static void draw_sign(bool nrcol, win_T *wp, winlinevars_T *wlv, int sign_idx)
{
  SignTextAttrs sattr = wlv->sattrs[sign_idx];
  int scl_attr = win_hl_attr(wp, use_cursor_line_highlight(wp, wlv->lnum) ? HLF_CLS : HLF_SC);

  if (sattr.text[0] && wlv->row == wlv->startrow + wlv->filler_lines && wlv->filler_todo <= 0) {
    int fill = nrcol ? number_width(wp) + 1 : SIGN_WIDTH;
    int attr = wlv->sign_cul_attr ? wlv->sign_cul_attr : sattr.hl_id ? syn_id2attr(sattr.hl_id) : 0;
    attr = hl_combine_attr(scl_attr, attr);
    draw_col_fill(wlv, schar_from_ascii(' '), fill, attr);
    int sign_pos = wlv->off - SIGN_WIDTH - (int)nrcol;
    assert(sign_pos >= 0);
    linebuf_char[sign_pos] = sattr.text[0];
    linebuf_char[sign_pos + 1] = sattr.text[1];
  } else {
    assert(!nrcol);  // handled in draw_lnum_col()
    draw_col_fill(wlv, schar_from_ascii(' '), SIGN_WIDTH, scl_attr);
  }
}

static inline void get_line_number_str(win_T *wp, linenr_T lnum, char *buf, size_t buf_len)
{
  linenr_T num;
  char *fmt = "%*" PRIdLINENR " ";

  if (wp->w_p_nu && !wp->w_p_rnu) {
    // 'number' + 'norelativenumber'
    num = lnum;
  } else {
    // 'relativenumber', don't use negative numbers
    num = abs(get_cursor_rel_lnum(wp, lnum));
    if (num == 0 && wp->w_p_nu && wp->w_p_rnu) {
      // 'number' + 'relativenumber'
      num = lnum;
      fmt = "%-*" PRIdLINENR " ";
    }
  }

  snprintf(buf, buf_len, fmt, number_width(wp), num);
}

/// Return true if CursorLineNr highlight is to be used for the number column.
/// - 'cursorline' must be set
/// - "wlv->lnum" must be the cursor line
/// - 'cursorlineopt' has "number"
/// - don't highlight filler lines (when in diff mode)
/// - When line is wrapped and 'cursorlineopt' does not have "line", only highlight the line number
///   itself on the first screenline of the wrapped line, otherwise highlight the number column of
///   all screenlines of the wrapped line.
static bool use_cursor_line_nr(win_T *wp, winlinevars_T *wlv)
{
  return wp->w_p_cul
         && wlv->lnum == wp->w_cursorline
         && (wp->w_p_culopt_flags & kOptCuloptFlagNumber)
         && (wlv->row == wlv->startrow + wlv->filler_lines
             || (wlv->row > wlv->startrow + wlv->filler_lines
                 && (wp->w_p_culopt_flags & kOptCuloptFlagLine)));
}

/// Return line number attribute, combining the appropriate LineNr* highlight
/// with the highest priority sign numhl highlight, if any.
static int get_line_number_attr(win_T *wp, winlinevars_T *wlv)
{
  int numhl_attr = wlv->sign_num_attr;

  // Get previous sign numhl for virt_lines belonging to the previous line.
  if ((wlv->n_virt_lines - wlv->filler_todo) < wlv->n_virt_below) {
    if (wlv->prev_num_attr == -1) {
      decor_redraw_signs(wp, wp->w_buffer, wlv->lnum - 2, NULL, NULL, NULL, &wlv->prev_num_attr);
      if (wlv->prev_num_attr > 0) {
        wlv->prev_num_attr = syn_id2attr(wlv->prev_num_attr);
      }
    }
    numhl_attr = wlv->prev_num_attr;
  }

  if (use_cursor_line_nr(wp, wlv)) {
    // TODO(vim): Can we use CursorLine instead of CursorLineNr
    // when CursorLineNr isn't set?
    return hl_combine_attr(win_hl_attr(wp, HLF_CLN), numhl_attr);
  }

  if (wp->w_p_rnu) {
    if (wlv->lnum < wp->w_cursor.lnum) {
      // Use LineNrAbove
      return hl_combine_attr(win_hl_attr(wp, HLF_LNA), numhl_attr);
    }
    if (wlv->lnum > wp->w_cursor.lnum) {
      // Use LineNrBelow
      return hl_combine_attr(win_hl_attr(wp, HLF_LNB), numhl_attr);
    }
  }

  return hl_combine_attr(win_hl_attr(wp, HLF_N), numhl_attr);
}

/// Display the absolute or relative line number.  After the first row fill with
/// blanks when the 'n' flag isn't in 'cpo'.
static void draw_lnum_col(win_T *wp, winlinevars_T *wlv)
{
  bool has_cpo_n = vim_strchr(p_cpo, CPO_NUMCOL) != NULL;

  if ((wp->w_p_nu || wp->w_p_rnu)
      && (wlv->row == wlv->startrow + wlv->filler_lines || !has_cpo_n)
      // there is no line number in a wrapped line when "n" is in
      // 'cpoptions', but 'breakindent' assumes it anyway.
      && !((has_cpo_n && !wp->w_p_bri) && wp->w_skipcol > 0 && wlv->lnum == wp->w_topline)) {
    // If 'signcolumn' is set to 'number' and a sign is present in "lnum",
    // then display the sign instead of the line number.
    if (wp->w_minscwidth == SCL_NUM && wlv->sattrs[0].text[0]
        && wlv->row == wlv->startrow + wlv->filler_lines && wlv->filler_todo <= 0) {
      draw_sign(true, wp, wlv, 0);
    } else {
      // Draw the line number (empty space after wrapping).
      int width = number_width(wp) + 1;
      int attr = get_line_number_attr(wp, wlv);
      if (wlv->row == wlv->startrow + wlv->filler_lines
          && (wp->w_skipcol == 0 || wlv->row > 0 || (wp->w_p_nu && wp->w_p_rnu))) {
        char buf[32];
        get_line_number_str(wp, wlv->lnum, buf, sizeof(buf));
        if (wp->w_skipcol > 0 && wlv->startrow == 0) {
          for (char *c = buf; *c == ' '; c++) {
            *c = '-';
          }
        }
        if (wp->w_p_rl) {  // reverse line numbers
          char *num = skipwhite(buf);
          rl_mirror_ascii(num, skiptowhite(num));
        }
        draw_col_buf(wp, wlv, buf, (size_t)width, attr, NULL, false);
      } else {
        draw_col_fill(wlv, schar_from_ascii(' '), width, attr);
      }
    }
  }
}

/// Build and draw the 'statuscolumn' string for line "lnum" in window "wp".
static void draw_statuscol(win_T *wp, winlinevars_T *wlv, int virtnum, int col_rows,
                           statuscol_T *stcp)
{
  // Adjust lnum for filler lines belonging to the line above and set lnum v:vars for first
  // row, first non-filler line, and first filler line belonging to the current line.
  linenr_T lnum = wlv->lnum - ((wlv->n_virt_lines - wlv->filler_todo) < wlv->n_virt_below);
  linenr_T relnum = (virtnum == -wlv->filler_lines || virtnum == 0
                     || virtnum == (wlv->n_virt_below - wlv->filler_lines))
                    ? abs(get_cursor_rel_lnum(wp, lnum)) : -1;

  char buf[MAXPATHL];
  // When a buffer's line count has changed, make a best estimate for the full
  // width of the status column by building with the largest possible line number.
  // Add potentially truncated width and rebuild before drawing anything.
  if (wp->w_statuscol_line_count != wp->w_nrwidth_line_count) {
    wp->w_statuscol_line_count = wp->w_nrwidth_line_count;
    set_vim_var_nr(VV_VIRTNUM, 0);
    int width = build_statuscol_str(wp, wp->w_nrwidth_line_count,
                                    wp->w_nrwidth_line_count, buf, stcp);
    if (width > stcp->width) {
      int addwidth = MIN(width - stcp->width, MAX_STCWIDTH - stcp->width);
      wp->w_nrwidth += addwidth;
      wp->w_nrwidth_width = wp->w_nrwidth;
      if (col_rows > 0) {
        // If only column is being redrawn, we now need to redraw the text as well
        wp->w_redr_statuscol = true;
        return;
      }
      stcp->width += addwidth;
      wp->w_valid &= ~VALID_WCOL;
    }
  }
  set_vim_var_nr(VV_VIRTNUM, virtnum);

  int width = build_statuscol_str(wp, lnum, relnum, buf, stcp);
  // Force a redraw in case of error or when truncated
  if (*wp->w_p_stc == NUL || (width > stcp->width && stcp->width < MAX_STCWIDTH)) {
    if (*wp->w_p_stc == NUL) {  // 'statuscolumn' reset due to error
      wp->w_nrwidth_line_count = 0;
      wp->w_nrwidth = (wp->w_p_nu || wp->w_p_rnu) * number_width(wp);
    } else {  // Avoid truncating 'statuscolumn'
      wp->w_nrwidth += MIN(width - stcp->width, MAX_STCWIDTH - stcp->width);
      wp->w_nrwidth_width = wp->w_nrwidth;
    }
    wp->w_redr_statuscol = true;
    return;
  }

  char *p = buf;
  char transbuf[MAXPATHL];
  colnr_T *fold_vcol = NULL;
  size_t len = strlen(buf);
  int scl_attr = win_hl_attr(wp, use_cursor_line_highlight(wp, wlv->lnum) ? HLF_CLS : HLF_SC);
  int num_attr = get_line_number_attr(wp, wlv);
  int cur_attr = num_attr;

  // Draw each segment with the specified highlighting.
  for (stl_hlrec_t *sp = stcp->hlrec; sp->start != NULL; sp++) {
    ptrdiff_t textlen = sp->start - p;
    // Make all characters printable.
    size_t translen = transstr_buf(p, textlen, transbuf, MAXPATHL, true);
    draw_col_buf(wp, wlv, transbuf, translen, cur_attr, fold_vcol, false);
    int attr = sp->item == STL_SIGNCOL ? scl_attr : sp->item == STL_FOLDCOL ? 0 : num_attr;
    cur_attr = hl_combine_attr(attr, sp->userhl < 0 ? syn_id2attr(-sp->userhl) : 0);
    fold_vcol = sp->item == STL_FOLDCOL ? stcp->fold_vcol : NULL;
    p = sp->start;
  }
  size_t translen = transstr_buf(p, buf + len - p, transbuf, MAXPATHL, true);
  draw_col_buf(wp, wlv, transbuf, translen, cur_attr, fold_vcol, false);
  draw_col_fill(wlv, schar_from_ascii(' '), stcp->width - width, cur_attr);
}

static void handle_breakindent(win_T *wp, winlinevars_T *wlv)
{
  // draw 'breakindent': indent wrapped text accordingly
  // if wlv->need_showbreak is set, breakindent also applies
  if (wp->w_p_bri && (wlv->row > wlv->startrow + wlv->filler_lines
                      || wlv->need_showbreak)) {
    int attr = 0;
    if (wlv->diff_hlf != (hlf_T)0) {
      attr = win_hl_attr(wp, (int)wlv->diff_hlf);
    }
    int num = get_breakindent_win(wp, ml_get_buf(wp->w_buffer, wlv->lnum));
    if (wlv->row == wlv->startrow) {
      num -= win_col_off2(wp);
      if (wlv->n_extra < 0) {
        num = 0;
      }
    }

    colnr_T vcol_before = wlv->vcol;

    for (int i = 0; i < num; i++) {
      linebuf_char[wlv->off] = schar_from_ascii(' ');

      advance_color_col(wlv, wlv->vcol);
      int myattr = attr;
      if (wlv->color_cols && wlv->vcol == *wlv->color_cols) {
        myattr = hl_combine_attr(win_hl_attr(wp, HLF_MC), myattr);
      }
      linebuf_attr[wlv->off] = myattr;
      linebuf_vcol[wlv->off] = wlv->vcol++;  // These are vcols, sorry I don't make the rules
      wlv->off++;
    }

    // Correct start of highlighted area for 'breakindent',
    if (wlv->fromcol >= vcol_before && wlv->fromcol < wlv->vcol) {
      wlv->fromcol = wlv->vcol;
    }

    // Correct end of highlighted area for 'breakindent',
    // required wen 'linebreak' is also set.
    if (wlv->tocol == vcol_before) {
      wlv->tocol = wlv->vcol;
    }
  }

  if (wp->w_skipcol > 0 && wlv->startrow == 0 && wp->w_p_wrap && wp->w_briopt_sbr) {
    wlv->need_showbreak = false;
  }
}

static void handle_showbreak_and_filler(win_T *wp, winlinevars_T *wlv)
{
  int remaining = wp->w_view_width - wlv->off;
  if (wlv->filler_todo > wlv->filler_lines - wlv->n_virt_lines) {
    // TODO(bfredl): check this doesn't inhibit TUI-style
    //               clear-to-end-of-line.
    draw_col_fill(wlv, schar_from_ascii(' '), remaining, 0);
  } else if (wlv->filler_todo > 0) {
    // Draw "deleted" diff line(s)
    schar_T c = wp->w_p_fcs_chars.diff;
    draw_col_fill(wlv, c, remaining, win_hl_attr(wp, HLF_DED));
  }

  char *const sbr = get_showbreak_value(wp);
  if (*sbr != NUL && wlv->need_showbreak) {
    // Draw 'showbreak' at the start of each broken line.
    // Combine 'showbreak' with 'cursorline', prioritizing 'showbreak'.
    int attr = hl_combine_attr(wlv->cul_attr, win_hl_attr(wp, HLF_AT));
    colnr_T vcol_before = wlv->vcol;
    draw_col_buf(wp, wlv, sbr, strlen(sbr), attr, NULL, true);
    wlv->vcol_sbr = wlv->vcol;

    // Correct start of highlighted area for 'showbreak'.
    if (wlv->fromcol >= vcol_before && wlv->fromcol < wlv->vcol) {
      wlv->fromcol = wlv->vcol;
    }

    // Correct end of highlighted area for 'showbreak',
    // required when 'linebreak' is also set.
    if (wlv->tocol == vcol_before) {
      wlv->tocol = wlv->vcol;
    }
  }

  if (wp->w_skipcol == 0 || wlv->startrow > 0 || !wp->w_p_wrap || !wp->w_briopt_sbr) {
    wlv->need_showbreak = false;
  }
}

static void apply_cursorline_highlight(win_T *wp, winlinevars_T *wlv)
{
  wlv->cul_attr = win_hl_attr(wp, HLF_CUL);
  HlAttrs ae = syn_attr2entry(wlv->cul_attr);
  // We make a compromise here (#7383):
  //  * low-priority CursorLine if fg is not set
  //  * high-priority ("same as Vim" priority) CursorLine if fg is set
  if (ae.rgb_fg_color == -1 && ae.cterm_fg_color == 0) {
    wlv->line_attr_lowprio = wlv->cul_attr;
  } else {
    if (!(State & MODE_INSERT) && bt_quickfix(wp->w_buffer)
        && qf_current_entry(wp) == wlv->lnum) {
      wlv->line_attr = hl_combine_attr(wlv->cul_attr, wlv->line_attr);
    } else {
      wlv->line_attr = wlv->cul_attr;
    }
  }
}

static void set_line_attr_for_diff(win_T *wp, winlinevars_T *wlv)
{
  wlv->line_attr = win_hl_attr(wp, (int)wlv->diff_hlf);
  // Overlay CursorLine onto diff-mode highlight.
  if (wlv->cul_attr) {
    wlv->line_attr = 0 != wlv->line_attr_lowprio  // Low-priority CursorLine
                     ? hl_combine_attr(hl_combine_attr(wlv->cul_attr, wlv->line_attr),
                                       hl_get_underline())
                     : hl_combine_attr(wlv->line_attr, wlv->cul_attr);
  }
}

/// Checks if there is more inline virtual text that need to be drawn.
static bool has_more_inline_virt(winlinevars_T *wlv, ptrdiff_t v)
{
  if (wlv->virt_inline_i < kv_size(wlv->virt_inline)) {
    return true;
  }

  int const count = (int)kv_size(decor_state.ranges_i);
  int const cur_end = decor_state.current_end;
  int const fut_beg = decor_state.future_begin;
  int *const indices = decor_state.ranges_i.items;
  DecorRangeSlot *const slots = decor_state.slots.items;

  int const beg_pos[] = { 0, fut_beg };
  int const end_pos[] = { cur_end, count };

  for (int pos_i = 0; pos_i < 2; pos_i++) {
    for (int i = beg_pos[pos_i]; i < end_pos[pos_i]; i++) {
      DecorRange *item = &slots[indices[i]].range;
      if (item->start_row != decor_state.row
          || item->kind != kDecorKindVirtText
          || item->data.vt->pos != kVPosInline
          || item->data.vt->width == 0) {
        continue;
      }
      if (item->draw_col >= -1 && item->start_col >= v) {
        return true;
      }
    }
  }
  return false;
}

static void handle_inline_virtual_text(win_T *wp, winlinevars_T *wlv, ptrdiff_t v, bool selected)
{
  while (wlv->n_extra == 0) {
    if (wlv->virt_inline_i >= kv_size(wlv->virt_inline)) {
      // need to find inline virtual text
      wlv->virt_inline = VIRTTEXT_EMPTY;
      wlv->virt_inline_i = 0;
      DecorState *state = &decor_state;
      int const end = state->current_end;
      int *const indices = state->ranges_i.items;
      DecorRangeSlot *const slots = state->slots.items;

      for (int i = 0; i < end; i++) {
        DecorRange *item = &slots[indices[i]].range;
        if (item->draw_col == -3) {
          // No more inline virtual text before this non-inline virtual text item,
          // so its position can be decided now.
          decor_init_draw_col(wlv->off, selected, item);
        }
        if (item->start_row != state->row
            || item->kind != kDecorKindVirtText
            || item->data.vt->pos != kVPosInline
            || item->data.vt->width == 0) {
          continue;
        }
        if (item->draw_col >= -1 && item->start_col == v) {
          wlv->virt_inline = item->data.vt->data.virt_text;
          wlv->virt_inline_hl_mode = item->data.vt->hl_mode;
          item->draw_col = INT_MIN;
          break;
        }
      }
      if (!kv_size(wlv->virt_inline)) {
        // no more inline virtual text here
        break;
      }
    } else {
      // already inside existing inline virtual text with multiple chunks
      int attr = 0;
      char *text = next_virt_text_chunk(wlv->virt_inline, &wlv->virt_inline_i, &attr);
      if (text == NULL) {
        continue;
      }
      wlv->p_extra = text;
      wlv->n_extra = (int)strlen(text);
      if (wlv->n_extra == 0) {
        continue;
      }
      wlv->sc_extra = NUL;
      wlv->sc_final = NUL;
      wlv->extra_attr = attr;
      wlv->n_attr = mb_charlen(text);
      // If the text didn't reach until the first window
      // column we need to skip cells.
      if (wlv->skip_cells > 0) {
        int virt_text_width = (int)mb_string2cells(wlv->p_extra);
        if (virt_text_width > wlv->skip_cells) {
          int skip_cells_remaining = wlv->skip_cells;
          // Skip cells in the text.
          while (skip_cells_remaining > 0) {
            int cells = utf_ptr2cells(wlv->p_extra);
            if (cells > skip_cells_remaining) {
              break;
            }
            int c_len = utfc_ptr2len(wlv->p_extra);
            skip_cells_remaining -= cells;
            wlv->p_extra += c_len;
            wlv->n_extra -= c_len;
            wlv->n_attr--;
          }
          // Skipped cells needed to be accounted for in vcol.
          wlv->skipped_cells += wlv->skip_cells - skip_cells_remaining;
          wlv->skip_cells = skip_cells_remaining;
        } else {
          // The whole text is left of the window, drop
          // it and advance to the next one.
          wlv->skip_cells -= virt_text_width;
          // Skipped cells needed to be accounted for in vcol.
          wlv->skipped_cells += virt_text_width;
          wlv->n_attr = 0;
          wlv->n_extra = 0;
          // Go to the start so the next virtual text chunk can be selected.
          continue;
        }
      }
      assert(wlv->n_extra > 0);
      wlv->extra_for_extmark = true;
    }
  }
}

/// Start a screen line at column zero.
static void win_line_start(win_T *wp, winlinevars_T *wlv)
{
  wlv->col = 0;
  wlv->off = 0;
  wlv->need_lbr = false;
  for (int i = 0; i < wp->w_view_width; i++) {
    linebuf_char[i] = schar_from_ascii(' ');
    linebuf_attr[i] = 0;
    linebuf_vcol[i] = -1;
  }
}

static void fix_for_boguscols(winlinevars_T *wlv)
{
  wlv->n_extra += wlv->vcol_off_co;
  wlv->vcol -= wlv->vcol_off_co;
  wlv->vcol_off_co = 0;
  wlv->col -= wlv->boguscols;
  wlv->old_boguscols = wlv->boguscols;
  wlv->boguscols = 0;
}

static int get_rightmost_vcol(win_T *wp, const int *color_cols)
{
  int ret = 0;

  if (wp->w_p_cuc) {
    ret = wp->w_virtcol;
  }

  if (color_cols) {
    // determine rightmost colorcolumn to possibly draw
    for (int i = 0; color_cols[i] >= 0; i++) {
      ret = MAX(ret, color_cols[i]);
    }
  }

  return ret;
}

/// Display line "lnum" of window "wp" on the screen.
/// wp->w_virtcol needs to be valid.
///
/// @param lnum         line to display
/// @param startrow     first row relative to window grid
/// @param endrow       last grid row to be redrawn
/// @param col_rows     set to the height of the line when only updating the columns,
///                     otherwise set to 0
/// @param concealed    only draw virtual lines belonging to the line above
/// @param spv          'spell' related variables kept between calls for "wp"
/// @param foldinfo     fold info for this line
/// @param[in, out] providers  decoration providers active this line
///                            items will be disables if they cause errors
///                            or explicitly return `false`.
///
/// @return             the number of last row the line occupies.
int win_line(win_T *wp, linenr_T lnum, int startrow, int endrow, int col_rows, bool concealed,
             spellvars_T *spv, foldinfo_T foldinfo)
{
  colnr_T vcol_prev = -1;             // "wlv.vcol" of previous character
  GridView *grid = &wp->w_grid;       // grid specific to the window
  const int view_width = wp->w_view_width;
  const int view_height = wp->w_view_height;

  const bool in_curline = wp == curwin && lnum == curwin->w_cursor.lnum;
  const bool has_fold = foldinfo.fi_level != 0 && foldinfo.fi_lines > 0;
  const bool has_foldtext = has_fold && *wp->w_p_fdt != NUL;

  const bool is_wrapped = wp->w_p_wrap
                          && !has_fold;       // Never wrap folded lines

  int saved_attr2 = 0;                  // char_attr saved for n_attr
  int n_attr3 = 0;                      // chars with overruling special attr
  int saved_attr3 = 0;                  // char_attr saved for n_attr3

  int fromcol_prev = -2;                // start of inverting after cursor
  bool noinvcur = false;                // don't invert the cursor
  bool lnum_in_visual_area = false;

  int char_attr_pri = 0;                // attributes with high priority
  int char_attr_base = 0;               // attributes with low priority
  bool area_highlighting = false;       // Visual or incsearch highlighting in this line
  int vi_attr = 0;                      // attributes for Visual and incsearch highlighting
  int area_attr = 0;                    // attributes desired by highlighting
  int search_attr = 0;                  // attributes desired by 'hlsearch' or ComplMatchIns
  int vcol_save_attr = 0;               // saved attr for 'cursorcolumn'
  int decor_attr = 0;                   // attributes desired by syntax and extmarks
  bool has_syntax = false;              // this buffer has syntax highl.
  int folded_attr = 0;                  // attributes for folded line
  int eol_hl_off = 0;                   // 1 if highlighted char after EOL
#define SPWORDLEN 150
  char nextline[SPWORDLEN * 2];         // text with start of the next line
  int nextlinecol = 0;                  // column where nextline[] starts
  int nextline_idx = 0;                 // index in nextline[] where next line
                                        // starts
  int spell_attr = 0;                   // attributes desired by spelling
  int word_end = 0;                     // last byte with same spell_attr
  int cur_checked_col = 0;              // checked column for current line
  bool extra_check = false;             // has extra highlighting
  int multi_attr = 0;                   // attributes desired by multibyte
  int mb_l = 1;                         // multi-byte byte length
  int mb_c = 0;                         // decoded multi-byte character
  schar_T mb_schar = 0;                 // complete screen char
  int change_start = MAXCOL;            // first col of changed area
  int change_end = -1;                  // last col of changed area
  bool in_multispace = false;           // in multiple consecutive spaces
  int multispace_pos = 0;               // position in lcs-multispace string

  int n_extra_next = 0;                 // n_extra to use after current extra chars
  int extra_attr_next = -1;             // extra_attr to use after current extra chars

  bool search_attr_from_match = false;  // if search_attr is from :match
  bool has_decor = false;               // this buffer has decoration

  int saved_search_attr = 0;            // search_attr to be used when n_extra goes to zero
  int saved_area_attr = 0;              // idem for area_attr
  int saved_decor_attr = 0;             // idem for decor_attr
  bool saved_search_attr_from_match = false;

  int win_col_offset = 0;               // offset for window columns
  bool area_active = false;             // whether in Visual selection, for virtual text
  bool decor_need_recheck = false;      // call decor_recheck_draw_col() at next char

  char buf_fold[FOLD_TEXT_LEN];         // Hold value returned by get_foldtext
  VirtText fold_vt = VIRTTEXT_EMPTY;
  char *foldtext_free = NULL;

  // 'cursorlineopt' has "screenline" and cursor is in this line
  bool cul_screenline = false;
  // margin columns for the screen line, needed for when 'cursorlineopt'
  // contains "screenline"
  int left_curline_col = 0;
  int right_curline_col = 0;

  int match_conc = 0;              ///< cchar for match functions
  bool on_last_col = false;
  int syntax_flags = 0;
  int syntax_seqnr = 0;
  int prev_syntax_id = 0;
  int conceal_attr = win_hl_attr(wp, HLF_CONCEAL);
  bool is_concealing = false;
  bool did_wcol = false;
#define vcol_hlc(wlv) ((wlv).vcol - (wlv).vcol_off_co)

  assert(startrow < endrow);

  // variables passed between functions
  winlinevars_T wlv = {
    .lnum = lnum,
    .foldinfo = foldinfo,
    .startrow = startrow,
    .row = startrow,
    .fromcol = -10,
    .tocol = MAXCOL,
    .vcol_sbr = -1,
    .old_boguscols = 0,
    .prev_num_attr = -1,
  };

  buf_T *buf = wp->w_buffer;
  // Not drawing text when line is concealed or drawing filler lines beyond last line.
  const bool draw_text = !concealed && (lnum != buf->b_ml.ml_line_count + 1);

  if (col_rows == 0 && draw_text) {
    // To speed up the loop below, set extra_check when there is linebreak,
    // trailing white space and/or syntax processing to be done.
    extra_check = wp->w_p_lbr;
    if (syntax_present(wp) && !wp->w_s->b_syn_error && !wp->w_s->b_syn_slow && !has_foldtext) {
      // Prepare for syntax highlighting in this line.  When there is an
      // error, stop syntax highlighting.
      int save_did_emsg = did_emsg;
      did_emsg = false;
      syntax_start(wp, lnum);
      if (did_emsg) {
        wp->w_s->b_syn_error = true;
      } else {
        did_emsg = save_did_emsg;
        if (!wp->w_s->b_syn_slow) {
          has_syntax = true;
          extra_check = true;
        }
      }
    }

    decor_providers_invoke_line(wp, lnum - 1);  // may invalidate wp->w_virtcol
    validate_virtcol(wp);

    has_decor = decor_redraw_line(wp, lnum - 1, &decor_state);

    if (has_decor) {
      extra_check = true;
    }

    // Check for columns to display for 'colorcolumn'.
    wlv.color_cols = wp->w_buffer->terminal ? NULL : wp->w_p_cc_cols;
    advance_color_col(&wlv, vcol_hlc(wlv));

    // handle Visual active in this window
    if (VIsual_active && wp->w_buffer == curwin->w_buffer) {
      pos_T *top, *bot;

      if (ltoreq(curwin->w_cursor, VIsual)) {
        // Visual is after curwin->w_cursor
        top = &curwin->w_cursor;
        bot = &VIsual;
      } else {
        // Visual is before curwin->w_cursor
        top = &VIsual;
        bot = &curwin->w_cursor;
      }
      lnum_in_visual_area = (lnum >= top->lnum && lnum <= bot->lnum);
      if (VIsual_mode == Ctrl_V) {
        // block mode
        if (lnum_in_visual_area) {
          wlv.fromcol = wp->w_old_cursor_fcol;
          wlv.tocol = wp->w_old_cursor_lcol;
        }
      } else {
        // non-block mode
        if (lnum > top->lnum && lnum <= bot->lnum) {
          wlv.fromcol = 0;
        } else if (lnum == top->lnum) {
          if (VIsual_mode == 'V') {       // linewise
            wlv.fromcol = 0;
          } else {
            getvvcol(wp, top, (colnr_T *)&wlv.fromcol, NULL, NULL);
            if (gchar_pos(top) == NUL) {
              wlv.tocol = wlv.fromcol + 1;
            }
          }
        }
        if (VIsual_mode != 'V' && lnum == bot->lnum) {
          if (*p_sel == 'e' && bot->col == 0
              && bot->coladd == 0) {
            wlv.fromcol = -10;
            wlv.tocol = MAXCOL;
          } else if (bot->col == MAXCOL) {
            wlv.tocol = MAXCOL;
          } else {
            pos_T pos = *bot;
            if (*p_sel == 'e') {
              getvvcol(wp, &pos, (colnr_T *)&wlv.tocol, NULL, NULL);
            } else {
              getvvcol(wp, &pos, NULL, NULL, (colnr_T *)&wlv.tocol);
              wlv.tocol++;
            }
          }
        }
      }

      // Check if the char under the cursor should be inverted (highlighted).
      if (!highlight_match && in_curline
          && cursor_is_block_during_visual(*p_sel == 'e')) {
        noinvcur = true;
      }

      // if inverting in this line set area_highlighting
      if (wlv.fromcol >= 0) {
        area_highlighting = true;
        vi_attr = win_hl_attr(wp, HLF_V);
      }
      // handle 'incsearch' and ":s///c" highlighting
    } else if (highlight_match
               && wp == curwin
               && !has_foldtext
               && lnum >= curwin->w_cursor.lnum
               && lnum <= curwin->w_cursor.lnum + search_match_lines) {
      if (lnum == curwin->w_cursor.lnum) {
        getvcol(curwin, &(curwin->w_cursor),
                (colnr_T *)&wlv.fromcol, NULL, NULL);
      } else {
        wlv.fromcol = 0;
      }
      if (lnum == curwin->w_cursor.lnum + search_match_lines) {
        pos_T pos = {
          .lnum = lnum,
          .col = search_match_endcol,
        };
        getvcol(curwin, &pos, (colnr_T *)&wlv.tocol, NULL, NULL);
      }
      // do at least one character; happens when past end of line
      if (wlv.fromcol == wlv.tocol && search_match_endcol) {
        wlv.tocol = wlv.fromcol + 1;
      }
      area_highlighting = true;
      vi_attr = win_hl_attr(wp, HLF_I);
    }
  }

  int bg_attr = win_bg_attr(wp);

  int linestatus = 0;
  wlv.filler_lines = diff_check_with_linestatus(wp, lnum, &linestatus);
  diffline_T line_changes = { 0 };
  int change_index = -1;
  if (wlv.filler_lines < 0 || linestatus < 0) {
    if (wlv.filler_lines == -1 || linestatus == -1) {
      if (diff_find_change(wp, lnum, &line_changes)) {
        wlv.diff_hlf = HLF_ADD;      // added line
      } else if (line_changes.num_changes > 0) {
        bool added = diff_change_parse(&line_changes, &line_changes.changes[0],
                                       &change_start, &change_end);
        if (change_start == 0) {
          if (added) {
            wlv.diff_hlf = HLF_TXA;  // added text on changed line
          } else {
            wlv.diff_hlf = HLF_TXD;  // changed text on changed line
          }
        } else {
          wlv.diff_hlf = HLF_CHD;    // unchanged text on changed line
        }
        change_index = 0;
      } else {
        wlv.diff_hlf = HLF_CHD;      // changed line
        change_index = 0;
      }
    } else {
      wlv.diff_hlf = HLF_ADD;               // added line
    }
    if (linestatus == 0) {
      wlv.filler_lines = 0;
    }
    area_highlighting = true;
  }
  VirtLines virt_lines = KV_INITIAL_VALUE;
  wlv.n_virt_lines = decor_virt_lines(wp, lnum - 1, lnum, &wlv.n_virt_below, &virt_lines, true);
  wlv.filler_lines += wlv.n_virt_lines;
  if (lnum == wp->w_topline) {
    wlv.filler_lines = wp->w_topfill;
    wlv.n_virt_lines = MIN(wlv.n_virt_lines, wlv.filler_lines);
  }
  wlv.filler_todo = wlv.filler_lines;

  // Cursor line highlighting for 'cursorline' in the current window.
  if (wp->w_p_cul && wp->w_p_culopt_flags != kOptCuloptFlagNumber && lnum == wp->w_cursorline
      // Do not show the cursor line in the text when Visual mode is active,
      // because it's not clear what is selected then.
      && !(wp == curwin && VIsual_active)) {
    cul_screenline = (is_wrapped && (wp->w_p_culopt_flags & kOptCuloptFlagScreenline));
    if (!cul_screenline) {
      apply_cursorline_highlight(wp, &wlv);
    } else {
      margin_columns_win(wp, &left_curline_col, &right_curline_col);
    }
    area_highlighting = true;
  }

  int sign_line_attr = 0;
  // TODO(bfredl, vigoux): line_attr should not take priority over decoration!
  decor_redraw_signs(wp, buf, wlv.lnum - 1, wlv.sattrs,
                     &sign_line_attr, &wlv.sign_cul_attr, &wlv.sign_num_attr);

  statuscol_T statuscol = { 0 };
  if (*wp->w_p_stc != NUL) {
    // Draw the 'statuscolumn' if option is set.
    statuscol.draw = true;
    statuscol.sattrs = wlv.sattrs;
    statuscol.foldinfo = foldinfo;
    statuscol.width = win_col_off(wp) - (wp == cmdwin_win);
    statuscol.sign_cul_id = use_cursor_line_highlight(wp, lnum) ? wlv.sign_cul_attr : 0;
  } else if (wlv.sign_cul_attr > 0) {
    wlv.sign_cul_attr = use_cursor_line_highlight(wp, lnum) ? syn_id2attr(wlv.sign_cul_attr) : 0;
  }
  if (wlv.sign_num_attr > 0) {
    wlv.sign_num_attr = syn_id2attr(wlv.sign_num_attr);
  }
  if (sign_line_attr > 0) {
    wlv.line_attr = syn_id2attr(sign_line_attr);
  }

  // Highlight the current line in the quickfix window.
  if (bt_quickfix(wp->w_buffer) && qf_current_entry(wp) == lnum) {
    wlv.line_attr = win_hl_attr(wp, HLF_QFL);
  }

  if (wlv.line_attr_lowprio || wlv.line_attr) {
    area_highlighting = true;
  }

  int line_attr_save = wlv.line_attr;
  int line_attr_lowprio_save = wlv.line_attr_lowprio;

  if (spv->spv_has_spell && col_rows == 0 && draw_text) {
    // Prepare for spell checking.
    extra_check = true;

    // When a word wrapped from the previous line the start of the
    // current line is valid.
    if (lnum == spv->spv_checked_lnum) {
      cur_checked_col = spv->spv_checked_col;
    }
    // Previous line was not spell checked, check for capital. This happens
    // for the first line in an updated region or after a closed fold.
    if (spv->spv_capcol_lnum == 0 && check_need_cap(wp, lnum, 0)) {
      spv->spv_cap_col = 0;
    } else if (lnum != spv->spv_capcol_lnum) {
      spv->spv_cap_col = -1;
    }
    spv->spv_checked_lnum = 0;

    // Get the start of the next line, so that words that wrap to the
    // next line are found too: "et<line-break>al.".
    // Trick: skip a few chars for C/shell/Vim comments
    nextline[SPWORDLEN] = NUL;
    if (lnum < wp->w_buffer->b_ml.ml_line_count) {
      char *line = ml_get_buf(wp->w_buffer, lnum + 1);
      spell_cat_line(nextline + SPWORDLEN, line, SPWORDLEN);
    }
    char *line = ml_get_buf(wp->w_buffer, lnum);

    // If current line is empty, check first word in next line for capital.
    char *ptr = skipwhite(line);
    if (*ptr == NUL) {
      spv->spv_cap_col = 0;
      spv->spv_capcol_lnum = lnum + 1;
    } else if (spv->spv_cap_col == 0) {
      // For checking first word with a capital skip white space.
      spv->spv_cap_col = (int)(ptr - line);
    }

    // Copy the end of the current line into nextline[].
    if (nextline[SPWORDLEN] == NUL) {
      // No next line or it is empty.
      nextlinecol = MAXCOL;
      nextline_idx = 0;
    } else {
      const colnr_T line_len = ml_get_buf_len(wp->w_buffer, lnum);
      if (line_len < SPWORDLEN) {
        // Short line, use it completely and append the start of the
        // next line.
        nextlinecol = 0;
        memmove(nextline, line, (size_t)line_len);
        STRMOVE(nextline + line_len, nextline + SPWORDLEN);
        nextline_idx = line_len + 1;
      } else {
        // Long line, use only the last SPWORDLEN bytes.
        nextlinecol = line_len - SPWORDLEN;
        memmove(nextline, line + nextlinecol, SPWORDLEN);
        nextline_idx = SPWORDLEN + 1;
      }
    }
  }

  // current line
  char *line = draw_text ? ml_get_buf(wp->w_buffer, lnum) : "";
  // current position in "line"
  char *ptr = line;

  colnr_T trailcol = MAXCOL;  // start of trailing spaces
  colnr_T leadcol = 0;        // start of leading spaces

  bool lcs_eol_todo = true;  // need to keep track of this even if lcs_eol is NUL
  const schar_T lcs_eol = wp->w_p_lcs_chars.eol;  // 'eol' value
  schar_T lcs_prec_todo = wp->w_p_lcs_chars.prec;  // 'prec' until it's been used, then NUL

  if (wp->w_p_list && !has_foldtext && draw_text) {
    if (wp->w_p_lcs_chars.space
        || wp->w_p_lcs_chars.multispace != NULL
        || wp->w_p_lcs_chars.leadmultispace != NULL
        || wp->w_p_lcs_chars.trail
        || wp->w_p_lcs_chars.lead
        || wp->w_p_lcs_chars.nbsp) {
      extra_check = true;
    }
    // find start of trailing whitespace
    if (wp->w_p_lcs_chars.trail) {
      trailcol = ml_get_buf_len(wp->w_buffer, lnum);
      while (trailcol > 0 && ascii_iswhite(ptr[trailcol - 1])) {
        trailcol--;
      }
      trailcol += (colnr_T)(ptr - line);
    }
    // find end of leading whitespace
    if (wp->w_p_lcs_chars.lead || wp->w_p_lcs_chars.leadmultispace != NULL) {
      leadcol = 0;
      while (ascii_iswhite(ptr[leadcol])) {
        leadcol++;
      }
      if (ptr[leadcol] == NUL) {
        // in a line full of spaces all of them are treated as trailing
        leadcol = 0;
      } else {
        // keep track of the first column not filled with spaces
        leadcol += (colnr_T)(ptr - line + 1);
      }
    }
  }

  // 'nowrap' or 'wrap' and a single line that doesn't fit: Advance to the
  // first character to be displayed.
  const int start_col = wp->w_p_wrap
                        ? (startrow == 0 ? wp->w_skipcol : 0)
                        : wp->w_leftcol;

  if (has_foldtext) {
    wlv.vcol = start_col;
  } else if (start_col > 0 && col_rows == 0) {
    char *prev_ptr = ptr;
    CharSize cs = { 0 };

    CharsizeArg csarg;
    CSType cstype = init_charsize_arg(&csarg, wp, lnum, line);
    csarg.max_head_vcol = start_col;
    int vcol = wlv.vcol;
    StrCharInfo ci = utf_ptr2StrCharInfo(ptr);
    while (vcol < start_col && *ci.ptr != NUL) {
      cs = win_charsize(cstype, vcol, ci.ptr, ci.chr.value, &csarg);
      vcol += cs.width;
      prev_ptr = ci.ptr;
      ci = utfc_next(ci);
      if (wp->w_p_list) {
        in_multispace = *prev_ptr == ' ' && (*ci.ptr == ' '
                                             || (prev_ptr > line && prev_ptr[-1] == ' '));
        if (!in_multispace) {
          multispace_pos = 0;
        } else if (ci.ptr >= line + leadcol
                   && wp->w_p_lcs_chars.multispace != NULL) {
          multispace_pos++;
          if (wp->w_p_lcs_chars.multispace[multispace_pos] == NUL) {
            multispace_pos = 0;
          }
        } else if (ci.ptr < line + leadcol
                   && wp->w_p_lcs_chars.leadmultispace != NULL) {
          multispace_pos++;
          if (wp->w_p_lcs_chars.leadmultispace[multispace_pos] == NUL) {
            multispace_pos = 0;
          }
        }
      }
    }
    wlv.vcol = vcol;
    ptr = ci.ptr;
    int charsize = cs.width;
    int head = cs.head;

    // When:
    // - 'cuc' is set, or
    // - 'colorcolumn' is set, or
    // - 'virtualedit' is set, or
    // - the visual mode is active, or
    // - drawing a fold
    // the end of the line may be before the start of the displayed part.
    if (wlv.vcol < start_col && (wp->w_p_cuc
                                 || wlv.color_cols
                                 || virtual_active(wp)
                                 || (VIsual_active && wp->w_buffer == curwin->w_buffer)
                                 || has_fold)) {
      wlv.vcol = start_col;
    }

    // Handle a character that's not completely on the screen: Put ptr at
    // that character but skip the first few screen characters.
    if (wlv.vcol > start_col) {
      wlv.vcol -= charsize;
      ptr = prev_ptr;
    }

    if (start_col > wlv.vcol) {
      wlv.skip_cells = start_col - wlv.vcol - head;
    }

    // Adjust for when the inverted text is before the screen,
    // and when the start of the inverted text is before the screen.
    if (wlv.tocol <= wlv.vcol) {
      wlv.fromcol = 0;
    } else if (wlv.fromcol >= 0 && wlv.fromcol < wlv.vcol) {
      wlv.fromcol = wlv.vcol;
    }

    // When w_skipcol is non-zero, first line needs 'showbreak'
    if (wp->w_p_wrap) {
      wlv.need_showbreak = true;
    }
    // When spell checking a word we need to figure out the start of the
    // word and if it's badly spelled or not.
    if (spv->spv_has_spell) {
      colnr_T linecol = (colnr_T)(ptr - line);
      hlf_T spell_hlf = HLF_COUNT;

      pos_T pos = wp->w_cursor;
      wp->w_cursor.lnum = lnum;
      wp->w_cursor.col = linecol;
      size_t len = spell_move_to(wp, FORWARD, SMT_ALL, true, &spell_hlf);

      // spell_move_to() may call ml_get() and make "line" invalid
      line = ml_get_buf(wp->w_buffer, lnum);
      ptr = line + linecol;

      if (len == 0 || wp->w_cursor.col > linecol) {
        // no bad word found at line start, don't check until end of a
        // word
        spell_hlf = HLF_COUNT;
        word_end = (int)(spell_to_word_end(ptr, wp) - line + 1);
      } else {
        // bad word found, use attributes until end of word
        assert(len <= INT_MAX);
        word_end = wp->w_cursor.col + (int)len + 1;

        // Turn index into actual attributes.
        if (spell_hlf != HLF_COUNT) {
          spell_attr = highlight_attr[spell_hlf];
        }
      }
      wp->w_cursor = pos;

      // Need to restart syntax highlighting for this line.
      if (has_syntax) {
        syntax_start(wp, lnum);
      }
    }
  }

  // Correct highlighting for cursor that can't be disabled.
  // Avoids having to check this for each character.
  if (wlv.fromcol >= 0) {
    if (noinvcur) {
      if ((colnr_T)wlv.fromcol == wp->w_virtcol) {
        // highlighting starts at cursor, let it start just after the
        // cursor
        fromcol_prev = wlv.fromcol;
        wlv.fromcol = -1;
      } else if ((colnr_T)wlv.fromcol < wp->w_virtcol) {
        // restart highlighting after the cursor
        fromcol_prev = wp->w_virtcol;
      }
    }
    if (wlv.fromcol >= wlv.tocol) {
      wlv.fromcol = -1;
    }
  }

  if (col_rows == 0 && draw_text && !has_foldtext) {
    const int v = (int)(ptr - line);
    area_highlighting |= prepare_search_hl_line(wp, lnum, v,
                                                &line, &screen_search_hl, &search_attr,
                                                &search_attr_from_match);
    ptr = line + v;  // "line" may have been updated
  }

  if ((State & MODE_INSERT) && ins_compl_win_active(wp)
      && (in_curline || ins_compl_lnum_in_range(lnum))) {
    area_highlighting = true;
  }

  win_line_start(wp, &wlv);
  bool draw_cols = true;
  int leftcols_width = 0;

  // won't highlight after TERM_ATTRS_MAX columns
  int term_attrs[TERM_ATTRS_MAX] = { 0 };
  if (wp->w_buffer->terminal) {
    terminal_get_line_attributes(wp->w_buffer->terminal, wp, lnum, term_attrs);
    extra_check = true;
  }

  const bool may_have_inline_virt
    = !has_foldtext && buf_meta_total(wp->w_buffer, kMTMetaInline) > 0;
  int virt_line_index = -1;
  int virt_line_flags = 0;
  // Repeat for the whole displayed line.
  while (true) {
    int has_match_conc = 0;  ///< match wants to conceal
    int decor_conceal = 0;

    bool did_decrement_ptr = false;

    // Skip this quickly when working on the text.
    if (draw_cols) {
      if (cul_screenline) {
        wlv.cul_attr = 0;
        wlv.line_attr = line_attr_save;
        wlv.line_attr_lowprio = line_attr_lowprio_save;
      }

      assert(wlv.off == 0);

      if (wp == cmdwin_win) {
        // Draw the cmdline character.
        draw_col_fill(&wlv, schar_from_ascii(cmdwin_type), 1, win_hl_attr(wp, HLF_AT));
      }

      if (wlv.filler_todo > 0) {
        int index = wlv.filler_todo - (wlv.filler_lines - wlv.n_virt_lines);
        if (index > 0) {
          virt_line_index = (int)kv_size(virt_lines) - index;
          assert(virt_line_index >= 0);
          virt_line_flags = kv_A(virt_lines, virt_line_index).flags;
        }
      }

      if (virt_line_index >= 0 && (virt_line_flags & kVLLeftcol)) {
        // skip columns
      } else if (statuscol.draw) {
        // Draw 'statuscolumn' if it is set.
        const int v = (int)(ptr - line);
        draw_statuscol(wp, &wlv, wlv.row - startrow - wlv.filler_lines, col_rows, &statuscol);
        if (wp->w_redr_statuscol) {
          break;
        }
        if (draw_text) {
          // Get the line again as evaluating 'statuscolumn' may free it.
          line = ml_get_buf(wp->w_buffer, lnum);
          ptr = line + v;
        }
      } else {
        // draw builtin info columns: fold, sign, number
        draw_foldcolumn(wp, &wlv);

        // wp->w_scwidth is zero if signcol=number is used
        for (int sign_idx = 0; sign_idx < wp->w_scwidth; sign_idx++) {
          draw_sign(false, wp, &wlv, sign_idx);
        }

        draw_lnum_col(wp, &wlv);
      }

      win_col_offset = wlv.off;

      // When only updating the columns and that's done, stop here.
      if (col_rows > 0) {
        wlv_put_linebuf(wp, &wlv, MIN(wlv.off, view_width), false, bg_attr, 0);
        // Need to update more screen lines if:
        // - 'statuscolumn' needs to be drawn, or
        // - LineNrAbove or LineNrBelow is used, or
        // - still drawing filler lines.
        if ((wlv.row + 1 - wlv.startrow < col_rows
             && (statuscol.draw
                 || win_hl_attr(wp, HLF_LNA) != win_hl_attr(wp, HLF_N)
                 || win_hl_attr(wp, HLF_LNB) != win_hl_attr(wp, HLF_N)))
            || wlv.filler_todo > 0) {
          wlv.row++;
          if (wlv.row == endrow) {
            break;
          }
          wlv.filler_todo--;
          if (wlv.filler_todo == 0 && (wp->w_botfill || !draw_text)) {
            break;
          }
          // win_line_start(wp, &wlv);
          wlv.col = 0;
          wlv.off = 0;
          continue;
        } else {
          break;
        }
      }

      // Check if 'breakindent' applies and show it.
      if (!wp->w_briopt_sbr) {
        handle_breakindent(wp, &wlv);
      }
      handle_showbreak_and_filler(wp, &wlv);
      if (wp->w_briopt_sbr) {
        handle_breakindent(wp, &wlv);
      }

      wlv.col = wlv.off;
      draw_cols = false;
      if (wlv.filler_todo <= 0) {
        leftcols_width = wlv.off;
      }
      if (has_decor && wlv.row == startrow + wlv.filler_lines) {
        // hide virt_text on text hidden by 'nowrap' or 'smoothscroll'
        decor_redraw_col(wp, (colnr_T)(ptr - line) - 1, wlv.off, true, &decor_state);
      }
      if (wlv.col >= view_width) {
        wlv.col = wlv.off = view_width;
        goto end_check;
      }
    }

    if (cul_screenline && wlv.filler_todo <= 0
        && wlv.vcol >= left_curline_col && wlv.vcol < right_curline_col) {
      apply_cursorline_highlight(wp, &wlv);
    }

    // When still displaying '$' of change command, stop at cursor.
    if (dollar_vcol >= 0 && in_curline && wlv.vcol >= wp->w_virtcol) {
      draw_virt_text(wp, buf, win_col_offset, &wlv.col, wlv.row);
      // don't clear anything after wlv.col
      wlv_put_linebuf(wp, &wlv, wlv.col, false, bg_attr, 0);
      // Pretend we have finished updating the window.  Except when
      // 'cursorcolumn' is set.
      if (wp->w_p_cuc) {
        wlv.row = wp->w_cline_row + wp->w_cline_height;
      } else {
        wlv.row = view_height;
      }
      break;
    }

    const bool draw_folded = has_fold && wlv.row == startrow + wlv.filler_lines;
    if (draw_folded && wlv.n_extra == 0) {
      wlv.char_attr = folded_attr = win_hl_attr(wp, HLF_FL);
      decor_attr = 0;
    }

    int extmark_attr = 0;
    if (wlv.filler_todo <= 0
        && (area_highlighting || spv->spv_has_spell || extra_check)) {
      if (wlv.n_extra == 0 || !wlv.extra_for_extmark) {
        wlv.reset_extra_attr = false;
      }

      if (has_decor && wlv.n_extra == 0) {
        // Duplicate the Visual area check after this block,
        // but don't check inside p_extra here.
        if (wlv.vcol == wlv.fromcol
            || (wlv.vcol + 1 == wlv.fromcol
                && (wlv.n_extra == 0 && utf_ptr2cells(ptr) > 1))
            || (vcol_prev == fromcol_prev
                && vcol_prev < wlv.vcol
                && wlv.vcol < wlv.tocol)) {
          area_active = true;
        } else if (area_active
                   && (wlv.vcol == wlv.tocol
                       || (noinvcur && wlv.vcol == wp->w_virtcol))) {
          area_active = false;
        }

        bool selected = (area_active || (area_highlighting && noinvcur
                                         && wlv.vcol == wp->w_virtcol));
        // When there may be inline virtual text, position of non-inline virtual text
        // can only be decided after drawing inline virtual text with lower priority.
        if (decor_need_recheck) {
          if (!may_have_inline_virt) {
            decor_recheck_draw_col(wlv.off, selected, &decor_state);
          }
          decor_need_recheck = false;
        }
        extmark_attr = decor_redraw_col(wp, (colnr_T)(ptr - line),
                                        may_have_inline_virt ? -3 : wlv.off,
                                        selected, &decor_state);
        if (may_have_inline_virt) {
          handle_inline_virtual_text(wp, &wlv, ptr - line, selected);
          if (wlv.n_extra > 0 && wlv.virt_inline_hl_mode <= kHlModeReplace) {
            // restore search_attr and area_attr when n_extra is down to zero
            // TODO(bfredl): this is ugly as fuck. look if we can do this some other way.
            saved_search_attr = search_attr;
            saved_area_attr = area_attr;
            saved_decor_attr = decor_attr;
            saved_search_attr_from_match = search_attr_from_match;
            search_attr = 0;
            area_attr = 0;
            decor_attr = 0;
            search_attr_from_match = false;
          }
        }
      }

      int *area_attr_p = wlv.extra_for_extmark && wlv.virt_inline_hl_mode <= kHlModeReplace
                         ? &saved_area_attr : &area_attr;

      // handle Visual or match highlighting in this line
      if (wlv.vcol == wlv.fromcol
          || (wlv.vcol + 1 == wlv.fromcol
              && ((wlv.n_extra == 0 && utf_ptr2cells(ptr) > 1)
                  || (wlv.n_extra > 0 && wlv.p_extra != NULL
                      && utf_ptr2cells(wlv.p_extra) > 1)))
          || (vcol_prev == fromcol_prev
              && vcol_prev < wlv.vcol               // not at margin
              && wlv.vcol < wlv.tocol)) {
        *area_attr_p = vi_attr;                     // start highlighting
        area_active = true;
      } else if (*area_attr_p != 0
                 && (wlv.vcol == wlv.tocol
                     || (noinvcur && wlv.vcol == wp->w_virtcol))) {
        *area_attr_p = 0;                           // stop highlighting
        area_active = false;
      }

      if (!has_foldtext && wlv.n_extra == 0) {
        // Check for start/end of 'hlsearch' and other matches.
        // After end, check for start/end of next match.
        // When another match, have to check for start again.
        const int v = (int)(ptr - line);
        search_attr = update_search_hl(wp, lnum, v, &line, &screen_search_hl,
                                       &has_match_conc, &match_conc, lcs_eol_todo,
                                       &on_last_col, &search_attr_from_match);
        ptr = line + v;  // "line" may have been changed

        // Do not allow a conceal over EOL otherwise EOL will be missed
        // and bad things happen.
        if (*ptr == NUL) {
          has_match_conc = 0;
        }

        // Check if ComplMatchIns highlight is needed.
        if ((State & MODE_INSERT) && ins_compl_win_active(wp)
            && (in_curline || ins_compl_lnum_in_range(lnum))) {
          int ins_match_attr = ins_compl_col_range_attr(lnum, (int)(ptr - line));
          if (ins_match_attr > 0) {
            search_attr = hl_combine_attr(search_attr, ins_match_attr);
          }
        }
      }

      if (wlv.diff_hlf != (hlf_T)0) {
        if (line_changes.num_changes > 0
            && change_index >= 0
            && change_index < line_changes.num_changes - 1) {
          if (ptr - line
              >= line_changes.changes[change_index + 1].dc_start[line_changes.bufidx]) {
            change_index += 1;
          }
        }
        bool added = false;
        if (line_changes.num_changes > 0 && change_index >= 0
            && change_index < line_changes.num_changes) {
          added = diff_change_parse(&line_changes, &line_changes.changes[change_index],
                                    &change_start, &change_end);
        }
        // When there is extra text (eg: virtual text) it gets the
        // diff highlighting for the line, but not for changed text.
        if (wlv.diff_hlf == HLF_CHD && ptr - line >= change_start
            && wlv.n_extra == 0) {
          wlv.diff_hlf = added ? HLF_TXA : HLF_TXD;   // added/changed text
        }
        if ((wlv.diff_hlf == HLF_TXD || wlv.diff_hlf == HLF_TXA)
            && ((ptr - line >= change_end && wlv.n_extra == 0)
                || (wlv.n_extra > 0 && wlv.extra_for_extmark))) {
          wlv.diff_hlf = HLF_CHD;                     // changed line
        }
        set_line_attr_for_diff(wp, &wlv);
      }

      // Decide which of the highlight attributes to use.
      if (area_attr != 0) {
        char_attr_pri = hl_combine_attr(wlv.line_attr, area_attr);
        if (!highlight_match) {
          // let search highlight show in Visual area if possible
          char_attr_pri = hl_combine_attr(search_attr, char_attr_pri);
        }
      } else if (search_attr != 0) {
        char_attr_pri = hl_combine_attr(wlv.line_attr, search_attr);
      } else if (wlv.line_attr != 0
                 && ((wlv.fromcol == -10 && wlv.tocol == MAXCOL)
                     || wlv.vcol < wlv.fromcol
                     || vcol_prev < fromcol_prev
                     || wlv.vcol >= wlv.tocol)) {
        // Use wlv.line_attr when not in the Visual or 'incsearch' area
        // (area_attr may be 0 when "noinvcur" is set).
        char_attr_pri = wlv.line_attr;
      } else {
        char_attr_pri = 0;
      }
      char_attr_base = hl_combine_attr(folded_attr, decor_attr);
      wlv.char_attr = hl_combine_attr(char_attr_base, char_attr_pri);
    }

    if (draw_folded && has_foldtext && wlv.n_extra == 0 && wlv.col == win_col_offset) {
      const int v = (int)(ptr - line);
      linenr_T lnume = lnum + foldinfo.fi_lines - 1;
      memset(buf_fold, ' ', FOLD_TEXT_LEN);
      wlv.p_extra = get_foldtext(wp, lnum, lnume, foldinfo, buf_fold, &fold_vt);
      wlv.n_extra = (int)strlen(wlv.p_extra);

      if (wlv.p_extra != buf_fold) {
        assert(foldtext_free == NULL);
        foldtext_free = wlv.p_extra;
      }
      wlv.sc_extra = NUL;
      wlv.sc_final = NUL;
      wlv.p_extra[wlv.n_extra] = NUL;

      // Get the line again as evaluating 'foldtext' may free it.
      line = ml_get_buf(wp->w_buffer, lnum);
      ptr = line + v;
    }

    // Draw 'fold' fillchar after 'foldtext', or after 'eol' listchar for transparent 'foldtext'.
    if (draw_folded && wlv.n_extra == 0 && wlv.col < view_width
        && (has_foldtext || (*ptr == NUL && (!wp->w_p_list || !lcs_eol_todo || lcs_eol == NUL)))) {
      // Fill rest of line with 'fold'.
      wlv.sc_extra = wp->w_p_fcs_chars.fold;
      wlv.sc_final = NUL;
      wlv.n_extra = view_width - wlv.col;
      // Don't continue search highlighting past the first filler char.
      search_attr = 0;
    }

    if (draw_folded && wlv.n_extra != 0 && wlv.col >= view_width) {
      // Truncate the folding.
      wlv.n_extra = 0;
    }

    // Get the next character to put on the screen.
    //
    // The "p_extra" points to the extra stuff that is inserted to
    // represent special characters (non-printable stuff) and other
    // things.  When all characters are the same, sc_extra is used.
    // If sc_final is set, it will compulsorily be used at the end.
    // "p_extra" must end in a NUL to avoid utfc_ptr2len() reads past
    // "p_extra[n_extra]".
    // For the '$' of the 'list' option, n_extra == 1, p_extra == "".
    if (wlv.n_extra > 0) {
      if (wlv.sc_extra != NUL || (wlv.n_extra == 1 && wlv.sc_final != NUL)) {
        mb_schar = (wlv.n_extra == 1 && wlv.sc_final != NUL) ? wlv.sc_final : wlv.sc_extra;
        mb_c = schar_get_first_codepoint(mb_schar);
        wlv.n_extra--;
      } else {
        assert(wlv.p_extra != NULL);
        mb_l = utfc_ptr2len(wlv.p_extra);
        mb_schar = utfc_ptr2schar(wlv.p_extra, &mb_c);
        // mb_l=0 at the end-of-line NUL
        if (mb_l > wlv.n_extra || mb_l == 0) {
          mb_l = 1;
        }

        // If a double-width char doesn't fit display a '>' in the last column.
        // Don't advance the pointer but put the character at the start of the next line.
        if (wlv.col >= view_width - 1 && schar_cells(mb_schar) == 2) {
          mb_c = '>';
          mb_l = 1;
          mb_schar = schar_from_ascii(mb_c);
          multi_attr = win_hl_attr(wp, HLF_AT);

          if (wlv.cul_attr) {
            multi_attr = 0 != wlv.line_attr_lowprio
                         ? hl_combine_attr(wlv.cul_attr, multi_attr)
                         : hl_combine_attr(multi_attr, wlv.cul_attr);
          }
        } else {
          wlv.n_extra -= mb_l;
          wlv.p_extra += mb_l;
        }

        // If a double-width char doesn't fit at the left side display a '<'.
        if (wlv.filler_todo <= 0 && wlv.skip_cells > 0 && mb_l > 1) {
          if (wlv.n_extra > 0) {
            n_extra_next = wlv.n_extra;
            extra_attr_next = wlv.extra_attr;
          }
          wlv.n_extra = 1;
          wlv.sc_extra = schar_from_ascii(MB_FILLER_CHAR);
          wlv.sc_final = NUL;
          mb_schar = schar_from_ascii(' ');
          mb_c = ' ';
          mb_l = 1;
          (void)mb_l;
          wlv.n_attr++;
          wlv.extra_attr = win_hl_attr(wp, HLF_AT);
        }
      }

      if (wlv.n_extra <= 0) {
        // Only restore search_attr and area_attr when there is no "n_extra" to show.
        if (n_extra_next <= 0) {
          if (search_attr == 0) {
            search_attr = saved_search_attr;
            saved_search_attr = 0;
          }
          if (area_attr == 0 && *ptr != NUL) {
            area_attr = saved_area_attr;
            saved_area_attr = 0;
          }
          if (decor_attr == 0) {
            decor_attr = saved_decor_attr;
            saved_decor_attr = 0;
          }
          if (wlv.extra_for_extmark) {
            // wlv.extra_attr should be used at this position but not any further.
            wlv.reset_extra_attr = true;
            extra_attr_next = -1;
          }
          wlv.extra_for_extmark = false;
        } else {
          assert(wlv.sc_extra != NUL || wlv.sc_final != NUL);
          assert(wlv.p_extra != NULL);
          wlv.sc_extra = NUL;
          wlv.sc_final = NUL;
          wlv.n_extra = n_extra_next;
          n_extra_next = 0;
          // wlv.extra_attr should be used at this position, but extra_attr_next
          // should be used after that.
          wlv.reset_extra_attr = true;
          assert(extra_attr_next >= 0);
        }
      }
    } else if (wlv.filler_todo > 0) {
      // Wait with reading text until filler lines are done. Still need to
      // initialize these.
      mb_c = ' ';
      mb_schar = schar_from_ascii(' ');
    } else if (has_foldtext || (has_fold && wlv.col >= view_width)) {
      // skip writing the buffer line itself
      mb_schar = NUL;
    } else {
      const char *prev_ptr = ptr;

      // first byte of next char
      int c0 = (uint8_t)(*ptr);
      if (c0 == NUL) {
        // no more cells to skip
        wlv.skip_cells = 0;
      }

      // Get a character from the line itself.
      mb_l = utfc_ptr2len(ptr);
      mb_schar = utfc_ptr2schar(ptr, &mb_c);

      // Overlong encoded ASCII or ASCII with composing char
      // is displayed normally, except a NUL.
      if (mb_l > 1 && mb_c < 0x80) {
        c0 = mb_c;
      }

      if ((mb_l == 1 && c0 >= 0x80)
          || (mb_l >= 1 && mb_c == 0)
          || (mb_l > 1 && (!vim_isprintc(mb_c)))) {
        // Illegal UTF-8 byte: display as <xx>.
        // Non-printable character : display as ? or fullwidth ?.
        transchar_hex(wlv.extra, mb_c);
        if (wp->w_p_rl) {  // reverse
          rl_mirror_ascii(wlv.extra, NULL);
        }

        wlv.p_extra = wlv.extra;
        mb_c = mb_ptr2char_adv((const char **)&wlv.p_extra);
        mb_schar = schar_from_char(mb_c);
        wlv.n_extra = (int)strlen(wlv.p_extra);
        wlv.sc_extra = NUL;
        wlv.sc_final = NUL;
        if (area_attr == 0 && search_attr == 0) {
          wlv.n_attr = wlv.n_extra + 1;
          wlv.extra_attr = win_hl_attr(wp, HLF_8);
          saved_attr2 = wlv.char_attr;               // save current attr
        }
      } else if (mb_l == 0) {        // at the NUL at end-of-line
        mb_l = 1;
      }
      // If a double-width char doesn't fit display a '>' in the
      // last column; the character is displayed at the start of the
      // next line.
      if (wlv.col >= view_width - 1 && schar_cells(mb_schar) == 2) {
        mb_schar = schar_from_ascii('>');
        mb_c = '>';
        mb_l = 1;
        multi_attr = win_hl_attr(wp, HLF_AT);
        // Put pointer back so that the character will be
        // displayed at the start of the next line.
        ptr--;
        did_decrement_ptr = true;
      } else if (*ptr != NUL) {
        ptr += mb_l - 1;
      }

      // If a double-width char doesn't fit at the left side display a '<' in
      // the first column.  Don't do this for unprintable characters.
      if (wlv.skip_cells > 0 && mb_l > 1 && wlv.n_extra == 0) {
        wlv.n_extra = 1;
        wlv.sc_extra = schar_from_ascii(MB_FILLER_CHAR);
        wlv.sc_final = NUL;
        mb_schar = schar_from_ascii(' ');
        mb_c = ' ';
        mb_l = 1;
        if (area_attr == 0 && search_attr == 0) {
          wlv.n_attr = wlv.n_extra + 1;
          wlv.extra_attr = win_hl_attr(wp, HLF_AT);
          saved_attr2 = wlv.char_attr;             // save current attr
        }
      }
      ptr++;

      decor_attr = 0;
      if (extra_check) {
        const bool no_plain_buffer = (wp->w_s->b_p_spo_flags & kOptSpoFlagNoplainbuffer) != 0;
        bool can_spell = !no_plain_buffer;

        // Get extmark and syntax attributes, unless still at the start of the line
        // (double-wide char that doesn't fit).
        const int v = (int)(ptr - line);
        const ptrdiff_t prev_v = prev_ptr - line;
        if (has_syntax && v > 0) {
          // Get the syntax attribute for the character.  If there
          // is an error, disable syntax highlighting.
          int save_did_emsg = did_emsg;
          did_emsg = false;

          decor_attr = get_syntax_attr(v - 1, spv->spv_has_spell ? &can_spell : NULL, false);

          if (did_emsg) {
            wp->w_s->b_syn_error = true;
            has_syntax = false;
          } else {
            did_emsg = save_did_emsg;
          }

          if (wp->w_s->b_syn_slow) {
            has_syntax = false;
          }

          // Need to get the line again, a multi-line regexp may
          // have made it invalid.
          line = ml_get_buf(wp->w_buffer, lnum);
          ptr = line + v;
          prev_ptr = line + prev_v;

          // no concealing past the end of the line, it interferes
          // with line highlighting.
          syntax_flags = (mb_schar == 0) ? 0 : get_syntax_info(&syntax_seqnr);
        }

        if (has_decor && v > 0) {
          // extmarks take preceedence over syntax.c
          decor_attr = hl_combine_attr(decor_attr, extmark_attr);
          decor_conceal = decor_state.conceal;
          can_spell = TRISTATE_TO_BOOL(decor_state.spell, can_spell);
        }

        char_attr_base = hl_combine_attr(folded_attr, decor_attr);
        wlv.char_attr = hl_combine_attr(char_attr_base, char_attr_pri);

        // Check spelling (unless at the end of the line).
        // Only do this when there is no syntax highlighting, the
        // @Spell cluster is not used or the current syntax item
        // contains the @Spell cluster.
        int v1 = (int)(ptr - line);
        if (spv->spv_has_spell && v1 >= word_end && v1 > cur_checked_col) {
          spell_attr = 0;
          // do not calculate cap_col at the end of the line or when
          // only white space is following
          if (mb_schar != 0 && (*skipwhite(prev_ptr) != NUL) && can_spell) {
            char *p;
            hlf_T spell_hlf = HLF_COUNT;
            v1 -= mb_l - 1;

            // Use nextline[] if possible, it has the start of the
            // next line concatenated.
            if ((prev_ptr - line) - nextlinecol >= 0) {
              p = nextline + ((prev_ptr - line) - nextlinecol);
            } else {
              p = (char *)prev_ptr;
            }
            spv->spv_cap_col -= (int)(prev_ptr - line);
            size_t tmplen = spell_check(wp, p, &spell_hlf, &spv->spv_cap_col, spv->spv_unchanged);
            assert(tmplen <= INT_MAX);
            int len = (int)tmplen;
            word_end = v1 + len;

            // In Insert mode only highlight a word that
            // doesn't touch the cursor.
            if (spell_hlf != HLF_COUNT
                && (State & MODE_INSERT)
                && wp->w_cursor.lnum == lnum
                && wp->w_cursor.col >=
                (colnr_T)(prev_ptr - line)
                && wp->w_cursor.col < (colnr_T)word_end) {
              spell_hlf = HLF_COUNT;
              spell_redraw_lnum = lnum;
            }

            if (spell_hlf == HLF_COUNT && p != prev_ptr
                && (p - nextline) + len > nextline_idx) {
              // Remember that the good word continues at the
              // start of the next line.
              spv->spv_checked_lnum = lnum + 1;
              spv->spv_checked_col = (int)((p - nextline) + len - nextline_idx);
            }

            // Turn index into actual attributes.
            if (spell_hlf != HLF_COUNT) {
              spell_attr = highlight_attr[spell_hlf];
            }

            if (spv->spv_cap_col > 0) {
              if (p != prev_ptr && (p - nextline) + spv->spv_cap_col >= nextline_idx) {
                // Remember that the word in the next line
                // must start with a capital.
                spv->spv_capcol_lnum = lnum + 1;
                spv->spv_cap_col = (int)((p - nextline) + spv->spv_cap_col - nextline_idx);
              } else {
                // Compute the actual column.
                spv->spv_cap_col += (int)(prev_ptr - line);
              }
            }
          }
        }
        if (spell_attr != 0) {
          char_attr_base = hl_combine_attr(char_attr_base, spell_attr);
          wlv.char_attr = hl_combine_attr(char_attr_base, char_attr_pri);
        }

        if (wp->w_buffer->terminal) {
          wlv.char_attr = hl_combine_attr(term_attrs[wlv.vcol], wlv.char_attr);
        }

        // we don't want linebreak to apply for lines that start with
        // leading spaces, followed by long letters (since it would add
        // a break at the beginning of a line and this might be unexpected)
        //
        // So only allow to linebreak, once we have found chars not in
        // 'breakat' in the line.
        if (wp->w_p_lbr && !wlv.need_lbr && mb_schar != NUL
            && !vim_isbreak((uint8_t)(*ptr))) {
          wlv.need_lbr = true;
        }
        // Found last space before word: check for line break.
        if (wp->w_p_lbr && c0 == mb_c && mb_c < 128 && wlv.need_lbr
            && vim_isbreak(mb_c) && !vim_isbreak((uint8_t)(*ptr))) {
          int mb_off = utf_head_off(line, ptr - 1);
          char *p = ptr - (mb_off + 1);

          CharsizeArg csarg;
          // lnum == 0, do not want virtual text to be counted here
          CSType cstype = init_charsize_arg(&csarg, wp, 0, line);
          wlv.n_extra = win_charsize(cstype, wlv.vcol, p, utf_ptr2CharInfo(p).value,
                                     &csarg).width - 1;

          if (on_last_col && mb_c != TAB) {
            // Do not continue search/match highlighting over the
            // line break, but for TABs the highlighting should
            // include the complete width of the character
            search_attr = 0;
          }

          if (mb_c == TAB && wlv.n_extra + wlv.col > view_width) {
            wlv.n_extra = tabstop_padding(wlv.vcol, wp->w_buffer->b_p_ts,
                                          wp->w_buffer->b_p_vts_array) - 1;
          }
          wlv.sc_extra = schar_from_ascii(mb_off > 0 ? MB_FILLER_CHAR : ' ');
          wlv.sc_final = NUL;
          if (mb_c < 128 && ascii_iswhite(mb_c)) {
            if (mb_c == TAB) {
              // See "Tab alignment" below.
              fix_for_boguscols(&wlv);
            }
            if (!wp->w_p_list) {
              mb_c = ' ';
              mb_schar = schar_from_ascii(mb_c);
            }
          }
        }

        if (wp->w_p_list) {
          in_multispace = mb_c == ' ' && (*ptr == ' ' || (prev_ptr > line && prev_ptr[-1] == ' '));
          if (!in_multispace) {
            multispace_pos = 0;
          }
        }

        // 'list': Change char 160 to 'nbsp' and space to 'space'.
        // But not when the character is followed by a composing
        // character (use mb_l to check that).
        if (wp->w_p_list
            && ((((mb_c == 160 && mb_l == 2) || (mb_c == 0x202f && mb_l == 3))
                 && wp->w_p_lcs_chars.nbsp)
                || (mb_c == ' '
                    && mb_l == 1
                    && (wp->w_p_lcs_chars.space
                        || (in_multispace && wp->w_p_lcs_chars.multispace != NULL))
                    && ptr - line >= leadcol
                    && ptr - line <= trailcol))) {
          if (in_multispace && wp->w_p_lcs_chars.multispace != NULL) {
            mb_schar = wp->w_p_lcs_chars.multispace[multispace_pos++];
            if (wp->w_p_lcs_chars.multispace[multispace_pos] == NUL) {
              multispace_pos = 0;
            }
          } else {
            mb_schar = (mb_c == ' ') ? wp->w_p_lcs_chars.space : wp->w_p_lcs_chars.nbsp;
          }
          wlv.n_attr = 1;
          wlv.extra_attr = win_hl_attr(wp, HLF_0);
          saved_attr2 = wlv.char_attr;  // save current attr
          mb_c = schar_get_first_codepoint(mb_schar);
        }

        if (mb_c == ' ' && mb_l == 1 && ((trailcol != MAXCOL && ptr > line + trailcol)
                                         || (leadcol != 0 && ptr < line + leadcol))) {
          if (leadcol != 0 && in_multispace && ptr < line + leadcol
              && wp->w_p_lcs_chars.leadmultispace != NULL) {
            mb_schar = wp->w_p_lcs_chars.leadmultispace[multispace_pos++];
            if (wp->w_p_lcs_chars.leadmultispace[multispace_pos] == NUL) {
              multispace_pos = 0;
            }
          } else if (ptr > line + trailcol && wp->w_p_lcs_chars.trail) {
            mb_schar = wp->w_p_lcs_chars.trail;
          } else if (ptr < line + leadcol && wp->w_p_lcs_chars.lead) {
            mb_schar = wp->w_p_lcs_chars.lead;
          } else if (leadcol != 0 && wp->w_p_lcs_chars.space) {
            mb_schar = wp->w_p_lcs_chars.space;
          }

          wlv.n_attr = 1;
          wlv.extra_attr = win_hl_attr(wp, HLF_0);
          saved_attr2 = wlv.char_attr;  // save current attr
          mb_c = schar_get_first_codepoint(mb_schar);
        }
      }

      // Handling of non-printable characters.
      if (!vim_isprintc(mb_c)) {
        // when getting a character from the file, we may have to
        // turn it into something else on the way to putting it on the screen.
        if (mb_c == TAB && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
          int tab_len = 0;
          colnr_T vcol_adjusted = wlv.vcol;  // removed showbreak length
          char *const sbr = get_showbreak_value(wp);

          // Only adjust the tab_len, when at the first column after the
          // showbreak value was drawn.
          if (*sbr != NUL && wlv.vcol == wlv.vcol_sbr && wp->w_p_wrap) {
            vcol_adjusted = wlv.vcol - mb_charlen(sbr);
          }
          // tab amount depends on current column
          tab_len = tabstop_padding(vcol_adjusted,
                                    wp->w_buffer->b_p_ts,
                                    wp->w_buffer->b_p_vts_array) - 1;

          if (!wp->w_p_lbr || !wp->w_p_list) {
            wlv.n_extra = tab_len;
          } else {
            int saved_nextra = wlv.n_extra;

            if (wlv.vcol_off_co > 0) {
              // there are characters to conceal
              tab_len += wlv.vcol_off_co;
            }
            // boguscols before fix_for_boguscols() from above.
            if (wp->w_p_lcs_chars.tab1 && wlv.old_boguscols > 0
                && wlv.n_extra > tab_len) {
              tab_len += wlv.n_extra - tab_len;
            }

            if (tab_len > 0) {
              // If wlv.n_extra > 0, it gives the number of chars
              // to use for a tab, else we need to calculate the
              // width for a tab.
              size_t tab2_len = schar_len(wp->w_p_lcs_chars.tab2);
              size_t len = (size_t)tab_len * tab2_len;
              if (wp->w_p_lcs_chars.tab3) {
                len += schar_len(wp->w_p_lcs_chars.tab3) - tab2_len;
              }
              if (wlv.n_extra > 0) {
                len += (size_t)(wlv.n_extra - tab_len);
              }
              mb_schar = wp->w_p_lcs_chars.tab1;
              mb_c = schar_get_first_codepoint(mb_schar);
              char *p = get_extra_buf(len + 1);
              memset(p, ' ', len);
              p[len] = NUL;
              wlv.p_extra = p;
              for (int i = 0; i < tab_len; i++) {
                if (*p == NUL) {
                  tab_len = i;
                  break;
                }
                schar_T lcs = wp->w_p_lcs_chars.tab2;

                // if tab3 is given, use it for the last char
                if (wp->w_p_lcs_chars.tab3 && i == tab_len - 1) {
                  lcs = wp->w_p_lcs_chars.tab3;
                }
                size_t slen = schar_get_adv(&p, lcs);
                wlv.n_extra += (int)slen - (saved_nextra > 0 ? 1 : 0);
              }

              // n_extra will be increased by fix_for_boguscols()
              // below, so need to adjust for that here
              if (wlv.vcol_off_co > 0) {
                wlv.n_extra -= wlv.vcol_off_co;
              }
            }
          }

          {
            int vc_saved = wlv.vcol_off_co;

            // Tab alignment should be identical regardless of
            // 'conceallevel' value. So tab compensates of all
            // previous concealed characters, and thus resets
            // vcol_off_co and boguscols accumulated so far in the
            // line. Note that the tab can be longer than
            // 'tabstop' when there are concealed characters.
            fix_for_boguscols(&wlv);

            // Make sure, the highlighting for the tab char will be
            // correctly set further below (effectively reverts the
            // fix_for_boguscols() call).
            if (wlv.n_extra == tab_len + vc_saved && wp->w_p_list
                && wp->w_p_lcs_chars.tab1) {
              tab_len += vc_saved;
            }
          }

          if (wp->w_p_list) {
            mb_schar = (wlv.n_extra == 0 && wp->w_p_lcs_chars.tab3)
                       ? wp->w_p_lcs_chars.tab3 : wp->w_p_lcs_chars.tab1;
            if (wp->w_p_lbr && wlv.p_extra != NULL && *wlv.p_extra != NUL) {
              wlv.sc_extra = NUL;  // using p_extra from above
            } else {
              wlv.sc_extra = wp->w_p_lcs_chars.tab2;
            }
            wlv.sc_final = wp->w_p_lcs_chars.tab3;
            wlv.n_attr = tab_len + 1;
            wlv.extra_attr = win_hl_attr(wp, HLF_0);
            saved_attr2 = wlv.char_attr;  // save current attr
          } else {
            wlv.sc_final = NUL;
            wlv.sc_extra = schar_from_ascii(' ');
            mb_schar = schar_from_ascii(' ');
          }
          mb_c = schar_get_first_codepoint(mb_schar);
        } else if (mb_schar == NUL
                   && (wp->w_p_list
                       || ((wlv.fromcol >= 0 || fromcol_prev >= 0)
                           && wlv.tocol > wlv.vcol
                           && VIsual_mode != Ctrl_V
                           && wlv.col < view_width
                           && !(noinvcur
                                && lnum == wp->w_cursor.lnum
                                && wlv.vcol == wp->w_virtcol)))
                   && lcs_eol_todo && lcs_eol != NUL) {
          // Display a '$' after the line or highlight an extra
          // character if the line break is included.
          // For a diff line the highlighting continues after the "$".
          if (wlv.diff_hlf == (hlf_T)0
              && wlv.line_attr == 0
              && wlv.line_attr_lowprio == 0) {
            // In virtualedit, visual selections may extend beyond end of line
            if (!(area_highlighting && virtual_active(wp)
                  && wlv.tocol != MAXCOL && wlv.vcol < wlv.tocol)) {
              wlv.p_extra = "";
            }
            wlv.n_extra = 0;
          }
          if (wp->w_p_list && wp->w_p_lcs_chars.eol > 0) {
            mb_schar = wp->w_p_lcs_chars.eol;
          } else {
            mb_schar = schar_from_ascii(' ');
          }
          lcs_eol_todo = false;
          ptr--;  // put it back at the NUL
          wlv.extra_attr = win_hl_attr(wp, HLF_AT);
          wlv.n_attr = 1;
          mb_c = schar_get_first_codepoint(mb_schar);
        } else if (mb_schar != NUL) {
          wlv.p_extra = transchar_buf(wp->w_buffer, mb_c);
          if (wlv.n_extra == 0) {
            wlv.n_extra = byte2cells(mb_c) - 1;
          }
          if ((dy_flags & kOptDyFlagUhex) && wp->w_p_rl) {
            rl_mirror_ascii(wlv.p_extra, NULL);   // reverse "<12>"
          }
          wlv.sc_extra = NUL;
          wlv.sc_final = NUL;
          if (wp->w_p_lbr) {
            mb_c = (uint8_t)(*wlv.p_extra);
            char *p = get_extra_buf((size_t)wlv.n_extra + 1);
            memset(p, ' ', (size_t)wlv.n_extra);
            memcpy(p, wlv.p_extra + 1, strlen(wlv.p_extra) - 1);
            p[wlv.n_extra] = NUL;
            wlv.p_extra = p;
          } else {
            wlv.n_extra = byte2cells(mb_c) - 1;
            mb_c = (uint8_t)(*wlv.p_extra++);
          }
          wlv.n_attr = wlv.n_extra + 1;
          wlv.extra_attr = win_hl_attr(wp, HLF_8);
          saved_attr2 = wlv.char_attr;  // save current attr
          mb_schar = schar_from_ascii(mb_c);
        } else if (VIsual_active
                   && (VIsual_mode == Ctrl_V || VIsual_mode == 'v')
                   && virtual_active(wp)
                   && wlv.tocol != MAXCOL
                   && wlv.vcol < wlv.tocol
                   && wlv.col < view_width) {
          mb_c = ' ';
          mb_schar = schar_from_char(mb_c);
          ptr--;  // put it back at the NUL
        }
      }

      if (wp->w_p_cole > 0
          && (wp != curwin || lnum != wp->w_cursor.lnum || conceal_cursor_line(wp))
          && ((syntax_flags & HL_CONCEAL) != 0 || has_match_conc > 0 || decor_conceal > 0)
          && !(lnum_in_visual_area && vim_strchr(wp->w_p_cocu, 'v') == NULL)) {
        wlv.char_attr = conceal_attr;
        if (((prev_syntax_id != syntax_seqnr && (syntax_flags & HL_CONCEAL) != 0)
             || has_match_conc > 1 || decor_conceal > 1)
            && (syn_get_sub_char() != NUL
                || (has_match_conc && match_conc)
                || (decor_conceal && decor_state.conceal_char)
                || wp->w_p_cole == 1)
            && wp->w_p_cole != 3) {
          if (schar_cells(mb_schar) > 1) {
            // When the first char to be concealed is double-width,
            // need to advance one more virtual column.
            wlv.n_extra++;
          }

          // First time at this concealed item: display one
          // character.
          if (has_match_conc && match_conc) {
            mb_schar = schar_from_char(match_conc);
          } else if (decor_conceal && decor_state.conceal_char) {
            mb_schar = decor_state.conceal_char;
            if (decor_state.conceal_attr) {
              wlv.char_attr = decor_state.conceal_attr;
            }
          } else if (syn_get_sub_char() != NUL) {
            mb_schar = schar_from_char(syn_get_sub_char());
          } else if (wp->w_p_lcs_chars.conceal != NUL) {
            mb_schar = wp->w_p_lcs_chars.conceal;
          } else {
            mb_schar = schar_from_ascii(' ');
          }

          mb_c = schar_get_first_codepoint(mb_schar);

          prev_syntax_id = syntax_seqnr;

          if (wlv.n_extra > 0) {
            wlv.vcol_off_co += wlv.n_extra;
          }
          wlv.vcol += wlv.n_extra;
          if (is_wrapped && wlv.n_extra > 0) {
            wlv.boguscols += wlv.n_extra;
            wlv.col += wlv.n_extra;
          }
          wlv.n_extra = 0;
          wlv.n_attr = 0;
        } else if (wlv.skip_cells == 0) {
          is_concealing = true;
          wlv.skip_cells = 1;
        }
      } else {
        prev_syntax_id = 0;
        is_concealing = false;
      }

      if (wlv.skip_cells > 0 && did_decrement_ptr) {
        // not showing the '>', put pointer back to avoid getting stuck
        ptr++;
      }
    }  // end of printing from buffer content

    // In the cursor line and we may be concealing characters: correct
    // the cursor column when we reach its position.
    // With 'virtualedit' we may never reach cursor position, but we still
    // need to correct the cursor column, so do that at end of line.
    if (!did_wcol && wlv.filler_todo <= 0
        && in_curline && conceal_cursor_line(wp)
        && (wlv.vcol + wlv.skip_cells >= wp->w_virtcol || mb_schar == NUL)) {
      wp->w_wcol = wlv.col - wlv.boguscols;
      if (wlv.vcol + wlv.skip_cells < wp->w_virtcol) {
        // Cursor beyond end of the line with 'virtualedit'.
        wp->w_wcol += wp->w_virtcol - wlv.vcol - wlv.skip_cells;
      }
      wp->w_wrow = wlv.row;
      did_wcol = true;
      wp->w_valid |= VALID_WCOL|VALID_WROW|VALID_VIRTCOL;
    }

    // Use "wlv.extra_attr", but don't override visual selection highlighting.
    if (wlv.n_attr > 0 && !search_attr_from_match) {
      wlv.char_attr = hl_combine_attr(wlv.char_attr, wlv.extra_attr);
      if (wlv.reset_extra_attr) {
        wlv.reset_extra_attr = false;
        if (extra_attr_next >= 0) {
          wlv.extra_attr = extra_attr_next;
          extra_attr_next = -1;
        } else {
          wlv.extra_attr = 0;
          // search_attr_from_match can be restored now that the extra_attr has been applied
          search_attr_from_match = saved_search_attr_from_match;
        }
      }
    }

    // Handle the case where we are in column 0 but not on the first
    // character of the line and the user wants us to show us a
    // special character (via 'listchars' option "precedes:<char>").
    if (lcs_prec_todo != NUL
        && wp->w_p_list
        && (wp->w_p_wrap ? (wp->w_skipcol > 0 && wlv.row == 0) : wp->w_leftcol > 0)
        && wlv.filler_todo <= 0
        && wlv.skip_cells <= 0
        && mb_schar != NUL) {
      lcs_prec_todo = NUL;
      if (schar_cells(mb_schar) > 1) {
        // Double-width character being overwritten by the "precedes"
        // character, need to fill up half the character.
        wlv.sc_extra = schar_from_ascii(MB_FILLER_CHAR);
        wlv.sc_final = NUL;
        if (wlv.n_extra > 0) {
          assert(wlv.p_extra != NULL);
          n_extra_next = wlv.n_extra;
          extra_attr_next = wlv.extra_attr;
          wlv.n_attr = MAX(wlv.n_attr + 1, 2);
        } else {
          wlv.n_attr = 2;
        }
        wlv.n_extra = 1;
        wlv.extra_attr = win_hl_attr(wp, HLF_AT);
      }
      mb_schar = wp->w_p_lcs_chars.prec;
      mb_c = schar_get_first_codepoint(mb_schar);
      saved_attr3 = wlv.char_attr;  // save current attr
      wlv.char_attr = win_hl_attr(wp, HLF_AT);  // overwriting char_attr
      n_attr3 = 1;
    }

    // At end of the text line or just after the last character.
    if (mb_schar == NUL && eol_hl_off == 0) {
      // flag to indicate whether prevcol equals startcol of search_hl or
      // one of the matches
      const bool prevcol_hl_flag = get_prevcol_hl_flag(wp, &screen_search_hl,
                                                       (colnr_T)(ptr - line) - 1);

      // Invert at least one char, used for Visual and empty line or
      // highlight match at end of line. If it's beyond the last
      // char on the screen, just overwrite that one (tricky!)  Not
      // needed when a '$' was displayed for 'list'.
      if (lcs_eol_todo
          && ((area_attr != 0 && wlv.vcol == wlv.fromcol
               && (VIsual_mode != Ctrl_V
                   || lnum == VIsual.lnum
                   || lnum == curwin->w_cursor.lnum))
              // highlight 'hlsearch' match at end of line
              || prevcol_hl_flag)) {
        int n = 0;

        if (wlv.col >= view_width) {
          n = -1;
        }
        if (n != 0) {
          // At the window boundary, highlight the last character
          // instead (better than nothing).
          wlv.off += n;
          wlv.col += n;
        } else {
          // Add a blank character to highlight.
          linebuf_char[wlv.off] = schar_from_ascii(' ');
        }
        if (area_attr == 0 && !has_fold) {
          // Use attributes from match with highest priority among
          // 'search_hl' and the match list.
          get_search_match_hl(wp,
                              &screen_search_hl,
                              (colnr_T)(ptr - line),
                              &wlv.char_attr);
        }

        const int eol_attr = wlv.cul_attr
                             ? hl_combine_attr(wlv.cul_attr, wlv.char_attr)
                             : wlv.char_attr;

        linebuf_attr[wlv.off] = eol_attr;
        linebuf_vcol[wlv.off] = wlv.vcol;
        wlv.col++;
        wlv.off++;
        wlv.vcol++;
        eol_hl_off = 1;
      }
    }

    // At end of the text line.
    if (mb_schar == NUL) {
      // Highlight 'cursorcolumn' & 'colorcolumn' past end of the line.

      // check if line ends before left margin
      wlv.vcol = MAX(wlv.vcol, start_col + wlv.col - win_col_off(wp));
      // Get rid of the boguscols now, we want to draw until the right
      // edge for 'cursorcolumn'.
      wlv.col -= wlv.boguscols;
      wlv.boguscols = 0;

      advance_color_col(&wlv, vcol_hlc(wlv));

      // Make sure alignment is the same regardless
      // if listchars=eol:X is used or not.
      const int eol_skip = (lcs_eol_todo && eol_hl_off == 0 ? 1 : 0);

      if (has_decor) {
        decor_redraw_eol(wp, &decor_state, &wlv.line_attr, wlv.col + eol_skip);
      }

      for (int i = wlv.col; i < view_width; i++) {
        linebuf_vcol[wlv.off + (i - wlv.col)] = wlv.vcol + (i - wlv.col);
      }

      if (((wp->w_p_cuc
            && wp->w_virtcol >= vcol_hlc(wlv) - eol_hl_off
            && wp->w_virtcol < view_width * (ptrdiff_t)(wlv.row - startrow + 1) + start_col
            && lnum != wp->w_cursor.lnum)
           || wlv.color_cols || wlv.line_attr_lowprio || wlv.line_attr
           || wlv.diff_hlf != 0 || wp->w_buffer->terminal)) {
        int rightmost_vcol = get_rightmost_vcol(wp, wlv.color_cols);
        const int cuc_attr = win_hl_attr(wp, HLF_CUC);
        const int mc_attr = win_hl_attr(wp, HLF_MC);

        if (wlv.diff_hlf == HLF_TXD || wlv.diff_hlf == HLF_TXA) {
          wlv.diff_hlf = HLF_CHD;
          set_line_attr_for_diff(wp, &wlv);
        }

        const int diff_attr = wlv.diff_hlf != 0
                              ? win_hl_attr(wp, (int)wlv.diff_hlf)
                              : 0;

        const int base_attr = hl_combine_attr(wlv.line_attr_lowprio, diff_attr);
        if (base_attr || wlv.line_attr || wp->w_buffer->terminal) {
          rightmost_vcol = INT_MAX;
        }

        while (wlv.col < view_width) {
          linebuf_char[wlv.off] = schar_from_ascii(' ');

          advance_color_col(&wlv, vcol_hlc(wlv));

          int col_attr = base_attr;

          if (wp->w_p_cuc && vcol_hlc(wlv) == wp->w_virtcol
              && lnum != wp->w_cursor.lnum) {
            col_attr = hl_combine_attr(col_attr, cuc_attr);
          } else if (wlv.color_cols && vcol_hlc(wlv) == *wlv.color_cols) {
            col_attr = hl_combine_attr(col_attr, mc_attr);
          }

          if (wp->w_buffer->terminal && wlv.vcol < TERM_ATTRS_MAX) {
            col_attr = hl_combine_attr(col_attr, term_attrs[wlv.vcol]);
          }

          col_attr = hl_combine_attr(col_attr, wlv.line_attr);

          linebuf_attr[wlv.off] = col_attr;
          // linebuf_vcol[] already filled by the for loop above
          wlv.off++;
          wlv.col++;
          wlv.vcol++;

          if (vcol_hlc(wlv) > rightmost_vcol) {
            break;
          }
        }
      }

      if (kv_size(fold_vt) > 0) {
        draw_virt_text_item(buf, win_col_offset, fold_vt, kHlModeCombine, view_width, 0, 0);
      }
      draw_virt_text(wp, buf, win_col_offset, &wlv.col, wlv.row);
      // Set increasing virtual columns in grid->vcols[] to set correct curswant
      // (or "coladd" for 'virtualedit') when clicking after end of line.
      wlv_put_linebuf(wp, &wlv, wlv.col, true, bg_attr, SLF_INC_VCOL);
      wlv.row++;

      // Update w_cline_height and w_cline_folded if the cursor line was
      // updated (saves a call to plines_win() later).
      if (in_curline) {
        curwin->w_cline_row = startrow;
        curwin->w_cline_height = wlv.row - startrow;
        curwin->w_cline_folded = has_fold;
        curwin->w_valid |= (VALID_CHEIGHT|VALID_CROW);
      }

      break;
    }

    // Show "extends" character from 'listchars' if beyond the line end and
    // 'list' is set.
    // Don't show this with 'wrap' as the line can't be scrolled horizontally.
    if (wp->w_p_lcs_chars.ext != NUL
        && wp->w_p_list
        && !wp->w_p_wrap
        && wlv.filler_todo <= 0
        && wlv.col == view_width - 1
        && !has_foldtext) {
      if (has_decor && *ptr == NUL && lcs_eol == 0 && lcs_eol_todo) {
        // Tricky: there might be a virtual text just _after_ the last char
        decor_redraw_col(wp, (colnr_T)(ptr - line), -1, false, &decor_state);
      }
      if (*ptr != NUL
          || (lcs_eol > 0 && lcs_eol_todo)
          || (wlv.n_extra > 0 && (wlv.sc_extra != NUL || *wlv.p_extra != NUL))
          || (may_have_inline_virt && has_more_inline_virt(&wlv, ptr - line))) {
        mb_schar = wp->w_p_lcs_chars.ext;
        wlv.char_attr = win_hl_attr(wp, HLF_AT);
        mb_c = schar_get_first_codepoint(mb_schar);
      }
    }

    advance_color_col(&wlv, vcol_hlc(wlv));

    // Highlight the cursor column if 'cursorcolumn' is set.  But don't
    // highlight the cursor position itself.
    // Also highlight the 'colorcolumn' if it is different than
    // 'cursorcolumn'
    vcol_save_attr = -1;
    if (!lnum_in_visual_area
        && search_attr == 0
        && area_attr == 0
        && wlv.filler_todo <= 0) {
      if (wp->w_p_cuc && vcol_hlc(wlv) == wp->w_virtcol
          && lnum != wp->w_cursor.lnum) {
        vcol_save_attr = wlv.char_attr;
        wlv.char_attr = hl_combine_attr(win_hl_attr(wp, HLF_CUC), wlv.char_attr);
      } else if (wlv.color_cols && vcol_hlc(wlv) == *wlv.color_cols) {
        vcol_save_attr = wlv.char_attr;
        wlv.char_attr = hl_combine_attr(win_hl_attr(wp, HLF_MC), wlv.char_attr);
      }
    }

    if (wlv.filler_todo <= 0) {
      // Apply lowest-priority line attr now, so everything can override it.
      wlv.char_attr = hl_combine_attr(wlv.line_attr_lowprio, wlv.char_attr);
    }

    if (wlv.filler_todo <= 0) {
      vcol_prev = wlv.vcol;
    }

    // Store character to be displayed.
    // Skip characters that are left of the screen for 'nowrap'.
    if (wlv.filler_todo > 0) {
      // TODO(bfredl): the main render loop should get called also with the virtual
      // lines chunks, so we get line wrapping and other Nice Things.
    } else if (wlv.skip_cells <= 0) {
      // Store the character.
      linebuf_char[wlv.off] = mb_schar;
      if (multi_attr) {
        linebuf_attr[wlv.off] = multi_attr;
        multi_attr = 0;
      } else {
        linebuf_attr[wlv.off] = wlv.char_attr;
      }

      linebuf_vcol[wlv.off] = wlv.vcol;

      if (schar_cells(mb_schar) > 1) {
        // Need to fill two screen columns.
        wlv.off++;
        wlv.col++;
        // UTF-8: Put a 0 in the second screen char.
        linebuf_char[wlv.off] = 0;
        linebuf_attr[wlv.off] = linebuf_attr[wlv.off - 1];

        linebuf_vcol[wlv.off] = ++wlv.vcol;

        // When "wlv.tocol" is halfway through a character, set it to the end
        // of the character, otherwise highlighting won't stop.
        if (wlv.tocol == wlv.vcol) {
          wlv.tocol++;
        }
      }
      wlv.off++;
      wlv.col++;
    } else if (wp->w_p_cole > 0 && is_concealing) {
      bool concealed_wide = schar_cells(mb_schar) > 1;

      wlv.skip_cells--;
      wlv.vcol_off_co++;
      if (concealed_wide) {
        // When a double-width char is concealed,
        // need to advance one more virtual column.
        wlv.vcol++;
        wlv.vcol_off_co++;
      }

      if (wlv.n_extra > 0) {
        wlv.vcol_off_co += wlv.n_extra;
      }

      if (is_wrapped) {
        // Special voodoo required if 'wrap' is on.
        //
        // Advance the column indicator to force the line
        // drawing to wrap early. This will make the line
        // take up the same screen space when parts are concealed,
        // so that cursor line computations aren't messed up.
        //
        // To avoid the fictitious advance of 'wlv.col' causing
        // trailing junk to be written out of the screen line
        // we are building, 'boguscols' keeps track of the number
        // of bad columns we have advanced.
        if (wlv.n_extra > 0) {
          wlv.vcol += wlv.n_extra;
          wlv.col += wlv.n_extra;
          wlv.boguscols += wlv.n_extra;
          wlv.n_extra = 0;
          wlv.n_attr = 0;
        }

        if (concealed_wide) {
          // Need to fill two screen columns.
          wlv.boguscols++;
          wlv.col++;
        }

        wlv.boguscols++;
        wlv.col++;
      } else {
        if (wlv.n_extra > 0) {
          wlv.vcol += wlv.n_extra;
          wlv.n_extra = 0;
          wlv.n_attr = 0;
        }
      }
    } else {
      wlv.skip_cells--;
    }

    // The skipped cells need to be accounted for in vcol.
    if (wlv.skipped_cells > 0) {
      wlv.vcol += wlv.skipped_cells;
      wlv.skipped_cells = 0;
    }

    // Only advance the "wlv.vcol" when after the 'number' or
    // 'relativenumber' column.
    if (wlv.filler_todo <= 0) {
      wlv.vcol++;
    }

    if (vcol_save_attr >= 0) {
      wlv.char_attr = vcol_save_attr;
    }

    // restore attributes after "precedes" in 'listchars'
    if (n_attr3 > 0 && --n_attr3 == 0) {
      wlv.char_attr = saved_attr3;
    }

    // restore attributes after last 'listchars' or 'number' char
    if (wlv.n_attr > 0 && --wlv.n_attr == 0) {
      wlv.char_attr = saved_attr2;
    }

    if (has_decor && wlv.filler_todo <= 0 && wlv.col >= view_width) {
      // At the end of screen line: might need to peek for decorations just after
      // this position.
      if (is_wrapped && wlv.n_extra == 0) {
        decor_redraw_col(wp, (colnr_T)(ptr - line), -3, false, &decor_state);
        // Check position/hiding of virtual text again on next screen line.
        decor_need_recheck = true;
      } else if (!is_wrapped) {
        // Without wrapping, we might need to display right_align and win_col
        // virt_text for the entire text line.
        decor_recheck_draw_col(-1, true, &decor_state);
        decor_redraw_col(wp, MAXCOL, -1, true, &decor_state);
      }
    }

end_check:
    // At end of screen line and there is more to come: Display the line
    // so far.  If there is no more to display it is caught above.
    if (wlv.col >= view_width && (!has_foldtext || virt_line_index >= 0)
        && (wlv.col <= leftcols_width
            || *ptr != NUL
            || wlv.filler_todo > 0
            || (wp->w_p_list && wp->w_p_lcs_chars.eol != NUL && lcs_eol_todo)
            || (wlv.n_extra != 0 && (wlv.sc_extra != NUL || *wlv.p_extra != NUL))
            || (may_have_inline_virt && has_more_inline_virt(&wlv, ptr - line)))) {
      int grid_width = wp->w_grid.target->cols;
      const bool wrap = is_wrapped                      // Wrapping enabled (not a folded line).
                        && wlv.filler_todo <= 0         // Not drawing diff filler lines.
                        && lcs_eol_todo                 // Haven't printed the lcs_eol character.
                        && wlv.row != endrow - 1        // Not the last line being displayed.
                        && view_width == grid_width     // Window spans the width of its grid.
                        && !wp->w_p_rl;                 // Not right-to-left.

      int draw_col = wlv.col - wlv.boguscols;

      for (int i = draw_col; i < view_width; i++) {
        linebuf_vcol[wlv.off + (i - draw_col)] = wlv.vcol - 1;
      }

      // Apply 'cursorline' highlight.
      if (wlv.boguscols != 0 && (wlv.line_attr_lowprio != 0 || wlv.line_attr != 0)) {
        int attr = hl_combine_attr(wlv.line_attr_lowprio, wlv.line_attr);
        while (draw_col < view_width) {
          linebuf_char[wlv.off] = schar_from_char(' ');
          linebuf_attr[wlv.off] = attr;
          // linebuf_vcol[] already filled by the for loop above
          wlv.off++;
          draw_col++;
        }
      }

      if (virt_line_index >= 0) {
        draw_virt_text_item(buf,
                            virt_line_flags & kVLLeftcol ? 0 : win_col_offset,
                            kv_A(virt_lines, virt_line_index).line,
                            kHlModeReplace,
                            view_width,
                            0,
                            virt_line_flags & kVLScroll ? wp->w_leftcol : 0);
      } else if (wlv.filler_todo <= 0) {
        draw_virt_text(wp, buf, win_col_offset, &draw_col, wlv.row);
      }

      wlv_put_linebuf(wp, &wlv, draw_col, true, bg_attr, wrap ? SLF_WRAP : 0);
      if (wrap) {
        int current_row = wlv.row;
        int dummy_col = 0;  // unused
        ScreenGrid *current_grid = grid_adjust(grid, &current_row, &dummy_col);

        // Force a redraw of the first column of the next line.
        current_grid->attrs[current_grid->line_offset[current_row + 1]] = -1;
      }

      wlv.boguscols = 0;
      wlv.vcol_off_co = 0;
      wlv.row++;

      // When not wrapping and finished diff lines, break here.
      if (!is_wrapped && wlv.filler_todo <= 0) {
        break;
      }

      // When the window is too narrow draw all "@" lines.
      if (wlv.col <= leftcols_width) {
        win_draw_end(wp, schar_from_ascii('@'), true, wlv.row, wp->w_view_height, HLF_AT);
        set_empty_rows(wp, wlv.row);
        wlv.row = endrow;
      }

      // When line got too long for screen break here.
      if (wlv.row == endrow) {
        wlv.row++;
        break;
      }

      win_line_start(wp, &wlv);
      draw_cols = true;

      lcs_prec_todo = wp->w_p_lcs_chars.prec;
      if (wlv.filler_todo <= 0) {
        wlv.need_showbreak = true;
      }
      if (statuscol.draw && vim_strchr(p_cpo, CPO_NUMCOL)
          && wlv.row > startrow + wlv.filler_lines) {
        statuscol.draw = false;  // don't draw status column if "n" is in 'cpo'
      }
      wlv.filler_todo--;
      virt_line_index = -1;
      virt_line_flags = 0;
      // When the filler lines are actually below the last line of the
      // file, or we are not drawing text for this line, break here.
      if (wlv.filler_todo == 0 && (wp->w_botfill || !draw_text)) {
        break;
      }
    }
  }     // for every character in the line

  clear_virttext(&fold_vt);
  kv_destroy(virt_lines);
  xfree(foldtext_free);
  return wlv.row;
}

/// Call grid_put_linebuf() using values from "wlv".
/// Also takes care of putting "<<<" on the first line for 'smoothscroll'
/// when 'showbreak' is not set.
///
/// @param clear_end  clear until the end of the screen line.
/// @param flags  for grid_put_linebuf(), but shouldn't contain SLF_RIGHTLEFT.
static void wlv_put_linebuf(win_T *wp, const winlinevars_T *wlv, int endcol, bool clear_end,
                            int bg_attr, int flags)
{
  GridView *grid = &wp->w_grid;

  int startcol = 0;
  int clear_width = clear_end ? wp->w_view_width : endcol;

  assert(!(flags & SLF_RIGHTLEFT));
  if (wp->w_p_rl) {
    linebuf_mirror(&startcol, &endcol, &clear_width, wp->w_view_width);
    flags |= SLF_RIGHTLEFT;
  }

  // Take care of putting "<<<" on the first line for 'smoothscroll'.
  if (wlv->row == 0 && wp->w_skipcol > 0
      // do not overwrite the 'showbreak' text with "<<<"
      && *get_showbreak_value(wp) == NUL
      // do not overwrite the 'listchars' "precedes" text with "<<<"
      && !(wp->w_p_list && wp->w_p_lcs_chars.prec != 0)) {
    int off = 0;
    if (wp->w_p_nu && wp->w_p_rnu) {
      // do not overwrite the line number, change "123 text" to "123<<<xt".
      while (off < wp->w_view_width && ascii_isdigit(schar_get_ascii(linebuf_char[off]))) {
        off++;
      }
    }

    for (int i = 0; i < 3 && off < wp->w_view_width; i++) {
      if (off + 1 < wp->w_view_width && linebuf_char[off + 1] == NUL) {
        // When the first half of a double-width character is
        // overwritten, change the second half to a space.
        linebuf_char[off + 1] = schar_from_ascii(' ');
      }
      linebuf_char[off] = schar_from_ascii('<');
      linebuf_attr[off] = HL_ATTR(HLF_AT);
      off++;
    }
  }

  int row = wlv->row;
  int coloff = 0;
  ScreenGrid *g = grid_adjust(grid, &row, &coloff);
  grid_put_linebuf(g, row, coloff, startcol, endcol, clear_width, bg_attr, wlv->vcol - 1, flags);
}
