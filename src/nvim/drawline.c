// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// drawline.c: Functions for drawing window lines on the screen.
// This is the middle level, drawscreen.c is the top and grid.c/screen.c the lower level.

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/arabic.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/cursor_shape.h"
#include "nvim/decoration.h"
#include "nvim/diff.h"
#include "nvim/drawline.h"
#include "nvim/fold.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/match.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/plines.h"
#include "nvim/quickfix.h"
#include "nvim/search.h"
#include "nvim/sign.h"
#include "nvim/spell.h"
#include "nvim/state.h"
#include "nvim/syntax.h"
#include "nvim/undo.h"
#include "nvim/window.h"

#define MB_FILLER_CHAR '<'  // character used when a double-width character
                            // doesn't fit.

/// for line_putchar. Contains the state that needs to be remembered from
/// putting one character to the next.
typedef struct {
  const char *p;
  int prev_c;   ///< previous Arabic character
  int prev_c1;  ///< first composing char for prev_c
} LineState;
#define LINE_STATE(p) { p, 0, 0 }

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "drawline.c.generated.h"
#endif

/// Advance **color_cols
///
/// @return  true when there are columns to draw.
static bool advance_color_col(int vcol, int **color_cols)
{
  while (**color_cols >= 0 && vcol > **color_cols) {
    (*color_cols)++;
  }
  return **color_cols >= 0;
}

/// Used when 'cursorlineopt' contains "screenline": compute the margins between
/// which the highlighting is used.
static void margin_columns_win(win_T *wp, int *left_col, int *right_col)
{
  // cache previous calculations depending on w_virtcol
  static int saved_w_virtcol;
  static win_T *prev_wp;
  static int prev_left_col;
  static int prev_right_col;
  static int prev_col_off;

  int cur_col_off = win_col_off(wp);
  int width1;
  int width2;

  if (saved_w_virtcol == wp->w_virtcol && prev_wp == wp
      && prev_col_off == cur_col_off) {
    *right_col = prev_right_col;
    *left_col = prev_left_col;
    return;
  }

  width1 = wp->w_width - cur_col_off;
  width2 = width1 + win_col_off2(wp);

  *left_col = 0;
  *right_col = width1;

  if (wp->w_virtcol >= (colnr_T)width1) {
    *right_col = width1 + ((wp->w_virtcol - width1) / width2 + 1) * width2;
  }
  if (wp->w_virtcol >= (colnr_T)width1 && width2 > 0) {
    *left_col = (wp->w_virtcol - width1) / width2 * width2 + width1;
  }

  // cache values
  prev_left_col = *left_col;
  prev_right_col = *right_col;
  prev_wp = wp;
  saved_w_virtcol = wp->w_virtcol;
  prev_col_off = cur_col_off;
}

/// Put a single char from an UTF-8 buffer into a line buffer.
///
/// Handles composing chars and arabic shaping state.
static int line_putchar(buf_T *buf, LineState *s, schar_T *dest, int maxcells, bool rl, int vcol)
{
  const char_u *p = (char_u *)s->p;
  int cells = utf_ptr2cells((char *)p);
  int c_len = utfc_ptr2len((char *)p);
  int u8c, u8cc[MAX_MCO];
  if (cells > maxcells) {
    return -1;
  }
  u8c = utfc_ptr2char((char *)p, u8cc);
  if (*p == TAB) {
    cells = MIN(tabstop_padding(vcol, buf->b_p_ts, buf->b_p_vts_array), maxcells);
    for (int c = 0; c < cells; c++) {
      schar_from_ascii(dest[c], ' ');
    }
    goto done;
  } else if (*p < 0x80 && u8cc[0] == 0) {
    schar_from_ascii(dest[0], (char)(*p));
    s->prev_c = u8c;
  } else {
    if (p_arshape && !p_tbidi && ARABIC_CHAR(u8c)) {
      // Do Arabic shaping.
      int pc, pc1, nc;
      int pcc[MAX_MCO];
      int firstbyte = *p;

      // The idea of what is the previous and next
      // character depends on 'rightleft'.
      if (rl) {
        pc = s->prev_c;
        pc1 = s->prev_c1;
        nc = utf_ptr2char((char *)p + c_len);
        s->prev_c1 = u8cc[0];
      } else {
        pc = utfc_ptr2char((char *)p + c_len, pcc);
        nc = s->prev_c;
        pc1 = pcc[0];
      }
      s->prev_c = u8c;

      u8c = arabic_shape(u8c, &firstbyte, &u8cc[0], pc, pc1, nc);
    } else {
      s->prev_c = u8c;
    }
    schar_from_cc(dest[0], u8c, u8cc);
  }
  if (cells > 1) {
    dest[1][0] = 0;
  }
done:
  s->p += c_len;
  return cells;
}

static inline void provider_err_virt_text(linenr_T lnum, char *err)
{
  Decoration err_decor = DECORATION_INIT;
  int hl_err = syn_check_group(S_LEN("ErrorMsg"));
  kv_push(err_decor.virt_text,
          ((VirtTextChunk){ .text = err,
                            .hl_id = hl_err }));
  err_decor.virt_text_width = (int)mb_string2cells(err);
  decor_add_ephemeral(lnum - 1, 0, lnum - 1, 0, &err_decor, 0, 0);
}

static void draw_virt_text(win_T *wp, buf_T *buf, int col_off, int *end_col, int max_col,
                           int win_row)
{
  DecorState *state = &decor_state;
  int right_pos = max_col;
  bool do_eol = state->eol_col > -1;
  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange *item = &kv_A(state->active, i);
    if (!(item->start_row == state->row
          && (kv_size(item->decor.virt_text) || item->decor.ui_watched))) {
      continue;
    }
    if (item->win_col == -1) {
      if (item->decor.virt_text_pos == kVTRightAlign) {
        right_pos -= item->decor.virt_text_width;
        item->win_col = right_pos;
      } else if (item->decor.virt_text_pos == kVTEndOfLine && do_eol) {
        item->win_col = state->eol_col;
      } else if (item->decor.virt_text_pos == kVTWinCol) {
        item->win_col = MAX(item->decor.col + col_off, 0);
      }
    }
    if (item->win_col < 0) {
      continue;
    }
    int col;
    if (item->decor.ui_watched) {
      // send mark position to UI
      col = item->win_col;
      WinExtmark m = { (NS)item->ns_id, item->mark_id, win_row, col };
      kv_push(win_extmark_arr, m);
    }
    if (kv_size(item->decor.virt_text)) {
      col = draw_virt_text_item(buf, item->win_col, item->decor.virt_text,
                                item->decor.hl_mode, max_col, item->win_col - col_off);
    }
    item->win_col = -2;  // deactivate
    if (item->decor.virt_text_pos == kVTEndOfLine && do_eol) {
      state->eol_col = col + 1;
    }

    *end_col = MAX(*end_col, col);
  }
}

static int draw_virt_text_item(buf_T *buf, int col, VirtText vt, HlMode hl_mode, int max_col,
                               int vcol)
{
  LineState s = LINE_STATE("");
  int virt_attr = 0;
  size_t virt_pos = 0;

  while (col < max_col) {
    if (!*s.p) {
      if (virt_pos >= kv_size(vt)) {
        break;
      }
      virt_attr = 0;
      do {
        s.p = kv_A(vt, virt_pos).text;
        int hl_id = kv_A(vt, virt_pos).hl_id;
        virt_attr = hl_combine_attr(virt_attr,
                                    hl_id > 0 ? syn_id2attr(hl_id) : 0);
        virt_pos++;
      } while (!s.p && virt_pos < kv_size(vt));
      if (!s.p) {
        break;
      }
    }
    if (!*s.p) {
      continue;
    }
    int attr;
    bool through = false;
    if (hl_mode == kHlModeCombine) {
      attr = hl_combine_attr(linebuf_attr[col], virt_attr);
    } else if (hl_mode == kHlModeBlend) {
      through = (*s.p == ' ');
      attr = hl_blend_attrs(linebuf_attr[col], virt_attr, &through);
    } else {
      attr = virt_attr;
    }
    schar_T dummy[2];
    int cells = line_putchar(buf, &s, through ? dummy : &linebuf_char[col],
                             max_col - col, false, vcol);
    // if we failed to emit a char, we still need to advance
    cells = MAX(cells, 1);

    for (int c = 0; c < cells; c++) {
      linebuf_attr[col++] = attr;
    }
    vcol += cells;
  }
  return col;
}

/// Return true if CursorLineSign highlight is to be used.
static bool use_cursor_line_sign(win_T *wp, linenr_T lnum)
{
  return wp->w_p_cul
         && lnum == wp->w_cursor.lnum
         && (wp->w_p_culopt_flags & CULOPT_NBR);
}

// Get information needed to display the sign in line 'lnum' in window 'wp'.
// If 'nrcol' is true, the sign is going to be displayed in the number column.
// Otherwise the sign is going to be displayed in the sign column.
//
// @param count max number of signs
// @param[out] n_extrap number of characters from pp_extra to display
// @param sign_idxp Index of the displayed sign
static void get_sign_display_info(bool nrcol, win_T *wp, linenr_T lnum, SignTextAttrs sattrs[],
                                  int row, int startrow, int filler_lines, int filler_todo,
                                  int *c_extrap, int *c_finalp, char_u *extra, size_t extra_size,
                                  char_u **pp_extra, int *n_extrap, int *char_attrp, int sign_idx,
                                  int cul_attr)
{
  // Draw cells with the sign value or blank.
  *c_extrap = ' ';
  *c_finalp = NUL;
  if (nrcol) {
    *n_extrap = number_width(wp) + 1;
  } else {
    if (use_cursor_line_sign(wp, lnum)) {
      *char_attrp = win_hl_attr(wp, HLF_CLS);
    } else {
      *char_attrp = win_hl_attr(wp, HLF_SC);
    }
    *n_extrap = win_signcol_width(wp);
  }

  if (row == startrow + filler_lines && filler_todo <= 0) {
    SignTextAttrs *sattr = sign_get_attr(sign_idx, sattrs, wp->w_scwidth);
    if (sattr != NULL) {
      *pp_extra = (char_u *)sattr->text;
      if (*pp_extra != NULL) {
        *c_extrap = NUL;
        *c_finalp = NUL;

        if (nrcol) {
          int n, width = number_width(wp) - 2;
          for (n = 0; n < width; n++) {
            extra[n] = ' ';
          }
          extra[n] = NUL;
          STRCAT(extra, *pp_extra);
          STRCAT(extra, " ");
          *pp_extra = extra;
          *n_extrap = (int)STRLEN(*pp_extra);
        } else {
          size_t symbol_blen = STRLEN(*pp_extra);

          // TODO(oni-link): Is sign text already extended to
          // full cell width?
          assert((size_t)win_signcol_width(wp) >= mb_string2cells((char *)(*pp_extra)));
          // symbol(s) bytes + (filling spaces) (one byte each)
          *n_extrap = (int)symbol_blen + win_signcol_width(wp) -
                      (int)mb_string2cells((char *)(*pp_extra));

          assert(extra_size > symbol_blen);
          memset(extra, ' ', extra_size);
          memcpy(extra, *pp_extra, symbol_blen);

          *pp_extra = extra;
          (*pp_extra)[*n_extrap] = NUL;
        }
      }

      if (use_cursor_line_sign(wp, lnum) && cul_attr > 0) {
        *char_attrp = cul_attr;
      } else {
        *char_attrp = sattr->hl_attr_id;
      }
    }
  }
}

static int get_sign_attrs(buf_T *buf, linenr_T lnum, SignTextAttrs *sattrs, int *line_attr,
                          int *num_attr, int *cul_attr)
{
  HlPriAttr line_attrs = { *line_attr, 0 };
  HlPriAttr num_attrs  = { *num_attr,  0 };
  HlPriAttr cul_attrs  = { *cul_attr,  0 };

  // TODO(bfredl, vigoux): line_attr should not take priority over decoration!
  int num_signs = buf_get_signattrs(buf, lnum, sattrs, &num_attrs, &line_attrs, &cul_attrs);
  decor_redraw_signs(buf, lnum - 1, &num_signs, sattrs, &num_attrs, &line_attrs, &cul_attrs);

  *line_attr = line_attrs.attr_id;
  *num_attr = num_attrs.attr_id;
  *cul_attr = cul_attrs.attr_id;

  return num_signs;
}

/// Return true if CursorLineNr highlight is to be used for the number column.
///
/// - 'cursorline' must be set
/// - lnum must be the cursor line
/// - 'cursorlineopt' has "number"
/// - don't highlight filler lines (when in diff mode)
/// - When line is wrapped and 'cursorlineopt' does not have "line", only highlight the line number
///   itself on the first screenline of the wrapped line, otherwise highlight the number column of
///   all screenlines of the wrapped line.
static bool use_cursor_line_nr(win_T *wp, linenr_T lnum, int row, int startrow, int filler_lines)
{
  return wp->w_p_cul
         && lnum == wp->w_cursor.lnum
         && (wp->w_p_culopt_flags & CULOPT_NBR)
         && (row == startrow + filler_lines
             || (row > startrow + filler_lines
                 && (wp->w_p_culopt_flags & CULOPT_LINE)));
}

static inline void get_line_number_str(win_T *wp, linenr_T lnum, char_u *buf, size_t buf_len)
{
  long num;
  char *fmt = "%*ld ";

  if (wp->w_p_nu && !wp->w_p_rnu) {
    // 'number' + 'norelativenumber'
    num = (long)lnum;
  } else {
    // 'relativenumber', don't use negative numbers
    num = labs((long)get_cursor_rel_lnum(wp, lnum));
    if (num == 0 && wp->w_p_nu && wp->w_p_rnu) {
      // 'number' + 'relativenumber'
      num = lnum;
      fmt = "%-*ld ";
    }
  }

  snprintf((char *)buf, buf_len, fmt, number_width(wp), num);
}

static int get_line_number_attr(win_T *wp, linenr_T lnum, int row, int startrow, int filler_lines)
{
  if (wp->w_p_rnu) {
    if (lnum < wp->w_cursor.lnum) {
      // Use LineNrAbove
      return win_hl_attr(wp, HLF_LNA);
    }
    if (lnum > wp->w_cursor.lnum) {
      // Use LineNrBelow
      return win_hl_attr(wp, HLF_LNB);
    }
  }

  if (use_cursor_line_nr(wp, lnum, row, startrow, filler_lines)) {
    // TODO(vim): Can we use CursorLine instead of CursorLineNr
    // when CursorLineNr isn't set?
    return win_hl_attr(wp, HLF_CLN);
  }

  return win_hl_attr(wp, HLF_N);
}

static void apply_cursorline_highlight(win_T *wp, linenr_T lnum, int *line_attr, int *cul_attr,
                                       int *line_attr_lowprio)
{
  *cul_attr = win_hl_attr(wp, HLF_CUL);
  HlAttrs ae = syn_attr2entry(*cul_attr);
  // We make a compromise here (#7383):
  //  * low-priority CursorLine if fg is not set
  //  * high-priority ("same as Vim" priority) CursorLine if fg is set
  if (ae.rgb_fg_color == -1 && ae.cterm_fg_color == 0) {
    *line_attr_lowprio = *cul_attr;
  } else {
    if (!(State & MODE_INSERT) && bt_quickfix(wp->w_buffer)
        && qf_current_entry(wp) == lnum) {
      *line_attr = hl_combine_attr(*cul_attr, *line_attr);
    } else {
      *line_attr = *cul_attr;
    }
  }
}

static bool check_mb_utf8(int *c, int *u8cc)
{
  if (utf_char2len(*c) > 1) {
    *u8cc = 0;
    *c = 0xc0;
    return true;
  }
  return false;
}

/// Display line "lnum" of window 'wp' on the screen.
/// wp->w_virtcol needs to be valid.
///
/// @param lnum         line to display
/// @param startrow     first row relative to window grid
/// @param endrow       last grid row to be redrawn
/// @param nochange     not updating for changed text
/// @param number_only  only update the number column
/// @param foldinfo     fold info for this line
/// @param[in, out] providers  decoration providers active this line
///                            items will be disables if they cause errors
///                            or explicitly return `false`.
///
/// @return             the number of last row the line occupies.
int win_line(win_T *wp, linenr_T lnum, int startrow, int endrow, bool nochange, bool number_only,
             foldinfo_T foldinfo, DecorProviders *providers, char **provider_err)
{
  int c = 0;                          // init for GCC
  long vcol = 0;                      // virtual column (for tabs)
  long vcol_sbr = -1;                 // virtual column after showbreak
  long vcol_prev = -1;                // "vcol" of previous character
  char_u *line;                  // current line
  char_u *ptr;                   // current position in "line"
  int row;                            // row in the window, excl w_winrow
  ScreenGrid *grid = &wp->w_grid;     // grid specific to the window

  char_u extra[57];                   // sign, line number and 'fdc' must
                                      // fit in here
  int n_extra = 0;                    // number of extra chars
  char_u *p_extra = NULL;        // string of extra chars, plus NUL
  char_u *p_extra_free = NULL;   // p_extra needs to be freed
  int c_extra = NUL;                  // extra chars, all the same
  int c_final = NUL;                  // final char, mandatory if set
  int extra_attr = 0;                 // attributes when n_extra != 0
  static char_u *at_end_str = (char_u *)"";  // used for p_extra when displaying
                                             // curwin->w_p_lcs_chars.eol at
                                             // end-of-line
  int lcs_eol_one = wp->w_p_lcs_chars.eol;     // 'eol'  until it's been used
  int lcs_prec_todo = wp->w_p_lcs_chars.prec;  // 'prec' until it's been used
  bool has_fold = foldinfo.fi_level != 0 && foldinfo.fi_lines > 0;

  // saved "extra" items for when draw_state becomes WL_LINE (again)
  int saved_n_extra = 0;
  char_u *saved_p_extra = NULL;
  int saved_c_extra = 0;
  int saved_c_final = 0;
  int saved_char_attr = 0;

  int n_attr = 0;                       // chars with special attr
  int saved_attr2 = 0;                  // char_attr saved for n_attr
  int n_attr3 = 0;                      // chars with overruling special attr
  int saved_attr3 = 0;                  // char_attr saved for n_attr3

  int n_skip = 0;                       // nr of chars to skip for 'nowrap'

  int fromcol = -10;                    // start of inverting
  int tocol = MAXCOL;                   // end of inverting
  int fromcol_prev = -2;                // start of inverting after cursor
  bool noinvcur = false;                // don't invert the cursor
  bool lnum_in_visual_area = false;
  pos_T pos;
  long v;

  int char_attr = 0;                    // attributes for next character
  bool attr_pri = false;                // char_attr has priority
  bool area_highlighting = false;       // Visual or incsearch highlighting in this line
  int attr = 0;                         // attributes for area highlighting
  int area_attr = 0;                    // attributes desired by highlighting
  int search_attr = 0;                  // attributes desired by 'hlsearch'
  int vcol_save_attr = 0;               // saved attr for 'cursorcolumn'
  int syntax_attr = 0;                  // attributes desired by syntax
  bool has_syntax = false;              // this buffer has syntax highl.
  int save_did_emsg;
  int eol_hl_off = 0;                   // 1 if highlighted char after EOL
  bool draw_color_col = false;          // highlight colorcolumn
  int *color_cols = NULL;               // pointer to according columns array
  bool has_spell = false;               // this buffer has spell checking
#define SPWORDLEN 150
  char_u nextline[SPWORDLEN * 2];       // text with start of the next line
  int nextlinecol = 0;                  // column where nextline[] starts
  int nextline_idx = 0;                 // index in nextline[] where next line
                                        // starts
  int spell_attr = 0;                   // attributes desired by spelling
  int word_end = 0;                     // last byte with same spell_attr
  static linenr_T checked_lnum = 0;     // line number for "checked_col"
  static int checked_col = 0;           // column in "checked_lnum" up to which
                                        // there are no spell errors
  static int cap_col = -1;              // column to check for Cap word
  static linenr_T capcol_lnum = 0;      // line number where "cap_col"
  int cur_checked_col = 0;              // checked column for current line
  int extra_check = 0;                  // has syntax or linebreak
  int multi_attr = 0;                   // attributes desired by multibyte
  int mb_l = 1;                         // multi-byte byte length
  int mb_c = 0;                         // decoded multi-byte character
  bool mb_utf8 = false;                 // screen char is UTF-8 char
  int u8cc[MAX_MCO];                    // composing UTF-8 chars
  int filler_lines;                     // nr of filler lines to be drawn
  int filler_todo;                      // nr of filler lines still to do + 1
  hlf_T diff_hlf = (hlf_T)0;            // type of diff highlighting
  int change_start = MAXCOL;            // first col of changed area
  int change_end = -1;                  // last col of changed area
  colnr_T trailcol = MAXCOL;            // start of trailing spaces
  colnr_T leadcol = 0;                  // start of leading spaces
  bool in_multispace = false;           // in multiple consecutive spaces
  int multispace_pos = 0;               // position in lcs-multispace string
  bool need_showbreak = false;          // overlong line, skip first x chars
  int line_attr = 0;                    // attribute for the whole line
  int line_attr_save;
  int line_attr_lowprio = 0;            // low-priority attribute for the line
  int line_attr_lowprio_save;
  int prev_c = 0;                       // previous Arabic character
  int prev_c1 = 0;                      // first composing char for prev_c

  bool search_attr_from_match = false;  // if search_attr is from :match
  bool has_decor = false;               // this buffer has decoration
  int win_col_offset = 0;               // offset for window columns

  char_u buf_fold[FOLD_TEXT_LEN];       // Hold value returned by get_foldtext

  bool area_active = false;

  int cul_attr = 0;                     // set when 'cursorline' active
  // 'cursorlineopt' has "screenline" and cursor is in this line
  bool cul_screenline = false;
  // margin columns for the screen line, needed for when 'cursorlineopt'
  // contains "screenline"
  int left_curline_col = 0;
  int right_curline_col = 0;

  // draw_state: items that are drawn in sequence:
#define WL_START        0               // nothing done yet
#define WL_CMDLINE      (WL_START + 1)    // cmdline window column
#define WL_FOLD         (WL_CMDLINE + 1)  // 'foldcolumn'
#define WL_SIGN         (WL_FOLD + 1)     // column for signs
#define WL_NR           (WL_SIGN + 1)     // line number
#define WL_BRI          (WL_NR + 1)       // 'breakindent'
#define WL_SBR          (WL_BRI + 1)      // 'showbreak' or 'diff'
#define WL_LINE         (WL_SBR + 1)      // text in the line
  int draw_state = WL_START;            // what to draw next

  int syntax_flags    = 0;
  int syntax_seqnr    = 0;
  int prev_syntax_id  = 0;
  int conceal_attr    = win_hl_attr(wp, HLF_CONCEAL);
  bool is_concealing  = false;
  int boguscols       = 0;              ///< nonexistent columns added to
                                        ///< force wrapping
  int vcol_off        = 0;              ///< offset for concealed characters
  int did_wcol        = false;
  int match_conc      = 0;              ///< cchar for match functions
  int old_boguscols = 0;
#define VCOL_HLC (vcol - vcol_off)
#define FIX_FOR_BOGUSCOLS \
  { \
    n_extra += vcol_off; \
    vcol -= vcol_off; \
    vcol_off = 0; \
    col -= boguscols; \
    old_boguscols = boguscols; \
    boguscols = 0; \
  }

  if (startrow > endrow) {              // past the end already!
    return startrow;
  }

  row = startrow;

  buf_T *buf = wp->w_buffer;
  bool end_fill = (lnum == buf->b_ml.ml_line_count + 1);

  if (!number_only) {
    // To speed up the loop below, set extra_check when there is linebreak,
    // trailing white space and/or syntax processing to be done.
    extra_check = wp->w_p_lbr;
    if (syntax_present(wp) && !wp->w_s->b_syn_error && !wp->w_s->b_syn_slow
        && !has_fold && !end_fill) {
      // Prepare for syntax highlighting in this line.  When there is an
      // error, stop syntax highlighting.
      save_did_emsg = did_emsg;
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

    has_decor = decor_redraw_line(buf, lnum - 1, &decor_state);

    decor_providers_invoke_line(wp, providers, lnum - 1, &has_decor, provider_err);

    if (*provider_err) {
      provider_err_virt_text(lnum, *provider_err);
      has_decor = true;
      *provider_err = NULL;
    }

    if (has_decor) {
      extra_check = true;
    }

    // Check for columns to display for 'colorcolumn'.
    color_cols = wp->w_buffer->terminal ? NULL : wp->w_p_cc_cols;
    if (color_cols != NULL) {
      draw_color_col = advance_color_col((int)VCOL_HLC, &color_cols);
    }

    if (wp->w_p_spell
        && !has_fold
        && !end_fill
        && *wp->w_s->b_p_spl != NUL
        && !GA_EMPTY(&wp->w_s->b_langp)
        && *(char **)(wp->w_s->b_langp.ga_data) != NULL) {
      // Prepare for spell checking.
      has_spell = true;
      extra_check = true;

      // Get the start of the next line, so that words that wrap to the next
      // line are found too: "et<line-break>al.".
      // Trick: skip a few chars for C/shell/Vim comments
      nextline[SPWORDLEN] = NUL;
      if (lnum < wp->w_buffer->b_ml.ml_line_count) {
        line = (char_u *)ml_get_buf(wp->w_buffer, lnum + 1, false);
        spell_cat_line(nextline + SPWORDLEN, line, SPWORDLEN);
      }

      // When a word wrapped from the previous line the start of the current
      // line is valid.
      if (lnum == checked_lnum) {
        cur_checked_col = checked_col;
      }
      checked_lnum = 0;

      // When there was a sentence end in the previous line may require a
      // word starting with capital in this line.  In line 1 always check
      // the first word.
      if (lnum != capcol_lnum) {
        cap_col = -1;
      }
      if (lnum == 1) {
        cap_col = 0;
      }
      capcol_lnum = 0;
    }

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
          fromcol = wp->w_old_cursor_fcol;
          tocol = wp->w_old_cursor_lcol;
        }
      } else {
        // non-block mode
        if (lnum > top->lnum && lnum <= bot->lnum) {
          fromcol = 0;
        } else if (lnum == top->lnum) {
          if (VIsual_mode == 'V') {       // linewise
            fromcol = 0;
          } else {
            getvvcol(wp, top, (colnr_T *)&fromcol, NULL, NULL);
            if (gchar_pos(top) == NUL) {
              tocol = fromcol + 1;
            }
          }
        }
        if (VIsual_mode != 'V' && lnum == bot->lnum) {
          if (*p_sel == 'e' && bot->col == 0
              && bot->coladd == 0) {
            fromcol = -10;
            tocol = MAXCOL;
          } else if (bot->col == MAXCOL) {
            tocol = MAXCOL;
          } else {
            pos = *bot;
            if (*p_sel == 'e') {
              getvvcol(wp, &pos, (colnr_T *)&tocol, NULL, NULL);
            } else {
              getvvcol(wp, &pos, NULL, NULL, (colnr_T *)&tocol);
              tocol++;
            }
          }
        }
      }

      // Check if the char under the cursor should be inverted (highlighted).
      if (!highlight_match && lnum == curwin->w_cursor.lnum && wp == curwin
          && cursor_is_block_during_visual(*p_sel == 'e')) {
        noinvcur = true;
      }

      // if inverting in this line set area_highlighting
      if (fromcol >= 0) {
        area_highlighting = true;
        attr = win_hl_attr(wp, HLF_V);
      }
      // handle 'incsearch' and ":s///c" highlighting
    } else if (highlight_match
               && wp == curwin
               && !has_fold
               && lnum >= curwin->w_cursor.lnum
               && lnum <= curwin->w_cursor.lnum + search_match_lines) {
      if (lnum == curwin->w_cursor.lnum) {
        getvcol(curwin, &(curwin->w_cursor),
                (colnr_T *)&fromcol, NULL, NULL);
      } else {
        fromcol = 0;
      }
      if (lnum == curwin->w_cursor.lnum + search_match_lines) {
        pos.lnum = lnum;
        pos.col = search_match_endcol;
        getvcol(curwin, &pos, (colnr_T *)&tocol, NULL, NULL);
      }
      // do at least one character; happens when past end of line
      if (fromcol == tocol && search_match_endcol) {
        tocol = fromcol + 1;
      }
      area_highlighting = true;
      attr = win_hl_attr(wp, HLF_I);
    }
  }

  int bg_attr = win_bg_attr(wp);

  filler_lines = diff_check(wp, lnum);
  if (filler_lines < 0) {
    if (filler_lines == -1) {
      if (diff_find_change(wp, lnum, &change_start, &change_end)) {
        diff_hlf = HLF_ADD;             // added line
      } else if (change_start == 0) {
        diff_hlf = HLF_TXD;             // changed text
      } else {
        diff_hlf = HLF_CHD;             // changed line
      }
    } else {
      diff_hlf = HLF_ADD;               // added line
    }
    filler_lines = 0;
    area_highlighting = true;
  }
  VirtLines virt_lines = KV_INITIAL_VALUE;
  int n_virt_lines = decor_virt_lines(wp, lnum, &virt_lines);
  filler_lines += n_virt_lines;
  if (lnum == wp->w_topline) {
    filler_lines = wp->w_topfill;
    n_virt_lines = MIN(n_virt_lines, filler_lines);
  }
  filler_todo = filler_lines;

  // Cursor line highlighting for 'cursorline' in the current window.
  if (lnum == wp->w_cursor.lnum) {
    // Do not show the cursor line in the text when Visual mode is active,
    // because it's not clear what is selected then.
    if (wp->w_p_cul && !(wp == curwin && VIsual_active)
        && wp->w_p_culopt_flags != CULOPT_NBR) {
      cul_screenline = (wp->w_p_wrap
                        && (wp->w_p_culopt_flags & CULOPT_SCRLINE));
      if (!cul_screenline) {
        apply_cursorline_highlight(wp, lnum, &line_attr, &cul_attr, &line_attr_lowprio);
      } else {
        margin_columns_win(wp, &left_curline_col, &right_curline_col);
      }
      area_highlighting = true;
    }
  }

  SignTextAttrs sattrs[SIGN_SHOW_MAX];  // sign attributes for the sign column
  int sign_num_attr = 0;                // sign attribute for the number column
  int sign_cul_attr = 0;                // sign attribute for cursorline
  CLEAR_FIELD(sattrs);
  int num_signs = get_sign_attrs(buf, lnum, sattrs, &line_attr, &sign_num_attr, &sign_cul_attr);

  // Highlight the current line in the quickfix window.
  if (bt_quickfix(wp->w_buffer) && qf_current_entry(wp) == lnum) {
    line_attr = win_hl_attr(wp, HLF_QFL);
  }

  if (line_attr_lowprio || line_attr) {
    area_highlighting = true;
  }

  if (cul_screenline) {
    line_attr_save = line_attr;
    line_attr_lowprio_save = line_attr_lowprio;
  }

  line = end_fill ? (char_u *)"" : (char_u *)ml_get_buf(wp->w_buffer, lnum, false);
  ptr = line;

  if (has_spell && !number_only) {
    // For checking first word with a capital skip white space.
    if (cap_col == 0) {
      cap_col = (int)getwhitecols((char *)line);
    }

    // To be able to spell-check over line boundaries copy the end of the
    // current line into nextline[].  Above the start of the next line was
    // copied to nextline[SPWORDLEN].
    if (nextline[SPWORDLEN] == NUL) {
      // No next line or it is empty.
      nextlinecol = MAXCOL;
      nextline_idx = 0;
    } else {
      v = (long)STRLEN(line);
      if (v < SPWORDLEN) {
        // Short line, use it completely and append the start of the
        // next line.
        nextlinecol = 0;
        memmove(nextline, line, (size_t)v);
        STRMOVE(nextline + v, nextline + SPWORDLEN);
        nextline_idx = (int)v + 1;
      } else {
        // Long line, use only the last SPWORDLEN bytes.
        nextlinecol = (int)v - SPWORDLEN;
        memmove(nextline, line + nextlinecol, SPWORDLEN);  // -V512
        nextline_idx = SPWORDLEN + 1;
      }
    }
  }

  if (wp->w_p_list && !has_fold && !end_fill) {
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
      trailcol = (colnr_T)STRLEN(ptr);
      while (trailcol > (colnr_T)0 && ascii_iswhite(ptr[trailcol - 1])) {
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
        leadcol = (colnr_T)0;
      } else {
        // keep track of the first column not filled with spaces
        leadcol += (colnr_T)(ptr - line) + 1;
      }
    }
  }

  // 'nowrap' or 'wrap' and a single line that doesn't fit: Advance to the
  // first character to be displayed.
  if (wp->w_p_wrap) {
    v = wp->w_skipcol;
  } else {
    v = wp->w_leftcol;
  }
  if (v > 0 && !number_only) {
    char_u *prev_ptr = ptr;
    chartabsize_T cts;
    int charsize;

    init_chartabsize_arg(&cts, wp, lnum, (colnr_T)vcol, (char *)line, (char *)ptr);
    while (cts.cts_vcol < v && *cts.cts_ptr != NUL) {
      charsize = win_lbr_chartabsize(&cts, NULL);
      cts.cts_vcol += charsize;
      prev_ptr = (char_u *)cts.cts_ptr;
      MB_PTR_ADV(cts.cts_ptr);
    }
    vcol = cts.cts_vcol;
    ptr = (char_u *)cts.cts_ptr;
    clear_chartabsize_arg(&cts);

    // When:
    // - 'cuc' is set, or
    // - 'colorcolumn' is set, or
    // - 'virtualedit' is set, or
    // - the visual mode is active,
    // the end of the line may be before the start of the displayed part.
    if (vcol < v && (wp->w_p_cuc
                     || draw_color_col
                     || virtual_active()
                     || (VIsual_active && wp->w_buffer == curwin->w_buffer))) {
      vcol = v;
    }

    // Handle a character that's not completely on the screen: Put ptr at
    // that character but skip the first few screen characters.
    if (vcol > v) {
      vcol -= charsize;
      ptr = prev_ptr;
      // If the character fits on the screen, don't need to skip it.
      // Except for a TAB.
      if (utf_ptr2cells((char *)ptr) >= charsize || *ptr == TAB) {
        n_skip = (int)(v - vcol);
      }
    }

    // Adjust for when the inverted text is before the screen,
    // and when the start of the inverted text is before the screen.
    if (tocol <= vcol) {
      fromcol = 0;
    } else if (fromcol >= 0 && fromcol < vcol) {
      fromcol = (int)vcol;
    }

    // When w_skipcol is non-zero, first line needs 'showbreak'
    if (wp->w_p_wrap) {
      need_showbreak = true;
    }
    // When spell checking a word we need to figure out the start of the
    // word and if it's badly spelled or not.
    if (has_spell) {
      size_t len;
      colnr_T linecol = (colnr_T)(ptr - line);
      hlf_T spell_hlf = HLF_COUNT;

      pos = wp->w_cursor;
      wp->w_cursor.lnum = lnum;
      wp->w_cursor.col = linecol;
      len = spell_move_to(wp, FORWARD, true, true, &spell_hlf);

      // spell_move_to() may call ml_get() and make "line" invalid
      line = (char_u *)ml_get_buf(wp->w_buffer, lnum, false);
      ptr = line + linecol;

      if (len == 0 || (int)wp->w_cursor.col > ptr - line) {
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
  if (fromcol >= 0) {
    if (noinvcur) {
      if ((colnr_T)fromcol == wp->w_virtcol) {
        // highlighting starts at cursor, let it start just after the
        // cursor
        fromcol_prev = fromcol;
        fromcol = -1;
      } else if ((colnr_T)fromcol < wp->w_virtcol) {
        // restart highlighting after the cursor
        fromcol_prev = wp->w_virtcol;
      }
    }
    if (fromcol >= tocol) {
      fromcol = -1;
    }
  }

  if (!number_only && !has_fold && !end_fill) {
    v = ptr - line;
    area_highlighting |= prepare_search_hl_line(wp, lnum, (colnr_T)v,
                                                &line, &screen_search_hl, &search_attr,
                                                &search_attr_from_match);
    ptr = line + v;  // "line" may have been updated
  }

  int off = 0;  // Offset relative start of line
  int col = 0;  // Visual column on screen.
  if (wp->w_p_rl) {
    // Rightleft window: process the text in the normal direction, but put
    // it in linebuf_char[off] from right to left.  Start at the
    // rightmost column of the window.
    col = grid->cols - 1;
    off += col;
  }

  // won't highlight after TERM_ATTRS_MAX columns
  int term_attrs[TERM_ATTRS_MAX] = { 0 };
  if (wp->w_buffer->terminal) {
    terminal_get_line_attributes(wp->w_buffer->terminal, wp, lnum, term_attrs);
    extra_check = true;
  }

  int sign_idx = 0;
  // Repeat for the whole displayed line.
  for (;;) {
    int has_match_conc = 0;  ///< match wants to conceal
    int decor_conceal = 0;

    bool did_decrement_ptr = false;

    // Skip this quickly when working on the text.
    if (draw_state != WL_LINE) {
      if (cul_screenline) {
        cul_attr = 0;
        line_attr = line_attr_save;
        line_attr_lowprio = line_attr_lowprio_save;
      }

      if (draw_state == WL_CMDLINE - 1 && n_extra == 0) {
        draw_state = WL_CMDLINE;
        if (cmdwin_type != 0 && wp == curwin) {
          // Draw the cmdline character.
          n_extra = 1;
          c_extra = cmdwin_type;
          c_final = NUL;
          char_attr = win_hl_attr(wp, HLF_AT);
        }
      }

      if (draw_state == WL_FOLD - 1 && n_extra == 0) {
        int fdc = compute_foldcolumn(wp, 0);

        draw_state = WL_FOLD;
        if (fdc > 0) {
          // Draw the 'foldcolumn'.  Allocate a buffer, "extra" may
          // already be in use.
          xfree(p_extra_free);
          p_extra_free = xmalloc(MAX_MCO * (size_t)fdc + 1);
          n_extra = (int)fill_foldcolumn(p_extra_free, wp, foldinfo, lnum);
          p_extra_free[n_extra] = NUL;
          p_extra = p_extra_free;
          c_extra = NUL;
          c_final = NUL;
          if (use_cursor_line_sign(wp, lnum)) {
            char_attr = win_hl_attr(wp, HLF_CLF);
          } else {
            char_attr = win_hl_attr(wp, HLF_FC);
          }
        }
      }

      // sign column, this is hit until sign_idx reaches count
      if (draw_state == WL_SIGN - 1 && n_extra == 0) {
        draw_state = WL_SIGN;
        // Show the sign column when there are any signs in this buffer
        if (wp->w_scwidth > 0) {
          get_sign_display_info(false, wp, lnum, sattrs, row,
                                startrow, filler_lines, filler_todo,
                                &c_extra, &c_final, extra, sizeof(extra),
                                &p_extra, &n_extra, &char_attr, sign_idx,
                                sign_cul_attr);
          sign_idx++;
          if (sign_idx < wp->w_scwidth) {
            draw_state = WL_SIGN - 1;
          } else {
            sign_idx = 0;
          }
        }
      }

      if (draw_state == WL_NR - 1 && n_extra == 0) {
        draw_state = WL_NR;
        // Display the absolute or relative line number. After the
        // first fill with blanks when the 'n' flag isn't in 'cpo'
        if ((wp->w_p_nu || wp->w_p_rnu)
            && (row == startrow + filler_lines
                || vim_strchr(p_cpo, CPO_NUMCOL) == NULL)) {
          // If 'signcolumn' is set to 'number' and a sign is present
          // in 'lnum', then display the sign instead of the line
          // number.
          if (*wp->w_p_scl == 'n' && *(wp->w_p_scl + 1) == 'u' && num_signs > 0) {
            get_sign_display_info(true, wp, lnum, sattrs, row,
                                  startrow, filler_lines, filler_todo,
                                  &c_extra, &c_final, extra, sizeof(extra),
                                  &p_extra, &n_extra, &char_attr, sign_idx,
                                  sign_cul_attr);
          } else {
            // Draw the line number (empty space after wrapping).
            if (row == startrow + filler_lines) {
              get_line_number_str(wp, lnum, (char_u *)extra, sizeof(extra));
              if (wp->w_skipcol > 0) {
                for (p_extra = extra; *p_extra == ' '; p_extra++) {
                  *p_extra = '-';
                }
              }
              if (wp->w_p_rl) {                       // reverse line numbers
                // like rl_mirror(), but keep the space at the end
                char_u *p2 = (char_u *)skipwhite((char *)extra);
                p2 = (char_u *)skiptowhite((char *)p2) - 1;
                for (char_u *p1 = (char_u *)skipwhite((char *)extra); p1 < p2; p1++, p2--) {
                  const char_u t = *p1;
                  *p1 = *p2;
                  *p2 = t;
                }
              }
              p_extra = extra;
              c_extra = NUL;
            } else {
              c_extra = ' ';
            }
            c_final = NUL;
            n_extra = number_width(wp) + 1;
            if (sign_num_attr > 0) {
              char_attr = sign_num_attr;
            } else {
              char_attr = get_line_number_attr(wp, lnum, row, startrow, filler_lines);
            }
          }
        }
      }

      if (draw_state == WL_NR && n_extra == 0) {
        win_col_offset = off;
      }

      if (wp->w_briopt_sbr && draw_state == WL_BRI - 1
          && n_extra == 0 && *get_showbreak_value(wp) != NUL) {
        // draw indent after showbreak value
        draw_state = WL_BRI;
      } else if (wp->w_briopt_sbr && draw_state == WL_SBR && n_extra == 0) {
        // after the showbreak, draw the breakindent
        draw_state = WL_BRI - 1;
      }

      // draw 'breakindent': indent wrapped text accordingly
      if (draw_state == WL_BRI - 1 && n_extra == 0) {
        draw_state = WL_BRI;
        // if need_showbreak is set, breakindent also applies
        if (wp->w_p_bri && (row != startrow || need_showbreak)
            && filler_lines == 0) {
          char_attr = 0;

          if (diff_hlf != (hlf_T)0) {
            char_attr = win_hl_attr(wp, (int)diff_hlf);
          }
          p_extra = NULL;
          c_extra = ' ';
          c_final = NUL;
          n_extra =
            get_breakindent_win(wp, (char_u *)ml_get_buf(wp->w_buffer, lnum, false));
          if (row == startrow) {
            n_extra -= win_col_off2(wp);
            if (n_extra < 0) {
              n_extra = 0;
            }
          }
          if (wp->w_skipcol > 0 && wp->w_p_wrap && wp->w_briopt_sbr) {
            need_showbreak = false;
          }
          // Correct end of highlighted area for 'breakindent',
          // required wen 'linebreak' is also set.
          if (tocol == vcol) {
            tocol += n_extra;
          }
        }
      }

      if (draw_state == WL_SBR - 1 && n_extra == 0) {
        draw_state = WL_SBR;
        if (filler_todo > filler_lines - n_virt_lines) {
          // TODO(bfredl): check this doesn't inhibit TUI-style
          //               clear-to-end-of-line.
          c_extra = ' ';
          c_final = NUL;
          if (wp->w_p_rl) {
            n_extra = col + 1;
          } else {
            n_extra = grid->cols - col;
          }
          char_attr = 0;
        } else if (filler_todo > 0) {
          // Draw "deleted" diff line(s)
          if (char2cells(wp->w_p_fcs_chars.diff) > 1) {
            c_extra = '-';
            c_final = NUL;
          } else {
            c_extra = wp->w_p_fcs_chars.diff;
            c_final = NUL;
          }
          if (wp->w_p_rl) {
            n_extra = col + 1;
          } else {
            n_extra = grid->cols - col;
          }
          char_attr = win_hl_attr(wp, HLF_DED);
        }
        char_u *const sbr = get_showbreak_value(wp);
        if (*sbr != NUL && need_showbreak) {
          // Draw 'showbreak' at the start of each broken line.
          p_extra = sbr;
          c_extra = NUL;
          c_final = NUL;
          n_extra = (int)STRLEN(sbr);
          char_attr = win_hl_attr(wp, HLF_AT);
          if (wp->w_skipcol == 0 || !wp->w_p_wrap) {
            need_showbreak = false;
          }
          vcol_sbr = vcol + mb_charlen(sbr);
          // Correct end of highlighted area for 'showbreak',
          // required when 'linebreak' is also set.
          if (tocol == vcol) {
            tocol += n_extra;
          }
          // Combine 'showbreak' with 'cursorline', prioritizing 'showbreak'.
          if (cul_attr) {
            char_attr = hl_combine_attr(cul_attr, char_attr);
          }
        }
      }

      if (draw_state == WL_LINE - 1 && n_extra == 0) {
        sign_idx = 0;
        draw_state = WL_LINE;

        if (has_decor && row == startrow + filler_lines) {
          // hide virt_text on text hidden by 'nowrap'
          decor_redraw_col(wp->w_buffer, (int)vcol, off, true, &decor_state);
        }

        if (saved_n_extra) {
          // Continue item from end of wrapped line.
          n_extra = saved_n_extra;
          c_extra = saved_c_extra;
          c_final = saved_c_final;
          p_extra = saved_p_extra;
          char_attr = saved_char_attr;
        } else {
          char_attr = 0;
        }
      }
    }

    if (cul_screenline && draw_state == WL_LINE
        && vcol >= left_curline_col
        && vcol < right_curline_col) {
      apply_cursorline_highlight(wp, lnum, &line_attr, &cul_attr, &line_attr_lowprio);
    }

    // When still displaying '$' of change command, stop at cursor
    if (((dollar_vcol >= 0
          && wp == curwin
          && lnum == wp->w_cursor.lnum
          && vcol >= (long)wp->w_virtcol)
         || (number_only && draw_state > WL_NR))
        && filler_todo <= 0) {
      draw_virt_text(wp, buf, win_col_offset, &col, grid->cols, row);
      grid_put_linebuf(grid, row, 0, col, -grid->cols, wp->w_p_rl, wp, bg_attr, false);
      // Pretend we have finished updating the window.  Except when
      // 'cursorcolumn' is set.
      if (wp->w_p_cuc) {
        row = wp->w_cline_row + wp->w_cline_height;
      } else {
        row = grid->rows;
      }
      break;
    }

    if (draw_state == WL_LINE
        && has_fold
        && col == win_col_offset
        && n_extra == 0
        && row == startrow) {
      char_attr = win_hl_attr(wp, HLF_FL);

      linenr_T lnume = lnum + foldinfo.fi_lines - 1;
      memset(buf_fold, ' ', FOLD_TEXT_LEN);
      p_extra = (char_u *)get_foldtext(wp, lnum, lnume, foldinfo, (char *)buf_fold);
      n_extra = (int)STRLEN(p_extra);

      if (p_extra != buf_fold) {
        xfree(p_extra_free);
        p_extra_free = p_extra;
      }
      c_extra = NUL;
      c_final = NUL;
      p_extra[n_extra] = NUL;
    }

    if (draw_state == WL_LINE
        && has_fold
        && col < grid->cols
        && n_extra == 0
        && row == startrow) {
      // fill rest of line with 'fold'
      c_extra = wp->w_p_fcs_chars.fold;
      c_final = NUL;

      n_extra = wp->w_p_rl ? (col + 1) : (grid->cols - col);
    }

    if (draw_state == WL_LINE
        && has_fold
        && col >= grid->cols
        && n_extra != 0
        && row == startrow) {
      // Truncate the folding.
      n_extra = 0;
    }

    if (draw_state == WL_LINE && (area_highlighting || has_spell)) {
      // handle Visual or match highlighting in this line
      if (vcol == fromcol
          || (vcol + 1 == fromcol && n_extra == 0
              && utf_ptr2cells((char *)ptr) > 1)
          || ((int)vcol_prev == fromcol_prev
              && vcol_prev < vcol               // not at margin
              && vcol < tocol)) {
        area_attr = attr;                       // start highlighting
        if (area_highlighting) {
          area_active = true;
        }
      } else if (area_attr != 0 && (vcol == tocol
                                    || (noinvcur
                                        && (colnr_T)vcol == wp->w_virtcol))) {
        area_attr = 0;                          // stop highlighting
        area_active = false;
      }

      if (!n_extra) {
        // Check for start/end of 'hlsearch' and other matches.
        // After end, check for start/end of next match.
        // When another match, have to check for start again.
        v = (ptr - line);
        search_attr = update_search_hl(wp, lnum, (colnr_T)v, &line, &screen_search_hl,
                                       &has_match_conc,
                                       &match_conc, lcs_eol_one, &search_attr_from_match);
        ptr = line + v;  // "line" may have been changed

        // Do not allow a conceal over EOL otherwise EOL will be missed
        // and bad things happen.
        if (*ptr == NUL) {
          has_match_conc = 0;
        }
      }

      if (diff_hlf != (hlf_T)0) {
        if (diff_hlf == HLF_CHD && ptr - line >= change_start
            && n_extra == 0) {
          diff_hlf = HLF_TXD;                   // changed text
        }
        if (diff_hlf == HLF_TXD && ptr - line > change_end
            && n_extra == 0) {
          diff_hlf = HLF_CHD;                   // changed line
        }
        line_attr = win_hl_attr(wp, (int)diff_hlf);
        // Overlay CursorLine onto diff-mode highlight.
        if (cul_attr) {
          line_attr = 0 != line_attr_lowprio  // Low-priority CursorLine
            ? hl_combine_attr(hl_combine_attr(cul_attr, line_attr),
                              hl_get_underline())
            : hl_combine_attr(line_attr, cul_attr);
        }
      }

      // Decide which of the highlight attributes to use.
      attr_pri = true;

      if (area_attr != 0) {
        char_attr = hl_combine_attr(line_attr, area_attr);
        if (!highlight_match) {
          // let search highlight show in Visual area if possible
          char_attr = hl_combine_attr(search_attr, char_attr);
        }
      } else if (search_attr != 0) {
        char_attr = hl_combine_attr(line_attr, search_attr);
      } else if (line_attr != 0 && ((fromcol == -10 && tocol == MAXCOL)
                                    || vcol < fromcol || vcol_prev < fromcol_prev
                                    || vcol >= tocol)) {
        // Use line_attr when not in the Visual or 'incsearch' area
        // (area_attr may be 0 when "noinvcur" is set).
        char_attr = line_attr;
      } else {
        attr_pri = false;
        if (has_syntax) {
          char_attr = syntax_attr;
        } else {
          char_attr = 0;
        }
      }
    }

    // Get the next character to put on the screen.
    //
    // The "p_extra" points to the extra stuff that is inserted to
    // represent special characters (non-printable stuff) and other
    // things.  When all characters are the same, c_extra is used.
    // If c_final is set, it will compulsorily be used at the end.
    // "p_extra" must end in a NUL to avoid utfc_ptr2len() reads past
    // "p_extra[n_extra]".
    // For the '$' of the 'list' option, n_extra == 1, p_extra == "".
    if (n_extra > 0) {
      if (c_extra != NUL || (n_extra == 1 && c_final != NUL)) {
        c = (n_extra == 1 && c_final != NUL) ? c_final : c_extra;
        mb_c = c;               // doesn't handle non-utf-8 multi-byte!
        mb_utf8 = check_mb_utf8(&c, u8cc);
      } else {
        assert(p_extra != NULL);
        c = *p_extra;
        mb_c = c;
        // If the UTF-8 character is more than one byte:
        // Decode it into "mb_c".
        mb_l = utfc_ptr2len((char *)p_extra);
        mb_utf8 = false;
        if (mb_l > n_extra) {
          mb_l = 1;
        } else if (mb_l > 1) {
          mb_c = utfc_ptr2char((char *)p_extra, u8cc);
          mb_utf8 = true;
          c = 0xc0;
        }
        if (mb_l == 0) {          // at the NUL at end-of-line
          mb_l = 1;
        }

        // If a double-width char doesn't fit display a '>' in the last column.
        if ((wp->w_p_rl ? (col <= 0) : (col >= grid->cols - 1))
            && utf_char2cells(mb_c) == 2) {
          c = '>';
          mb_c = c;
          mb_l = 1;
          (void)mb_l;
          multi_attr = win_hl_attr(wp, HLF_AT);

          if (cul_attr) {
            multi_attr = 0 != line_attr_lowprio
              ? hl_combine_attr(cul_attr, multi_attr)
              : hl_combine_attr(multi_attr, cul_attr);
          }

          // put the pointer back to output the double-width
          // character at the start of the next line.
          n_extra++;
          p_extra--;
        } else {
          n_extra -= mb_l - 1;
          p_extra += mb_l - 1;
        }
        p_extra++;
      }
      n_extra--;
    } else if (foldinfo.fi_lines > 0) {
      // skip writing the buffer line itself
      c = NUL;
      XFREE_CLEAR(p_extra_free);
    } else {
      int c0;

      XFREE_CLEAR(p_extra_free);

      // Get a character from the line itself.
      c0 = c = *ptr;
      mb_c = c;
      // If the UTF-8 character is more than one byte: Decode it
      // into "mb_c".
      mb_l = utfc_ptr2len((char *)ptr);
      mb_utf8 = false;
      if (mb_l > 1) {
        mb_c = utfc_ptr2char((char *)ptr, u8cc);
        // Overlong encoded ASCII or ASCII with composing char
        // is displayed normally, except a NUL.
        if (mb_c < 0x80) {
          c0 = c = mb_c;
        }
        mb_utf8 = true;

        // At start of the line we can have a composing char.
        // Draw it as a space with a composing char.
        if (utf_iscomposing(mb_c)) {
          int i;

          for (i = MAX_MCO - 1; i > 0; i--) {
            u8cc[i] = u8cc[i - 1];
          }
          u8cc[0] = mb_c;
          mb_c = ' ';
        }
      }

      if ((mb_l == 1 && c >= 0x80)
          || (mb_l >= 1 && mb_c == 0)
          || (mb_l > 1 && (!vim_isprintc(mb_c)))) {
        // Illegal UTF-8 byte: display as <xx>.
        // Non-BMP character : display as ? or fullwidth ?.
        transchar_hex((char *)extra, mb_c);
        if (wp->w_p_rl) {  // reverse
          rl_mirror(extra);
        }

        p_extra = extra;
        c = *p_extra;
        mb_c = mb_ptr2char_adv((const char_u **)&p_extra);
        mb_utf8 = (c >= 0x80);
        n_extra = (int)STRLEN(p_extra);
        c_extra = NUL;
        c_final = NUL;
        if (area_attr == 0 && search_attr == 0) {
          n_attr = n_extra + 1;
          extra_attr = win_hl_attr(wp, HLF_8);
          saved_attr2 = char_attr;               // save current attr
        }
      } else if (mb_l == 0) {        // at the NUL at end-of-line
        mb_l = 1;
      } else if (p_arshape && !p_tbidi && ARABIC_CHAR(mb_c)) {
        // Do Arabic shaping.
        int pc, pc1, nc;
        int pcc[MAX_MCO];

        // The idea of what is the previous and next
        // character depends on 'rightleft'.
        if (wp->w_p_rl) {
          pc = prev_c;
          pc1 = prev_c1;
          nc = utf_ptr2char((char *)ptr + mb_l);
          prev_c1 = u8cc[0];
        } else {
          pc = utfc_ptr2char((char *)ptr + mb_l, pcc);
          nc = prev_c;
          pc1 = pcc[0];
        }
        prev_c = mb_c;

        mb_c = arabic_shape(mb_c, &c, &u8cc[0], pc, pc1, nc);
      } else {
        prev_c = mb_c;
      }
      // If a double-width char doesn't fit display a '>' in the
      // last column; the character is displayed at the start of the
      // next line.
      if ((wp->w_p_rl ? (col <= 0) :
           (col >= grid->cols - 1))
          && utf_char2cells(mb_c) == 2) {
        c = '>';
        mb_c = c;
        mb_utf8 = false;
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
      if (n_skip > 0 && mb_l > 1 && n_extra == 0) {
        n_extra = 1;
        c_extra = MB_FILLER_CHAR;
        c_final = NUL;
        c = ' ';
        if (area_attr == 0 && search_attr == 0) {
          n_attr = n_extra + 1;
          extra_attr = win_hl_attr(wp, HLF_AT);
          saved_attr2 = char_attr;             // save current attr
        }
        mb_c = c;
        mb_utf8 = false;
        mb_l = 1;
      }
      ptr++;

      if (extra_check) {
        bool no_plain_buffer = (wp->w_s->b_p_spo_flags & SPO_NPBUFFER) != 0;
        bool can_spell = !no_plain_buffer;

        // Get syntax attribute, unless still at the start of the line
        // (double-wide char that doesn't fit).
        v = (ptr - line);
        if (has_syntax && v > 0) {
          // Get the syntax attribute for the character.  If there
          // is an error, disable syntax highlighting.
          save_did_emsg = did_emsg;
          did_emsg = false;

          syntax_attr = get_syntax_attr((colnr_T)v - 1,
                                        has_spell ? &can_spell : NULL, false);

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
          line = (char_u *)ml_get_buf(wp->w_buffer, lnum, false);
          ptr = line + v;

          if (!attr_pri) {
            if (cul_attr) {
              char_attr = 0 != line_attr_lowprio
                ? hl_combine_attr(cul_attr, syntax_attr)
                : hl_combine_attr(syntax_attr, cul_attr);
            } else {
              char_attr = syntax_attr;
            }
          } else {
            char_attr = hl_combine_attr(syntax_attr, char_attr);
          }
          // no concealing past the end of the line, it interferes
          // with line highlighting.
          if (c == NUL) {
            syntax_flags = 0;
          } else {
            syntax_flags = get_syntax_info(&syntax_seqnr);
          }
        } else if (!attr_pri) {
          char_attr = 0;
        }

        if (has_decor && v > 0) {
          bool selected = (area_active || (area_highlighting && noinvcur
                                           && (colnr_T)vcol == wp->w_virtcol));
          int extmark_attr = decor_redraw_col(wp->w_buffer, (colnr_T)v - 1, off,
                                              selected, &decor_state);
          if (extmark_attr != 0) {
            if (!attr_pri) {
              char_attr = hl_combine_attr(char_attr, extmark_attr);
            } else {
              char_attr = hl_combine_attr(extmark_attr, char_attr);
            }
          }

          decor_conceal = decor_state.conceal;
          if (decor_conceal && decor_state.conceal_char) {
            decor_conceal = 2;  // really??
          }

          if (decor_state.spell) {
            can_spell = true;
          }
        }

        // Check spelling (unless at the end of the line).
        // Only do this when there is no syntax highlighting, the
        // @Spell cluster is not used or the current syntax item
        // contains the @Spell cluster.
        v = (ptr - line);
        if (has_spell && v >= word_end && v > cur_checked_col) {
          spell_attr = 0;
          if (!attr_pri) {
            char_attr = hl_combine_attr(char_attr, syntax_attr);
          }
          if (c != 0 && ((!has_syntax && !no_plain_buffer) || can_spell)) {
            char_u *prev_ptr;
            char_u *p;
            int len;
            hlf_T spell_hlf = HLF_COUNT;
            prev_ptr = ptr - mb_l;
            v -= mb_l - 1;

            // Use nextline[] if possible, it has the start of the
            // next line concatenated.
            if ((prev_ptr - line) - nextlinecol >= 0) {
              p = nextline + ((prev_ptr - line) - nextlinecol);
            } else {
              p = prev_ptr;
            }
            cap_col -= (int)(prev_ptr - line);
            size_t tmplen = spell_check(wp, p, &spell_hlf, &cap_col, nochange);
            assert(tmplen <= INT_MAX);
            len = (int)tmplen;
            word_end = (int)v + len;

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
              checked_lnum = lnum + 1;
              checked_col = (int)((p - nextline) + len - nextline_idx);
            }

            // Turn index into actual attributes.
            if (spell_hlf != HLF_COUNT) {
              spell_attr = highlight_attr[spell_hlf];
            }

            if (cap_col > 0) {
              if (p != prev_ptr
                  && (p - nextline) + cap_col >= nextline_idx) {
                // Remember that the word in the next line
                // must start with a capital.
                capcol_lnum = lnum + 1;
                cap_col = (int)((p - nextline) + cap_col
                                - nextline_idx);
              } else {
                // Compute the actual column.
                cap_col += (int)(prev_ptr - line);
              }
            }
          }
        }
        if (spell_attr != 0) {
          if (!attr_pri) {
            char_attr = hl_combine_attr(char_attr, spell_attr);
          } else {
            char_attr = hl_combine_attr(spell_attr, char_attr);
          }
        }

        if (wp->w_buffer->terminal) {
          char_attr = hl_combine_attr(term_attrs[vcol], char_attr);
        }

        // Found last space before word: check for line break.
        if (wp->w_p_lbr && c0 == c && vim_isbreak(c)
            && !vim_isbreak((int)(*ptr))) {
          int mb_off = utf_head_off((char *)line, (char *)ptr - 1);
          char_u *p = ptr - (mb_off + 1);
          chartabsize_T cts;

          init_chartabsize_arg(&cts, wp, lnum, (colnr_T)vcol, (char *)line, (char *)p);
          n_extra = win_lbr_chartabsize(&cts, NULL) - 1;

          // We have just drawn the showbreak value, no need to add
          // space for it again.
          if (vcol == vcol_sbr) {
            n_extra -= mb_charlen(get_showbreak_value(wp));
            if (n_extra < 0) {
              n_extra = 0;
            }
          }

          if (c == TAB && n_extra + col > grid->cols) {
            n_extra = tabstop_padding((colnr_T)vcol, wp->w_buffer->b_p_ts,
                                      wp->w_buffer->b_p_vts_array) - 1;
          }
          c_extra = mb_off > 0 ? MB_FILLER_CHAR : ' ';
          c_final = NUL;
          if (ascii_iswhite(c)) {
            if (c == TAB) {
              // See "Tab alignment" below.
              FIX_FOR_BOGUSCOLS;
            }
            if (!wp->w_p_list) {
              c = ' ';
            }
          }
          clear_chartabsize_arg(&cts);
        }

        in_multispace = c == ' ' && ((ptr > line + 1 && ptr[-2] == ' ') || *ptr == ' ');
        if (!in_multispace) {
          multispace_pos = 0;
        }

        // 'list': Change char 160 to 'nbsp' and space to 'space'.
        // But not when the character is followed by a composing
        // character (use mb_l to check that).
        if (wp->w_p_list
            && ((((c == 160 && mb_l == 1)
                  || (mb_utf8
                      && ((mb_c == 160 && mb_l == 2)
                          || (mb_c == 0x202f && mb_l == 3))))
                 && wp->w_p_lcs_chars.nbsp)
                || (c == ' '
                    && mb_l == 1
                    && (wp->w_p_lcs_chars.space
                        || (in_multispace && wp->w_p_lcs_chars.multispace != NULL))
                    && ptr - line >= leadcol
                    && ptr - line <= trailcol))) {
          if (in_multispace && wp->w_p_lcs_chars.multispace != NULL) {
            c = wp->w_p_lcs_chars.multispace[multispace_pos++];
            if (wp->w_p_lcs_chars.multispace[multispace_pos] == NUL) {
              multispace_pos = 0;
            }
          } else {
            c = (c == ' ') ? wp->w_p_lcs_chars.space : wp->w_p_lcs_chars.nbsp;
          }
          n_attr = 1;
          extra_attr = win_hl_attr(wp, HLF_0);
          saved_attr2 = char_attr;  // save current attr
          mb_c = c;
          mb_utf8 = check_mb_utf8(&c, u8cc);
        }

        if (c == ' ' && ((trailcol != MAXCOL && ptr > line + trailcol)
                         || (leadcol != 0 && ptr < line + leadcol))) {
          if (leadcol != 0 && in_multispace && ptr < line + leadcol
              && wp->w_p_lcs_chars.leadmultispace != NULL) {
            c = wp->w_p_lcs_chars.leadmultispace[multispace_pos++];
            if (wp->w_p_lcs_chars.leadmultispace[multispace_pos] == NUL) {
              multispace_pos = 0;
            }
          } else if (ptr > line + trailcol && wp->w_p_lcs_chars.trail) {
            c = wp->w_p_lcs_chars.trail;
          } else if (ptr < line + leadcol && wp->w_p_lcs_chars.lead) {
            c = wp->w_p_lcs_chars.lead;
          } else if (leadcol != 0 && wp->w_p_lcs_chars.space) {
            c = wp->w_p_lcs_chars.space;
          }

          n_attr = 1;
          extra_attr = win_hl_attr(wp, HLF_0);
          saved_attr2 = char_attr;  // save current attr
          mb_c = c;
          mb_utf8 = check_mb_utf8(&c, u8cc);
        }
      }

      // Handling of non-printable characters.
      if (!vim_isprintc(c)) {
        // when getting a character from the file, we may have to
        // turn it into something else on the way to putting it on the screen.
        if (c == TAB && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
          int tab_len = 0;
          long vcol_adjusted = vcol;  // removed showbreak length
          char_u *const sbr = get_showbreak_value(wp);

          // Only adjust the tab_len, when at the first column after the
          // showbreak value was drawn.
          if (*sbr != NUL && vcol == vcol_sbr && wp->w_p_wrap) {
            vcol_adjusted = vcol - mb_charlen(sbr);
          }
          // tab amount depends on current column
          tab_len = tabstop_padding((colnr_T)vcol_adjusted,
                                    wp->w_buffer->b_p_ts,
                                    wp->w_buffer->b_p_vts_array) - 1;

          if (!wp->w_p_lbr || !wp->w_p_list) {
            n_extra = tab_len;
          } else {
            char_u *p;
            int i;
            int saved_nextra = n_extra;

            if (vcol_off > 0) {
              // there are characters to conceal
              tab_len += vcol_off;
            }
            // boguscols before FIX_FOR_BOGUSCOLS macro from above.
            if (wp->w_p_lcs_chars.tab1 && old_boguscols > 0
                && n_extra > tab_len) {
              tab_len += n_extra - tab_len;
            }

            // If n_extra > 0, it gives the number of chars
            // to use for a tab, else we need to calculate the width
            // for a tab.
            int len = (tab_len * utf_char2len(wp->w_p_lcs_chars.tab2));
            if (wp->w_p_lcs_chars.tab3) {
              len += utf_char2len(wp->w_p_lcs_chars.tab3);
            }
            if (n_extra > 0) {
              len += n_extra - tab_len;
            }
            c = wp->w_p_lcs_chars.tab1;
            p = xmalloc((size_t)len + 1);
            memset(p, ' ', (size_t)len);
            p[len] = NUL;
            xfree(p_extra_free);
            p_extra_free = p;
            for (i = 0; i < tab_len; i++) {
              if (*p == NUL) {
                tab_len = i;
                break;
              }
              int lcs = wp->w_p_lcs_chars.tab2;

              // if tab3 is given, use it for the last char
              if (wp->w_p_lcs_chars.tab3 && i == tab_len - 1) {
                lcs = wp->w_p_lcs_chars.tab3;
              }
              p += utf_char2bytes(lcs, (char *)p);
              n_extra += utf_char2len(lcs) - (saved_nextra > 0 ? 1 : 0);
            }
            p_extra = p_extra_free;

            // n_extra will be increased by FIX_FOX_BOGUSCOLS
            // macro below, so need to adjust for that here
            if (vcol_off > 0) {
              n_extra -= vcol_off;
            }
          }

          {
            int vc_saved = vcol_off;

            // Tab alignment should be identical regardless of
            // 'conceallevel' value. So tab compensates of all
            // previous concealed characters, and thus resets
            // vcol_off and boguscols accumulated so far in the
            // line. Note that the tab can be longer than
            // 'tabstop' when there are concealed characters.
            FIX_FOR_BOGUSCOLS;

            // Make sure, the highlighting for the tab char will be
            // correctly set further below (effectively reverts the
            // FIX_FOR_BOGSUCOLS macro).
            if (n_extra == tab_len + vc_saved && wp->w_p_list
                && wp->w_p_lcs_chars.tab1) {
              tab_len += vc_saved;
            }
          }

          mb_utf8 = false;  // don't draw as UTF-8
          if (wp->w_p_list) {
            c = (n_extra == 0 && wp->w_p_lcs_chars.tab3)
                 ? wp->w_p_lcs_chars.tab3
                 : wp->w_p_lcs_chars.tab1;
            if (wp->w_p_lbr) {
              c_extra = NUL;  // using p_extra from above
            } else {
              c_extra = wp->w_p_lcs_chars.tab2;
            }
            c_final = wp->w_p_lcs_chars.tab3;
            n_attr = tab_len + 1;
            extra_attr = win_hl_attr(wp, HLF_0);
            saved_attr2 = char_attr;  // save current attr
            mb_c = c;
            mb_utf8 = check_mb_utf8(&c, u8cc);
          } else {
            c_final = NUL;
            c_extra = ' ';
            c = ' ';
          }
        } else if (c == NUL
                   && (wp->w_p_list
                       || ((fromcol >= 0 || fromcol_prev >= 0)
                           && tocol > vcol
                           && VIsual_mode != Ctrl_V
                           && (wp->w_p_rl ? (col >= 0) : (col < grid->cols))
                           && !(noinvcur
                                && lnum == wp->w_cursor.lnum
                                && (colnr_T)vcol == wp->w_virtcol)))
                   && lcs_eol_one > 0) {
          // Display a '$' after the line or highlight an extra
          // character if the line break is included.
          // For a diff line the highlighting continues after the "$".
          if (diff_hlf == (hlf_T)0
              && line_attr == 0
              && line_attr_lowprio == 0) {
            // In virtualedit, visual selections may extend beyond end of line
            if (area_highlighting && virtual_active()
                && tocol != MAXCOL && vcol < tocol) {
              n_extra = 0;
            } else {
              p_extra = at_end_str;
              n_extra = 1;
              c_extra = NUL;
              c_final = NUL;
            }
          }
          if (wp->w_p_list && wp->w_p_lcs_chars.eol > 0) {
            c = wp->w_p_lcs_chars.eol;
          } else {
            c = ' ';
          }
          lcs_eol_one = -1;
          ptr--;  // put it back at the NUL
          extra_attr = win_hl_attr(wp, HLF_AT);
          n_attr = 1;
          mb_c = c;
          mb_utf8 = check_mb_utf8(&c, u8cc);
        } else if (c != NUL) {
          p_extra = transchar_buf(wp->w_buffer, c);
          if (n_extra == 0) {
            n_extra = byte2cells(c) - 1;
          }
          if ((dy_flags & DY_UHEX) && wp->w_p_rl) {
            rl_mirror(p_extra);                 // reverse "<12>"
          }
          c_extra = NUL;
          c_final = NUL;
          if (wp->w_p_lbr) {
            char_u *p;

            c = *p_extra;
            p = xmalloc((size_t)n_extra + 1);
            memset(p, ' ', (size_t)n_extra);
            STRNCPY(p, p_extra + 1, STRLEN(p_extra) - 1);  // NOLINT(runtime/printf)
            p[n_extra] = NUL;
            xfree(p_extra_free);
            p_extra_free = p_extra = p;
          } else {
            n_extra = byte2cells(c) - 1;
            c = *p_extra++;
          }
          n_attr = n_extra + 1;
          extra_attr = win_hl_attr(wp, HLF_8);
          saved_attr2 = char_attr;  // save current attr
          mb_utf8 = false;   // don't draw as UTF-8
        } else if (VIsual_active
                   && (VIsual_mode == Ctrl_V || VIsual_mode == 'v')
                   && virtual_active()
                   && tocol != MAXCOL
                   && vcol < tocol
                   && (wp->w_p_rl ? (col >= 0) : (col < grid->cols))) {
          c = ' ';
          ptr--;  // put it back at the NUL
        }
      }

      if (wp->w_p_cole > 0
          && (wp != curwin || lnum != wp->w_cursor.lnum || conceal_cursor_line(wp))
          && ((syntax_flags & HL_CONCEAL) != 0 || has_match_conc > 0 || decor_conceal > 0)
          && !(lnum_in_visual_area && vim_strchr(wp->w_p_cocu, 'v') == NULL)) {
        char_attr = conceal_attr;
        if (((prev_syntax_id != syntax_seqnr && (syntax_flags & HL_CONCEAL) != 0)
             || has_match_conc > 1 || decor_conceal > 1)
            && (syn_get_sub_char() != NUL
                || (has_match_conc && match_conc)
                || (decor_conceal && decor_state.conceal_char)
                || wp->w_p_cole == 1)
            && wp->w_p_cole != 3) {
          // First time at this concealed item: display one
          // character.
          if (has_match_conc && match_conc) {
            c = match_conc;
          } else if (decor_conceal && decor_state.conceal_char) {
            c = decor_state.conceal_char;
            if (decor_state.conceal_attr) {
              char_attr = decor_state.conceal_attr;
            }
          } else if (syn_get_sub_char() != NUL) {
            c = syn_get_sub_char();
          } else if (wp->w_p_lcs_chars.conceal != NUL) {
            c = wp->w_p_lcs_chars.conceal;
          } else {
            c = ' ';
          }

          prev_syntax_id = syntax_seqnr;

          if (n_extra > 0) {
            vcol_off += n_extra;
          }
          vcol += n_extra;
          if (wp->w_p_wrap && n_extra > 0) {
            if (wp->w_p_rl) {
              col -= n_extra;
              boguscols -= n_extra;
            } else {
              boguscols += n_extra;
              col += n_extra;
            }
          }
          n_extra = 0;
          n_attr = 0;
        } else if (n_skip == 0) {
          is_concealing = true;
          n_skip = 1;
        }
        mb_c = c;
        mb_utf8 = check_mb_utf8(&c, u8cc);
      } else {
        prev_syntax_id = 0;
        is_concealing = false;
      }

      if (n_skip > 0 && did_decrement_ptr) {
        // not showing the '>', put pointer back to avoid getting stuck
        ptr++;
      }
    }  // end of printing from buffer content

    // In the cursor line and we may be concealing characters: correct
    // the cursor column when we reach its position.
    if (!did_wcol && draw_state == WL_LINE
        && wp == curwin && lnum == wp->w_cursor.lnum
        && conceal_cursor_line(wp)
        && (int)wp->w_virtcol <= vcol + n_skip) {
      if (wp->w_p_rl) {
        wp->w_wcol = grid->cols - col + boguscols - 1;
      } else {
        wp->w_wcol = col - boguscols;
      }
      wp->w_wrow = row;
      did_wcol = true;
      wp->w_valid |= VALID_WCOL|VALID_WROW|VALID_VIRTCOL;
    }

    // Don't override visual selection highlighting.
    if (n_attr > 0 && draw_state == WL_LINE && !search_attr_from_match) {
      char_attr = hl_combine_attr(char_attr, extra_attr);
    }

    // Handle the case where we are in column 0 but not on the first
    // character of the line and the user wants us to show us a
    // special character (via 'listchars' option "precedes:<char>".
    if (lcs_prec_todo != NUL
        && wp->w_p_list
        && (wp->w_p_wrap ? (wp->w_skipcol > 0 && row == 0) : wp->w_leftcol > 0)
        && filler_todo <= 0
        && draw_state > WL_NR
        && c != NUL) {
      c = wp->w_p_lcs_chars.prec;
      lcs_prec_todo = NUL;
      if (utf_char2cells(mb_c) > 1) {
        // Double-width character being overwritten by the "precedes"
        // character, need to fill up half the character.
        c_extra = MB_FILLER_CHAR;
        c_final = NUL;
        n_extra = 1;
        n_attr = 2;
        extra_attr = win_hl_attr(wp, HLF_AT);
      }
      mb_c = c;
      mb_utf8 = check_mb_utf8(&c, u8cc);
      saved_attr3 = char_attr;  // save current attr
      char_attr = win_hl_attr(wp, HLF_AT);  // overwriting char_attr
      n_attr3 = 1;
    }

    // At end of the text line or just after the last character.
    if (c == NUL && eol_hl_off == 0) {
      // flag to indicate whether prevcol equals startcol of search_hl or
      // one of the matches
      bool prevcol_hl_flag = get_prevcol_hl_flag(wp, &screen_search_hl,
                                                 (long)(ptr - line) - 1);

      // Invert at least one char, used for Visual and empty line or
      // highlight match at end of line. If it's beyond the last
      // char on the screen, just overwrite that one (tricky!)  Not
      // needed when a '$' was displayed for 'list'.
      if (wp->w_p_lcs_chars.eol == lcs_eol_one
          && ((area_attr != 0 && vcol == fromcol
               && (VIsual_mode != Ctrl_V
                   || lnum == VIsual.lnum
                   || lnum == curwin->w_cursor.lnum))
              // highlight 'hlsearch' match at end of line
              || prevcol_hl_flag)) {
        int n = 0;

        if (wp->w_p_rl) {
          if (col < 0) {
            n = 1;
          }
        } else {
          if (col >= grid->cols) {
            n = -1;
          }
        }
        if (n != 0) {
          // At the window boundary, highlight the last character
          // instead (better than nothing).
          off += n;
          col += n;
        } else {
          // Add a blank character to highlight.
          schar_from_ascii(linebuf_char[off], ' ');
        }
        if (area_attr == 0 && !has_fold) {
          // Use attributes from match with highest priority among
          // 'search_hl' and the match list.
          get_search_match_hl(wp, &screen_search_hl, (long)(ptr - line), &char_attr);
        }

        int eol_attr = char_attr;
        if (cul_attr) {
          eol_attr = hl_combine_attr(cul_attr, eol_attr);
        }
        linebuf_attr[off] = eol_attr;
        if (wp->w_p_rl) {
          col--;
          off--;
        } else {
          col++;
          off++;
        }
        vcol++;
        eol_hl_off = 1;
      }
      // Highlight 'cursorcolumn' & 'colorcolumn' past end of the line.
      if (wp->w_p_wrap) {
        v = wp->w_skipcol;
      } else {
        v = wp->w_leftcol;
      }

      // check if line ends before left margin
      if (vcol < v + col - win_col_off(wp)) {
        vcol = v + col - win_col_off(wp);
      }
      // Get rid of the boguscols now, we want to draw until the right
      // edge for 'cursorcolumn'.
      col -= boguscols;
      // boguscols = 0;  // Disabled because value never read after this

      if (draw_color_col) {
        draw_color_col = advance_color_col((int)VCOL_HLC, &color_cols);
      }

      bool has_virttext = false;
      // Make sure alignment is the same regardless
      // if listchars=eol:X is used or not.
      int eol_skip = (wp->w_p_lcs_chars.eol == lcs_eol_one && eol_hl_off == 0
                      ? 1 : 0);

      if (has_decor) {
        has_virttext = decor_redraw_eol(wp->w_buffer, &decor_state, &line_attr,
                                        col + eol_skip);
      }

      if (((wp->w_p_cuc
            && (int)wp->w_virtcol >= VCOL_HLC - eol_hl_off
            && (int)wp->w_virtcol <
            (long)grid->cols * (row - startrow + 1) + v
            && lnum != wp->w_cursor.lnum)
           || draw_color_col || line_attr_lowprio || line_attr
           || diff_hlf != (hlf_T)0 || has_virttext)) {
        int rightmost_vcol = 0;
        int i;

        if (wp->w_p_cuc) {
          rightmost_vcol = wp->w_virtcol;
        }

        if (draw_color_col) {
          // determine rightmost colorcolumn to possibly draw
          for (i = 0; color_cols[i] >= 0; i++) {
            if (rightmost_vcol < color_cols[i]) {
              rightmost_vcol = color_cols[i];
            }
          }
        }

        int cuc_attr = win_hl_attr(wp, HLF_CUC);
        int mc_attr = win_hl_attr(wp, HLF_MC);

        int diff_attr = 0;
        if (diff_hlf == HLF_TXD) {
          diff_hlf = HLF_CHD;
        }
        if (diff_hlf != 0) {
          diff_attr = win_hl_attr(wp, (int)diff_hlf);
        }

        int base_attr = hl_combine_attr(line_attr_lowprio, diff_attr);
        if (base_attr || line_attr || has_virttext) {
          rightmost_vcol = INT_MAX;
        }

        int col_stride = wp->w_p_rl ? -1 : 1;

        while (wp->w_p_rl ? col >= 0 : col < grid->cols) {
          schar_from_ascii(linebuf_char[off], ' ');
          col += col_stride;
          if (draw_color_col) {
            draw_color_col = advance_color_col((int)VCOL_HLC, &color_cols);
          }

          int col_attr = base_attr;

          if (wp->w_p_cuc && VCOL_HLC == (long)wp->w_virtcol) {
            col_attr = cuc_attr;
          } else if (draw_color_col && VCOL_HLC == *color_cols) {
            col_attr = mc_attr;
          }

          col_attr = hl_combine_attr(col_attr, line_attr);

          linebuf_attr[off] = col_attr;
          off += col_stride;

          if (VCOL_HLC >= rightmost_vcol) {
            break;
          }

          vcol += 1;
        }
      }

      // TODO(bfredl): integrate with the common beyond-the-end-loop
      if (wp->w_buffer->terminal) {
        // terminal buffers may need to highlight beyond the end of the
        // logical line
        int n = wp->w_p_rl ? -1 : 1;
        while (col >= 0 && col < grid->cols) {
          schar_from_ascii(linebuf_char[off], ' ');
          linebuf_attr[off] = vcol >= TERM_ATTRS_MAX ? 0 : term_attrs[vcol];
          off += n;
          vcol += n;
          col += n;
        }
      }

      draw_virt_text(wp, buf, win_col_offset, &col, grid->cols, row);
      grid_put_linebuf(grid, row, 0, col, grid->cols, wp->w_p_rl, wp, bg_attr, false);
      row++;

      // Update w_cline_height and w_cline_folded if the cursor line was
      // updated (saves a call to plines_win() later).
      if (wp == curwin && lnum == curwin->w_cursor.lnum) {
        curwin->w_cline_row = startrow;
        curwin->w_cline_height = row - startrow;
        curwin->w_cline_folded = foldinfo.fi_lines > 0;
        curwin->w_valid |= (VALID_CHEIGHT|VALID_CROW);
        conceal_cursor_used = conceal_cursor_line(curwin);
      }
      break;
    }

    // Show "extends" character from 'listchars' if beyond the line end and
    // 'list' is set.
    if (wp->w_p_lcs_chars.ext != NUL
        && draw_state == WL_LINE
        && wp->w_p_list
        && !wp->w_p_wrap
        && filler_todo <= 0
        && (wp->w_p_rl ? col == 0 : col == grid->cols - 1)
        && !has_fold
        && (*ptr != NUL
            || lcs_eol_one > 0
            || (n_extra && (c_extra != NUL || *p_extra != NUL)))) {
      c = wp->w_p_lcs_chars.ext;
      char_attr = win_hl_attr(wp, HLF_AT);
      mb_c = c;
      mb_utf8 = check_mb_utf8(&c, u8cc);
    }

    // advance to the next 'colorcolumn'
    if (draw_color_col) {
      draw_color_col = advance_color_col((int)VCOL_HLC, &color_cols);
    }

    // Highlight the cursor column if 'cursorcolumn' is set.  But don't
    // highlight the cursor position itself.
    // Also highlight the 'colorcolumn' if it is different than
    // 'cursorcolumn'
    // Also highlight the 'colorcolumn' if 'breakindent' and/or 'showbreak'
    // options are set
    vcol_save_attr = -1;
    if ((draw_state == WL_LINE
         || draw_state == WL_BRI
         || draw_state == WL_SBR)
        && !lnum_in_visual_area
        && search_attr == 0
        && area_attr == 0
        && filler_todo <= 0) {
      if (wp->w_p_cuc && VCOL_HLC == (long)wp->w_virtcol
          && lnum != wp->w_cursor.lnum) {
        vcol_save_attr = char_attr;
        char_attr = hl_combine_attr(win_hl_attr(wp, HLF_CUC), char_attr);
      } else if (draw_color_col && VCOL_HLC == *color_cols) {
        vcol_save_attr = char_attr;
        char_attr = hl_combine_attr(win_hl_attr(wp, HLF_MC), char_attr);
      }
    }

    // Apply lowest-priority line attr now, so everything can override it.
    if (draw_state == WL_LINE) {
      char_attr = hl_combine_attr(line_attr_lowprio, char_attr);
    }

    // Store character to be displayed.
    // Skip characters that are left of the screen for 'nowrap'.
    vcol_prev = vcol;
    if (draw_state < WL_LINE || n_skip <= 0) {
      //
      // Store the character.
      //
      if (wp->w_p_rl && utf_char2cells(mb_c) > 1) {
        // A double-wide character is: put first half in left cell.
        off--;
        col--;
      }
      if (mb_utf8) {
        schar_from_cc(linebuf_char[off], mb_c, u8cc);
      } else {
        schar_from_ascii(linebuf_char[off], (char)c);
      }
      if (multi_attr) {
        linebuf_attr[off] = multi_attr;
        multi_attr = 0;
      } else {
        linebuf_attr[off] = char_attr;
      }

      if (utf_char2cells(mb_c) > 1) {
        // Need to fill two screen columns.
        off++;
        col++;
        // UTF-8: Put a 0 in the second screen char.
        linebuf_char[off][0] = 0;
        if (draw_state > WL_NR && filler_todo <= 0) {
          vcol++;
        }
        // When "tocol" is halfway through a character, set it to the end of
        // the character, otherwise highlighting won't stop.
        if (tocol == vcol) {
          tocol++;
        }
        if (wp->w_p_rl) {
          // now it's time to backup one cell
          off--;
          col--;
        }
      }
      if (wp->w_p_rl) {
        off--;
        col--;
      } else {
        off++;
        col++;
      }
    } else if (wp->w_p_cole > 0 && is_concealing) {
      n_skip--;
      vcol_off++;
      if (n_extra > 0) {
        vcol_off += n_extra;
      }
      if (wp->w_p_wrap) {
        // Special voodoo required if 'wrap' is on.
        //
        // Advance the column indicator to force the line
        // drawing to wrap early. This will make the line
        // take up the same screen space when parts are concealed,
        // so that cursor line computations aren't messed up.
        //
        // To avoid the fictitious advance of 'col' causing
        // trailing junk to be written out of the screen line
        // we are building, 'boguscols' keeps track of the number
        // of bad columns we have advanced.
        if (n_extra > 0) {
          vcol += n_extra;
          if (wp->w_p_rl) {
            col -= n_extra;
            boguscols -= n_extra;
          } else {
            col += n_extra;
            boguscols += n_extra;
          }
          n_extra = 0;
          n_attr = 0;
        }

        if (utf_char2cells(mb_c) > 1) {
          // Need to fill two screen columns.
          if (wp->w_p_rl) {
            boguscols--;
            col--;
          } else {
            boguscols++;
            col++;
          }
        }

        if (wp->w_p_rl) {
          boguscols--;
          col--;
        } else {
          boguscols++;
          col++;
        }
      } else {
        if (n_extra > 0) {
          vcol += n_extra;
          n_extra = 0;
          n_attr = 0;
        }
      }
    } else {
      n_skip--;
    }

    // Only advance the "vcol" when after the 'number' or 'relativenumber'
    // column.
    if (draw_state > WL_NR
        && filler_todo <= 0) {
      vcol++;
    }

    if (vcol_save_attr >= 0) {
      char_attr = vcol_save_attr;
    }

    // restore attributes after "predeces" in 'listchars'
    if (draw_state > WL_NR && n_attr3 > 0 && --n_attr3 == 0) {
      char_attr = saved_attr3;
    }

    // restore attributes after last 'listchars' or 'number' char
    if (n_attr > 0 && draw_state == WL_LINE && --n_attr == 0) {
      char_attr = saved_attr2;
    }

    // At end of screen line and there is more to come: Display the line
    // so far.  If there is no more to display it is caught above.
    if ((wp->w_p_rl ? (col < 0) : (col >= grid->cols))
        && foldinfo.fi_lines == 0
        && (draw_state != WL_LINE
            || *ptr != NUL
            || filler_todo > 0
            || (wp->w_p_list && wp->w_p_lcs_chars.eol != NUL
                && p_extra != at_end_str)
            || (n_extra != 0
                && (c_extra != NUL || *p_extra != NUL)))) {
      bool wrap = wp->w_p_wrap       // Wrapping enabled.
                  && filler_todo <= 0          // Not drawing diff filler lines.
                  && lcs_eol_one != -1         // Haven't printed the lcs_eol character.
                  && row != endrow - 1         // Not the last line being displayed.
                  && (grid->cols == Columns  // Window spans the width of the screen,
                      || ui_has(kUIMultigrid))  // or has dedicated grid.
                  && !wp->w_p_rl;              // Not right-to-left.

      int draw_col = col - boguscols;
      if (filler_todo > 0) {
        int index = filler_todo - (filler_lines - n_virt_lines);
        if (index > 0) {
          int i = (int)kv_size(virt_lines) - index;
          assert(i >= 0);
          int offset = kv_A(virt_lines, i).left_col ? 0 : win_col_offset;
          draw_virt_text_item(buf, offset, kv_A(virt_lines, i).line,
                              kHlModeReplace, grid->cols, offset);
        }
      } else {
        draw_virt_text(wp, buf, win_col_offset, &draw_col, grid->cols, row);
      }

      grid_put_linebuf(grid, row, 0, draw_col, grid->cols, wp->w_p_rl, wp, bg_attr, wrap);
      if (wrap) {
        ScreenGrid *current_grid = grid;
        int current_row = row, dummy_col = 0;  // dummy_col unused
        grid_adjust(&current_grid, &current_row, &dummy_col);

        // Force a redraw of the first column of the next line.
        current_grid->attrs[current_grid->line_offset[current_row + 1]] = -1;

        // Remember that the line wraps, used for modeless copy.
        current_grid->line_wraps[current_row] = true;
      }

      boguscols = 0;
      row++;

      // When not wrapping and finished diff lines, or when displayed
      // '$' and highlighting until last column, break here.
      if ((!wp->w_p_wrap && filler_todo <= 0) || lcs_eol_one == -1) {
        break;
      }

      // When the window is too narrow draw all "@" lines.
      if (draw_state != WL_LINE && filler_todo <= 0) {
        win_draw_end(wp, '@', ' ', true, row, wp->w_grid.rows, HLF_AT);
        row = endrow;
      }

      // When line got too long for screen break here.
      if (row == endrow) {
        row++;
        break;
      }

      col = 0;
      off = 0;
      if (wp->w_p_rl) {
        col = grid->cols - 1;  // col is not used if breaking!
        off += col;
      }

      // reset the drawing state for the start of a wrapped line
      draw_state = WL_START;
      saved_n_extra = n_extra;
      saved_p_extra = p_extra;
      saved_c_extra = c_extra;
      saved_c_final = c_final;
      saved_char_attr = char_attr;
      n_extra = 0;
      lcs_prec_todo = wp->w_p_lcs_chars.prec;
      if (filler_todo <= 0) {
        need_showbreak = true;
      }
      filler_todo--;
      // When the filler lines are actually below the last line of the
      // file, don't draw the line itself, break here.
      if (filler_todo == 0 && (wp->w_botfill || end_fill)) {
        break;
      }
    }
  }     // for every character in the line

  // After an empty line check first word for capital.
  if (*skipwhite((char *)line) == NUL) {
    capcol_lnum = lnum + 1;
    cap_col = 0;
  }

  kv_destroy(virt_lines);
  xfree(p_extra_free);
  return row;
}
