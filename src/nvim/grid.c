// Low-level functions to manipulate individual character cells on the
// screen grid.
//
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
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/decoration.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/log.h"
#include "nvim/map_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"

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

schar_T schar_from_str(const char *str)
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
    schar_cache_clear();
    return true;
  }
  return false;
}

void schar_cache_clear(void)
{
  decor_check_invalid_glyphs();
  set_clear(glyph, &glyph_cache);

  // for char options we have stored the original strings. Regenerate
  // the parsed schar_T values with the new clean cache.
  // This must not return an error as cell widths have not changed.
  if (check_chars_options()) {
    abort();
  }
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

/// sets final NUL
size_t schar_get(char *buf_out, schar_T sc)
{
  size_t len = schar_get_adv(&buf_out, sc);
  *buf_out = NUL;
  return len;
}

/// advance buf_out. do NOT set final NUL
size_t schar_get_adv(char **buf_out, schar_T sc)
{
  size_t len;
  if (schar_high(sc)) {
    uint32_t idx = schar_idx(sc);
    assert(idx < glyph_cache.h.n_keys);
    len = strlen(&glyph_cache.keys[idx]);
    memcpy(*buf_out, &glyph_cache.keys[idx], len);
  } else {
    len = strnlen((char *)&sc, 4);
    memcpy(*buf_out, (char *)&sc, len);
  }
  *buf_out += len;
  return len;
}

size_t schar_len(schar_T sc)
{
  if (schar_high(sc)) {
    uint32_t idx = schar_idx(sc);
    assert(idx < glyph_cache.h.n_keys);
    return strlen(&glyph_cache.keys[idx]);
  } else {
    return strnlen((char *)&sc, 4);
  }
}

int schar_cells(schar_T sc)
{
  // hot path
#ifdef ORDER_BIG_ENDIAN
  if (!(sc & 0x80FFFFFF)) {
    return 1;
  }
#else
  if (sc < 0x80) {
    return 1;
  }
#endif

  char sc_buf[MAX_SCHAR_SIZE];
  schar_get(sc_buf, sc);
  return utf_ptr2cells(sc_buf);
}

/// gets first raw UTF-8 byte of an schar
static char schar_get_first_byte(schar_T sc)
{
  assert(!(schar_high(sc) && schar_idx(sc) >= glyph_cache.h.n_keys));
  return schar_high(sc) ? glyph_cache.keys[schar_idx(sc)] : *(char *)&sc;
}

int schar_get_first_codepoint(schar_T sc)
{
  char sc_buf[MAX_SCHAR_SIZE];
  schar_get(sc_buf, sc);
  return utf_ptr2char(sc_buf);
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
    size_t len = (size_t)utf_char2bytes(c0new, scbuf_new);
    if (c1new) {
      len += (size_t)utf_char2bytes(c1new, scbuf_new + len);
    }

    int off = utf_char2len(c0) + (c1 ? utf_char2len(c1) : 0);
    size_t rest = strlen(scbuf + off);
    if (rest + len + 1 > MAX_SCHAR_SIZE) {
      // Too bigly, discard one code-point.
      // This should be enough as c0 cannot grow more than from 2 to 4 bytes
      // (base arabic to extended arabic)
      rest -= (size_t)utf_cp_bounds(scbuf + off, scbuf + off + rest - 1).begin_off + 1;
    }
    memcpy(scbuf_new + len, scbuf + off, rest);
    buf[i] = schar_from_buf(scbuf_new, len + rest);

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
  memset(grid->attrs + off, fill, (size_t)width * sizeof(sattr_T));
  memset(grid->vcols + off, -1, (size_t)width * sizeof(colnr_T));
}

void grid_invalidate(ScreenGrid *grid)
{
  memset(grid->attrs, -1, sizeof(sattr_T) * (size_t)grid->rows * (size_t)grid->cols);
}

static bool grid_invalid_row(ScreenGrid *grid, int row)
{
  return grid->attrs[grid->line_offset[row]] < 0;
}

/// Get a single character directly from grid.chars
///
/// @param[out] attrp  set to the character's attribute (optional)
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
static int grid_line_clear_to = 0;
static int grid_line_clear_attr = 0;
static int grid_line_flags = 0;

/// Start a group of grid_line_puts calls that builds a single grid line.
///
/// Must be matched with a grid_line_flush call before moving to
/// another line.
void grid_line_start(ScreenGrid *grid, int row)
{
  int col = 0;
  grid_line_maxcol = grid->cols;
  grid_adjust(&grid, &row, &col);
  assert(grid_line_grid == NULL);
  grid_line_row = row;
  grid_line_grid = grid;
  grid_line_coloff = col;
  grid_line_first = (int)linebuf_size;
  grid_line_maxcol = MIN(grid_line_maxcol, grid->cols - grid_line_coloff);
  grid_line_last = 0;
  grid_line_clear_to = 0;
  grid_line_clear_attr = 0;
  grid_line_flags = 0;

  assert((size_t)grid_line_maxcol <= linebuf_size);

  if (rdb_flags & kOptRdbFlagInvalid) {
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
  if (col >= grid_line_maxcol) {
    return;
  }

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

  assert(grid_line_grid);

  int start_col = col;

  const int max_col = grid_line_maxcol;
  while (col < max_col && (len < 0 || (int)(ptr - text) < len) && *ptr != NUL) {
    // check if this is the first byte of a multibyte
    int mbyte_blen;
    if (len >= 0) {
      int maxlen = (int)((text + len) - ptr);
      mbyte_blen = utfc_ptr2len_len(ptr, maxlen);
      if (mbyte_blen > maxlen) {
        mbyte_blen = 1;
      }
    } else {
      mbyte_blen = utfc_ptr2len(ptr);
    }
    int firstc;
    schar_T schar = utfc_ptrlen2schar(ptr, mbyte_blen, &firstc);
    int mbyte_cells = utf_ptr2cells_len(ptr, mbyte_blen);
    if (mbyte_cells > 2 || schar == 0) {
      mbyte_cells = 1;
      schar = schar_from_char(0xFFFD);
    }

    if (col + mbyte_cells > max_col) {
      // Only 1 cell left, but character requires 2 cells:
      // display a '>' in the last column to avoid wrapping.
      schar = schar_from_ascii('>');
      mbyte_cells = 1;
    }

    // When at the start of the text and overwriting the right half of a
    // two-cell character in the same grid, truncate that into a '>'.
    if (ptr == text && col > grid_line_first && col < grid_line_last
        && linebuf_char[col] == 0) {
      linebuf_char[col - 1] = schar_from_ascii('>');
    }

    linebuf_char[col] = schar;
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

int grid_line_fill(int start_col, int end_col, schar_T sc, int attr)
{
  end_col = MIN(end_col, grid_line_maxcol);
  if (start_col >= end_col) {
    return end_col;
  }

  for (int col = start_col; col < end_col; col++) {
    linebuf_char[col] = sc;
    linebuf_attr[col] = attr;
    linebuf_vcol[col] = -1;
  }

  grid_line_first = MIN(grid_line_first, start_col);
  grid_line_last = MAX(grid_line_last, end_col);
  return end_col;
}

void grid_line_clear_end(int start_col, int end_col, int attr)
{
  if (grid_line_first > start_col) {
    grid_line_first = start_col;
    grid_line_last = start_col;
  }
  grid_line_clear_to = end_col;
  grid_line_clear_attr = attr;
}

/// move the cursor to a position in a currently rendered line.
void grid_line_cursor_goto(int col)
{
  ui_grid_cursor_goto(grid_line_grid->handle, grid_line_row, col);
}

void grid_line_mirror(void)
{
  grid_line_clear_to = MAX(grid_line_last, grid_line_clear_to);
  if (grid_line_first >= grid_line_clear_to) {
    return;
  }
  linebuf_mirror(&grid_line_first, &grid_line_last, &grid_line_clear_to, grid_line_maxcol);
  grid_line_flags |= SLF_RIGHTLEFT;
}

void linebuf_mirror(int *firstp, int *lastp, int *clearp, int maxcol)
{
  int first = *firstp;
  int last = *lastp;

  size_t n = (size_t)(last - first);
  int mirror = maxcol - 1;  // Mirrors are more fun than television.
  schar_T *scratch_char = (schar_T *)linebuf_scratch;
  memcpy(scratch_char + first, linebuf_char + first, n * sizeof(schar_T));
  for (int col = first; col < last; col++) {
    int rev = mirror - col;
    if (col + 1 < last && scratch_char[col + 1] == 0) {
      linebuf_char[rev - 1] = scratch_char[col];
      linebuf_char[rev] = 0;
      col++;
    } else {
      linebuf_char[rev] = scratch_char[col];
    }
  }

  // for attr and vcol: assumes doublewidth chars are self-consistent
  sattr_T *scratch_attr = (sattr_T *)linebuf_scratch;
  memcpy(scratch_attr + first, linebuf_attr + first, n * sizeof(sattr_T));
  for (int col = first; col < last; col++) {
    linebuf_attr[mirror - col] = scratch_attr[col];
  }

  colnr_T *scratch_vcol = (colnr_T *)linebuf_scratch;
  memcpy(scratch_vcol + first, linebuf_vcol + first, n * sizeof(colnr_T));
  for (int col = first; col < last; col++) {
    linebuf_vcol[mirror - col] = scratch_vcol[col];
  }

  *firstp = maxcol - *clearp;
  *clearp = maxcol - first;
  *lastp = maxcol - last;
}

/// End a group of grid_line_puts calls and send the screen buffer to the UI layer.
void grid_line_flush(void)
{
  ScreenGrid *grid = grid_line_grid;
  grid_line_grid = NULL;
  grid_line_clear_to = MAX(grid_line_last, grid_line_clear_to);
  assert(grid_line_clear_to <= grid_line_maxcol);
  if (grid_line_first >= grid_line_clear_to) {
    return;
  }

  grid_put_linebuf(grid, grid_line_row, grid_line_coloff, grid_line_first, grid_line_last,
                   grid_line_clear_to, grid_line_clear_attr, -1, grid_line_flags);
}

/// flush grid line but only if on a valid row
///
/// This is a stopgap until message.c has been refactored to behave
void grid_line_flush_if_valid_row(void)
{
  if (grid_line_row < 0 || grid_line_row >= grid_line_grid->rows) {
    if (rdb_flags & kOptRdbFlagInvalid) {
      abort();
    } else {
      grid_line_grid = NULL;
      return;
    }
  }
  grid_line_flush();
}

void grid_clear(ScreenGrid *grid, int start_row, int end_row, int start_col, int end_col, int attr)
{
  for (int row = start_row; row < end_row; row++) {
    grid_line_start(grid, row);
    end_col = MIN(end_col, grid_line_maxcol);
    if (grid_line_row >= grid_line_grid->rows || start_col >= end_col) {
      grid_line_grid = NULL;  // TODO(bfredl): make callers behave instead
      return;
    }
    grid_line_clear_end(start_col, end_col, attr);
    grid_line_flush();
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
              || rdb_flags & kOptRdbFlagNodelta));
}

/// Move one buffered line to the window grid, but only the characters that
/// have actually changed.  Handle insert/delete character.
///
/// @param coloff  gives the first column on the grid for this line.
/// @param endcol  gives the columns where valid characters are.
/// @param clear_width  see SLF_RIGHTLEFT.
/// @param flags  can have bits:
/// - SLF_RIGHTLEFT  rightleft text, like a window with 'rightleft' option set:
///   - When false, clear columns "endcol" to "clear_width".
///   - When true, clear columns "col" to "endcol".
/// - SLF_WRAP  hint to UI that "row" contains a line wrapped into the next row.
/// - SLF_INC_VCOL:
///   - When false, use "last_vcol" for grid->vcols[] of the columns to clear.
///   - When true, use an increasing sequence starting from "last_vcol + 1" for
///     grid->vcols[] of the columns to clear.
void grid_put_linebuf(ScreenGrid *grid, int row, int coloff, int col, int endcol, int clear_width,
                      int bg_attr, colnr_T last_vcol, int flags)
{
  bool redraw_next;                         // redraw_this for next character
  bool clear_next = false;
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
    linebuf_attr[col - 1] = grid->attrs[off_to + (size_t)col - 1];
    col--;
  }

  int clear_start = endcol;
  if (flags & SLF_RIGHTLEFT) {
    clear_start = col;
    col = endcol;
    endcol = clear_width;
    clear_width = col;
  }

  if (p_arshape && !p_tbidi && endcol > col) {
    line_do_arabic_shape(linebuf_char + col, endcol - col);
  }

  if (bg_attr) {
    for (int c = col; c < endcol; c++) {
      linebuf_attr[c] = hl_combine_attr(bg_attr, linebuf_attr[c]);
    }
  }

  redraw_next = grid_char_needs_redraw(grid, col, off_to + (size_t)col, endcol - col);

  int start_dirty = -1;
  int end_dirty = 0;

  while (col < endcol) {
    int char_cells = 1;  // 1: normal char
                         // 2: occupies two display cells
    if (col + 1 < endcol && linebuf_char[col + 1] == 0) {
      char_cells = 2;
    }
    bool redraw_this = redraw_next;  // Does character need redraw?
    size_t off = off_to + (size_t)col;
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
    grid->chars[off_to + (size_t)col] = schar_from_ascii(' ');
    end_dirty++;
  }

  // When clearing the left half of a double-wide char also clear the right half.
  if (off_to + (size_t)clear_width < max_off_to
      && grid->chars[off_to + (size_t)clear_width] == 0) {
    clear_width++;
  }

  int clear_dirty_start = -1, clear_end = -1;
  if (flags & SLF_RIGHTLEFT) {
    for (col = clear_width - 1; col >= clear_start; col--) {
      size_t off = off_to + (size_t)col;
      grid->vcols[off] = (flags & SLF_INC_VCOL) ? ++last_vcol : last_vcol;
    }
  }
  // blank out the rest of the line
  // TODO(bfredl): we could cache winline widths
  for (col = clear_start; col < clear_width; col++) {
    size_t off = off_to + (size_t)col;
    if (grid->chars[off] != schar_from_ascii(' ')
        || grid->attrs[off] != bg_attr
        || rdb_flags & kOptRdbFlagNodelta) {
      grid->chars[off] = schar_from_ascii(' ');
      grid->attrs[off] = bg_attr;
      if (clear_dirty_start == -1) {
        clear_dirty_start = col;
      }
      clear_end = col + 1;
    }
    if (!(flags & SLF_RIGHTLEFT)) {
      grid->vcols[off] = (flags & SLF_INC_VCOL) ? ++last_vcol : last_vcol;
    }
  }

  if ((flags & SLF_RIGHTLEFT) && start_dirty != -1 && clear_dirty_start != -1) {
    if (grid->throttled || clear_dirty_start >= start_dirty - 5) {
      // cannot draw now or too small to be worth a separate "clear" event
      start_dirty = clear_dirty_start;
    } else {
      ui_line(grid, row, invalid_row, coloff + clear_dirty_start, coloff + clear_dirty_start,
              coloff + clear_end, bg_attr, flags & SLF_WRAP);
    }
    clear_end = end_dirty;
  } else {
    if (start_dirty == -1) {  // clear only
      start_dirty = clear_dirty_start;
      end_dirty = clear_dirty_start;
    } else if (clear_end < end_dirty) {  // put only
      clear_end = end_dirty;
    } else {
      end_dirty = endcol;
    }
  }

  if (clear_end > start_dirty) {
    if (!grid->throttled) {
      ui_line(grid, row, invalid_row, coloff + start_dirty, coloff + end_dirty, coloff + clear_end,
              bg_attr, flags & SLF_WRAP);
    } else if (grid->dirty_col) {
      // TODO(bfredl): really get rid of the extra pseudo terminal in message.c
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
    xfree(linebuf_scratch);
    linebuf_char = xmalloc((size_t)columns * sizeof(schar_T));
    linebuf_attr = xmalloc((size_t)columns * sizeof(sattr_T));
    linebuf_vcol = xmalloc((size_t)columns * sizeof(colnr_T));
    linebuf_scratch = xmalloc((size_t)columns * sizeof(sscratch_T));
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

#ifdef EXITFREE
/// Doesn't allow reinit, so must only be called by free_all_mem!
void grid_free_all_mem(void)
{
  grid_free(&default_grid);
  grid_free(&msg_grid);
  XFREE_CLEAR(msg_grid.dirty_col);
  xfree(linebuf_char);
  xfree(linebuf_attr);
  xfree(linebuf_vcol);
  xfree(linebuf_scratch);
  set_destroy(glyph, &glyph_cache);
}
#endif

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

  bool was_resized = false;
  if (want_allocation && (!has_allocation
                          || grid_allocated->rows != total_rows
                          || grid_allocated->cols != total_cols)) {
    grid_alloc(grid_allocated, total_rows, total_cols,
               wp->w_grid_alloc.valid, false);
    grid_allocated->valid = true;
    if (wp->w_floating && wp->w_config.border) {
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

/// Put a unicode character in a screen cell.
schar_T schar_from_char(int c)
{
  schar_T sc = 0;
  if (c >= 0x200000) {
    // TODO(bfredl): this must NEVER happen, even if the file contained overlong sequences
    c = 0xFFFD;
  }
  utf_char2bytes(c, (char *)&sc);
  return sc;
}
