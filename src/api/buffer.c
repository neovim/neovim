// Much of this code was adapted from 'if_py_both.h' from the original
// vim source
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
#include "ex_cmds.h"
#include "mark.h"
#include "fileio.h"
#include "move.h"
#include "../window.h"
#include "undo.h"

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
  buf_T *buf = find_buffer(buffer, err);

  if (!buf) {
    return 0;
  }

  return buf->b_ml.ml_line_count;
}

String buffer_get_line(Buffer buffer, int64_t index, Error *err)
{
  String rv = {.size = 0};
  StringArray slice = buffer_get_slice(buffer, index, index, true, true, err);

  if (slice.size) {
    rv = slice.items[0];
  }

  return rv;
}

void buffer_set_line(Buffer buffer, int64_t index, String line, Error *err)
{
  StringArray array = {.items = &line, .size = 1};
  buffer_set_slice(buffer, index, index, true, true, array, err);
}

void buffer_del_line(Buffer buffer, int64_t index, Error *err)
{
  StringArray array = {.size = 0};
  buffer_set_slice(buffer, index, index, true, true, array, err);
}

StringArray buffer_get_slice(Buffer buffer,
                             int64_t start,
                             int64_t end,
                             bool include_start,
                             bool include_end,
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

  rv.size = end - start;
  rv.items = xmalloc(sizeof(String) * rv.size);

  for (uint32_t i = 0; i < rv.size; i++) {
    rv.items[i].data = xstrdup((char *)ml_get_buf(buf, start + i, FALSE));
    rv.items[i].size = strlen(rv.items[i].data);
  }

  return rv;
}

void buffer_set_slice(Buffer buffer,
                      int64_t start,
                      int64_t end,
                      bool include_start,
                      bool include_end,
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
  uint32_t new_len = replacement.size;
  uint32_t old_len = end - start;
  uint32_t i;
  int32_t extra = 0; // lines added to text, can be negative
  char **lines;

  if (new_len == 0) {
    // avoid allocating zero bytes
    lines = NULL;
  } else {
    lines = xcalloc(sizeof(char *), new_len);
  }

  for (i = 0; i < new_len; i++) {
    String l = replacement.items[i];
    lines[i] = xstrndup(l.data, l.size);
  }

  try_start();
  switch_to_win_for_buf(buf, &save_curwin, &save_curtab, &save_curbuf);

  if (u_save(start - 1, end) == FAIL) {
    set_api_error("Cannot save undo information", err);
    goto cleanup;
  }

  // If the size of the range is reducing (ie, new_len < old_len) we
  // need to delete some old_len. We do this at the start, by
  // repeatedly deleting line "start".
  for (i = 0; new_len < old_len && i < old_len - new_len; i++) {
    if (ml_delete(start, false) == FAIL) {
      set_api_error("Cannot delete line", err);
      goto cleanup;
    }
  }

  extra -= i;

  // For as long as possible, replace the existing old_len with the
  // new old_len. This is a more efficient operation, as it requires
  // less memory allocation and freeing.
  for (i = 0; i < old_len && i < new_len; i++) {
    if (ml_replace(start + i, (char_u *)lines[i], false) == FAIL) {
      set_api_error("Cannot replace line", err);
      goto cleanup;
    }
    // Mark lines that haven't been passed to the buffer as they need
    // to be freed later
    lines[i] = NULL;
  }

  // Now we may need to insert the remaining new old_len
  while (i < new_len) {
    if (ml_append(start + i - 1, (char_u *)lines[i], 0, false) == FAIL) {
      set_api_error("Cannot insert line", err);
      goto cleanup;
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
    mark_adjust(start, end - 1, MAXLNUM, extra);
  }

  changed_lines(start, 0, end, extra);

  if (buf == curbuf) {
    fix_cursor(start, end, extra);
  }

cleanup:
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

  return dict_get_value(buf->b_vars, name, false, err);
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

  rv.data = xstrdup((char *)buf->b_ffname);
  rv.size = strlen(rv.data);
  return rv;
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
