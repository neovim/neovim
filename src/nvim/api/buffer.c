// Much of this code was adapted from 'if_py_both.h' from the original
// vim source
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/buffer.h"
#include "nvim/api/helpers.h"
#include "nvim/api/defs.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/ex_cmds.h"
#include "nvim/mark.h"
#include "nvim/fileio.h"
#include "nvim/move.h"
#include "nvim/window.h"
#include "nvim/undo.h"

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

Integer buffer_get_length(Buffer buffer, Error *err)
{
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return 0;
  }

  return buf->b_ml.ml_line_count;
}

String buffer_get_line(Buffer buffer, Integer index, Error *err)
{
  String rv = {.size = 0};
  StringArray slice = buffer_get_slice(buffer, index, index, true, true, err);

  if (slice.size) {
    rv = slice.items[0];
  }

  return rv;
}

void buffer_set_line(Buffer buffer, Integer index, String line, Error *err)
{
  StringArray array = {.items = &line, .size = 1};
  buffer_set_slice(buffer, index, index, true, true, array, err);
}

void buffer_del_line(Buffer buffer, Integer index, Error *err)
{
  StringArray array = {.size = 0};
  buffer_set_slice(buffer, index, index, true, true, array, err);
}

StringArray buffer_get_slice(Buffer buffer,
                             Integer start,
                             Integer end,
                             Boolean include_start,
                             Boolean include_end,
                             Error *err)
{
  StringArray rv = {.size = 0};
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return rv;
  }

  start = normalize_index(buf, start) + (include_start ? 0 : 1);
  end = normalize_index(buf, end) + (include_end ? 1 : 0);

  if (start >= end) {
    // Return 0-length array
    return rv;
  }

  rv.size = (size_t)(end - start);
  rv.items = xcalloc(sizeof(String), rv.size);

  for (size_t i = 0; i < rv.size; i++) {
    int64_t lnum = start + (int64_t)i;

    if (lnum > LONG_MAX) {
      set_api_error("Line index is too high", err);
      goto end;
    }

    const char *bufstr = (char *) ml_get_buf(buf, (linenr_T) lnum, false);
    rv.items[i] = cstr_to_string(bufstr);
  }

end:
  if (err->set) {
    for (size_t i = 0; i < rv.size; i++) {
      if (rv.items[i].data != NULL) {
        free(rv.items[i].data);
      }
    }

    free(rv.items);
  }

  return rv;
}

void buffer_set_slice(Buffer buffer,
                      Integer start,
                      Integer end,
                      Boolean include_start,
                      Boolean include_end,
                      StringArray replacement,
                      Error *err)
{
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return;
  }

  start = normalize_index(buf, start) + (include_start ? 0 : 1);
  end = normalize_index(buf, end) + (include_end ? 1 : 0);

  if (start > end) {
    set_api_error("start > end", err);
    return;
  }

  buf_T *save_curbuf = NULL;
  win_T *save_curwin = NULL;
  tabpage_T *save_curtab = NULL;
  size_t new_len = replacement.size;
  size_t old_len = (size_t)(end - start);
  ssize_t extra = 0;  // lines added to text, can be negative
  char **lines = (new_len != 0) ? xmalloc(new_len * sizeof(char *)) : NULL;

  for (size_t i = 0; i < new_len; i++) {
    String l = replacement.items[i];
    lines[i] = xstrndup(l.data, l.size);
  }

  try_start();
  switch_to_win_for_buf(buf, &save_curwin, &save_curtab, &save_curbuf);

  if (u_save((linenr_T)(start - 1), (linenr_T)end) == FAIL) {
    set_api_error("Cannot save undo information", err);
    goto end;
  }

  // If the size of the range is reducing (ie, new_len < old_len) we
  // need to delete some old_len. We do this at the start, by
  // repeatedly deleting line "start".
  size_t to_delete = (new_len < old_len) ? (size_t)(old_len - new_len) : 0;
  for (size_t i = 0; i < to_delete; i++) {
    if (ml_delete((linenr_T)start, false) == FAIL) {
      set_api_error("Cannot delete line", err);
      goto end;
    }
  }

  if ((ssize_t)to_delete > 0) {
    extra -= (ssize_t)to_delete;
  }

  // For as long as possible, replace the existing old_len with the
  // new old_len. This is a more efficient operation, as it requires
  // less memory allocation and freeing.
  size_t to_replace = old_len < new_len ? old_len : new_len;
  for (size_t i = 0; i < to_replace; i++) {
    int64_t lnum = start + (int64_t)i;

    if (lnum > LONG_MAX) {
      set_api_error("Index value is too high", err);
      goto end;
    }

    if (ml_replace((linenr_T)lnum, (char_u *)lines[i], false) == FAIL) {
      set_api_error("Cannot replace line", err);
      goto end;
    }
    // Mark lines that haven't been passed to the buffer as they need
    // to be freed later
    lines[i] = NULL;
  }

  // Now we may need to insert the remaining new old_len
  for (size_t i = to_replace; i < new_len; i++) {
    int64_t lnum = start + (int64_t)i - 1;

    if (lnum > LONG_MAX) {
      set_api_error("Index value is too high", err);
      goto end;
    }

    if (ml_append((linenr_T)lnum, (char_u *)lines[i], 0, false) == FAIL) {
      set_api_error("Cannot insert line", err);
      goto end;
    }

    // Same as with replacing
    lines[i] = NULL;
    i++;
    extra++;
  }

  // Adjust marks. Invalidate any which lie in the
  // changed range, and move any in the remainder of the buffer.
  // Only adjust marks if we managed to switch to a window that holds
  // the buffer, otherwise line numbers will be invalid.
  if (save_curbuf == NULL) {
    mark_adjust((linenr_T)start, (linenr_T)(end - 1), MAXLNUM, extra);
  }

  changed_lines((linenr_T)start, 0, (linenr_T)end, extra);

  if (buf == curbuf) {
    fix_cursor((linenr_T)start, (linenr_T)end, extra);
  }

end:
  for (uint32_t i = 0; i < new_len; i++) {
    if (lines[i] != NULL) {
      free(lines[i]);
    }
  }

  free(lines);
  restore_win_for_buf(save_curwin, save_curtab, save_curbuf);
  try_end(err);
}

Object buffer_get_var(Buffer buffer, String name, Error *err)
{
  Object rv;
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return rv;
  }

  return dict_get_value(buf->b_vars, name, err);
}

Object buffer_set_var(Buffer buffer, String name, Object value, Error *err)
{
  Object rv;
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return rv;
  }

  return dict_set_value(buf->b_vars, name, value, err);
}

Object buffer_get_option(Buffer buffer, String name, Error *err)
{
  Object rv;
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return rv;
  }

  return get_option_from(buf, SREQ_BUF, name, err);
}

void buffer_set_option(Buffer buffer, String name, Object value, Error *err)
{
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return;
  }

  set_option_to(buf, SREQ_BUF, name, value, err);
}

String buffer_get_name(Buffer buffer, Error *err)
{
  String rv = {.size = 0, .data = ""};
  buf_T *buf = find_buffer(buffer, err);

  if (!buf || buf->b_ffname == NULL) {
    return rv;
  }

  return cstr_to_string((char *)buf->b_ffname);
}

void buffer_set_name(Buffer buffer, String name, Error *err)
{
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return;
  }

  aco_save_T aco;
  int ren_ret;
  char *val = xstrndup(name.data, name.size);

  try_start();
  // Using aucmd_*: autocommands will be executed by rename_buffer
  aucmd_prepbuf(&aco, buf);
  ren_ret = rename_buffer((char_u *)val);
  aucmd_restbuf(&aco);

  if (try_end(err)) {
    return;
  }

  if (ren_ret == FAIL) {
    set_api_error("failed to rename buffer", err);
  }
}

Boolean buffer_is_valid(Buffer buffer)
{
  Error stub = {.set = false};
  return find_buffer(buffer, &stub) != NULL;
}

void buffer_insert(Buffer buffer, Integer lnum, StringArray lines, Error *err)
{
  buffer_set_slice(buffer, lnum, lnum, false, true, lines, err);
}

Position buffer_get_mark(Buffer buffer, String name, Error *err)
{
  Position rv;
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return rv;
  }

  if (name.size != 0) {
    set_api_error("mark name must be a single character", err);
    return rv;
  }

  pos_T *posp;
  buf_T *savebuf;
  char mark = *name.data;

  try_start();
  switch_buffer(&savebuf, buf);
  posp = getmark(mark, false);
  restore_buffer(savebuf);

  if (try_end(err)) {
    return rv;
  }

  if (posp == NULL) {
    set_api_error("invalid mark name", err);
    return rv;
  }

  rv.row = posp->lnum;
  rv.col = posp->col;
  return rv;
}

static void switch_to_win_for_buf(buf_T *buf,
                                  win_T **save_curwinp,
                                  tabpage_T **save_curtabp,
                                  buf_T **save_curbufp)
{
  win_T *wp;
  tabpage_T *tp;

  if (find_win_for_buf(buf, &wp, &tp) == FAIL
      || switch_win(save_curwinp, save_curtabp, wp, tp, true) == FAIL)
    switch_buffer(save_curbufp, buf);
}

static void restore_win_for_buf(win_T *save_curwin,
                                tabpage_T *save_curtab,
                                buf_T *save_curbuf)
{
  if (save_curbuf == NULL) {
    restore_win(save_curwin, save_curtab, true);
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
    } else if (extra < 0) {
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
