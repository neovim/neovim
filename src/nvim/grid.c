// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/arabic.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/screen.h"
#include "nvim/ui.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "grid.c.generated.h"
#endif

// temporary buffer for rendering a single screenline, so it can be
// compared with previous contents to calculate smallest delta.
// Per-cell attributes
static size_t linebuf_size = 0;

/// Determine if dedicated window grid should be used or the default_grid
///
/// If UI did not request multigrid support, draw all windows on the
/// default_grid.
///
/// NB: this function can only been used with window grids in a context where
/// win_grid_alloc already has been called!
///
/// If the default_grid is used, adjust window relative positions to global
/// screen positions.
void grid_adjust(ScreenGrid **grid, int *row_off, int *col_off)
{
  if ((*grid)->target) {
    *row_off += (*grid)->row_offset;
    *col_off += (*grid)->col_offset;
    *grid = (*grid)->target;
  }
}

/// Put a unicode char, and up to MAX_MCO composing chars, in a screen cell.
int schar_from_cc(char_u *p, int c, int u8cc[MAX_MCO])
{
  int len = utf_char2bytes(c, (char *)p);
  for (int i = 0; i < MAX_MCO; i++) {
    if (u8cc[i] == 0) {
      break;
    }
    len += utf_char2bytes(u8cc[i], (char *)p + len);
  }
  p[len] = 0;
  return len;
}

/// clear a line in the grid starting at "off" until "width" characters
/// are cleared.
void grid_clear_line(ScreenGrid *grid, size_t off, int width, bool valid)
{
  for (int col = 0; col < width; col++) {
    schar_from_ascii(grid->chars[off + (size_t)col], ' ');
  }
  int fill = valid ? 0 : -1;
  (void)memset(grid->attrs + off, fill, (size_t)width * sizeof(sattr_T));
}

void grid_invalidate(ScreenGrid *grid)
{
  (void)memset(grid->attrs, -1, sizeof(sattr_T) * (size_t)grid->rows * (size_t)grid->cols);
}

bool grid_invalid_row(ScreenGrid *grid, int row)
{
  return grid->attrs[grid->line_offset[row]] < 0;
}

static int line_off2cells(schar_T *line, size_t off, size_t max_off)
{
  return (off + 1 < max_off && line[off + 1][0] == 0) ? 2 : 1;
}

/// Return number of display cells for char at grid->chars[off].
/// We make sure that the offset used is less than "max_off".
static int grid_off2cells(ScreenGrid *grid, size_t off, size_t max_off)
{
  return line_off2cells(grid->chars, off, max_off);
}

/// Return true if the character at "row"/"col" on the screen is the left side
/// of a double-width character.
///
/// Caller must make sure "row" and "col" are not invalid!
bool grid_lefthalve(ScreenGrid *grid, int row, int col)
{
  grid_adjust(&grid, &row, &col);

  return grid_off2cells(grid, grid->line_offset[row] + (size_t)col,
                        grid->line_offset[row] + (size_t)grid->cols) > 1;
}

/// Correct a position on the screen, if it's the right half of a double-wide
/// char move it to the left half.  Returns the corrected column.
int grid_fix_col(ScreenGrid *grid, int col, int row)
{
  int coloff = 0;
  grid_adjust(&grid, &row, &coloff);

  col += coloff;
  if (grid->chars != NULL && col > 0
      && grid->chars[grid->line_offset[row] + (size_t)col][0] == 0) {
    return col - 1 - coloff;
  }
  return col - coloff;
}

/// output a single character directly to the grid
void grid_putchar(ScreenGrid *grid, int c, int row, int col, int attr)
{
  char buf[MB_MAXBYTES + 1];

  buf[utf_char2bytes(c, buf)] = NUL;
  grid_puts(grid, (char_u *)buf, row, col, attr);
}

/// get a single character directly from grid.chars into "bytes[]".
/// Also return its attribute in *attrp;
void grid_getbytes(ScreenGrid *grid, int row, int col, char_u *bytes, int *attrp)
{
  size_t off;

  grid_adjust(&grid, &row, &col);

  // safety check
  if (grid->chars != NULL && row < grid->rows && col < grid->cols) {
    off = grid->line_offset[row] + (size_t)col;
    *attrp = grid->attrs[off];
    schar_copy(bytes, grid->chars[off]);
  }
}

/// put string '*text' on the window grid at position 'row' and 'col', with
/// attributes 'attr', and update chars[] and attrs[].
/// Note: only outputs within one row, message is truncated at grid boundary!
/// Note: if grid, row and/or col is invalid, nothing is done.
void grid_puts(ScreenGrid *grid, char_u *text, int row, int col, int attr)
{
  grid_puts_len(grid, text, -1, row, col, attr);
}

static ScreenGrid *put_dirty_grid = NULL;
static int put_dirty_row = -1;
static int put_dirty_first = INT_MAX;
static int put_dirty_last = 0;

/// Start a group of grid_puts_len calls that builds a single grid line.
///
/// Must be matched with a grid_puts_line_flush call before moving to
/// another line.
void grid_puts_line_start(ScreenGrid *grid, int row)
{
  int col = 0;  // unused
  grid_adjust(&grid, &row, &col);
  assert(put_dirty_row == -1);
  put_dirty_row = row;
  put_dirty_grid = grid;
}

void grid_put_schar(ScreenGrid *grid, int row, int col, char_u *schar, int attr)
{
  assert(put_dirty_row == row);
  size_t off = grid->line_offset[row] + (size_t)col;
  if (grid->attrs[off] != attr || schar_cmp(grid->chars[off], schar)) {
    schar_copy(grid->chars[off], schar);
    grid->attrs[off] = attr;

    put_dirty_first = MIN(put_dirty_first, col);
    // TODO(bfredl): Y U NO DOUBLEWIDTH?
    put_dirty_last = MAX(put_dirty_last, col + 1);
  }
}

/// like grid_puts(), but output "text[len]".  When "len" is -1 output up to
/// a NUL.
void grid_puts_len(ScreenGrid *grid, char_u *text, int textlen, int row, int col, int attr)
{
  size_t off;
  char_u *ptr = text;
  int len = textlen;
  int c;
  size_t max_off;
  int mbyte_blen = 1;
  int mbyte_cells = 1;
  int u8c = 0;
  int u8cc[MAX_MCO];
  bool clear_next_cell = false;
  int prev_c = 0;  // previous Arabic character
  int pc, nc, nc1;
  int pcc[MAX_MCO];
  int need_redraw;
  bool do_flush = false;

  grid_adjust(&grid, &row, &col);

  // Safety check. The check for negative row and column is to fix issue
  // vim/vim#4102. TODO(neovim): find out why row/col could be negative.
  if (grid->chars == NULL
      || row >= grid->rows || row < 0
      || col >= grid->cols || col < 0) {
    return;
  }

  if (put_dirty_row == -1) {
    grid_puts_line_start(grid, row);
    do_flush = true;
  } else {
    if (grid != put_dirty_grid || row != put_dirty_row) {
      abort();
    }
  }
  off = grid->line_offset[row] + (size_t)col;

  // When drawing over the right half of a double-wide char clear out the
  // left half.  Only needed in a terminal.
  if (grid != &default_grid && col == 0 && grid_invalid_row(grid, row)) {
    // redraw the previous cell, make it empty
    put_dirty_first = -1;
    put_dirty_last = MAX(put_dirty_last, 1);
  }

  max_off = grid->line_offset[row] + (size_t)grid->cols;
  while (col < grid->cols
         && (len < 0 || (int)(ptr - text) < len)
         && *ptr != NUL) {
    c = *ptr;
    // check if this is the first byte of a multibyte
    if (len > 0) {
      mbyte_blen = utfc_ptr2len_len(ptr, (int)((text + len) - ptr));
    } else {
      mbyte_blen = utfc_ptr2len((char *)ptr);
    }
    if (len >= 0) {
      u8c = utfc_ptr2char_len(ptr, u8cc, (int)((text + len) - ptr));
    } else {
      u8c = utfc_ptr2char(ptr, u8cc);
    }
    mbyte_cells = utf_char2cells(u8c);
    if (p_arshape && !p_tbidi && arabic_char(u8c)) {
      // Do Arabic shaping.
      if (len >= 0 && (int)(ptr - text) + mbyte_blen >= len) {
        // Past end of string to be displayed.
        nc = NUL;
        nc1 = NUL;
      } else {
        nc = utfc_ptr2char_len(ptr + mbyte_blen, pcc,
                               (int)((text + len) - ptr - mbyte_blen));
        nc1 = pcc[0];
      }
      pc = prev_c;
      prev_c = u8c;
      u8c = arabic_shape(u8c, &c, &u8cc[0], nc, nc1, pc);
    } else {
      prev_c = u8c;
    }
    if (col + mbyte_cells > grid->cols) {
      // Only 1 cell left, but character requires 2 cells:
      // display a '>' in the last column to avoid wrapping. */
      c = '>';
      u8c = '>';
      u8cc[0] = 0;
      mbyte_cells = 1;
    }

    schar_T buf;
    schar_from_cc(buf, u8c, u8cc);

    need_redraw = schar_cmp(grid->chars[off], buf)
                  || (mbyte_cells == 2 && grid->chars[off + 1][0] != 0)
                  || grid->attrs[off] != attr
                  || exmode_active;

    if (need_redraw) {
      // When at the end of the text and overwriting a two-cell
      // character with a one-cell character, need to clear the next
      // cell.  Also when overwriting the left half of a two-cell char
      // with the right half of a two-cell char.  Do this only once
      // (utf8_off2cells() may return 2 on the right half).
      if (clear_next_cell) {
        clear_next_cell = false;
      } else if ((len < 0 ? ptr[mbyte_blen] == NUL : ptr + mbyte_blen >= text + len)
                 && ((mbyte_cells == 1
                      && grid_off2cells(grid, off, max_off) > 1)
                     || (mbyte_cells == 2
                         && grid_off2cells(grid, off, max_off) == 1
                         && grid_off2cells(grid, off + 1, max_off) > 1))) {
        clear_next_cell = true;
      }

      // When at the start of the text and overwriting the right half of a
      // two-cell character in the same grid, truncate that into a '>'.
      if (ptr == text && col > 0 && grid->chars[off][0] == 0) {
        grid->chars[off - 1][0] = '>';
        grid->chars[off - 1][1] = 0;
      }

      schar_copy(grid->chars[off], buf);
      grid->attrs[off] = attr;
      if (mbyte_cells == 2) {
        grid->chars[off + 1][0] = 0;
        grid->attrs[off + 1] = attr;
      }
      put_dirty_first = MIN(put_dirty_first, col);
      put_dirty_last = MAX(put_dirty_last, col + mbyte_cells);
    }

    off += (size_t)mbyte_cells;
    col += mbyte_cells;
    ptr += mbyte_blen;
    if (clear_next_cell) {
      // This only happens at the end, display one space next.
      ptr = (char_u *)" ";
      len = -1;
    }
  }

  if (do_flush) {
    grid_puts_line_flush(true);
  }
}

/// End a group of grid_puts_len calls and send the screen buffer to the UI
/// layer.
///
/// @param set_cursor Move the visible cursor to the end of the changed region.
///                   This is a workaround for not yet refactored code paths
///                   and shouldn't be used in new code.
void grid_puts_line_flush(bool set_cursor)
{
  assert(put_dirty_row != -1);
  if (put_dirty_first < put_dirty_last) {
    if (set_cursor) {
      ui_grid_cursor_goto(put_dirty_grid->handle, put_dirty_row,
                          MIN(put_dirty_last, put_dirty_grid->cols - 1));
    }
    if (!put_dirty_grid->throttled) {
      ui_line(put_dirty_grid, put_dirty_row, put_dirty_first, put_dirty_last,
              put_dirty_last, 0, false);
    } else if (put_dirty_grid->dirty_col) {
      if (put_dirty_last > put_dirty_grid->dirty_col[put_dirty_row]) {
        put_dirty_grid->dirty_col[put_dirty_row] = put_dirty_last;
      }
    }
    put_dirty_first = INT_MAX;
    put_dirty_last = 0;
  }
  put_dirty_row = -1;
  put_dirty_grid = NULL;
}

/// Fill the grid from "start_row" to "end_row" (exclusive), from "start_col"
/// to "end_col" (exclusive) with character "c1" in first column followed by
/// "c2" in the other columns.  Use attributes "attr".
void grid_fill(ScreenGrid *grid, int start_row, int end_row, int start_col, int end_col, int c1,
               int c2, int attr)
{
  schar_T sc;

  int row_off = 0, col_off = 0;
  grid_adjust(&grid, &row_off, &col_off);
  start_row += row_off;
  end_row += row_off;
  start_col += col_off;
  end_col += col_off;

  // safety check
  if (end_row > grid->rows) {
    end_row = grid->rows;
  }
  if (end_col > grid->cols) {
    end_col = grid->cols;
  }

  // nothing to do
  if (start_row >= end_row || start_col >= end_col) {
    return;
  }

  for (int row = start_row; row < end_row; row++) {
    // When drawing over the right half of a double-wide char clear
    // out the left half.  When drawing over the left half of a
    // double wide-char clear out the right half.  Only needed in a
    // terminal.
    if (start_col > 0 && grid_fix_col(grid, start_col, row) != start_col) {
      grid_puts_len(grid, (char_u *)" ", 1, row, start_col - 1, 0);
    }
    if (end_col < grid->cols
        && grid_fix_col(grid, end_col, row) != end_col) {
      grid_puts_len(grid, (char_u *)" ", 1, row, end_col, 0);
    }

    // if grid was resized (in ext_multigrid mode), the UI has no redraw updates
    // for the newly resized grid. It is better mark everything as dirty and
    // send all the updates.
    int dirty_first = INT_MAX;
    int dirty_last = 0;

    int col = start_col;
    schar_from_char(sc, c1);
    size_t lineoff = grid->line_offset[row];
    for (col = start_col; col < end_col; col++) {
      size_t off = lineoff + (size_t)col;
      if (schar_cmp(grid->chars[off], sc)
          || grid->attrs[off] != attr) {
        schar_copy(grid->chars[off], sc);
        grid->attrs[off] = attr;
        if (dirty_first == INT_MAX) {
          dirty_first = col;
        }
        dirty_last = col + 1;
      }
      if (col == start_col) {
        schar_from_char(sc, c2);
      }
    }
    if (dirty_last > dirty_first) {
      // TODO(bfredl): support a cleared suffix even with a batched line?
      if (put_dirty_row == row) {
        put_dirty_first = MIN(put_dirty_first, dirty_first);
        put_dirty_last = MAX(put_dirty_last, dirty_last);
      } else if (grid->throttled) {
        // Note: assumes msg_grid is the only throttled grid
        assert(grid == &msg_grid);
        int dirty = 0;
        if (attr != HL_ATTR(HLF_MSG) || c2 != ' ') {
          dirty = dirty_last;
        } else if (c1 != ' ') {
          dirty = dirty_first + 1;
        }
        if (grid->dirty_col && dirty > grid->dirty_col[row]) {
          grid->dirty_col[row] = dirty;
        }
      } else {
        int last = c2 != ' ' ? dirty_last : dirty_first + (c1 != ' ');
        ui_line(grid, row, dirty_first, last, dirty_last, attr, false);
      }
    }

    if (end_col == grid->cols) {
      grid->line_wraps[row] = false;
    }
  }
}

/// Check whether the given character needs redrawing:
/// - the (first byte of the) character is different
/// - the attributes are different
/// - the character is multi-byte and the next byte is different
/// - the character is two cells wide and the second cell differs.
static int grid_char_needs_redraw(ScreenGrid *grid, size_t off_from, size_t off_to, int cols)
{
  return (cols > 0
          && ((schar_cmp(linebuf_char[off_from], grid->chars[off_to])
               || linebuf_attr[off_from] != grid->attrs[off_to]
               || (line_off2cells(linebuf_char, off_from, off_from + (size_t)cols) > 1
                   && schar_cmp(linebuf_char[off_from + 1],
                                grid->chars[off_to + 1])))
              || rdb_flags & RDB_NODELTA));
}

/// Move one buffered line to the window grid, but only the characters that
/// have actually changed.  Handle insert/delete character.
/// "coloff" gives the first column on the grid for this line.
/// "endcol" gives the columns where valid characters are.
/// "clear_width" is the width of the window.  It's > 0 if the rest of the line
/// needs to be cleared, negative otherwise.
/// "rlflag" is TRUE in a rightleft window:
///    When TRUE and "clear_width" > 0, clear columns 0 to "endcol"
///    When FALSE and "clear_width" > 0, clear columns "endcol" to "clear_width"
/// If "wrap" is true, then hint to the UI that "row" contains a line
/// which has wrapped into the next row.
void grid_put_linebuf(ScreenGrid *grid, int row, int coloff, int endcol, int clear_width,
                      int rlflag, win_T *wp, int bg_attr, bool wrap)
{
  size_t max_off_from;
  size_t max_off_to;
  int col = 0;
  bool redraw_this;                         // Does character need redraw?
  bool redraw_next;                         // redraw_this for next character
  bool clear_next = false;
  int char_cells;                           // 1: normal char
                                            // 2: occupies two display cells
  int start_dirty = -1, end_dirty = 0;

  // TODO(bfredl): check all callsites and eliminate
  // Check for illegal row and col, just in case
  if (row >= grid->rows) {
    row = grid->rows - 1;
  }
  if (endcol > grid->cols) {
    endcol = grid->cols;
  }

  grid_adjust(&grid, &row, &coloff);

  // Safety check. Avoids clang warnings down the call stack.
  if (grid->chars == NULL || row >= grid->rows || coloff >= grid->cols) {
    DLOG("invalid state, skipped");
    return;
  }

  size_t off_from = 0;
  size_t off_to = grid->line_offset[row] + (size_t)coloff;
  max_off_from = linebuf_size;
  max_off_to = grid->line_offset[row] + (size_t)grid->cols;

  if (rlflag) {
    // Clear rest first, because it's left of the text.
    if (clear_width > 0) {
      while (col <= endcol && grid->chars[off_to][0] == ' '
             && grid->chars[off_to][1] == NUL
             && grid->attrs[off_to] == bg_attr) {
        off_to++;
        col++;
      }
      if (col <= endcol) {
        grid_fill(grid, row, row + 1, col + coloff, endcol + coloff + 1, ' ', ' ', bg_attr);
      }
    }
    col = endcol + 1;
    off_to = grid->line_offset[row] + (size_t)col + (size_t)coloff;
    off_from += (size_t)col;
    endcol = (clear_width > 0 ? clear_width : -clear_width);
  }

  if (bg_attr) {
    for (int c = col; c < endcol; c++) {
      linebuf_attr[off_from + (size_t)c] =
        hl_combine_attr(bg_attr, linebuf_attr[off_from + (size_t)c]);
    }
  }

  redraw_next = grid_char_needs_redraw(grid, off_from, off_to, endcol - col);

  while (col < endcol) {
    char_cells = 1;
    if (col + 1 < endcol) {
      char_cells = line_off2cells(linebuf_char, off_from, max_off_from);
    }
    redraw_this = redraw_next;
    redraw_next = grid_char_needs_redraw(grid, off_from + (size_t)char_cells,
                                         off_to + (size_t)char_cells,
                                         endcol - col - char_cells);

    if (redraw_this) {
      if (start_dirty == -1) {
        start_dirty = col;
      }
      end_dirty = col + char_cells;
      // When writing a single-width character over a double-width
      // character and at the end of the redrawn text, need to clear out
      // the right half of the old character.
      // Also required when writing the right half of a double-width
      // char over the left half of an existing one
      if (col + char_cells == endcol
          && ((char_cells == 1
               && grid_off2cells(grid, off_to, max_off_to) > 1)
              || (char_cells == 2
                  && grid_off2cells(grid, off_to, max_off_to) == 1
                  && grid_off2cells(grid, off_to + 1, max_off_to) > 1))) {
        clear_next = true;
      }

      schar_copy(grid->chars[off_to], linebuf_char[off_from]);
      if (char_cells == 2) {
        schar_copy(grid->chars[off_to + 1], linebuf_char[off_from + 1]);
      }

      grid->attrs[off_to] = linebuf_attr[off_from];
      // For simplicity set the attributes of second half of a
      // double-wide character equal to the first half.
      if (char_cells == 2) {
        grid->attrs[off_to + 1] = linebuf_attr[off_from];
      }
    }

    off_to += (size_t)char_cells;
    off_from += (size_t)char_cells;
    col += char_cells;
  }

  if (clear_next) {
    // Clear the second half of a double-wide character of which the left
    // half was overwritten with a single-wide character.
    schar_from_ascii(grid->chars[off_to], ' ');
    end_dirty++;
  }

  int clear_end = -1;
  if (clear_width > 0 && !rlflag) {
    // blank out the rest of the line
    // TODO(bfredl): we could cache winline widths
    while (col < clear_width) {
      if (grid->chars[off_to][0] != ' '
          || grid->chars[off_to][1] != NUL
          || grid->attrs[off_to] != bg_attr) {
        grid->chars[off_to][0] = ' ';
        grid->chars[off_to][1] = NUL;
        grid->attrs[off_to] = bg_attr;
        if (start_dirty == -1) {
          start_dirty = col;
          end_dirty = col;
        } else if (clear_end == -1) {
          end_dirty = endcol;
        }
        clear_end = col + 1;
      }
      col++;
      off_to++;
    }
  }

  if (clear_width > 0 || wp->w_width != grid->cols) {
    // If we cleared after the end of the line, it did not wrap.
    // For vsplit, line wrapping is not possible.
    grid->line_wraps[row] = false;
  }

  if (clear_end < end_dirty) {
    clear_end = end_dirty;
  }
  if (start_dirty == -1) {
    start_dirty = end_dirty;
  }
  if (clear_end > start_dirty) {
    ui_line(grid, row, coloff + start_dirty, coloff + end_dirty, coloff + clear_end,
            bg_attr, wrap);
  }
}

void grid_alloc(ScreenGrid *grid, int rows, int columns, bool copy, bool valid)
{
  int new_row;
  ScreenGrid new = *grid;
  assert(rows >= 0 && columns >= 0);
  size_t ncells = (size_t)rows * (size_t)columns;
  new.chars = xmalloc(ncells * sizeof(schar_T));
  new.attrs = xmalloc(ncells * sizeof(sattr_T));
  new.line_offset = xmalloc((size_t)rows * sizeof(*new.line_offset));
  new.line_wraps = xmalloc((size_t)rows * sizeof(*new.line_wraps));

  new.rows = rows;
  new.cols = columns;

  for (new_row = 0; new_row < new.rows; new_row++) {
    new.line_offset[new_row] = (size_t)new_row * (size_t)new.cols;
    new.line_wraps[new_row] = false;

    grid_clear_line(&new, new.line_offset[new_row], columns, valid);

    if (copy) {
      // If the screen is not going to be cleared, copy as much as
      // possible from the old screen to the new one and clear the rest
      // (used when resizing the window at the "--more--" prompt or when
      // executing an external command, for the GUI).
      if (new_row < grid->rows && grid->chars != NULL) {
        int len = MIN(grid->cols, new.cols);
        memmove(new.chars + new.line_offset[new_row],
                grid->chars + grid->line_offset[new_row],
                (size_t)len * sizeof(schar_T));
        memmove(new.attrs + new.line_offset[new_row],
                grid->attrs + grid->line_offset[new_row],
                (size_t)len * sizeof(sattr_T));
      }
    }
  }
  grid_free(grid);
  *grid = new;

  // Share a single scratch buffer for all grids, by
  // ensuring it is as wide as the widest grid.
  if (linebuf_size < (size_t)columns) {
    xfree(linebuf_char);
    xfree(linebuf_attr);
    linebuf_char = xmalloc((size_t)columns * sizeof(schar_T));
    linebuf_attr = xmalloc((size_t)columns * sizeof(sattr_T));
    linebuf_size = (size_t)columns;
  }
}

void grid_free(ScreenGrid *grid)
{
  xfree(grid->chars);
  xfree(grid->attrs);
  xfree(grid->line_offset);
  xfree(grid->line_wraps);

  grid->chars = NULL;
  grid->attrs = NULL;
  grid->line_offset = NULL;
  grid->line_wraps = NULL;
}

/// Doesn't allow reinit, so must only be called by free_all_mem!
void grid_free_all_mem(void)
{
  grid_free(&default_grid);
  xfree(linebuf_char);
  xfree(linebuf_attr);
}

/// (Re)allocates a window grid if size changed while in ext_multigrid mode.
/// Updates size, offsets and handle for the grid regardless.
///
/// If "doclear" is true, don't try to copy from the old grid rather clear the
/// resized grid.
void win_grid_alloc(win_T *wp)
{
  ScreenGrid *grid = &wp->w_grid;
  ScreenGrid *grid_allocated = &wp->w_grid_alloc;

  int rows = wp->w_height_inner;
  int cols = wp->w_width_inner;
  int total_rows = wp->w_height_outer;
  int total_cols = wp->w_width_outer;

  bool want_allocation = ui_has(kUIMultigrid) || wp->w_floating;
  bool has_allocation = (grid_allocated->chars != NULL);

  if (grid->rows != rows) {
    wp->w_lines_valid = 0;
    xfree(wp->w_lines);
    wp->w_lines = xcalloc((size_t)rows + 1, sizeof(wline_T));
  }

  int was_resized = false;
  if (want_allocation && (!has_allocation
                          || grid_allocated->rows != total_rows
                          || grid_allocated->cols != total_cols)) {
    grid_alloc(grid_allocated, total_rows, total_cols,
               wp->w_grid_alloc.valid, false);
    grid_allocated->valid = true;
    if (wp->w_floating && wp->w_float_config.border) {
      wp->w_redr_border = true;
    }
    was_resized = true;
  } else if (!want_allocation && has_allocation) {
    // Single grid mode, all rendering will be redirected to default_grid.
    // Only keep track of the size and offset of the window.
    grid_free(grid_allocated);
    grid_allocated->valid = false;
    was_resized = true;
  } else if (want_allocation && has_allocation && !wp->w_grid_alloc.valid) {
    grid_invalidate(grid_allocated);
    grid_allocated->valid = true;
  }

  grid->rows = rows;
  grid->cols = cols;

  if (want_allocation) {
    grid->target = grid_allocated;
    grid->row_offset = wp->w_winrow_off;
    grid->col_offset = wp->w_wincol_off;
  } else {
    grid->target = &default_grid;
    grid->row_offset = wp->w_winrow + wp->w_winrow_off;
    grid->col_offset = wp->w_wincol + wp->w_wincol_off;
  }

  // send grid resize event if:
  // - a grid was just resized
  // - screen_resize was called and all grid sizes must be sent
  // - the UI wants multigrid event (necessary)
  if ((resizing_screen || was_resized) && want_allocation) {
    ui_call_grid_resize(grid_allocated->handle,
                        grid_allocated->cols, grid_allocated->rows);
  }
}

/// assign a handle to the grid. The grid need not be allocated.
void grid_assign_handle(ScreenGrid *grid)
{
  static int last_grid_handle = DEFAULT_GRID_HANDLE;

  // only assign a grid handle if not already
  if (grid->handle == 0) {
    grid->handle = ++last_grid_handle;
  }
}
