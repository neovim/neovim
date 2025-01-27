#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "auto/config.h"
#include "nvim/memory.h"
#include "nvim/vterm/screen.h"
#include "nvim/vterm/state.h"
#include "nvim/vterm/vterm.h"
#include "nvim/vterm/vterm_internal_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "vterm/vterm.c.generated.h"
#endif

// *****************
// * API functions *
// *****************

static void *default_malloc(size_t size, void *allocdata)
{
  void *ptr = xmalloc(size);
  if (ptr) {
    memset(ptr, 0, size);
  }
  return ptr;
}

static void default_free(void *ptr, void *allocdata)
{
  xfree(ptr);
}

static VTermAllocatorFunctions default_allocator = {
  .malloc = &default_malloc,
  .free = &default_free,
};

/// Convenient shortcut for default cases
VTerm *vterm_new(int rows, int cols)
{
  return vterm_build(&(const struct VTermBuilder){
    .rows = rows,
    .cols = cols,
  });
}

// A handy macro for defaulting values out of builder fields
#define DEFAULT(v, def)  ((v) ? (v) : (def))

VTerm *vterm_build(const struct VTermBuilder *builder)
{
  const VTermAllocatorFunctions *allocator = DEFAULT(builder->allocator, &default_allocator);

  // Need to bootstrap using the allocator function directly
  VTerm *vt = (*allocator->malloc)(sizeof(VTerm), builder->allocdata);

  vt->allocator = allocator;
  vt->allocdata = builder->allocdata;

  vt->rows = builder->rows;
  vt->cols = builder->cols;

  vt->parser.state = NORMAL;

  vt->parser.callbacks = NULL;
  vt->parser.cbdata = NULL;

  vt->parser.emit_nul = false;

  vt->outfunc = NULL;
  vt->outdata = NULL;

  vt->outbuffer_len = DEFAULT(builder->outbuffer_len, 4096);
  vt->outbuffer_cur = 0;
  vt->outbuffer = vterm_allocator_malloc(vt, vt->outbuffer_len);

  vt->tmpbuffer_len = DEFAULT(builder->tmpbuffer_len, 4096);
  vt->tmpbuffer = vterm_allocator_malloc(vt, vt->tmpbuffer_len);

  return vt;
}

void vterm_free(VTerm *vt)
{
  if (vt->screen) {
    vterm_screen_free(vt->screen);
  }

  if (vt->state) {
    vterm_state_free(vt->state);
  }

  vterm_allocator_free(vt, vt->outbuffer);
  vterm_allocator_free(vt, vt->tmpbuffer);

  vterm_allocator_free(vt, vt);
}

void *vterm_allocator_malloc(VTerm *vt, size_t size)
{
  return (*vt->allocator->malloc)(size, vt->allocdata);
}

void vterm_allocator_free(VTerm *vt, void *ptr)
{
  (*vt->allocator->free)(ptr, vt->allocdata);
}

void vterm_get_size(const VTerm *vt, int *rowsp, int *colsp)
{
  if (rowsp) {
    *rowsp = vt->rows;
  }
  if (colsp) {
    *colsp = vt->cols;
  }
}

void vterm_set_size(VTerm *vt, int rows, int cols)
{
  if (rows < 1 || cols < 1) {
    return;
  }

  vt->rows = rows;
  vt->cols = cols;

  if (vt->parser.callbacks && vt->parser.callbacks->resize) {
    (*vt->parser.callbacks->resize)(rows, cols, vt->parser.cbdata);
  }
}

void vterm_set_utf8(VTerm *vt, int is_utf8)
{
  vt->mode.utf8 = (unsigned)is_utf8;
}

void vterm_output_set_callback(VTerm *vt, VTermOutputCallback *func, void *user)
{
  vt->outfunc = func;
  vt->outdata = user;
}

void vterm_push_output_bytes(VTerm *vt, const char *bytes, size_t len)
{
  if (vt->outfunc) {
    (vt->outfunc)(bytes, len, vt->outdata);
    return;
  }

  if (len > vt->outbuffer_len - vt->outbuffer_cur) {
    return;
  }

  memcpy(vt->outbuffer + vt->outbuffer_cur, bytes, len);
  vt->outbuffer_cur += len;
}

void vterm_push_output_sprintf(VTerm *vt, const char *format, ...)
  FUNC_ATTR_PRINTF(2, 3)
{
  va_list args;
  va_start(args, format);
  size_t len = (size_t)vsnprintf(vt->tmpbuffer, vt->tmpbuffer_len, format, args);
  vterm_push_output_bytes(vt, vt->tmpbuffer, len);
  va_end(args);
}

void vterm_push_output_sprintf_ctrl(VTerm *vt, uint8_t ctrl, const char *fmt, ...)
  FUNC_ATTR_PRINTF(3, 4)
{
  size_t cur;

  if (ctrl >= 0x80 && !vt->mode.ctrl8bit) {
    cur = (size_t)snprintf(vt->tmpbuffer, vt->tmpbuffer_len, ESC_S "%c", ctrl - 0x40);
  } else {
    cur = (size_t)snprintf(vt->tmpbuffer, vt->tmpbuffer_len, "%c", ctrl);
  }

  if (cur >= vt->tmpbuffer_len) {
    return;
  }

  va_list args;
  va_start(args, fmt);
  cur += (size_t)vsnprintf(vt->tmpbuffer + cur, vt->tmpbuffer_len - cur, fmt, args);
  va_end(args);

  if (cur >= vt->tmpbuffer_len) {
    return;
  }

  vterm_push_output_bytes(vt, vt->tmpbuffer, cur);
}

void vterm_push_output_sprintf_str(VTerm *vt, uint8_t ctrl, bool term, const char *fmt, ...)
  FUNC_ATTR_PRINTF(4, 5)
{
  size_t cur = 0;

  if (ctrl) {
    if (ctrl >= 0x80 && !vt->mode.ctrl8bit) {
      cur = (size_t)snprintf(vt->tmpbuffer, vt->tmpbuffer_len, ESC_S "%c", ctrl - 0x40);
    } else {
      cur = (size_t)snprintf(vt->tmpbuffer, vt->tmpbuffer_len, "%c", ctrl);
    }

    if (cur >= vt->tmpbuffer_len) {
      return;
    }
  }

  va_list args;
  va_start(args, fmt);
  cur += (size_t)vsnprintf(vt->tmpbuffer + cur, vt->tmpbuffer_len - cur, fmt, args);
  va_end(args);

  if (cur >= vt->tmpbuffer_len) {
    return;
  }

  if (term) {
    cur += (size_t)snprintf(vt->tmpbuffer + cur, vt->tmpbuffer_len - cur,
                            vt->mode.ctrl8bit ? "\x9C" : ESC_S "\\");  // ST

    if (cur >= vt->tmpbuffer_len) {
      return;
    }
  }

  vterm_push_output_bytes(vt, vt->tmpbuffer, cur);
}

VTermValueType vterm_get_attr_type(VTermAttr attr)
{
  switch (attr) {
  case VTERM_ATTR_BOLD:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_ATTR_UNDERLINE:
    return VTERM_VALUETYPE_INT;
  case VTERM_ATTR_ITALIC:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_ATTR_BLINK:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_ATTR_REVERSE:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_ATTR_CONCEAL:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_ATTR_STRIKE:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_ATTR_FONT:
    return VTERM_VALUETYPE_INT;
  case VTERM_ATTR_FOREGROUND:
    return VTERM_VALUETYPE_COLOR;
  case VTERM_ATTR_BACKGROUND:
    return VTERM_VALUETYPE_COLOR;
  case VTERM_ATTR_SMALL:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_ATTR_BASELINE:
    return VTERM_VALUETYPE_INT;
  case VTERM_ATTR_URI:
    return VTERM_VALUETYPE_INT;

  case VTERM_N_ATTRS:
    return 0;
  }
  return 0;  // UNREACHABLE
}

void vterm_scroll_rect(VTermRect rect, int downward, int rightward,
                       int (*moverect)(VTermRect src, VTermRect dest, void *user),
                       int (*eraserect)(VTermRect rect, int selective, void *user), void *user)
{
  VTermRect src;
  VTermRect dest;

  if (abs(downward) >= rect.end_row - rect.start_row
      || abs(rightward) >= rect.end_col - rect.start_col) {
    // Scroll more than area; just erase the lot
    (*eraserect)(rect, 0, user);
    return;
  }

  if (rightward >= 0) {
    // rect: [XXX................]
    // src:     [----------------]
    // dest: [----------------]
    dest.start_col = rect.start_col;
    dest.end_col = rect.end_col - rightward;
    src.start_col = rect.start_col + rightward;
    src.end_col = rect.end_col;
  } else {
    // rect: [................XXX]
    // src:  [----------------]
    // dest:    [----------------]
    int leftward = -rightward;
    dest.start_col = rect.start_col + leftward;
    dest.end_col = rect.end_col;
    src.start_col = rect.start_col;
    src.end_col = rect.end_col - leftward;
  }

  if (downward >= 0) {
    dest.start_row = rect.start_row;
    dest.end_row = rect.end_row - downward;
    src.start_row = rect.start_row + downward;
    src.end_row = rect.end_row;
  } else {
    int upward = -downward;
    dest.start_row = rect.start_row + upward;
    dest.end_row = rect.end_row;
    src.start_row = rect.start_row;
    src.end_row = rect.end_row - upward;
  }

  if (moverect) {
    (*moverect)(dest, src, user);
  }

  if (downward > 0) {
    rect.start_row = rect.end_row - downward;
  } else if (downward < 0) {
    rect.end_row = rect.start_row - downward;
  }

  if (rightward > 0) {
    rect.start_col = rect.end_col - rightward;
  } else if (rightward < 0) {
    rect.end_col = rect.start_col - rightward;
  }

  (*eraserect)(rect, 0, user);
}
