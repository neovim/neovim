#include <stdint.h>
#include <stdlib.h>

#include "api/buffer.h"
#include "api/helpers.h"
#include "api/defs.h"
#include "../vim.h"
#include "../buffer.h"
#include "memline.h"
#include "memory.h"
#include "misc1.h"
#include "misc2.h"
#include "move.h"
#include "../window.h"
#include "undo.h"

static buf_T *find_buffer(Buffer buffer, Error *err);

// Find a window that contains "buf" and switch to it.
// If there is no such window, use the current window and change "curbuf".
// Caller must initialize save_curbuf to NULL.
// restore_win_for_buf() MUST be called later!
static void switch_to_win_for_buf(buf_T *buf,
                                  win_T **save_curwinp,
                                  tabpage_T **save_curtabp,
                                  buf_T **save_curbufp);

static void restore_win_for_buf(win_T *save_curwin,
                                tabpage_T *save_curtab,
                                buf_T *save_curbuf);

// Check if deleting lines made the cursor position invalid.
// Changed the lines from "lo" to "hi" and added "extra" lines (negative if
// deleted).
static void fix_cursor(linenr_T lo, linenr_T hi, linenr_T extra);

// Normalizes 0-based indexes to buffer line numbers
static int64_t normalize_index(buf_T *buf, int64_t index);

int64_t buffer_get_length(Buffer buffer, Error *err)
{
  abort();
}

String buffer_get_line(Buffer buffer, int64_t index, Error *err)
{
  String rv;
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return rv;
  }

  index = normalize_index(buf, index);
  char *line = (char *)ml_get_buf(buf, index, false);
  rv.size = strlen(line);
  rv.data = xmalloc(rv.size);
  memcpy(rv.data, line, rv.size);
  return rv;
}

void buffer_set_line(Buffer buffer, int64_t index, Object line, Error *err)
{
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return;
  }

  if (line.type != kObjectTypeNil && line.type != kObjectTypeString) {
    set_api_error("Invalid line", err);
    return;
  }

  index = normalize_index(buf, index);
  buf_T *save_curbuf = NULL;
  win_T *save_curwin = NULL;
  tabpage_T *save_curtab = NULL;
  try_start();
  switch_to_win_for_buf(buf, &save_curwin, &save_curtab, &save_curbuf);

  if (line.type == kObjectTypeNil) {
    // Delete the line

    if (u_savedel(index, 1L) == FAIL) {
      // Failed to save undo
      set_api_error("Cannot save undo information", err);
    } else if (ml_delete(index, FALSE) == FAIL) {
      // Failed to delete
      set_api_error("Cannot delete the line", err);
    } else {
      restore_win_for_buf(save_curwin, save_curtab, save_curbuf);
      // Success
      if (buf == curbuf) {
        // fix the cursor if it's the current buffer
        fix_cursor(index, index + 1, -1);
      }

      if (save_curbuf == NULL) {
        // Only adjust marks if we managed to switch to a window that
        // holds the buffer, otherwise line numbers will be invalid.
        deleted_lines_mark(index, 1L);
      }
    }

  } else if (line.type == kObjectTypeString) {
    // Replace line
    char *string = xmalloc(line.data.string.size + 1);
    memcpy(string, line.data.string.data, line.data.string.size);
    string[line.data.string.size] = NUL;

    if (u_savesub(index) == FAIL) {
      // Failed to save undo
      set_api_error("Cannot save undo information", err);
    } else if (ml_replace(index, (char_u *)string, FALSE) == FAIL) {
      // Failed to replace
      set_api_error("Cannot replace line", err);
      free(string);
    } else {
      // Success
      changed_bytes(index, 0);
      restore_win_for_buf(save_curwin, save_curtab, save_curbuf);

      // Check that the cursor is not beyond the end of the line now.
      if (buf == curbuf) {
        check_cursor_col();
      }
    }
  }

  try_end(err);
}

StringArray buffer_get_slice(Buffer buffer,
    int64_t start,
    int64_t end,
    Error *err)
{
  abort();
}

void buffer_set_slice(Buffer buffer,
    int64_t start,
    int64_t end,
    StringArray lines,
    Error *err)
{
  abort();
}

Object buffer_get_var(Buffer buffer, String name, Error *err)
{
  abort();
}

void buffer_set_var(Buffer buffer, String name, Object value, Error *err)
{
  abort();
}

String buffer_get_option(Buffer buffer, String name, Error *err)
{
  abort();
}

void buffer_set_option(Buffer buffer, String name, String value, Error *err)
{
  abort();
}

void buffer_del_option(Buffer buffer, String name, Error *err)
{
  abort();
}

String buffer_get_name(Buffer buffer, Error *err)
{
  abort();
}

void buffer_set_name(Buffer buffer, String name, Error *err)
{
  abort();
}

bool buffer_is_valid(Buffer buffer)
{
  abort();
}

void buffer_insert(Buffer buffer, StringArray lines, int64_t lnum, Error *err)
{
  abort();
}

Position buffer_mark(Buffer buffer, String name, Error *err)
{
  abort();
}

static buf_T *find_buffer(Buffer buffer, Error *err)
{
  buf_T *buf = buflist_findnr(buffer);

  if (buf == NULL) {
    set_api_error("Invalid buffer id", err);
  }

  return buf;
}

static void switch_to_win_for_buf(buf_T *buf,
                                  win_T **save_curwinp,
                                  tabpage_T **save_curtabp,
                                  buf_T **save_curbufp)
{
  win_T *wp;
  tabpage_T *tp;

  if (find_win_for_buf(buf, &wp, &tp) == FAIL
      || switch_win(save_curwinp, save_curtabp, wp, tp, TRUE) == FAIL)
    switch_buffer(save_curbufp, buf);
}

static void restore_win_for_buf(win_T *save_curwin,
                                tabpage_T *save_curtab,
                                buf_T *save_curbuf)
{
  if (save_curbuf == NULL) {
    restore_win(save_curwin, save_curtab, TRUE);
  } else {
    restore_buffer(save_curbuf);
  }
}

static void fix_cursor(linenr_T lo, linenr_T hi, linenr_T extra)
{
  if (curwin->w_cursor.lnum >= lo) {
    // Adjust the cursor position if it's in/after the changed
    // lines.
    if (curwin->w_cursor.lnum >= hi) {
      curwin->w_cursor.lnum += extra;
      check_cursor_col();
    }
    else if (extra < 0) {
      curwin->w_cursor.lnum = lo;
      check_cursor();
    } else {
      check_cursor_col();
    }
    changed_cline_bef_curs();
  }
  invalidate_botline();
}

static int64_t normalize_index(buf_T *buf, int64_t index)
{
  // Fix if < 0
  index = index < 0 ?  buf->b_ml.ml_line_count + index : index;
  // Convert the index to a vim line number
  index++;
  // Fix if > line_count
  index = index > buf->b_ml.ml_line_count ? buf->b_ml.ml_line_count : index;
  return index;
}
