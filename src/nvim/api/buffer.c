// Much of this code was adapted from 'if_py_both.h' from the original
// vim source
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>

#include "nvim/api/buffer.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/cursor.h"
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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/buffer.c.generated.h"
#endif

/// Gets the buffer line count
///
/// @param buffer The buffer handle
/// @param[out] err Details of an error that may have occurred
/// @return The line count
Integer buffer_line_count(Buffer buffer, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return 0;
  }

  return buf->b_ml.ml_line_count;
}

/// Gets a buffer line
///
/// @param buffer The buffer handle
/// @param index The line index
/// @param[out] err Details of an error that may have occurred
/// @return The line string
String buffer_get_line(Buffer buffer, Integer index, Error *err)
{
  String rv = {.size = 0};
  Array slice = buffer_get_line_slice(buffer, index, index, true, true, err);

  if (!err->set && slice.size) {
    rv = slice.items[0].data.string;
  }

  xfree(slice.items);

  return rv;
}

/// Sets a buffer line
///
/// @param buffer The buffer handle
/// @param index The line index
/// @param line The new line.
/// @param[out] err Details of an error that may have occurred
void buffer_set_line(Buffer buffer, Integer index, String line, Error *err)
{
  Object l = STRING_OBJ(line);
  Array array = {.items = &l, .size = 1};
  buffer_set_line_slice(buffer, index, index, true, true, array, err);
}

/// Deletes a buffer line
///
/// @param buffer The buffer handle
/// @param index The line index
/// @param[out] err Details of an error that may have occurred
void buffer_del_line(Buffer buffer, Integer index, Error *err)
{
  Array array = ARRAY_DICT_INIT;
  buffer_set_line_slice(buffer, index, index, true, true, array, err);
}

/// Retrieves a line range from the buffer
///
/// @param buffer The buffer handle
/// @param start The first line index
/// @param end The last line index
/// @param include_start True if the slice includes the `start` parameter
/// @param include_end True if the slice includes the `end` parameter
/// @param[out] err Details of an error that may have occurred
/// @return An array of lines
ArrayOf(String) buffer_get_line_slice(Buffer buffer,
                                 Integer start,
                                 Integer end,
                                 Boolean include_start,
                                 Boolean include_end,
                                 Error *err)
{
  Array rv = ARRAY_DICT_INIT;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf || !inbounds(buf, start)) {
    return rv;
  }

  start = normalize_index(buf, start) + (include_start ? 0 : 1);
  include_end = include_end || (end >= buf->b_ml.ml_line_count);
  end = normalize_index(buf, end) + (include_end ? 1 : 0);

  if (start >= end) {
    // Return 0-length array
    return rv;
  }

  rv.size = (size_t)(end - start);
  rv.items = xcalloc(sizeof(Object), rv.size);

  for (size_t i = 0; i < rv.size; i++) {
    int64_t lnum = start + (int64_t)i;

    if (lnum > LONG_MAX) {
      api_set_error(err, Validation, _("Line index is too high"));
      goto end;
    }

    const char *bufstr = (char *) ml_get_buf(buf, (linenr_T) lnum, false);
    Object str = STRING_OBJ(cstr_to_string(bufstr));

    // Vim represents NULs as NLs, but this may confuse clients.
    strchrsub(str.data.string.data, '\n', '\0');

    rv.items[i] = str;
  }

end:
  if (err->set) {
    for (size_t i = 0; i < rv.size; i++) {
      xfree(rv.items[i].data.string.data);
    }

    xfree(rv.items);
    rv.items = NULL;
  }

  return rv;
}

/// Replaces a line range on the buffer
///
/// @param buffer The buffer handle
/// @param start The first line index
/// @param end The last line index
/// @param include_start True if the slice includes the `start` parameter
/// @param include_end True if the slice includes the `end` parameter
/// @param replacement An array of lines to use as replacement(A 0-length
//         array will simply delete the line range)
/// @param[out] err Details of an error that may have occurred
void buffer_set_line_slice(Buffer buffer,
                      Integer start,
                      Integer end,
                      Boolean include_start,
                      Boolean include_end,
                      ArrayOf(String) replacement,
                      Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  if (!inbounds(buf, start)) {
    api_set_error(err, Validation, _("Index out of bounds"));
    return;
  }

  start = normalize_index(buf, start) + (include_start ? 0 : 1);
  include_end = include_end || (end >= buf->b_ml.ml_line_count);
  end = normalize_index(buf, end) + (include_end ? 1 : 0);

  if (start > end) {
    api_set_error(err,
                  Validation,
                  _("Argument \"start\" is higher than \"end\""));
    return;
  }

  buf_T *save_curbuf = NULL;
  win_T *save_curwin = NULL;
  tabpage_T *save_curtab = NULL;
  size_t new_len = replacement.size;
  size_t old_len = (size_t)(end - start);
  ssize_t extra = 0;  // lines added to text, can be negative
  char **lines = (new_len != 0) ? xcalloc(new_len, sizeof(char *)) : NULL;

  for (size_t i = 0; i < new_len; i++) {
    if (replacement.items[i].type != kObjectTypeString) {
      api_set_error(err,
                    Validation,
                    _("All items in the replacement array must be strings"));
      goto end;
    }

    String l = replacement.items[i].data.string;

    // Fill lines[i] with l's contents. Disallow newlines in the middle of a
    // line and convert NULs to newlines to avoid truncation.
    lines[i] = xmallocz(l.size);
    for (size_t j = 0; j < l.size; j++) {
      if (l.data[j] == '\n') {
        api_set_error(err, Exception, _("string cannot contain newlines"));
        new_len = i + 1;
        goto end;
      }
      lines[i][j] = (char) (l.data[j] == '\0' ? '\n' : l.data[j]);
    }
  }

  try_start();
  switch_to_win_for_buf(buf, &save_curwin, &save_curtab, &save_curbuf);

  if (u_save((linenr_T)(start - 1), (linenr_T)end) == FAIL) {
    api_set_error(err, Exception, _("Failed to save undo information"));
    goto end;
  }

  // If the size of the range is reducing (ie, new_len < old_len) we
  // need to delete some old_len. We do this at the start, by
  // repeatedly deleting line "start".
  size_t to_delete = (new_len < old_len) ? (size_t)(old_len - new_len) : 0;
  for (size_t i = 0; i < to_delete; i++) {
    if (ml_delete((linenr_T)start, false) == FAIL) {
      api_set_error(err, Exception, _("Failed to delete line"));
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
      api_set_error(err, Validation, _("Index value is too high"));
      goto end;
    }

    if (ml_replace((linenr_T)lnum, (char_u *)lines[i], false) == FAIL) {
      api_set_error(err, Exception, _("Failed to replace line"));
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
      api_set_error(err, Validation, _("Index value is too high"));
      goto end;
    }

    if (ml_append((linenr_T)lnum, (char_u *)lines[i], 0, false) == FAIL) {
      api_set_error(err, Exception, _("Failed to insert line"));
      goto end;
    }

    // Same as with replacing, but we also need to free lines
    xfree(lines[i]);
    lines[i] = NULL;
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
  for (size_t i = 0; i < new_len; i++) {
    xfree(lines[i]);
  }

  xfree(lines);
  restore_win_for_buf(save_curwin, save_curtab, save_curbuf);
  try_end(err);
}

/// Gets a buffer-scoped (b:) variable.
///
/// @param buffer The buffer handle
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object buffer_get_var(Buffer buffer, String name, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object) OBJECT_INIT;
  }

  return dict_get_value(buf->b_vars, name, err);
}

/// Sets a buffer-scoped (b:) variable. 'nil' value deletes the variable.
///
/// @param buffer The buffer handle
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return The old value
Object buffer_set_var(Buffer buffer, String name, Object value, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_value(buf->b_vars, name, value, err);
}

/// Gets a buffer option value
///
/// @param buffer The buffer handle
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return The option value
Object buffer_get_option(Buffer buffer, String name, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object) OBJECT_INIT;
  }

  return get_option_from(buf, SREQ_BUF, name, err);
}

/// Sets a buffer option value. Passing 'nil' as value deletes the option(only
/// works if there's a global fallback)
///
/// @param buffer The buffer handle
/// @param name The option name
/// @param value The option value
/// @param[out] err Details of an error that may have occurred
void buffer_set_option(Buffer buffer, String name, Object value, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  set_option_to(buf, SREQ_BUF, name, value, err);
}

/// Gets the buffer number
///
/// @param buffer The buffer handle
/// @param[out] err Details of an error that may have occurred
/// @return The buffer number
Integer buffer_get_number(Buffer buffer, Error *err)
{
  Integer rv = 0;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return rv;
  }

  return buf->b_fnum;
}

/// Gets the full file name for the buffer
///
/// @param buffer The buffer handle
/// @param[out] err Details of an error that may have occurred
/// @return The buffer name
String buffer_get_name(Buffer buffer, Error *err)
{
  String rv = STRING_INIT;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf || buf->b_ffname == NULL) {
    return rv;
  }

  return cstr_to_string((char *)buf->b_ffname);
}

/// Sets the full file name for a buffer
///
/// @param buffer The buffer handle
/// @param name The buffer name
/// @param[out] err Details of an error that may have occurred
void buffer_set_name(Buffer buffer, String name, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  try_start();

  // Using aucmd_*: autocommands will be executed by rename_buffer
  aco_save_T aco;
  aucmd_prepbuf(&aco, buf);
  int ren_ret = rename_buffer((char_u *) name.data);
  aucmd_restbuf(&aco);

  if (try_end(err)) {
    return;
  }

  if (ren_ret == FAIL) {
    api_set_error(err, Exception, _("Failed to rename buffer"));
  }
}

/// Checks if a buffer is valid
///
/// @param buffer The buffer handle
/// @return true if the buffer is valid, false otherwise
Boolean buffer_is_valid(Buffer buffer)
{
  Error stub = ERROR_INIT;
  return find_buffer_by_handle(buffer, &stub) != NULL;
}

/// Inserts a sequence of lines to a buffer at a certain index
///
/// @param buffer The buffer handle
/// @param lnum Insert the lines after `lnum`. If negative, it will append
///        to the end of the buffer.
/// @param lines An array of lines
/// @param[out] err Details of an error that may have occurred
void buffer_insert(Buffer buffer,
                   Integer lnum,
                   ArrayOf(String) lines,
                   Error *err)
{
  bool end_start = lnum < 0;
  buffer_set_line_slice(buffer, lnum, lnum, !end_start, end_start, lines, err);
}

/// Return a tuple (row,col) representing the position of the named mark
///
/// @param buffer The buffer handle
/// @param name The mark's name
/// @param[out] err Details of an error that may have occurred
/// @return The (row, col) tuple
ArrayOf(Integer, 2) buffer_get_mark(Buffer buffer, String name, Error *err)
{
  Array rv = ARRAY_DICT_INIT;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return rv;
  }

  if (name.size != 1) {
    api_set_error(err, Validation, _("Mark name must be a single character"));
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
    api_set_error(err, Validation, _("Invalid mark name"));
    return rv;
  }

  ADD(rv, INTEGER_OBJ(posp->lnum));
  ADD(rv, INTEGER_OBJ(posp->col));

  return rv;
}


// Check if deleting lines made the cursor position invalid.
// Changed the lines from "lo" to "hi" and added "extra" lines (negative if
// deleted).
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

// Normalizes 0-based indexes to buffer line numbers
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

// Returns true if the 0-indexed `index` is within the 1-indexed buffer bounds.
static bool inbounds(buf_T *buf, int64_t index)
{
  linenr_T nlines = buf->b_ml.ml_line_count;
  return index >= -nlines && index < nlines;
}
