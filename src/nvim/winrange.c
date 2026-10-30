// A window kept to a range of its buffer's lines (|nvim_win_set_range()|):
// it shows and edits only those lines, while its buffer stays whole (a
// language server, a write, other windows see all of it).
//
// The range is an extmark of the buffer, so it follows the edits: lines
// added in it, or right after its last, grow it; one that ends on the
// buffer's last line runs to the buffer's end (lines appended are its). The cursor is put back in
// it after each Normal-mode command (before an operator works on the
// motion's text) and in Insert mode; the view never starts above it.

#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/cursor.h"
#include "nvim/decoration_defs.h"
#include "nvim/extmark.h"
#include "nvim/marktree.h"
#include "nvim/memline.h"
#include "nvim/move.h"
#include "nvim/pos_defs.h"
#include "nvim/winrange.h"

#include "winrange.c.generated.h"

/// The namespace of the windows' ranges.
static uint32_t range_ns(void)
{
  static uint32_t ns = 0;
  if (ns == 0) {
    ns = (uint32_t)nvim_create_namespace(STATIC_CSTR_AS_STRING("nvim.win_range"));
  }
  return ns;
}

/// The lines window `wp` is kept to, if it is: `*top`..`*bot` (from 1).
bool win_range(win_T *wp, linenr_T *top, linenr_T *bot)
{
  if (wp->w_range_mark == 0 || wp->w_range_buf != wp->w_buffer->handle) {
    return false;
  }
  MTPair p = extmark_from_id(wp->w_buffer, range_ns(), wp->w_range_mark);
  if (!p.start.id) {
    return false;
  }
  linenr_T count = wp->w_buffer->b_ml.ml_line_count;
  // The end is the start of the line after the last one (lines opened
  // there move it down), else the end of the buffer's last line.
  linenr_T last = p.end_pos.col == 0 && p.end_pos.row > p.start.pos.row
                  ? (linenr_T)p.end_pos.row : (linenr_T)p.end_pos.row + 1;
  *top = MIN((linenr_T)p.start.pos.row + 1, count);
  *bot = wp->w_range_to_end ? count : MIN(MAX(last, *top), count);
  return true;
}

/// Keeps window `wp` to rows `srow`..`erow` (from 0) of its buffer.
void win_range_set(win_T *wp, int srow, int erow, Error *err)
{
  buf_T *buf = wp->w_buffer;
  linenr_T count = buf->b_ml.ml_line_count;
  if (srow < 0 || erow < srow || erow >= count) {
    api_set_error(err, kErrorTypeValidation, "Invalid range: %d..%d (the buffer has %d lines)",
                  srow, erow, (int)count);
    return;
  }
  if (wp->w_range_buf != buf->handle) {
    win_range_del(wp);
  }
  uint32_t id = wp->w_range_mark;
  // The start stays before text inserted at it. The end is the start of the
  // line after the last one, and moves with text added there: a line opened
  // after the last one ("o") grows the range. On the buffer's last line, its
  // end.
  bool at_end = erow + 1 >= count;
  int end_row = at_end ? erow : erow + 1;
  colnr_T end_col = at_end ? ml_get_buf_len(buf, (linenr_T)erow + 1) : 0;
  extmark_set(buf, range_ns(), &id, srow, 0, end_row, end_col, (DecorInline)DECOR_INLINE_INIT, 0,
              false, true, true, false, err);
  if (ERROR_SET(err)) {
    return;
  }
  wp->w_range_mark = id;
  wp->w_range_buf = buf->handle;
  wp->w_range_to_end = at_end;
  win_range_clamp(wp);
}

/// Window `wp` no longer kept to a range.
void win_range_del(win_T *wp)
{
  if (wp->w_range_mark == 0) {
    return;
  }
  buf_T *buf = handle_get_buffer(wp->w_range_buf);
  if (buf != NULL) {
    extmark_del_id(buf, range_ns(), wp->w_range_mark);
  }
  wp->w_range_mark = 0;
  wp->w_range_buf = 0;
  wp->w_range_to_end = false;
}

/// The cursor of window `wp` back in its range, the view not above it.
void win_range_clamp(win_T *wp)
{
  linenr_T top, bot;
  if (!win_range(wp, &top, &bot)) {
    return;
  }
  if (wp->w_cursor.lnum < top || wp->w_cursor.lnum > bot) {
    wp->w_cursor.lnum = wp->w_cursor.lnum < top ? top : bot;
    check_cursor_col(wp);
  }
  if (wp->w_topline < top) {
    set_topline(wp, top);
  }
}
