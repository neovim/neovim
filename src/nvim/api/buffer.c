// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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
#include "nvim/ex_cmds.h"
#include "nvim/mark.h"
#include "nvim/fileio.h"
#include "nvim/move.h"
#include "nvim/syntax.h"
#include "nvim/window.h"
#include "nvim/undo.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/buffer.c.generated.h"
#endif

/// Gets the buffer line count
///
/// @param buffer   Buffer handle
/// @param[out] err Error details, if any
/// @return Line count
Integer nvim_buf_line_count(Buffer buffer, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return 0;
  }

  return buf->b_ml.ml_line_count;
}

/// Gets a buffer line
///
/// @deprecated use nvim_buf_get_lines instead.
///             for positive indices (including 0) use
///                 "nvim_buf_get_lines(buffer, index, index+1, true)"
///             for negative indices use
///                 "nvim_buf_get_lines(buffer, index-1, index, true)"
///
/// @param buffer   Buffer handle
/// @param index    Line index
/// @param[out] err Error details, if any
/// @return Line string
String buffer_get_line(Buffer buffer, Integer index, Error *err)
{
  String rv = { .size = 0 };

  index = convert_index(index);
  Array slice = nvim_buf_get_lines(0, buffer, index, index+1, true, err);

  if (!ERROR_SET(err) && slice.size) {
    rv = slice.items[0].data.string;
  }

  xfree(slice.items);

  return rv;
}

/// Sets a buffer line
///
/// @deprecated use nvim_buf_set_lines instead.
///             for positive indices use
///                 "nvim_buf_set_lines(buffer, index, index+1, true, [line])"
///             for negative indices use
///                 "nvim_buf_set_lines(buffer, index-1, index, true, [line])"
///
/// @param buffer   Buffer handle
/// @param index    Line index
/// @param line     Contents of the new line
/// @param[out] err Error details, if any
void buffer_set_line(Buffer buffer, Integer index, String line, Error *err)
{
  Object l = STRING_OBJ(line);
  Array array = { .items = &l, .size = 1 };
  index = convert_index(index);
  nvim_buf_set_lines(0, buffer, index, index+1, true,  array, err);
}

/// Deletes a buffer line
///
/// @deprecated use nvim_buf_set_lines instead.
///             for positive indices use
///                 "nvim_buf_set_lines(buffer, index, index+1, true, [])"
///             for negative indices use
///                 "nvim_buf_set_lines(buffer, index-1, index, true, [])"
/// @param buffer   buffer handle
/// @param index    line index
/// @param[out] err Error details, if any
void buffer_del_line(Buffer buffer, Integer index, Error *err)
{
  Array array = ARRAY_DICT_INIT;
  index = convert_index(index);
  nvim_buf_set_lines(0, buffer, index, index+1, true, array, err);
}

/// Retrieves a line range from the buffer
///
/// @deprecated use nvim_buf_get_lines(buffer, newstart, newend, false)
///             where newstart = start + int(not include_start) - int(start < 0)
///                   newend = end + int(include_end) - int(end < 0)
///                   int(bool) = 1 if bool is true else 0
/// @param buffer         Buffer handle
/// @param start          First line index
/// @param end            Last line index
/// @param include_start  True if the slice includes the `start` parameter
/// @param include_end    True if the slice includes the `end` parameter
/// @param[out] err       Error details, if any
/// @return Array of lines
ArrayOf(String) buffer_get_line_slice(Buffer buffer,
                                      Integer start,
                                      Integer end,
                                      Boolean include_start,
                                      Boolean include_end,
                                      Error *err)
{
  start = convert_index(start) + !include_start;
  end = convert_index(end) + include_end;
  return nvim_buf_get_lines(0, buffer, start , end, false, err);
}

/// Retrieves a line range from the buffer
///
/// Indexing is zero-based, end-exclusive. Negative indices are interpreted
/// as length+1+index, i e -1 refers to the index past the end. So to get the
/// last element set start=-2 and end=-1.
///
/// Out-of-bounds indices are clamped to the nearest valid value, unless
/// `strict_indexing` is set.
///
/// @param buffer           Buffer handle
/// @param start            First line index
/// @param end              Last line index (exclusive)
/// @param strict_indexing  Whether out-of-bounds should be an error.
/// @param[out] err         Error details, if any
/// @return Array of lines
ArrayOf(String) nvim_buf_get_lines(uint64_t channel_id,
                                   Buffer buffer,
                                   Integer start,
                                   Integer end,
                                   Boolean strict_indexing,
                                   Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return rv;
  }

  bool oob = false;
  start = normalize_index(buf, start, &oob);
  end = normalize_index(buf, end, &oob);

  if (strict_indexing && oob) {
    api_set_error(err, kErrorTypeValidation, "Index out of bounds");
    return rv;
  }

  if (start >= end) {
    // Return 0-length array
    return rv;
  }

  rv.size = (size_t)(end - start);
  rv.items = xcalloc(sizeof(Object), rv.size);

  for (size_t i = 0; i < rv.size; i++) {
    int64_t lnum = start + (int64_t)i;

    if (lnum >= MAXLNUM) {
      api_set_error(err, kErrorTypeValidation, "Line index is too high");
      goto end;
    }

    const char *bufstr = (char *)ml_get_buf(buf, (linenr_T)lnum, false);
    Object str = STRING_OBJ(cstr_to_string(bufstr));

    // Vim represents NULs as NLs, but this may confuse clients.
    if (channel_id != VIML_INTERNAL_CALL) {
      strchrsub(str.data.string.data, '\n', '\0');
    }

    rv.items[i] = str;
  }

end:
  if (ERROR_SET(err)) {
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
/// @deprecated use nvim_buf_set_lines(buffer, newstart, newend, false, lines)
///             where newstart = start + int(not include_start) + int(start < 0)
///                   newend = end + int(include_end) + int(end < 0)
///                   int(bool) = 1 if bool is true else 0
///
/// @param buffer         Buffer handle
/// @param start          First line index
/// @param end            Last line index
/// @param include_start  True if the slice includes the `start` parameter
/// @param include_end    True if the slice includes the `end` parameter
/// @param replacement    Array of lines to use as replacement (0-length
//                        array will delete the line range)
/// @param[out] err       Error details, if any
void buffer_set_line_slice(Buffer buffer,
                           Integer start,
                           Integer end,
                           Boolean include_start,
                           Boolean include_end,
                           ArrayOf(String) replacement,  // NOLINT
                           Error *err)
{
  start = convert_index(start) + !include_start;
  end = convert_index(end) + include_end;
  nvim_buf_set_lines(0, buffer, start, end, false, replacement, err);
}


/// Replaces line range on the buffer
///
/// Indexing is zero-based, end-exclusive. Negative indices are interpreted
/// as length+1+index, i e -1 refers to the index past the end. So to change
/// or delete the last element set start=-2 and end=-1.
///
/// To insert lines at a given index, set both start and end to the same index.
/// To delete a range of lines, set replacement to an empty array.
///
/// Out-of-bounds indices are clamped to the nearest valid value, unless
/// `strict_indexing` is set.
///
/// @param buffer           Buffer handle
/// @param start            First line index
/// @param end              Last line index (exclusive)
/// @param strict_indexing  Whether out-of-bounds should be an error.
/// @param replacement      Array of lines to use as replacement
/// @param[out] err         Error details, if any
void nvim_buf_set_lines(uint64_t channel_id,
                        Buffer buffer,
                        Integer start,
                        Integer end,
                        Boolean strict_indexing,
                        ArrayOf(String) replacement,  // NOLINT
                        Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  bool oob = false;
  start = normalize_index(buf, start, &oob);
  end = normalize_index(buf, end, &oob);

  if (strict_indexing && oob) {
    api_set_error(err, kErrorTypeValidation, "Index out of bounds");
    return;
  }


  if (start > end) {
    api_set_error(err,
                  kErrorTypeValidation,
                  "Argument \"start\" is higher than \"end\"");
    return;
  }

  for (size_t i = 0; i < replacement.size; i++) {
    if (replacement.items[i].type != kObjectTypeString) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "All items in the replacement array must be strings");
      return;
    }
    // Disallow newlines in the middle of the line.
    if (channel_id != VIML_INTERNAL_CALL) {
      const String l = replacement.items[i].data.string;
      if (memchr(l.data, NL, l.size)) {
        api_set_error(err, kErrorTypeValidation,
                      "String cannot contain newlines");
        return;
      }
    }
  }

  win_T *save_curwin = NULL;
  tabpage_T *save_curtab = NULL;
  size_t new_len = replacement.size;
  size_t old_len = (size_t)(end - start);
  ptrdiff_t extra = 0;  // lines added to text, can be negative
  char **lines = (new_len != 0) ? xcalloc(new_len, sizeof(char *)) : NULL;

  for (size_t i = 0; i < new_len; i++) {
    const String l = replacement.items[i].data.string;

    // Fill lines[i] with l's contents. Convert NULs to newlines as required by
    // NL-used-for-NUL.
    lines[i] = xmemdupz(l.data, l.size);
    memchrsub(lines[i], NUL, NL, l.size);
  }

  try_start();
  bufref_T save_curbuf = { NULL, 0, 0 };
  switch_to_win_for_buf(buf, &save_curwin, &save_curtab, &save_curbuf);

  if (u_save((linenr_T)(start - 1), (linenr_T)end) == FAIL) {
    api_set_error(err, kErrorTypeException, "Failed to save undo information");
    goto end;
  }

  // If the size of the range is reducing (ie, new_len < old_len) we
  // need to delete some old_len. We do this at the start, by
  // repeatedly deleting line "start".
  size_t to_delete = (new_len < old_len) ? (size_t)(old_len - new_len) : 0;
  for (size_t i = 0; i < to_delete; i++) {
    if (ml_delete((linenr_T)start, false) == FAIL) {
      api_set_error(err, kErrorTypeException, "Failed to delete line");
      goto end;
    }
  }

  if (to_delete > 0) {
    extra -= (ptrdiff_t)to_delete;
  }

  // For as long as possible, replace the existing old_len with the
  // new old_len. This is a more efficient operation, as it requires
  // less memory allocation and freeing.
  size_t to_replace = old_len < new_len ? old_len : new_len;
  for (size_t i = 0; i < to_replace; i++) {
    int64_t lnum = start + (int64_t)i;

    if (lnum >= MAXLNUM) {
      api_set_error(err, kErrorTypeValidation, "Index value is too high");
      goto end;
    }

    if (ml_replace((linenr_T)lnum, (char_u *)lines[i], false) == FAIL) {
      api_set_error(err, kErrorTypeException, "Failed to replace line");
      goto end;
    }
    // Mark lines that haven't been passed to the buffer as they need
    // to be freed later
    lines[i] = NULL;
  }

  // Now we may need to insert the remaining new old_len
  for (size_t i = to_replace; i < new_len; i++) {
    int64_t lnum = start + (int64_t)i - 1;

    if (lnum >= MAXLNUM) {
      api_set_error(err, kErrorTypeValidation, "Index value is too high");
      goto end;
    }

    if (ml_append((linenr_T)lnum, (char_u *)lines[i], 0, false) == FAIL) {
      api_set_error(err, kErrorTypeException, "Failed to insert line");
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
  if (save_curbuf.br_buf == NULL) {
    mark_adjust((linenr_T)start,
                (linenr_T)(end - 1),
                MAXLNUM,
                (long)extra,
                false);
  }

  changed_lines((linenr_T)start, 0, (linenr_T)end, (long)extra);

  if (save_curbuf.br_buf == NULL) {
    fix_cursor((linenr_T)start, (linenr_T)end, (linenr_T)extra);
  }

end:
  for (size_t i = 0; i < new_len; i++) {
    xfree(lines[i]);
  }

  xfree(lines);
  restore_win_for_buf(save_curwin, save_curtab, &save_curbuf);
  try_end(err);
}

/// Gets a buffer-scoped (b:) variable.
///
/// @param buffer     Buffer handle
/// @param name       Variable name
/// @param[out] err   Error details, if any
/// @return Variable value
Object nvim_buf_get_var(Buffer buffer, String name, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object) OBJECT_INIT;
  }

  return dict_get_value(buf->b_vars, name, err);
}

/// Gets a changed tick of a buffer
///
/// @param[in]  buffer  Buffer handle.
/// @param[out] err     Error details, if any
///
/// @return `b:changedtick` value.
Integer nvim_buf_get_changedtick(Buffer buffer, Error *err)
  FUNC_API_SINCE(2)
{
  const buf_T *const buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return -1;
  }

  return buf->b_changedtick;
}

/// Gets a list of dictionaries describing buffer-local mappings.
/// The "buffer" key in the returned dictionary reflects the buffer
/// handle where the mapping is present.
///
/// @param  mode       Mode short-name ("n", "i", "v", ...)
/// @param  buffer     Buffer handle
/// @param[out]  err   Error details, if any
/// @returns Array of maparg()-like dictionaries describing mappings
ArrayOf(Dictionary) nvim_buf_get_keymap(Buffer buffer, String mode, Error *err)
    FUNC_API_SINCE(3)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Array)ARRAY_DICT_INIT;
  }

  return keymap_array(mode, buf);
}

/// Sets a buffer-scoped (b:) variable
///
/// @param buffer     Buffer handle
/// @param name       Variable name
/// @param value      Variable value
/// @param[out] err   Error details, if any
void nvim_buf_set_var(Buffer buffer, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  dict_set_var(buf->b_vars, name, value, false, false, err);
}

/// Removes a buffer-scoped (b:) variable
///
/// @param buffer     Buffer handle
/// @param name       Variable name
/// @param[out] err   Error details, if any
void nvim_buf_del_var(Buffer buffer, String name, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  dict_set_var(buf->b_vars, name, NIL, true, false, err);
}

/// Sets a buffer-scoped (b:) variable
///
/// @deprecated
///
/// @param buffer     Buffer handle
/// @param name       Variable name
/// @param value      Variable value
/// @param[out] err   Error details, if any
/// @return Old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object buffer_set_var(Buffer buffer, String name, Object value, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_var(buf->b_vars, name, value, false, true, err);
}

/// Removes a buffer-scoped (b:) variable
///
/// @deprecated
///
/// @param buffer     Buffer handle
/// @param name       Variable name
/// @param[out] err   Error details, if any
/// @return Old value
Object buffer_del_var(Buffer buffer, String name, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_var(buf->b_vars, name, NIL, true, true, err);
}


/// Gets a buffer option value
///
/// @param buffer     Buffer handle
/// @param name       Option name
/// @param[out] err   Error details, if any
/// @return Option value
Object nvim_buf_get_option(Buffer buffer, String name, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object) OBJECT_INIT;
  }

  return get_option_from(buf, SREQ_BUF, name, err);
}

/// Sets a buffer option value. Passing 'nil' as value deletes the option (only
/// works if there's a global fallback)
///
/// @param buffer     Buffer handle
/// @param name       Option name
/// @param value      Option value
/// @param[out] err   Error details, if any
void nvim_buf_set_option(Buffer buffer, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  set_option_to(buf, SREQ_BUF, name, value, err);
}

/// Gets the buffer number
///
/// @deprecated The buffer number now is equal to the object id,
///             so there is no need to use this function.
///
/// @param buffer     Buffer handle
/// @param[out] err   Error details, if any
/// @return Buffer number
Integer nvim_buf_get_number(Buffer buffer, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(2)
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
/// @param buffer     Buffer handle
/// @param[out] err   Error details, if any
/// @return Buffer name
String nvim_buf_get_name(Buffer buffer, Error *err)
  FUNC_API_SINCE(1)
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
/// @param buffer     Buffer handle
/// @param name       Buffer name
/// @param[out] err   Error details, if any
void nvim_buf_set_name(Buffer buffer, String name, Error *err)
  FUNC_API_SINCE(1)
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
    api_set_error(err, kErrorTypeException, "Failed to rename buffer");
  }
}

/// Checks if a buffer is valid
///
/// @param buffer Buffer handle
/// @return true if the buffer is valid, false otherwise
Boolean nvim_buf_is_valid(Buffer buffer)
  FUNC_API_SINCE(1)
{
  Error stub = ERROR_INIT;
  Boolean ret = find_buffer_by_handle(buffer, &stub) != NULL;
  api_clear_error(&stub);
  return ret;
}

/// Inserts a sequence of lines to a buffer at a certain index
///
/// @deprecated use nvim_buf_set_lines(buffer, lnum, lnum, true, lines)
///
/// @param buffer     Buffer handle
/// @param lnum       Insert the lines after `lnum`. If negative, appends to
///                   the end of the buffer.
/// @param lines      Array of lines
/// @param[out] err   Error details, if any
void buffer_insert(Buffer buffer,
                   Integer lnum,
                   ArrayOf(String) lines,
                   Error *err)
{
  // "lnum" will be the index of the line after inserting,
  // no matter if it is negative or not
  nvim_buf_set_lines(0, buffer, lnum, lnum, true, lines, err);
}

/// Return a tuple (row,col) representing the position of the named mark
///
/// @param buffer     Buffer handle
/// @param name       Mark name
/// @param[out] err   Error details, if any
/// @return (row, col) tuple
ArrayOf(Integer, 2) nvim_buf_get_mark(Buffer buffer, String name, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return rv;
  }

  if (name.size != 1) {
    api_set_error(err, kErrorTypeValidation,
                  "Mark name must be a single character");
    return rv;
  }

  pos_T *posp;
  char mark = *name.data;

  try_start();
  bufref_T save_buf;
  switch_buffer(&save_buf, buf);
  posp = getmark(mark, false);
  restore_buffer(&save_buf);

  if (try_end(err)) {
    return rv;
  }

  if (posp == NULL) {
    api_set_error(err, kErrorTypeValidation, "Invalid mark name");
    return rv;
  }

  ADD(rv, INTEGER_OBJ(posp->lnum));
  ADD(rv, INTEGER_OBJ(posp->col));

  return rv;
}

/// Adds a highlight to buffer.
///
/// Useful for plugins that dynamically generate highlights to a buffer
/// (like a semantic highlighter or linter). The function adds a single
/// highlight to a buffer. Unlike matchaddpos() highlights follow changes to
/// line numbering (as lines are inserted/removed above the highlighted line),
/// like signs and marks do.
///
/// `src_id` is useful for batch deletion/updating of a set of highlights. When
/// called with `src_id = 0`, an unique source id is generated and returned.
/// Successive calls can pass that `src_id` to associate new highlights with
/// the same source group. All highlights in the same group can be cleared
/// with `nvim_buf_clear_highlight`. If the highlight never will be manually
/// deleted, pass `src_id = -1`.
///
/// If `hl_group` is the empty string no highlight is added, but a new `src_id`
/// is still returned. This is useful for an external plugin to synchrounously
/// request an unique `src_id` at initialization, and later asynchronously add
/// and clear highlights in response to buffer changes.
///
/// @param buffer     Buffer handle
/// @param src_id     Source group to use or 0 to use a new group,
///                   or -1 for ungrouped highlight
/// @param hl_group   Name of the highlight group to use
/// @param line       Line to highlight (zero-indexed)
/// @param col_start  Start of (byte-indexed) column range to highlight
/// @param col_end    End of (byte-indexed) column range to highlight,
///                   or -1 to highlight to end of line
/// @param[out] err   Error details, if any
/// @return The src_id that was used
Integer nvim_buf_add_highlight(Buffer buffer,
                               Integer src_id,
                               String hl_group,
                               Integer line,
                               Integer col_start,
                               Integer col_end,
                               Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }

  if (line < 0 || line >= MAXLNUM) {
    api_set_error(err, kErrorTypeValidation, "Line number outside range");
    return 0;
  }
  if (col_start < 0 || col_start > MAXCOL) {
    api_set_error(err, kErrorTypeValidation, "Column value outside range");
    return 0;
  }
  if (col_end < 0 || col_end > MAXCOL) {
    col_end = MAXCOL;
  }

  int hlg_id = 0;
  if (hl_group.size > 0) {
    hlg_id = syn_check_group((char_u *)hl_group.data, (int)hl_group.size);
  }

  src_id = bufhl_add_hl(buf, (int)src_id, hlg_id, (linenr_T)line+1,
                        (colnr_T)col_start+1, (colnr_T)col_end);
  return src_id;
}

/// Clears highlights from a given source group and a range of lines
///
/// To clear a source group in the entire buffer, pass in 0 and -1 to
/// line_start and line_end respectively.
///
/// @param buffer     Buffer handle
/// @param src_id     Highlight source group to clear, or -1 to clear all.
/// @param line_start Start of range of lines to clear
/// @param line_end   End of range of lines to clear (exclusive) or -1 to clear
///                   to end of file.
/// @param[out] err   Error details, if any
void nvim_buf_clear_highlight(Buffer buffer,
                              Integer src_id,
                              Integer line_start,
                              Integer line_end,
                              Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return;
  }

  if (line_start < 0 || line_start >= MAXLNUM) {
    api_set_error(err, kErrorTypeValidation, "Line number outside range");
    return;
  }
  if (line_end < 0 || line_end > MAXLNUM) {
    line_end = MAXLNUM;
  }

  bufhl_clear_line_range(buf, (int)src_id, (int)line_start+1, (int)line_end);
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
static int64_t normalize_index(buf_T *buf, int64_t index, bool *oob)
{
  int64_t line_count = buf->b_ml.ml_line_count;
  // Fix if < 0
  index = index < 0 ? line_count + index +1 : index;

  // Check for oob
  if (index > line_count) {
    *oob = true;
    index = line_count;
  } else if (index < 0) {
    *oob = true;
    index = 0;
  }
  // Convert the index to a vim line number
  index++;
  return index;
}

static int64_t convert_index(int64_t index)
{
  return index < 0 ? index - 1 : index;
}
