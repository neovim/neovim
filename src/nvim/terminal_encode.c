/// terminal_encode.c
///
/// Serialize terminal screen content (including scrollback) to ANSI escape sequences.

#include "klib/kvec.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/grid.h"
#include "nvim/strings.h"
#include "nvim/terminal_defs.h"
#include "nvim/terminal_encode.h"
#include "nvim/vterm/pen.h"
#include "nvim/vterm/screen.h"
#include "nvim/vterm/state.h"
#include "nvim/vterm/vterm.h"
#include "nvim/vterm/vterm_defs.h"

#include "terminal_encode.c.generated.h"

/// Check if a `VTermScreenCell` is blank (empty or space).
///
/// @param cell  The cell to check.
/// @return true if the cell contains no visible character.
static bool cell_is_blank(const VTermScreenCell *cell)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  return cell->schar == 0 || cell->schar == schar_from_char(' ');
}

/// Compare two `VTermColor` values. Unlike `memcmp()`, this function does not read undefined bytes
/// from the union's inactive members.
///
/// @param a  First color to compare.
/// @param b  Second color to compare.
/// @return true if the two colors are equal.
static bool vterm_color_equal(const VTermColor *a, const VTermColor *b)
{
  if (VTERM_COLOR_IS_DEFAULT_FG(a) || VTERM_COLOR_IS_DEFAULT_BG(a)
      || VTERM_COLOR_IS_DEFAULT_FG(b) || VTERM_COLOR_IS_DEFAULT_BG(b)) {
    // Default fg/bg have no extra value to compare.
    // They shouldn't be compared as indexed/rgb color
    return a->type == b->type;
  }
  if (VTERM_COLOR_IS_INDEXED(a) && VTERM_COLOR_IS_INDEXED(b)) {
    return a->indexed.idx == b->indexed.idx;
  }
  if (VTERM_COLOR_IS_RGB(a) && VTERM_COLOR_IS_RGB(b)) {
    return a->rgb.red == b->rgb.red
           && a->rgb.green == b->rgb.green
           && a->rgb.blue == b->rgb.blue;
  }
  return false;
}

/// Compare all SGR attributes and colors of two cells to decide whether a new escape
/// sequence is needed.
///
/// @param a  First cell to compare.
/// @param b  Second cell to compare.
/// @return true if the two cells have identical attributes.
static bool cell_sgr_equal(const VTermScreenCell *a, const VTermScreenCell *b)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  // `VTermScreenCellAttrs` is a struct with bit-fields. It's packed into 32 bits, where only 20
  // bits are used, so `memcmp()` would read undefined padding.
  return a->attrs.bold == b->attrs.bold
         && a->attrs.underline == b->attrs.underline
         && a->attrs.italic == b->attrs.italic
         && a->attrs.blink == b->attrs.blink
         && a->attrs.reverse == b->attrs.reverse
         && a->attrs.conceal == b->attrs.conceal
         && a->attrs.strike == b->attrs.strike
         && a->attrs.font == b->attrs.font
         && a->attrs.dwl == b->attrs.dwl
         && a->attrs.dhl == b->attrs.dhl
         && a->attrs.small == b->attrs.small
         && a->attrs.baseline == b->attrs.baseline
         && a->attrs.dim == b->attrs.dim
         && a->attrs.overline == b->attrs.overline
         && vterm_color_equal(&a->fg, &b->fg)
         && vterm_color_equal(&a->bg, &b->bg);
}

/// Append a single foreground or background color as an SGR parameter string.
///
/// Emits `;38;5;idx` for indexed colors, `;38;2;R;G;B` for RGB-color, and skips default colors.
///
/// @param out    Output buffer to append to.
/// @param color  The `VTermColor` to encode.
/// @param is_fg  true for foreground (38), false for background (48).
/// @param state  VTerm state.
static void te_encode_append_sgr_color(StringBuilder *out, const VTermColor *color, bool is_fg,
                                       VTermState *state)
  FUNC_ATTR_NONNULL_ALL
{
  // default color
  if ((is_fg && VTERM_COLOR_IS_DEFAULT_FG(color)) || (!is_fg && VTERM_COLOR_IS_DEFAULT_BG(color))) {
    return;
  }

  // indexed color
  if (VTERM_COLOR_IS_INDEXED(color)) {
    kv_printf(*out, ";%d;5;%d", is_fg ? 38 : 48, color->indexed.idx);
    return;
  }

  // RGB color
  VTermColor rgb = *color;
  vterm_state_convert_color_to_rgb(state, &rgb);
  kv_printf(*out, ";%d;2;%d;%d;%d", is_fg ? 38 : 48, rgb.rgb.red, rgb.rgb.green, rgb.rgb.blue);
}

/// Append a complete SGR escape sequence for a cell. Writes `\x1b[0;...m` encoding all text
/// attributes.
///
/// @param out    Output buffer to append to.
/// @param cell   The cell to encode.
/// @param state  VTerm state.
static void te_encode_append_sgr(StringBuilder *out, const VTermScreenCell *cell, VTermState *state)
  FUNC_ATTR_NONNULL_ALL
{
  kv_concat(*out, "\x1b[0");
  if (cell->attrs.bold) {
    kv_concat(*out, ";1");
  }
  if (cell->attrs.dim) {
    kv_concat(*out, ";2");
  }
  if (cell->attrs.italic) {
    kv_concat(*out, ";3");
  }
  switch (cell->attrs.underline) {
  case VTERM_UNDERLINE_SINGLE:
    kv_concat(*out, ";4");
    break;
  case VTERM_UNDERLINE_DOUBLE:
    kv_concat(*out, ";21");
    break;
  case VTERM_UNDERLINE_CURLY:
    kv_concat(*out, ";4:3");
    break;
  case VTERM_UNDERLINE_OFF:
    break;
  }
  if (cell->attrs.blink) {
    kv_concat(*out, ";5");
  }
  if (cell->attrs.reverse) {
    kv_concat(*out, ";7");
  }
  if (cell->attrs.conceal) {
    kv_concat(*out, ";8");
  }
  if (cell->attrs.strike) {
    kv_concat(*out, ";9");
  }
  if (cell->attrs.font) {
    kv_printf(*out, ";%d", 10 + cell->attrs.font);
  }
  te_encode_append_sgr_color(out, &cell->fg, true, state);
  te_encode_append_sgr_color(out, &cell->bg, false, state);
  if (cell->attrs.overline) {
    kv_concat(*out, ";53");
  }
  if (cell->attrs.small) {
    if (cell->attrs.baseline == VTERM_BASELINE_RAISE) {
      kv_concat(*out, ";73");
    } else if (cell->attrs.baseline == VTERM_BASELINE_LOWER) {
      kv_concat(*out, ";74");
    }
  }
  kv_push(*out, 'm');
}

/// Encode one row of cells into an ANSI text line.
///
/// Trailing blank cells are trimmed to reduce output size. Adjacent cells with identical SGR
/// attributes reuse the same escape sequence. Wide character cells with width 0 are skipped.
///
/// @param term   Terminal instance (provides VTerm state).
/// @param cells  Array of `VTermScreenCell` representing one screen row.
/// @param cols   Number of cells in the row.
/// @param out    Output buffer to append to.
static void te_encode_line2ansi(Terminal *term, const VTermScreenCell *cells, size_t cols,
                                StringBuilder *out)
  FUNC_ATTR_NONNULL_ALL
{
  // Trim trailing blank cells to optimize output size
  size_t end = cols;
  while (end > 0 && cell_is_blank(&cells[end - 1])) {
    end--;
  }
  // Preserve empty lines
  if (end == 0) {
    kv_concat(*out, "\x1b[0m\n");
    return;
  }

  VTermState *state = vterm_obtain_state(term->vt);
  VTermScreenCell curr = { 0 };

  // iterate cells
  for (size_t col = 0; col < end; col++) {
    const VTermScreenCell *cell = &cells[col];

    // Skip for wide chars
    if (cell->width == 0) {
      continue;
    }

    // Append escape sequence on sgr change
    if (!cell_sgr_equal(&curr, cell)) {
      te_encode_append_sgr(out, cell, state);
      curr = *cell;
    }

    // Append character
    if (cell->schar) {
      char buf[MAX_SCHAR_SIZE];
      size_t len = schar_get(buf, cell->schar);
      kv_concat_len(*out, buf, len);
    } else {
      kv_push(*out, ' ');
    }
  }

  kv_concat(*out, "\n");
}

/// Export rendered terminal state (scrollback + visible screen) as ANSI escape sequences.
///
/// @param term   Terminal instance to export.
/// @param start  1-based line number to start from (1 for first line).
/// @param end    1-based line number to end at (inclusive), or 0 for all remaining.
/// @return A `String` containing the ANSI escape sequences. The caller must free `data`.
String te_encode_export_ansi(Terminal *term, int start, int end)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int height, width;
  vterm_get_size(term->vt, &height, &width);
  linenr_T total = (linenr_T)term->sb_current + (linenr_T)height;
  // Range write will skip this block so that user-selected ranges are exported as is.
  if (end == 0 || end >= total) {
    end = total;
    if (term->sb_current == 0) {
      // Don't save empty lines when the visible screen is not full.
      int last_row = height - 1;
      while (last_row >= 0) {
        bool empty = true;
        for (int col = 0; col < width; col++) {
          VTermScreenCell cell;
          vterm_screen_get_cell(term->vts, (VTermPos){ .row = last_row, .col = col }, &cell);
          if (!cell_is_blank(&cell)) {
            empty = false;
            break;
          }
        }
        if (!empty) {
          break;
        }
        last_row--;
      }
      // Screen row 0 = buffer line 1
      end = (linenr_T)last_row + 1;
    }
  }

  StringBuilder out = KV_INITIAL_VALUE;
  VTermScreenCell *cells = xmalloc(sizeof(*cells) * (size_t)width);

  for (linenr_T lnum = start; lnum <= end; lnum++) {
    if (lnum <= (linenr_T)term->sb_current) {
      // Scrollback: line 1 = sb_buffer[sb_current-1]
      size_t idx = term->sb_current - (size_t)lnum;
      ScrollbackLine *line = term->sb_buffer[idx];
      te_encode_line2ansi(term, line->cells, line->cols, &out);
    } else {
      // Visible screen: line sb_current+1 = row 0
      int row = (lnum - (linenr_T)term->sb_current - 1);
      for (int col = 0; col < width; col++) {
        vterm_screen_get_cell(term->vts, (VTermPos){ .row = row, .col = col }, &cells[col]);
      }
      te_encode_line2ansi(term, cells, (size_t)width, &out);
    }
  }

  xfree(cells);
  // Reset SGR so the last char's attributes (if exist) do not bleed beyond the exported content.
  kv_concat(out, "\x1b[0m");
  // Guarantee it's NUL-terminated. Otherwise, it will cause heap-buffer-overflow in `strlen`.
  kv_push(out, NUL);
  // .size should -1 to exclude the side-effect from `kv_push`.
  return (String){ .data = out.items, .size = --out.size };
}
