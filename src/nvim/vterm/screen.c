#include <stdio.h>
#include <string.h>

#include "nvim/grid.h"
#include "nvim/mbyte.h"
#include "nvim/tui/termkey/termkey.h"
#include "nvim/vterm/pen.h"
#include "nvim/vterm/screen.h"
#include "nvim/vterm/state.h"
#include "nvim/vterm/vterm.h"
#include "nvim/vterm/vterm_defs.h"
#include "nvim/vterm/vterm_internal_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "vterm/screen.c.generated.h"
#endif

#define UNICODE_SPACE 0x20
#define UNICODE_LINEFEED 0x0a

#undef DEBUG_REFLOW

static inline void clearcell(const VTermScreen *screen, ScreenCell *cell)
{
  cell->schar = 0;
  cell->pen = screen->pen;
}

ScreenCell *getcell(const VTermScreen *screen, int row, int col)
{
  if (row < 0 || row >= screen->rows) {
    return NULL;
  }
  if (col < 0 || col >= screen->cols) {
    return NULL;
  }
  return screen->buffer + (screen->cols * row) + col;
}

static ScreenCell *alloc_buffer(VTermScreen *screen, int rows, int cols)
{
  ScreenCell *new_buffer = vterm_allocator_malloc(screen->vt,
                                                  sizeof(ScreenCell) * (size_t)rows * (size_t)cols);

  for (int row = 0; row < rows; row++) {
    for (int col = 0; col < cols; col++) {
      clearcell(screen, &new_buffer[row * cols + col]);
    }
  }

  return new_buffer;
}

static void damagerect(VTermScreen *screen, VTermRect rect)
{
  VTermRect emit;

  switch (screen->damage_merge) {
  case VTERM_DAMAGE_CELL:
    // Always emit damage event
    emit = rect;
    break;

  case VTERM_DAMAGE_ROW:
    // Emit damage longer than one row. Try to merge with existing damage in the same row
    if (rect.end_row > rect.start_row + 1) {
      // Bigger than 1 line - flush existing, emit this
      vterm_screen_flush_damage(screen);
      emit = rect;
    } else if (screen->damaged.start_row == -1) {
      // None stored yet
      screen->damaged = rect;
      return;
    } else if (rect.start_row == screen->damaged.start_row) {
      // Merge with the stored line
      if (screen->damaged.start_col > rect.start_col) {
        screen->damaged.start_col = rect.start_col;
      }
      if (screen->damaged.end_col < rect.end_col) {
        screen->damaged.end_col = rect.end_col;
      }
      return;
    } else {
      // Emit the currently stored line, store a new one
      emit = screen->damaged;
      screen->damaged = rect;
    }
    break;

  case VTERM_DAMAGE_SCREEN:
  case VTERM_DAMAGE_SCROLL:
    // Never emit damage event
    if (screen->damaged.start_row == -1) {
      screen->damaged = rect;
    } else {
      rect_expand(&screen->damaged, &rect);
    }
    return;

  default:
    DEBUG_LOG("TODO: Maybe merge damage for level %d\n", screen->damage_merge);
    return;
  }

  if (screen->callbacks && screen->callbacks->damage) {
    (*screen->callbacks->damage)(emit, screen->cbdata);
  }
}

static void damagescreen(VTermScreen *screen)
{
  VTermRect rect = {
    .start_row = 0,
    .end_row = screen->rows,
    .start_col = 0,
    .end_col = screen->cols,
  };

  damagerect(screen, rect);
}

static int putglyph(VTermGlyphInfo *info, VTermPos pos, void *user)
{
  VTermScreen *screen = user;
  ScreenCell *cell = getcell(screen, pos.row, pos.col);

  if (!cell) {
    return 0;
  }

  cell->schar = info->schar;
  if (info->schar != 0) {
    cell->pen = screen->pen;
  }

  for (int col = 1; col < info->width; col++) {
    getcell(screen, pos.row, pos.col + col)->schar = (uint32_t)-1;
  }

  VTermRect rect = {
    .start_row = pos.row,
    .end_row = pos.row + 1,
    .start_col = pos.col,
    .end_col = pos.col + info->width,
  };

  cell->pen.protected_cell = info->protected_cell;
  cell->pen.dwl = info->dwl;
  cell->pen.dhl = info->dhl;

  damagerect(screen, rect);

  return 1;
}

static void sb_pushline_from_row(VTermScreen *screen, int row)
{
  VTermPos pos = { .row = row };
  for (pos.col = 0; pos.col < screen->cols; pos.col++) {
    vterm_screen_get_cell(screen, pos, screen->sb_buffer + pos.col);
  }

  (screen->callbacks->sb_pushline)(screen->cols, screen->sb_buffer, screen->cbdata);
}

static int moverect_internal(VTermRect dest, VTermRect src, void *user)
{
  VTermScreen *screen = user;

  if (screen->callbacks && screen->callbacks->sb_pushline
      && dest.start_row == 0 && dest.start_col == 0           // starts top-left corner
      && dest.end_col == screen->cols                         // full width
      && screen->buffer == screen->buffers[BUFIDX_PRIMARY]) {  // not altscreen
    for (int row = 0; row < src.start_row; row++) {
      sb_pushline_from_row(screen, row);
    }
  }

  int cols = src.end_col - src.start_col;
  int downward = src.start_row - dest.start_row;

  int init_row, test_row, inc_row;
  if (downward < 0) {
    init_row = dest.end_row - 1;
    test_row = dest.start_row - 1;
    inc_row = -1;
  } else {
    init_row = dest.start_row;
    test_row = dest.end_row;
    inc_row = +1;
  }

  for (int row = init_row; row != test_row; row += inc_row) {
    memmove(getcell(screen, row, dest.start_col),
            getcell(screen, row + downward, src.start_col),
            (size_t)cols * sizeof(ScreenCell));
  }

  return 1;
}

static int moverect_user(VTermRect dest, VTermRect src, void *user)
{
  VTermScreen *screen = user;

  if (screen->callbacks && screen->callbacks->moverect) {
    if (screen->damage_merge != VTERM_DAMAGE_SCROLL) {
      // Avoid an infinite loop
      vterm_screen_flush_damage(screen);
    }

    if ((*screen->callbacks->moverect)(dest, src, screen->cbdata)) {
      return 1;
    }
  }

  damagerect(screen, dest);

  return 1;
}

static int erase_internal(VTermRect rect, int selective, void *user)
{
  VTermScreen *screen = user;

  for (int row = rect.start_row; row < screen->state->rows && row < rect.end_row; row++) {
    const VTermLineInfo *info = vterm_state_get_lineinfo(screen->state, row);

    for (int col = rect.start_col; col < rect.end_col; col++) {
      ScreenCell *cell = getcell(screen, row, col);

      if (selective && cell->pen.protected_cell) {
        continue;
      }

      cell->schar = 0;
      cell->pen = (ScreenPen){
        // Only copy .fg and .bg; leave things like rv in reset state
        .fg = screen->pen.fg,
        .bg = screen->pen.bg,
      };
      cell->pen.dwl = info->doublewidth;
      cell->pen.dhl = info->doubleheight;
    }
  }

  return 1;
}

static int erase_user(VTermRect rect, int selective, void *user)
{
  VTermScreen *screen = user;

  damagerect(screen, rect);

  return 1;
}

static int erase(VTermRect rect, int selective, void *user)
{
  erase_internal(rect, selective, user);
  return erase_user(rect, 0, user);
}

static int scrollrect(VTermRect rect, int downward, int rightward, void *user)
{
  VTermScreen *screen = user;

  if (screen->damage_merge != VTERM_DAMAGE_SCROLL) {
    vterm_scroll_rect(rect, downward, rightward,
                      moverect_internal, erase_internal, screen);

    vterm_screen_flush_damage(screen);

    vterm_scroll_rect(rect, downward, rightward,
                      moverect_user, erase_user, screen);

    return 1;
  }

  if (screen->damaged.start_row != -1
      && !rect_intersects(&rect, &screen->damaged)) {
    vterm_screen_flush_damage(screen);
  }

  if (screen->pending_scrollrect.start_row == -1) {
    screen->pending_scrollrect = rect;
    screen->pending_scroll_downward = downward;
    screen->pending_scroll_rightward = rightward;
  } else if (rect_equal(&screen->pending_scrollrect, &rect)
             && ((screen->pending_scroll_downward == 0 && downward == 0)
                 || (screen->pending_scroll_rightward == 0 && rightward == 0))) {
    screen->pending_scroll_downward += downward;
    screen->pending_scroll_rightward += rightward;
  } else {
    vterm_screen_flush_damage(screen);

    screen->pending_scrollrect = rect;
    screen->pending_scroll_downward = downward;
    screen->pending_scroll_rightward = rightward;
  }

  vterm_scroll_rect(rect, downward, rightward,
                    moverect_internal, erase_internal, screen);

  if (screen->damaged.start_row == -1) {
    return 1;
  }

  if (rect_contains(&rect, &screen->damaged)) {
    // Scroll region entirely contains the damage; just move it
    vterm_rect_move(&screen->damaged, -downward, -rightward);
    rect_clip(&screen->damaged, &rect);
  }
  // There are a number of possible cases here, but lets restrict this to only the common case where
  // we might actually gain some performance by optimising it. Namely, a vertical scroll that neatly
  // cuts the damage region in half.
  else if (rect.start_col <= screen->damaged.start_col
           && rect.end_col >= screen->damaged.end_col
           && rightward == 0) {
    if (screen->damaged.start_row >= rect.start_row
        && screen->damaged.start_row < rect.end_row) {
      screen->damaged.start_row -= downward;
      if (screen->damaged.start_row < rect.start_row) {
        screen->damaged.start_row = rect.start_row;
      }
      if (screen->damaged.start_row > rect.end_row) {
        screen->damaged.start_row = rect.end_row;
      }
    }
    if (screen->damaged.end_row >= rect.start_row
        && screen->damaged.end_row < rect.end_row) {
      screen->damaged.end_row -= downward;
      if (screen->damaged.end_row < rect.start_row) {
        screen->damaged.end_row = rect.start_row;
      }
      if (screen->damaged.end_row > rect.end_row) {
        screen->damaged.end_row = rect.end_row;
      }
    }
  } else {
    DEBUG_LOG("TODO: Just flush and redo damaged=" STRFrect " rect=" STRFrect "\n",
              ARGSrect(screen->damaged), ARGSrect(rect));
  }

  return 1;
}

static int movecursor(VTermPos pos, VTermPos oldpos, int visible, void *user)
{
  VTermScreen *screen = user;

  if (screen->callbacks && screen->callbacks->movecursor) {
    return (*screen->callbacks->movecursor)(pos, oldpos, visible, screen->cbdata);
  }

  return 0;
}

static int setpenattr(VTermAttr attr, VTermValue *val, void *user)
{
  VTermScreen *screen = user;

  switch (attr) {
  case VTERM_ATTR_BOLD:
    screen->pen.bold = (unsigned)val->boolean;
    return 1;
  case VTERM_ATTR_UNDERLINE:
    screen->pen.underline = (unsigned)val->number;
    return 1;
  case VTERM_ATTR_ITALIC:
    screen->pen.italic = (unsigned)val->boolean;
    return 1;
  case VTERM_ATTR_BLINK:
    screen->pen.blink = (unsigned)val->boolean;
    return 1;
  case VTERM_ATTR_REVERSE:
    screen->pen.reverse = (unsigned)val->boolean;
    return 1;
  case VTERM_ATTR_CONCEAL:
    screen->pen.conceal = (unsigned)val->boolean;
    return 1;
  case VTERM_ATTR_STRIKE:
    screen->pen.strike = (unsigned)val->boolean;
    return 1;
  case VTERM_ATTR_FONT:
    screen->pen.font = (unsigned)val->number;
    return 1;
  case VTERM_ATTR_FOREGROUND:
    screen->pen.fg = val->color;
    return 1;
  case VTERM_ATTR_BACKGROUND:
    screen->pen.bg = val->color;
    return 1;
  case VTERM_ATTR_SMALL:
    screen->pen.small = (unsigned)val->boolean;
    return 1;
  case VTERM_ATTR_BASELINE:
    screen->pen.baseline = (unsigned)val->number;
    return 1;
  case VTERM_ATTR_URI:
    screen->pen.uri = val->number;
    return 1;

  case VTERM_N_ATTRS:
    return 0;
  }

  return 0;
}

static int settermprop(VTermProp prop, VTermValue *val, void *user)
{
  VTermScreen *screen = user;

  switch (prop) {
  case VTERM_PROP_ALTSCREEN:
    if (val->boolean && !screen->buffers[BUFIDX_ALTSCREEN]) {
      return 0;
    }

    screen->buffer =
      val->boolean ? screen->buffers[BUFIDX_ALTSCREEN] : screen->buffers[BUFIDX_PRIMARY];
    // only send a damage event on disable; because during enable there's an erase that sends a
    // damage anyway
    if (!val->boolean) {
      damagescreen(screen);
    }
    break;
  case VTERM_PROP_REVERSE:
    screen->global_reverse = (unsigned)val->boolean;
    damagescreen(screen);
    break;
  default:
    ;  // ignore
  }

  if (screen->callbacks && screen->callbacks->settermprop) {
    return (*screen->callbacks->settermprop)(prop, val, screen->cbdata);
  }

  return 1;
}

static int bell(void *user)
{
  VTermScreen *screen = user;

  if (screen->callbacks && screen->callbacks->bell) {
    return (*screen->callbacks->bell)(screen->cbdata);
  }

  return 0;
}

/// How many cells are non-blank Returns the position of the first blank cell in the trailing blank
/// end
static int line_popcount(ScreenCell *buffer, int row, int rows, int cols)
{
  int col = cols - 1;
  while (col >= 0 && buffer[row * cols + col].schar == 0) {
    col--;
  }
  return col + 1;
}

static void resize_buffer(VTermScreen *screen, int bufidx, int new_rows, int new_cols, bool active,
                          VTermStateFields *statefields)
{
  int old_rows = screen->rows;
  int old_cols = screen->cols;

  ScreenCell *old_buffer = screen->buffers[bufidx];
  VTermLineInfo *old_lineinfo = statefields->lineinfos[bufidx];

  ScreenCell *new_buffer = vterm_allocator_malloc(screen->vt,
                                                  sizeof(ScreenCell) * (size_t)new_rows *
                                                  (size_t)new_cols);
  VTermLineInfo *new_lineinfo = vterm_allocator_malloc(screen->vt,
                                                       sizeof(new_lineinfo[0]) * (size_t)new_rows);

  int old_row = old_rows - 1;
  int new_row = new_rows - 1;

  VTermPos old_cursor = statefields->pos;
  VTermPos new_cursor = { -1, -1 };

#ifdef DEBUG_REFLOW
  fprintf(stderr, "Resizing from %dx%d to %dx%d; cursor was at (%d,%d)\n",
          old_cols, old_rows, new_cols, new_rows, old_cursor.col, old_cursor.row);
#endif

  // Keep track of the final row that is knonw to be blank, so we know what spare space we have for
  // scrolling into
  int final_blank_row = new_rows;

  while (old_row >= 0) {
    int old_row_end = old_row;
    // TODO(vterm): Stop if dwl or dhl
    while (screen->reflow && old_lineinfo && old_row > 0 && old_lineinfo[old_row].continuation) {
      old_row--;
    }
    int old_row_start = old_row;

    int width = 0;
    for (int row = old_row_start; row <= old_row_end; row++) {
      if (screen->reflow && row < (old_rows - 1) && old_lineinfo[row + 1].continuation) {
        width += old_cols;
      } else {
        width += line_popcount(old_buffer, row, old_rows, old_cols);
      }
    }

    if (final_blank_row == (new_row + 1) && width == 0) {
      final_blank_row = new_row;
    }

    int new_height = screen->reflow
                     ? width ? (width + new_cols - 1) / new_cols : 1
                     : 1;

    int new_row_end = new_row;
    int new_row_start = new_row - new_height + 1;

    old_row = old_row_start;
    int old_col = 0;

    int spare_rows = new_rows - final_blank_row;

    if (new_row_start < 0    // we'd fall off the top
        && spare_rows >= 0    // we actually have spare rows
        && (!active || new_cursor.row == -1 || (new_cursor.row - new_row_start) < new_rows)) {
      // Attempt to scroll content down into the blank rows at the bottom to make it fit
      int downwards = -new_row_start;
      if (downwards > spare_rows) {
        downwards = spare_rows;
      }
      int rowcount = new_rows - downwards;

#ifdef DEBUG_REFLOW
      fprintf(stderr, "  scroll %d rows +%d downwards\n", rowcount, downwards);
#endif

      memmove(&new_buffer[downwards * new_cols], &new_buffer[0],
              (size_t)rowcount * (size_t)new_cols * sizeof(ScreenCell));
      memmove(&new_lineinfo[downwards],          &new_lineinfo[0],
              (size_t)rowcount * sizeof(new_lineinfo[0]));

      new_row += downwards;
      new_row_start += downwards;
      new_row_end += downwards;

      if (new_cursor.row >= 0) {
        new_cursor.row += downwards;
      }

      final_blank_row += downwards;
    }

#ifdef DEBUG_REFLOW
    fprintf(stderr, "  rows [%d..%d] <- [%d..%d] width=%d\n",
            new_row_start, new_row_end, old_row_start, old_row_end, width);
#endif

    if (new_row_start < 0) {
      if (old_row_start <= old_cursor.row && old_cursor.row <= old_row_end) {
        new_cursor.row = 0;
        new_cursor.col = old_cursor.col;
        if (new_cursor.col >= new_cols) {
          new_cursor.col = new_cols - 1;
        }
      }
      break;
    }

    for (new_row = new_row_start, old_row = old_row_start; new_row <= new_row_end; new_row++) {
      int count = width >= new_cols ? new_cols : width;
      width -= count;

      int new_col = 0;

      while (count) {
        // TODO(vterm): This could surely be done a lot faster by memcpy()'ing the entire range
        new_buffer[new_row * new_cols + new_col] = old_buffer[old_row * old_cols + old_col];

        if (old_cursor.row == old_row && old_cursor.col == old_col) {
          new_cursor.row = new_row, new_cursor.col = new_col;
        }

        old_col++;
        if (old_col == old_cols) {
          old_row++;

          if (!screen->reflow) {
            new_col++;
            break;
          }
          old_col = 0;
        }

        new_col++;
        count--;
      }

      if (old_cursor.row == old_row && old_cursor.col >= old_col) {
        new_cursor.row = new_row, new_cursor.col = (old_cursor.col - old_col + new_col);
        if (new_cursor.col >= new_cols) {
          new_cursor.col = new_cols - 1;
        }
      }

      while (new_col < new_cols) {
        clearcell(screen, &new_buffer[new_row * new_cols + new_col]);
        new_col++;
      }

      new_lineinfo[new_row].continuation = (new_row > new_row_start);
    }

    old_row = old_row_start - 1;
    new_row = new_row_start - 1;
  }

  if (old_cursor.row <= old_row) {
    // cursor would have moved entirely off the top of the screen; lets just bring it within range
    new_cursor.row = 0, new_cursor.col = old_cursor.col;
    if (new_cursor.col >= new_cols) {
      new_cursor.col = new_cols - 1;
    }
  }

  // We really expect the cursor position to be set by now
  if (active && (new_cursor.row == -1 || new_cursor.col == -1)) {
    fprintf(stderr, "screen_resize failed to update cursor position\n");
    abort();
  }

  if (old_row >= 0 && bufidx == BUFIDX_PRIMARY) {
    // Push spare lines to scrollback buffer
    if (screen->callbacks && screen->callbacks->sb_pushline) {
      for (int row = 0; row <= old_row; row++) {
        sb_pushline_from_row(screen, row);
      }
    }
    if (active) {
      statefields->pos.row -= (old_row + 1);
    }
  }
  if (new_row >= 0 && bufidx == BUFIDX_PRIMARY
      && screen->callbacks && screen->callbacks->sb_popline) {
    // Try to backfill rows by popping scrollback buffer
    while (new_row >= 0) {
      if (!(screen->callbacks->sb_popline(old_cols, screen->sb_buffer, screen->cbdata))) {
        break;
      }

      VTermPos pos = { .row = new_row };
      for (pos.col = 0; pos.col < old_cols && pos.col < new_cols;
           pos.col += screen->sb_buffer[pos.col].width) {
        VTermScreenCell *src = &screen->sb_buffer[pos.col];
        ScreenCell *dst = &new_buffer[pos.row * new_cols + pos.col];

        dst->schar = src->schar;

        dst->pen.bold = src->attrs.bold;
        dst->pen.underline = src->attrs.underline;
        dst->pen.italic = src->attrs.italic;
        dst->pen.blink = src->attrs.blink;
        dst->pen.reverse = src->attrs.reverse ^ screen->global_reverse;
        dst->pen.conceal = src->attrs.conceal;
        dst->pen.strike = src->attrs.strike;
        dst->pen.font = src->attrs.font;
        dst->pen.small = src->attrs.small;
        dst->pen.baseline = src->attrs.baseline;

        dst->pen.fg = src->fg;
        dst->pen.bg = src->bg;

        dst->pen.uri = src->uri;

        if (src->width == 2 && pos.col < (new_cols - 1)) {
          (dst + 1)->schar = (uint32_t)-1;
        }
      }
      for (; pos.col < new_cols; pos.col++) {
        clearcell(screen, &new_buffer[pos.row * new_cols + pos.col]);
      }
      new_row--;

      if (active) {
        statefields->pos.row++;
      }
    }
  }
  if (new_row >= 0) {
    // Scroll new rows back up to the top and fill in blanks at the bottom
    int moverows = new_rows - new_row - 1;
    memmove(&new_buffer[0], &new_buffer[(new_row + 1) * new_cols],
            (size_t)moverows * (size_t)new_cols * sizeof(ScreenCell));
    memmove(&new_lineinfo[0], &new_lineinfo[new_row + 1],
            (size_t)moverows * sizeof(new_lineinfo[0]));

    new_cursor.row -= (new_row + 1);

    for (new_row = moverows; new_row < new_rows; new_row++) {
      for (int col = 0; col < new_cols; col++) {
        clearcell(screen, &new_buffer[new_row * new_cols + col]);
      }
      new_lineinfo[new_row] = (VTermLineInfo){ 0 };
    }
  }

  vterm_allocator_free(screen->vt, old_buffer);
  screen->buffers[bufidx] = new_buffer;

  vterm_allocator_free(screen->vt, old_lineinfo);
  statefields->lineinfos[bufidx] = new_lineinfo;

  if (active) {
    statefields->pos = new_cursor;
  }
}

static int resize(int new_rows, int new_cols, VTermStateFields *fields, void *user)
{
  VTermScreen *screen = user;

  int altscreen_active = (screen->buffers[BUFIDX_ALTSCREEN]
                          && screen->buffer == screen->buffers[BUFIDX_ALTSCREEN]);

  int old_rows = screen->rows;
  int old_cols = screen->cols;

  if (new_cols > old_cols) {
    // Ensure that ->sb_buffer is large enough for a new or and old row
    if (screen->sb_buffer) {
      vterm_allocator_free(screen->vt, screen->sb_buffer);
    }

    screen->sb_buffer = vterm_allocator_malloc(screen->vt,
                                               sizeof(VTermScreenCell) * (size_t)new_cols);
  }

  resize_buffer(screen, 0, new_rows, new_cols, !altscreen_active, fields);
  if (screen->buffers[BUFIDX_ALTSCREEN]) {
    resize_buffer(screen, 1, new_rows, new_cols, altscreen_active, fields);
  } else if (new_rows != old_rows) {
    // We don't need a full resize of the altscreen because it isn't enabled but we should at least
    // keep the lineinfo the right size
    vterm_allocator_free(screen->vt, fields->lineinfos[BUFIDX_ALTSCREEN]);

    VTermLineInfo *new_lineinfo = vterm_allocator_malloc(screen->vt,
                                                         sizeof(new_lineinfo[0]) *
                                                         (size_t)new_rows);
    for (int row = 0; row < new_rows; row++) {
      new_lineinfo[row] = (VTermLineInfo){ 0 };
    }

    fields->lineinfos[BUFIDX_ALTSCREEN] = new_lineinfo;
  }

  screen->buffer =
    altscreen_active ? screen->buffers[BUFIDX_ALTSCREEN] : screen->buffers[BUFIDX_PRIMARY];

  screen->rows = new_rows;
  screen->cols = new_cols;

  if (new_cols <= old_cols) {
    if (screen->sb_buffer) {
      vterm_allocator_free(screen->vt, screen->sb_buffer);
    }

    screen->sb_buffer = vterm_allocator_malloc(screen->vt,
                                               sizeof(VTermScreenCell) * (size_t)new_cols);
  }

  // TODO(vterm): Maaaaybe we can optimise this if there's no reflow happening
  damagescreen(screen);

  if (screen->callbacks && screen->callbacks->resize) {
    return (*screen->callbacks->resize)(new_rows, new_cols, screen->cbdata);
  }

  return 1;
}

static int setlineinfo(int row, const VTermLineInfo *newinfo, const VTermLineInfo *oldinfo,
                       void *user)
{
  VTermScreen *screen = user;

  if (newinfo->doublewidth != oldinfo->doublewidth
      || newinfo->doubleheight != oldinfo->doubleheight) {
    for (int col = 0; col < screen->cols; col++) {
      ScreenCell *cell = getcell(screen, row, col);
      cell->pen.dwl = newinfo->doublewidth;
      cell->pen.dhl = newinfo->doubleheight;
    }

    VTermRect rect = {
      .start_row = row,
      .end_row = row + 1,
      .start_col = 0,
      .end_col = newinfo->doublewidth ? screen->cols / 2 : screen->cols,
    };
    damagerect(screen, rect);

    if (newinfo->doublewidth) {
      rect.start_col = screen->cols / 2;
      rect.end_col = screen->cols;

      erase_internal(rect, 0, user);
    }
  }

  return 1;
}

static int sb_clear(void *user)
{
  VTermScreen *screen = user;

  if (screen->callbacks && screen->callbacks->sb_clear) {
    if ((*screen->callbacks->sb_clear)(screen->cbdata)) {
      return 1;
    }
  }

  return 0;
}

static VTermStateCallbacks state_cbs = {
  .putglyph = &putglyph,
  .movecursor = &movecursor,
  .scrollrect = &scrollrect,
  .erase = &erase,
  .setpenattr = &setpenattr,
  .settermprop = &settermprop,
  .bell = &bell,
  .resize = &resize,
  .setlineinfo = &setlineinfo,
  .sb_clear = &sb_clear,
};

static VTermScreen *screen_new(VTerm *vt)
{
  VTermState *state = vterm_obtain_state(vt);
  if (!state) {
    return NULL;
  }

  VTermScreen *screen = vterm_allocator_malloc(vt, sizeof(VTermScreen));
  int rows, cols;

  vterm_get_size(vt, &rows, &cols);

  screen->vt = vt;
  screen->state = state;

  screen->damage_merge = VTERM_DAMAGE_CELL;
  screen->damaged.start_row = -1;
  screen->pending_scrollrect.start_row = -1;

  screen->rows = rows;
  screen->cols = cols;

  screen->global_reverse = false;
  screen->reflow = false;

  screen->callbacks = NULL;
  screen->cbdata = NULL;

  screen->buffers[BUFIDX_PRIMARY] = alloc_buffer(screen, rows, cols);

  screen->buffer = screen->buffers[BUFIDX_PRIMARY];

  screen->sb_buffer = vterm_allocator_malloc(screen->vt, sizeof(VTermScreenCell) * (size_t)cols);

  vterm_state_set_callbacks(screen->state, &state_cbs, screen);

  return screen;
}

void vterm_screen_free(VTermScreen *screen)
{
  vterm_allocator_free(screen->vt, screen->buffers[BUFIDX_PRIMARY]);
  if (screen->buffers[BUFIDX_ALTSCREEN]) {
    vterm_allocator_free(screen->vt, screen->buffers[BUFIDX_ALTSCREEN]);
  }

  vterm_allocator_free(screen->vt, screen->sb_buffer);

  vterm_allocator_free(screen->vt, screen);
}

void vterm_screen_reset(VTermScreen *screen, int hard)
{
  screen->damaged.start_row = -1;
  screen->pending_scrollrect.start_row = -1;
  vterm_state_reset(screen->state, hard);
  vterm_screen_flush_damage(screen);
}

// Copy internal to external representation of a screen cell
int vterm_screen_get_cell(const VTermScreen *screen, VTermPos pos, VTermScreenCell *cell)
{
  ScreenCell *intcell = getcell(screen, pos.row, pos.col);
  if (!intcell) {
    return 0;
  }

  cell->schar = intcell->schar;

  cell->attrs.bold = intcell->pen.bold;
  cell->attrs.underline = intcell->pen.underline;
  cell->attrs.italic = intcell->pen.italic;
  cell->attrs.blink = intcell->pen.blink;
  cell->attrs.reverse = intcell->pen.reverse ^ screen->global_reverse;
  cell->attrs.conceal = intcell->pen.conceal;
  cell->attrs.strike = intcell->pen.strike;
  cell->attrs.font = intcell->pen.font;
  cell->attrs.small = intcell->pen.small;
  cell->attrs.baseline = intcell->pen.baseline;

  cell->attrs.dwl = intcell->pen.dwl;
  cell->attrs.dhl = intcell->pen.dhl;

  cell->fg = intcell->pen.fg;
  cell->bg = intcell->pen.bg;

  cell->uri = intcell->pen.uri;

  if (pos.col < (screen->cols - 1)
      && getcell(screen, pos.row, pos.col + 1)->schar == (uint32_t)-1) {
    cell->width = 2;
  } else {
    cell->width = 1;
  }

  return 1;
}

VTermScreen *vterm_obtain_screen(VTerm *vt)
{
  if (vt->screen) {
    return vt->screen;
  }

  VTermScreen *screen = screen_new(vt);
  vt->screen = screen;

  return screen;
}

void vterm_screen_enable_reflow(VTermScreen *screen, bool reflow)
{
  screen->reflow = reflow;
}

#undef vterm_screen_set_reflow
void vterm_screen_set_reflow(VTermScreen *screen, bool reflow)
{
  vterm_screen_enable_reflow(screen, reflow);
}

void vterm_screen_enable_altscreen(VTermScreen *screen, int altscreen)
{
  if (!screen->buffers[BUFIDX_ALTSCREEN] && altscreen) {
    int rows, cols;
    vterm_get_size(screen->vt, &rows, &cols);

    screen->buffers[BUFIDX_ALTSCREEN] = alloc_buffer(screen, rows, cols);
  }
}

void vterm_screen_set_callbacks(VTermScreen *screen, const VTermScreenCallbacks *callbacks,
                                void *user)
{
  screen->callbacks = callbacks;
  screen->cbdata = user;
}

void vterm_screen_set_unrecognised_fallbacks(VTermScreen *screen,
                                             const VTermStateFallbacks *fallbacks, void *user)
{
  vterm_state_set_unrecognised_fallbacks(screen->state, fallbacks, user);
}

void vterm_screen_flush_damage(VTermScreen *screen)
{
  if (screen->pending_scrollrect.start_row != -1) {
    vterm_scroll_rect(screen->pending_scrollrect, screen->pending_scroll_downward,
                      screen->pending_scroll_rightward,
                      moverect_user, erase_user, screen);

    screen->pending_scrollrect.start_row = -1;
  }

  if (screen->damaged.start_row != -1) {
    if (screen->callbacks && screen->callbacks->damage) {
      (*screen->callbacks->damage)(screen->damaged, screen->cbdata);
    }

    screen->damaged.start_row = -1;
  }
}

void vterm_screen_set_damage_merge(VTermScreen *screen, VTermDamageSize size)
{
  vterm_screen_flush_damage(screen);
  screen->damage_merge = size;
}

/// Same as vterm_state_convert_color_to_rgb(), but takes a `screen` instead of a `state` instance.
void vterm_screen_convert_color_to_rgb(const VTermScreen *screen, VTermColor *col)
{
  vterm_state_convert_color_to_rgb(screen->state, col);
}

// Some utility functions on VTermRect structures

#define STRFrect "(%d,%d-%d,%d)"
#define ARGSrect(r) (r).start_row, (r).start_col, (r).end_row, (r).end_col

// Expand dst to contain src as well
void rect_expand(VTermRect *dst, VTermRect *src)
{
  if (dst->start_row > src->start_row) {
    dst->start_row = src->start_row;
  }
  if (dst->start_col > src->start_col) {
    dst->start_col = src->start_col;
  }
  if (dst->end_row < src->end_row) {
    dst->end_row = src->end_row;
  }
  if (dst->end_col < src->end_col) {
    dst->end_col = src->end_col;
  }
}

// Clip the dst to ensure it does not step outside of bounds
void rect_clip(VTermRect *dst, VTermRect *bounds)
{
  if (dst->start_row < bounds->start_row) {
    dst->start_row = bounds->start_row;
  }
  if (dst->start_col < bounds->start_col) {
    dst->start_col = bounds->start_col;
  }
  if (dst->end_row > bounds->end_row) {
    dst->end_row = bounds->end_row;
  }
  if (dst->end_col > bounds->end_col) {
    dst->end_col = bounds->end_col;
  }
  // Ensure it doesn't end up negatively-sized
  if (dst->end_row < dst->start_row) {
    dst->end_row = dst->start_row;
  }
  if (dst->end_col < dst->start_col) {
    dst->end_col = dst->start_col;
  }
}

// True if the two rectangles are equal
int rect_equal(VTermRect *a, VTermRect *b)
{
  return (a->start_row == b->start_row)
         && (a->start_col == b->start_col)
         && (a->end_row == b->end_row)
         && (a->end_col == b->end_col);
}

// True if small is contained entirely within big
int rect_contains(VTermRect *big, VTermRect *small)
{
  if (small->start_row < big->start_row) {
    return 0;
  }
  if (small->start_col < big->start_col) {
    return 0;
  }
  if (small->end_row > big->end_row) {
    return 0;
  }
  if (small->end_col > big->end_col) {
    return 0;
  }
  return 1;
}

// True if the rectangles overlap at all
int rect_intersects(VTermRect *a, VTermRect *b)
{
  if (a->start_row > b->end_row || b->start_row > a->end_row) {
    return 0;
  }
  if (a->start_col > b->end_col || b->start_col > a->end_col) {
    return 0;
  }
  return 1;
}
