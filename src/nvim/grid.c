// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Most of the routines in this file perform screen (grid) manipulations. The
// given operation is performed physically on the screen. The corresponding
// change is also made to the internal screen image. In this way, the editor
// anticipates the effect of editing changes on the appearance of the screen.
// That way, when we call update_screen() a complete redraw isn't usually
// necessary. Another advantage is that we can keep adding code to anticipate
// screen changes, and in the meantime, everything still works.
//
// The grid_*() functions write to the screen and handle updating grid->lines[].

#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/defs.h"
#include "nvim/arabic.h"
#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/drawscreen.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/log.h"
#include "nvim/map.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/types.h"
#include "nvim/ui.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "grid.c.generated.h"
#endif

// temporary buffer for rendering a single screenline, so it can be
// compared with previous contents to calculate smallest delta.
// Per-cell attributes
static size_t linebuf_size = 0;

// Used to cache glyphs which doesn't fit an a sizeof(schar_T) length UTF-8 string.
// Then it instead stores an index into glyph_cache.keys[] which is a flat char array.
// The hash part is used by schar_from_buf() to quickly lookup glyphs which already
// has been interned. schar_get() should used to convert a schar_T value
// back to a string buffer.
//
// The maximum byte size of a glyph is MAX_SCHAR_SIZE (including the final NUL).
static Set(glyph) glyph_cache = SET_INIT;

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
schar_T schar_from_cc(int c, int u8cc[MAX_MCO])
{
  char buf[MAX_SCHAR_SIZE];
  int len = utf_char2bytes(c, buf);
  for (int i = 0; i < MAX_MCO; i++) {
    if (u8cc[i] == 0) {
      break;
    }
    len += utf_char2bytes(u8cc[i], buf + len);
  }
  buf[len] = 0;
  return schar_from_buf(buf, (size_t)len);
}

schar_T schar_from_str(char *str)
{
  if (str == NULL) {
    return 0;
  }
  return schar_from_buf(str, strlen(str));
}

/// @param buf need not be NUL terminated, but may not contain embedded NULs.
///
/// caller must ensure len < MAX_SCHAR_SIZE (not =, as NUL needs a byte)
schar_T schar_from_buf(const char *buf, size_t len)
{
  assert(len < MAX_SCHAR_SIZE);
  if (len <= 4) {
    schar_T sc = 0;
    memcpy((char *)&sc, buf, len);
    return sc;
  } else {
    String str = { .data = (char *)buf, .size = len };

    MHPutStatus status;
    uint32_t idx = set_put_idx(glyph, &glyph_cache, str, &status);
    assert(idx < 0xFFFFFF);
#ifdef ORDER_BIG_ENDIAN
    return idx + ((uint32_t)0xFF << 24);
#else
    return 0xFF + (idx << 8);
#endif
  }
}

/// Check if cache is full, and if it is, clear it.
///
/// This should normally only be called in update_screen()
///
/// @return true if cache was clered, and all your screen buffers now are hosed
/// and you need to use UPD_CLEAR
bool schar_cache_clear_if_full(void)
{
  // note: critical max is really (1<<24)-1. This gives us some marginal
  // until next time update_screen() is called
  if (glyph_cache.h.n_keys > (1<<21)) {
    set_clear(glyph, &glyph_cache);
    return true;
  }
  return false;
}

/// For testing. The condition in schar_cache_clear_force is hard to
/// reach, so this function can be used to force a cache clear in a test.
void schar_cache_clear_force(void)
{
  set_clear(glyph, &glyph_cache);
  must_redraw = UPD_CLEAR;
}

bool schar_high(schar_T sc)
{
#ifdef ORDER_BIG_ENDIAN
  return ((sc & 0xFF000000) == 0xFF000000);
#else
  return ((sc & 0xFF) == 0xFF);
#endif
}

#ifdef ORDER_BIG_ENDIAN
# define schar_idx(sc) (sc & (0x00FFFFFF))
#else
# define schar_idx(sc) (sc >> 8)
#endif

void schar_get(char *buf_out, schar_T sc)
{
  if (schar_high(sc)) {
    uint32_t idx = schar_idx(sc);
    assert(idx < glyph_cache.h.n_keys);
    xstrlcpy(buf_out, &glyph_cache.keys[idx], 32);
  } else {
    memcpy(buf_out, (char *)&sc, 4);
    buf_out[4] = NUL;
  }
}

/// gets first raw UTF-8 byte of an schar
static char schar_get_first_byte(schar_T sc)
{
  assert(!(schar_high(sc) && schar_idx(sc) >= glyph_cache.h.n_keys));
  return schar_high(sc) ? glyph_cache.keys[schar_idx(sc)] : *(char *)&sc;
}

/// @return ascii char or NUL if not ascii
char schar_get_ascii(schar_T sc)
{
#ifdef ORDER_BIG_ENDIAN
  return (!(sc & 0x80FFFFFF)) ? *(char *)&sc : NUL;
#else
  return (sc < 0x80) ? (char)sc : NUL;
#endif
}

static bool schar_in_arabic_block(schar_T sc)
{
  char first_byte = schar_get_first_byte(sc);
  return ((uint8_t)first_byte & 0xFE) == 0xD8;
}

/// Get the first two codepoints of an schar, or NUL when not available
static void schar_get_first_two_codepoints(schar_T sc, int *c0, int *c1)
{
  char sc_buf[MAX_SCHAR_SIZE];
  schar_get(sc_buf, sc);

  *c0 = utf_ptr2char(sc_buf);
  int len = utf_ptr2len(sc_buf);
  if (*c0 == NUL) {
    *c1 = NUL;
  } else {
    *c1 = utf_ptr2char(sc_buf + len);
  }
}

void line_do_arabic_shape(schar_T *buf, int cols)
{
  int i = 0;

  for (i = 0; i < cols; i++) {
    // quickly skip over non-arabic text
    if (schar_in_arabic_block(buf[i])) {
      break;
    }
  }

  if (i == cols) {
    return;
  }

  int c0prev = 0;
  int c0, c1;
  schar_get_first_two_codepoints(buf[i], &c0, &c1);

  for (; i < cols; i++) {
    int c0next, c1next;
    schar_get_first_two_codepoints(i + 1 < cols ? buf[i + 1] : 0, &c0next, &c1next);

    if (!ARABIC_CHAR(c0)) {
      goto next;
    }

    int c1new = c1;
    int c0new = arabic_shape(c0, &c1new, c0next, c1next, c0prev);

    if (c0new == c0 && c1new == c1) {
      goto next;  // unchanged
    }

    char scbuf[MAX_SCHAR_SIZE];
    schar_get(scbuf, buf[i]);

    char scbuf_new[MAX_SCHAR_SIZE];
    int len = utf_char2bytes(c0new, scbuf_new);
    if (c1new) {
      len += utf_char2bytes(c1new, scbuf_new + len);
    }

    int off = utf_char2len(c0) + (c1 ? utf_char2len(c1) : 0);
    size_t rest = strlen(scbuf + off);
    if (rest + (size_t)off + 1 > MAX_SCHAR_SIZE) {
      // TODO(bfredl): this cannot happen just yet, as we only construct
      // schar_T values with up to MAX_MCO+1 composing codepoints. When code
      // is improved so that MAX_SCHAR_SIZE becomes the only/sharp limit,
      // we need be able to peel off a composing char which doesn't fit anymore.
      abort();
    }
    memcpy(scbuf_new + len, scbuf + off, rest);
    buf[i] = schar_from_buf(scbuf_new, (size_t)len + rest);

next:
    c0prev = c0;
    c0 = c0next;
    c1 = c1next;
  }
}

/// clear a line in the grid starting at "off" until "width" characters
/// are cleared.
void grid_clear_line(ScreenGrid *grid, size_t off, int width, bool valid)
{
  for (int col = 0; col < width; col++) {
    grid->chars[off + (size_t)col] = schar_from_ascii(' ');
  }
  int fill = valid ? 0 : -1;
  (void)memset(grid->attrs + off, fill, (size_t)width * sizeof(sattr_T));
  (void)memset(grid->vcols + off, -1, (size_t)width * sizeof(colnr_T));
}

void grid_invalidate(ScreenGrid *grid)
{
  (void)memset(grid->attrs, -1, sizeof(sattr_T) * (size_t)grid->rows * (size_t)grid->cols);
}

static bool grid_invalid_row(ScreenGrid *grid, int row)
{
  return grid->attrs[grid->line_offset[row]] < 0;
}

/// Get a single character directly from grid.chars into "bytes", which must
/// have a size of "MB_MAXBYTES + 1".
/// If "attrp" is not NULL, return the character's attribute in "*attrp".
schar_T grid_getchar(ScreenGrid *grid, int row, int col, int *attrp)
{
  grid_adjust(&grid, &row, &col);

  // safety check
  if (grid->chars == NULL || row >= grid->rows || col >= grid->cols) {
    return NUL;
  }

  size_t off = grid->line_offset[row] + (size_t)col;
  if (attrp != NULL) {
    *attrp = grid->attrs[off];
  }
  return grid->chars[off];
}

static ScreenGrid *grid_line_grid = NULL;
static int grid_line_row = -1;
static int grid_line_coloff = 0;
static int grid_line_maxcol = 0;
static int grid_line_first = INT_MAX;
static int grid_line_last = 0;

/// Start a group of grid_line_puts calls that builds a single grid line.
///
/// Must be matched with a grid_line_flush call before moving to
/// another line.
void grid_line_start(ScreenGrid *grid, int row)
{
  int col = 0;
  grid_adjust(&grid, &row, &col);
  assert(grid_line_grid == NULL);
  grid_line_row = row;
  grid_line_grid = grid;
  grid_line_coloff = col;
  grid_line_first = (int)linebuf_size;
  grid_line_maxcol = grid->cols - grid_line_coloff;
  grid_line_last = 0;

  assert((size_t)grid_line_maxcol <= linebuf_size);

  if (rdb_flags & RDB_INVALID) {
    // Current batch must not depend on previous contents of linebuf_char.
    // Set invalid values which will cause assertion failures later if they are used.
    memset(linebuf_char, 0xFF, sizeof(schar_T) * linebuf_size);
    memset(linebuf_attr, 0xFF, sizeof(sattr_T) * linebuf_size);
  }
}

/// Get present char from current rendered screen line
///
/// This indicates what already is on screen, not the pending render buffer.
///
/// @return char or space if out of bounds
schar_T grid_line_getchar(int col, int *attr)
{
  if (col < grid_line_maxcol) {
    col += grid_line_coloff;
    size_t off = grid_line_grid->line_offset[grid_line_row] + (size_t)col;
    if (attr != NULL) {
      *attr = grid_line_grid->attrs[off];
    }
    return grid_line_grid->chars[off];
  } else {
    // NUL is a very special value (right-half of double width), space is True Neutral™
    return schar_from_ascii(' ');
  }
}

void grid_line_put_schar(int col, schar_T schar, int attr)
{
  assert(grid_line_grid);

  linebuf_char[col] = schar;
  linebuf_attr[col] = attr;

  grid_line_first = MIN(grid_line_first, col);
  // TODO(bfredl): Y U NO DOUBLEWIDTH?
  grid_line_last = MAX(grid_line_last, col + 1);
  linebuf_vcol[col] = -1;
}

/// Put string "text" at "col" position relative to the grid line from the
/// recent grid_line_start() call.
///
/// @param textlen length of string or -1 to use strlen(text)
/// Note: only outputs within one row!
///
/// @return number of grid cells used
int grid_line_puts(int col, const char *text, int textlen, int attr)
{
  const char *ptr = text;
  int len = textlen;
  int u8cc[MAX_MCO];

  assert(grid_line_grid);

  int start_col = col;

  int max_col = grid_line_maxcol;
  while (col < max_col
         && (len < 0 || (int)(ptr - text) < len)
         && *ptr != NUL) {
    // check if this is the first byte of a multibyte
    int mbyte_blen = len > 0
      ? utfc_ptr2len_len(ptr, (int)((text + len) - ptr))
      : utfc_ptr2len(ptr);
    int u8c = len >= 0
      ? utfc_ptr2char_len(ptr, u8cc, (int)((text + len) - ptr))
      : utfc_ptr2char(ptr, u8cc);
    int mbyte_cells = utf_char2cells(u8c);
    if (mbyte_cells > 2) {
      mbyte_cells = 1;
      u8c = 0xFFFD;
      u8cc[0] = 0;
    }

    if (col + mbyte_cells > max_col) {
      // Only 1 cell left, but character requires 2 cells:
      // display a '>' in the last column to avoid wrapping. */
      u8c = '>';
      u8cc[0] = 0;
      mbyte_cells = 1;
    }

    schar_T buf;
    // TODO(bfredl): why not just keep the original byte sequence.
    buf = schar_from_cc(u8c, u8cc);

    // When at the start of the text and overwriting the right half of a
    // two-cell character in the same grid, truncate that into a '>'.
    if (ptr == text && col > grid_line_first && col < grid_line_last
        && linebuf_char[col] == 0) {
      linebuf_char[col - 1] = schar_from_ascii('>');
    }

    linebuf_char[col] = buf;
    linebuf_attr[col] = attr;
    linebuf_vcol[col] = -1;
    if (mbyte_cells == 2) {
      linebuf_char[col + 1] = 0;
      linebuf_attr[col + 1] = attr;
      linebuf_vcol[col + 1] = -1;
    }

    col += mbyte_cells;
    ptr += mbyte_blen;
  }

  if (col > start_col) {
    grid_line_first = MIN(grid_line_first, start_col);
    grid_line_last = MAX(grid_line_last, col);
  }

  return col - start_col;
}

void grid_line_fill(int start_col, int end_col, int c, int attr)
{
  schar_T sc = schar_from_char(c);
  for (int col = start_col; col < end_col; col++) {
    linebuf_char[col] = sc;
    linebuf_attr[col] = attr;
    linebuf_vcol[col] = -1;
  }
  if (start_col < end_col) {
    grid_line_first = MIN(grid_line_first, start_col);
    grid_line_last = MAX(grid_line_last, end_col);
  }
}

/// move the cursor to a position in a currently rendered line.
void grid_line_cursor_goto(int col)
{
  ui_grid_cursor_goto(grid_line_grid->handle, grid_line_row, col);
}

/// End a group of grid_line_puts calls and send the screen buffer to the UI layer.
void grid_line_flush(void)
{
  ScreenGrid *grid = grid_line_grid;
  grid_line_grid = NULL;
  if (!(grid_line_first < grid_line_last)) {
    return;
  }

  grid_put_linebuf(grid, grid_line_row, grid_line_coloff, grid_line_first, grid_line_last,
                   grid_line_last, false, 0, false);
}

/// flush grid line but only if on a valid row
///
/// This is a stopgap until message.c has been refactored to behave
void grid_line_flush_if_valid_row(void)
{
  if (grid_line_row < 0 || grid_line_row >= grid_line_grid->rows) {
    if (rdb_flags & RDB_INVALID) {
      abort();
    } else {
      grid_line_grid = NULL;
      return;
    }
  }
  grid_line_flush();
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
    int dirty_first = INT_MAX;
    int dirty_last = 0;
    size_t lineoff = grid->line_offset[row];

    // When drawing over the right half of a double-wide char clear
    // out the left half.  When drawing over the left half of a
    // double wide-char clear out the right half.  Only needed in a
    // terminal.
    if (start_col > 0 && grid->chars[lineoff + (size_t)start_col] == NUL) {
      size_t off = lineoff + (size_t)start_col - 1;
      grid->chars[off] = schar_from_ascii(' ');
      grid->attrs[off] = attr;
      dirty_first = start_col - 1;
    }
    if (end_col < grid->cols && grid->chars[lineoff + (size_t)end_col] == NUL) {
      size_t off = lineoff + (size_t)end_col;
      grid->chars[off] = schar_from_ascii(' ');
      grid->attrs[off] = attr;
      dirty_last = end_col + 1;
    }

    int col = start_col;
    sc = schar_from_char(c1);
    for (col = start_col; col < end_col; col++) {
      size_t off = lineoff + (size_t)col;
      if (grid->chars[off] != sc || grid->attrs[off] != attr || rdb_flags & RDB_NODELTA) {
        grid->chars[off] = sc;
        grid->attrs[off] = attr;
        if (dirty_first == INT_MAX) {
          dirty_first = col;
        }
        dirty_last = col + 1;
      }
      grid->vcols[off] = -1;
      if (col == start_col) {
        sc = schar_from_char(c2);
      }
    }
    if (dirty_last > dirty_first) {
      if (grid->throttled) {
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
  }
}

/// Check whether the given character needs redrawing:
/// - the (first byte of the) character is different
/// - the attributes are different
/// - the character is multi-byte and the next byte is different
/// - the character is two cells wide and the second cell differs.
static int grid_char_needs_redraw(ScreenGrid *grid, int col, size_t off_to, int cols)
{
  return (cols > 0
          && ((linebuf_char[col] != grid->chars[off_to]
               || linebuf_attr[col] != grid->attrs[off_to]
               || (cols > 1 && linebuf_char[col + 1] == 0
                   && linebuf_char[col + 1] != grid->chars[off_to + 1]))
              || exmode_active  // TODO(bfredl): what in the actual fuck
              || rdb_flags & RDB_NODELTA));
}

/// Move one buffered line to the window grid, but only the characters that
/// have actually changed.  Handle insert/delete character.
/// "coloff" gives the first column on the grid for this line.
/// "endcol" gives the columns where valid characters are.
/// "clear_width" is the width of the window.  It's > 0 if the rest of the line
/// needs to be cleared, negative otherwise.
/// "rl" is true for rightleft text, like a window with 'rightleft' option set
///    When true and "clear_width" > 0, clear columns 0 to "endcol"
///    When false and "clear_width" > 0, clear columns "endcol" to "clear_width"
/// If "wrap" is true, then hint to the UI that "row" contains a line
/// which has wrapped into the next row.
void grid_put_linebuf(ScreenGrid *grid, int row, int coloff, int col, int endcol, int clear_width,
                      bool rl, int bg_attr, bool wrap)
{
  bool redraw_next;                         // redraw_this for next character
  bool clear_next = false;
  int char_cells;                           // 1: normal char
                                            // 2: occupies two display cells
  assert(0 <= row && row < grid->rows);
  // TODO(bfredl): check all callsites and eliminate
  // Check for illegal col, just in case
  if (endcol > grid->cols) {
    endcol = grid->cols;
  }

  // Safety check. Avoids clang warnings down the call stack.
  if (grid->chars == NULL || row >= grid->rows || coloff >= grid->cols) {
    DLOG("invalid state, skipped");
    return;
  }

  bool invalid_row = grid != &default_grid && grid_invalid_row(grid, row) && col == 0;
  size_t off_to = grid->line_offset[row] + (size_t)coloff;
  const size_t max_off_to = grid->line_offset[row] + (size_t)grid->cols;

  // When at the start of the text and overwriting the right half of a
  // two-cell character in the same grid, truncate that into a '>'.
  if (col > 0 && grid->chars[off_to + (size_t)col] == 0) {
    linebuf_char[col - 1] = schar_from_ascii('>');
    col--;
  }

  if (rl) {
    // Clear rest first, because it's left of the text.
    if (clear_width > 0) {
      while (col <= endcol && grid->chars[off_to + (size_t)col] == schar_from_ascii(' ')
             && grid->attrs[off_to + (size_t)col] == bg_attr) {
        col++;
      }
      if (col <= endcol) {
        grid_fill(grid, row, row + 1, col + coloff, endcol + coloff + 1, ' ', ' ', bg_attr);
      }
    }
    col = endcol + 1;
    endcol = (clear_width > 0 ? clear_width : -clear_width);
  }

  if (p_arshape && !p_tbidi) {
    line_do_arabic_shape(linebuf_char + col, endcol - col);
  }

  if (bg_attr) {
    for (int c = col; c < endcol; c++) {
      linebuf_attr[c] = hl_combine_attr(bg_attr, linebuf_attr[c]);
    }
  }

  redraw_next = grid_char_needs_redraw(grid, col, (size_t)col + off_to, endcol - col);

  int start_dirty = -1, end_dirty = 0;

  while (col < endcol) {
    char_cells = 1;
    if (col + 1 < endcol && linebuf_char[col + 1] == 0) {
      char_cells = 2;
    }
    bool redraw_this = redraw_next;  // Does character need redraw?
    size_t off = (size_t)col + off_to;
    redraw_next = grid_char_needs_redraw(grid, col + char_cells,
                                         off + (size_t)char_cells,
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
      if (col + char_cells == endcol && off + (size_t)char_cells < max_off_to
          && grid->chars[off + (size_t)char_cells] == NUL) {
        clear_next = true;
      }

      grid->chars[off] = linebuf_char[col];
      if (char_cells == 2) {
        grid->chars[off + 1] = linebuf_char[col + 1];
      }

      grid->attrs[off] = linebuf_attr[col];
      // For simplicity set the attributes of second half of a
      // double-wide character equal to the first half.
      if (char_cells == 2) {
        grid->attrs[off + 1] = linebuf_attr[col];
      }
    }

    grid->vcols[off] = linebuf_vcol[col];
    if (char_cells == 2) {
      grid->vcols[off + 1] = linebuf_vcol[col + 1];
    }

    col += char_cells;
  }

  if (clear_next) {
    // Clear the second half of a double-wide character of which the left
    // half was overwritten with a single-wide character.
    grid->chars[(size_t)col + off_to] = schar_from_ascii(' ');
    end_dirty++;
  }

  int clear_end = -1;
  if (clear_width > 0 && !rl) {
    // blank out the rest of the line
    // TODO(bfredl): we could cache winline widths
    while (col < clear_width) {
      size_t off = (size_t)col + off_to;
      if (grid->chars[off] != schar_from_ascii(' ')
          || grid->attrs[off] != bg_attr
          || rdb_flags & RDB_NODELTA) {
        grid->chars[off] = schar_from_ascii(' ');
        grid->attrs[off] = bg_attr;
        if (start_dirty == -1) {
          start_dirty = col;
          end_dirty = col;
        } else if (clear_end == -1) {
          end_dirty = endcol;
        }
        clear_end = col + 1;
      }
      grid->vcols[off] = MAXCOL;
      col++;
    }
  }

  if (clear_end < end_dirty) {
    clear_end = end_dirty;
  }
  if (start_dirty == -1) {
    start_dirty = end_dirty;
  }
  if (clear_end > start_dirty) {
    if (!grid->throttled) {
      int start_pos = coloff + start_dirty;
      // When drawing over the right half of a double-wide char clear out the
      // left half.  Only needed in a terminal.
      if (invalid_row && start_pos == 0) {
        start_pos = -1;
      }
      ui_line(grid, row, start_pos, coloff + end_dirty, coloff + clear_end,
              bg_attr, wrap);
    } else if (grid->dirty_col) {
      // TODO(bfredl): really get rid of the extra psuedo terminal in message.c
      // by using a linebuf_char copy for "throttled message line"
      if (clear_end > grid->dirty_col[row]) {
        grid->dirty_col[row] = clear_end;
      }
    }
  }
}

void grid_alloc(ScreenGrid *grid, int rows, int columns, bool copy, bool valid)
{
  int new_row;
  ScreenGrid ngrid = *grid;
  assert(rows >= 0 && columns >= 0);
  size_t ncells = (size_t)rows * (size_t)columns;
  ngrid.chars = xmalloc(ncells * sizeof(schar_T));
  ngrid.attrs = xmalloc(ncells * sizeof(sattr_T));
  ngrid.vcols = xmalloc(ncells * sizeof(colnr_T));
  memset(ngrid.vcols, -1, ncells * sizeof(colnr_T));
  ngrid.line_offset = xmalloc((size_t)rows * sizeof(*ngrid.line_offset));

  ngrid.rows = rows;
  ngrid.cols = columns;

  for (new_row = 0; new_row < ngrid.rows; new_row++) {
    ngrid.line_offset[new_row] = (size_t)new_row * (size_t)ngrid.cols;

    grid_clear_line(&ngrid, ngrid.line_offset[new_row], columns, valid);

    if (copy) {
      // If the screen is not going to be cleared, copy as much as
      // possible from the old screen to the new one and clear the rest
      // (used when resizing the window at the "--more--" prompt or when
      // executing an external command, for the GUI).
      if (new_row < grid->rows && grid->chars != NULL) {
        int len = MIN(grid->cols, ngrid.cols);
        memmove(ngrid.chars + ngrid.line_offset[new_row],
                grid->chars + grid->line_offset[new_row],
                (size_t)len * sizeof(schar_T));
        memmove(ngrid.attrs + ngrid.line_offset[new_row],
                grid->attrs + grid->line_offset[new_row],
                (size_t)len * sizeof(sattr_T));
        memmove(ngrid.vcols + ngrid.line_offset[new_row],
                grid->vcols + grid->line_offset[new_row],
                (size_t)len * sizeof(colnr_T));
      }
    }
  }
  grid_free(grid);
  *grid = ngrid;

  // Share a single scratch buffer for all grids, by
  // ensuring it is as wide as the widest grid.
  if (linebuf_size < (size_t)columns) {
    xfree(linebuf_char);
    xfree(linebuf_attr);
    xfree(linebuf_vcol);
    linebuf_char = xmalloc((size_t)columns * sizeof(schar_T));
    linebuf_attr = xmalloc((size_t)columns * sizeof(sattr_T));
    linebuf_vcol = xmalloc((size_t)columns * sizeof(colnr_T));
    linebuf_size = (size_t)columns;
  }
}

void grid_free(ScreenGrid *grid)
{
  xfree(grid->chars);
  xfree(grid->attrs);
  xfree(grid->vcols);
  xfree(grid->line_offset);

  grid->chars = NULL;
  grid->attrs = NULL;
  grid->vcols = NULL;
  grid->line_offset = NULL;
}

/// Doesn't allow reinit, so must only be called by free_all_mem!
void grid_free_all_mem(void)
{
  grid_free(&default_grid);
  xfree(linebuf_char);
  xfree(linebuf_attr);
  xfree(linebuf_vcol);
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
    ui_check_cursor_grid(grid_allocated->handle);
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

/// insert lines on the screen and move the existing lines down
/// 'line_count' is the number of lines to be inserted.
/// 'end' is the line after the scrolled part. Normally it is Rows.
/// 'col' is the column from with we start inserting.
//
/// 'row', 'col' and 'end' are relative to the start of the region.
void grid_ins_lines(ScreenGrid *grid, int row, int line_count, int end, int col, int width)
{
  int j;
  unsigned temp;

  int row_off = 0;
  grid_adjust(&grid, &row_off, &col);
  row += row_off;
  end += row_off;

  if (line_count <= 0) {
    return;
  }

  // Shift line_offset[] line_count down to reflect the inserted lines.
  // Clear the inserted lines.
  for (int i = 0; i < line_count; i++) {
    if (width != grid->cols) {
      // need to copy part of a line
      j = end - 1 - i;
      while ((j -= line_count) >= row) {
        linecopy(grid, j + line_count, j, col, width);
      }
      j += line_count;
      grid_clear_line(grid, grid->line_offset[j] + (size_t)col, width, false);
    } else {
      j = end - 1 - i;
      temp = (unsigned)grid->line_offset[j];
      while ((j -= line_count) >= row) {
        grid->line_offset[j + line_count] = grid->line_offset[j];
      }
      grid->line_offset[j + line_count] = temp;
      grid_clear_line(grid, temp, grid->cols, false);
    }
  }

  if (!grid->throttled) {
    ui_call_grid_scroll(grid->handle, row, end, col, col + width, -line_count, 0);
  }
}

/// delete lines on the screen and move lines up.
/// 'end' is the line after the scrolled part. Normally it is Rows.
/// When scrolling region used 'off' is the offset from the top for the region.
/// 'row' and 'end' are relative to the start of the region.
void grid_del_lines(ScreenGrid *grid, int row, int line_count, int end, int col, int width)
{
  int j;
  unsigned temp;

  int row_off = 0;
  grid_adjust(&grid, &row_off, &col);
  row += row_off;
  end += row_off;

  if (line_count <= 0) {
    return;
  }

  // Now shift line_offset[] line_count up to reflect the deleted lines.
  // Clear the inserted lines.
  for (int i = 0; i < line_count; i++) {
    if (width != grid->cols) {
      // need to copy part of a line
      j = row + i;
      while ((j += line_count) <= end - 1) {
        linecopy(grid, j - line_count, j, col, width);
      }
      j -= line_count;
      grid_clear_line(grid, grid->line_offset[j] + (size_t)col, width, false);
    } else {
      // whole width, moving the line pointers is faster
      j = row + i;
      temp = (unsigned)grid->line_offset[j];
      while ((j += line_count) <= end - 1) {
        grid->line_offset[j - line_count] = grid->line_offset[j];
      }
      grid->line_offset[j - line_count] = temp;
      grid_clear_line(grid, temp, grid->cols, false);
    }
  }

  if (!grid->throttled) {
    ui_call_grid_scroll(grid->handle, row, end, col, col + width, line_count, 0);
  }
}

static void linecopy(ScreenGrid *grid, int to, int from, int col, int width)
{
  unsigned off_to = (unsigned)(grid->line_offset[to] + (size_t)col);
  unsigned off_from = (unsigned)(grid->line_offset[from] + (size_t)col);

  memmove(grid->chars + off_to, grid->chars + off_from, (size_t)width * sizeof(schar_T));
  memmove(grid->attrs + off_to, grid->attrs + off_from, (size_t)width * sizeof(sattr_T));
  memmove(grid->vcols + off_to, grid->vcols + off_from, (size_t)width * sizeof(colnr_T));
}

win_T *get_win_by_grid_handle(handle_T handle)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_grid_alloc.handle == handle) {
      return wp;
    }
  }
  return NULL;
}
