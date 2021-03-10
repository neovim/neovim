// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Some of this code was adapted from 'if_py_both.h' from the original
// vim source
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>

#include <lauxlib.h>

#include "nvim/api/buffer.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/lua/executor.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/getchar.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/ex_cmds.h"
#include "nvim/map_defs.h"
#include "nvim/map.h"
#include "nvim/mark.h"
#include "nvim/extmark.h"
#include "nvim/decoration.h"
#include "nvim/fileio.h"
#include "nvim/move.h"
#include "nvim/syntax.h"
#include "nvim/window.h"
#include "nvim/undo.h"
#include "nvim/ex_docmd.h"
#include "nvim/buffer_updates.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/buffer.c.generated.h"
#endif


/// \defgroup api-buffer
///
/// \brief For more information on buffers, see |buffers|
///
/// Unloaded Buffers:~
///
/// Buffers may be unloaded by the |:bunload| command or the buffer's
/// |'bufhidden'| option. When a buffer is unloaded its file contents are freed
/// from memory and vim cannot operate on the buffer lines until it is reloaded
/// (usually by opening the buffer again in a new window). API methods such as
/// |nvim_buf_get_lines()| and |nvim_buf_line_count()| will be affected.
///
/// You can use |nvim_buf_is_loaded()| or |nvim_buf_line_count()| to check
/// whether a buffer is loaded.


/// Gets the buffer line count
///
/// @param buffer   Buffer handle, or 0 for current buffer
/// @param[out] err Error details, if any
/// @return Line count, or 0 for unloaded buffer. |api-buffer|
Integer nvim_buf_line_count(Buffer buffer, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return 0;
  }

  // return sentinel value if the buffer isn't loaded
  if (buf->b_ml.ml_mfp == NULL) {
    return 0;
  }

  return buf->b_ml.ml_line_count;
}

/// Activates buffer-update events on a channel, or as Lua callbacks.
///
/// Example (Lua): capture buffer updates in a global `events` variable
/// (use "print(vim.inspect(events))" to see its contents):
/// <pre>
///   events = {}
///   vim.api.nvim_buf_attach(0, false, {
///     on_lines=function(...) table.insert(events, {...}) end})
/// </pre>
///
/// @see |nvim_buf_detach()|
/// @see |api-buffer-updates-lua|
///
/// @param channel_id
/// @param buffer Buffer handle, or 0 for current buffer
/// @param send_buffer True if the initial notification should contain the
///        whole buffer: first notification will be `nvim_buf_lines_event`.
///        Else the first notification will be `nvim_buf_changedtick_event`.
///        Not for Lua callbacks.
/// @param  opts  Optional parameters.
///             - on_lines: Lua callback invoked on change.
///               Return `true` to detach. Args:
///               - the string "lines"
///               - buffer handle
///               - b:changedtick
///               - first line that changed (zero-indexed)
///               - last line that was changed
///               - last line in the updated range
///               - byte count of previous contents
///               - deleted_codepoints (if `utf_sizes` is true)
///               - deleted_codeunits (if `utf_sizes` is true)
///             - on_bytes: lua callback invoked on change.
///               This callback receives more granular information about the
///               change compared to on_lines.
///               Return `true` to detach.
///               Args:
///               - the string "bytes"
///               - buffer handle
///               - b:changedtick
///               - start row of the changed text (zero-indexed)
///               - start column of the changed text
///               - byte offset of the changed text (from the start of
///                   the buffer)
///               - old end row of the changed text
///               - old end column of the changed text
///               - old end byte length of the changed text
///               - new end row of the changed text
///               - new end column of the changed text
///               - new end byte length of the changed text
///             - on_changedtick: Lua callback invoked on changedtick
///               increment without text change. Args:
///               - the string "changedtick"
///               - buffer handle
///               - b:changedtick
///             - on_detach: Lua callback invoked on detach. Args:
///               - the string "detach"
///               - buffer handle
///             - on_reload: Lua callback invoked on reload. The entire buffer
///                          content should be considered changed. Args:
///               - the string "detach"
///               - buffer handle
///             - utf_sizes: include UTF-32 and UTF-16 size of the replaced
///               region, as args to `on_lines`.
///             - preview: also attach to command preview (i.e. 'inccommand')
///               events.
/// @param[out] err Error details, if any
/// @return False if attach failed (invalid parameter, or buffer isn't loaded);
///         otherwise True. TODO: LUA_API_NO_EVAL
Boolean nvim_buf_attach(uint64_t channel_id,
                        Buffer buffer,
                        Boolean send_buffer,
                        DictionaryOf(LuaRef) opts,
                        Error *err)
  FUNC_API_SINCE(4)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return false;
  }

  bool is_lua = (channel_id == LUA_INTERNAL_CALL);
  BufUpdateCallbacks cb = BUF_UPDATE_CALLBACKS_INIT;
  struct {
    const char *name;
    LuaRef *dest;
  } cbs[] = {
    { "on_lines", &cb.on_lines },
    { "on_bytes", &cb.on_bytes },
    { "on_changedtick", &cb.on_changedtick },
    { "on_detach", &cb.on_detach },
    { "on_reload", &cb.on_reload },
    { NULL, NULL },
  };

  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    bool key_used = false;
    if (is_lua) {
      for (size_t j = 0; cbs[j].name; j++) {
        if (strequal(cbs[j].name, k.data)) {
          if (v->type != kObjectTypeLuaRef) {
            api_set_error(err, kErrorTypeValidation,
                          "%s is not a function", cbs[j].name);
            goto error;
          }
          *(cbs[j].dest) = v->data.luaref;
          v->data.luaref = LUA_NOREF;
          key_used = true;
          break;
        }
      }

      if (key_used) {
        continue;
      } else if (strequal("utf_sizes", k.data)) {
        if (v->type != kObjectTypeBoolean) {
          api_set_error(err, kErrorTypeValidation, "utf_sizes must be boolean");
          goto error;
        }
        cb.utf_sizes = v->data.boolean;
        key_used = true;
      } else if (strequal("preview", k.data)) {
        if (v->type != kObjectTypeBoolean) {
          api_set_error(err, kErrorTypeValidation, "preview must be boolean");
          goto error;
        }
        cb.preview = v->data.boolean;
        key_used = true;
      }
    }

    if (!key_used) {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      goto error;
    }
  }

  return buf_updates_register(buf, channel_id, cb, send_buffer);

error:
  // TODO(bfredl): ASAN build should check that the ref table is empty?
  api_free_luaref(cb.on_lines);
  api_free_luaref(cb.on_bytes);
  api_free_luaref(cb.on_changedtick);
  api_free_luaref(cb.on_detach);
  return false;
}

/// Deactivates buffer-update events on the channel.
///
/// @see |nvim_buf_attach()|
/// @see |api-lua-detach| for detaching Lua callbacks
///
/// @param channel_id
/// @param buffer Buffer handle, or 0 for current buffer
/// @param[out] err Error details, if any
/// @return False if detach failed (because the buffer isn't loaded);
///         otherwise True.
Boolean nvim_buf_detach(uint64_t channel_id,
                        Buffer buffer,
                        Error *err)
  FUNC_API_SINCE(4) FUNC_API_REMOTE_ONLY
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return false;
  }

  buf_updates_unregister(buf, channel_id);
  return true;
}

void nvim__buf_redraw_range(Buffer buffer, Integer first, Integer last,
                            Error *err)
  FUNC_API_LUA_ONLY
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return;
  }

  redraw_buf_range_later(buf, (linenr_T)first+1, (linenr_T)last);
}

/// Gets a line-range from the buffer.
///
/// Indexing is zero-based, end-exclusive. Negative indices are interpreted
/// as length+1+index: -1 refers to the index past the end. So to get the
/// last element use start=-2 and end=-1.
///
/// Out-of-bounds indices are clamped to the nearest valid value, unless
/// `strict_indexing` is set.
///
/// @param channel_id
/// @param buffer           Buffer handle, or 0 for current buffer
/// @param start            First line index
/// @param end              Last line index (exclusive)
/// @param strict_indexing  Whether out-of-bounds should be an error.
/// @param[out] err         Error details, if any
/// @return Array of lines, or empty array for unloaded buffer.
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

  // return sentinel value if the buffer isn't loaded
  if (buf->b_ml.ml_mfp == NULL) {
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

  if (!buf_collect_lines(buf, rv.size, start,
                         (channel_id != VIML_INTERNAL_CALL), &rv, err)) {
    goto end;
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

static bool check_string_array(Array arr, bool disallow_nl, Error *err)
{
  for (size_t i = 0; i < arr.size; i++) {
    if (arr.items[i].type != kObjectTypeString) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "All items in the replacement array must be strings");
      return false;
    }
    // Disallow newlines in the middle of the line.
    if (disallow_nl) {
      const String l = arr.items[i].data.string;
      if (memchr(l.data, NL, l.size)) {
        api_set_error(err, kErrorTypeValidation,
                      "String cannot contain newlines");
        return false;
      }
    }
  }
  return true;
}

/// Sets (replaces) a line-range in the buffer.
///
/// Indexing is zero-based, end-exclusive. Negative indices are interpreted
/// as length+1+index: -1 refers to the index past the end. So to change
/// or delete the last element use start=-2 and end=-1.
///
/// To insert lines at a given index, set `start` and `end` to the same index.
/// To delete a range of lines, set `replacement` to an empty array.
///
/// Out-of-bounds indices are clamped to the nearest valid value, unless
/// `strict_indexing` is set.
///
/// @param channel_id
/// @param buffer           Buffer handle, or 0 for current buffer
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
                        ArrayOf(String) replacement,
                        Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_CHECK_TEXTLOCK
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

  bool disallow_nl = (channel_id != VIML_INTERNAL_CALL);
  if (!check_string_array(replacement, disallow_nl, err)) {
    return;
  }

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
  aco_save_T aco;
  aucmd_prepbuf(&aco, (buf_T *)buf);

  if (!MODIFIABLE(buf)) {
    api_set_error(err, kErrorTypeException, "Buffer is not 'modifiable'");
    goto end;
  }

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
  mark_adjust((linenr_T)start,
              (linenr_T)(end - 1),
              MAXLNUM,
              (long)extra,
              kExtmarkUndo);

  changed_lines((linenr_T)start, 0, (linenr_T)end, (long)extra, true);
  fix_cursor((linenr_T)start, (linenr_T)end, (linenr_T)extra);

end:
  for (size_t i = 0; i < new_len; i++) {
    xfree(lines[i]);
  }

  xfree(lines);
  aucmd_restbuf(&aco);
  try_end(err);
}

/// Sets (replaces) a range in the buffer
///
/// This is recommended over nvim_buf_set_lines when only modifying parts of a
/// line, as extmarks will be preserved on non-modified parts of the touched
/// lines.
///
/// Indexing is zero-based and end-exclusive.
///
/// To insert text at a given index, set `start` and `end` ranges to the same
/// index. To delete a range, set `replacement` to an array containing
/// an empty string, or simply an empty array.
///
/// Prefer nvim_buf_set_lines when adding or deleting entire lines only.
///
/// @param channel_id
/// @param buffer           Buffer handle, or 0 for current buffer
/// @param start_row        First line index
/// @param start_column     Last column
/// @param end_row          Last line index
/// @param end_column       Last column
/// @param replacement      Array of lines to use as replacement
/// @param[out] err         Error details, if any
void nvim_buf_set_text(uint64_t channel_id, Buffer buffer,
                       Integer start_row, Integer start_col,
                       Integer end_row, Integer end_col,
                       ArrayOf(String) replacement, Error *err)
  FUNC_API_SINCE(7)
{
  FIXED_TEMP_ARRAY(scratch, 1);
  if (replacement.size == 0) {
    scratch.items[0] = STRING_OBJ(STATIC_CSTR_AS_STRING(""));
    replacement = scratch;
  }

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return;
  }

  bool oob = false;

  // check range is ordered and everything!
  // start_row, end_row within buffer len (except add text past the end?)
  start_row = normalize_index(buf, start_row, &oob);
  if (oob || start_row == buf->b_ml.ml_line_count + 1) {
    api_set_error(err, kErrorTypeValidation, "start_row out of bounds");
    return;
  }

  end_row = normalize_index(buf, end_row, &oob);
  if (oob || end_row == buf->b_ml.ml_line_count + 1) {
    api_set_error(err, kErrorTypeValidation, "end_row out of bounds");
    return;
  }

  char *str_at_start = (char *)ml_get_buf(buf, start_row, false);
  if (start_col < 0 || (size_t)start_col > strlen(str_at_start)) {
    api_set_error(err, kErrorTypeValidation, "start_col out of bounds");
    return;
  }

  char *str_at_end = (char *)ml_get_buf(buf, end_row, false);
  size_t len_at_end = strlen(str_at_end);
  if (end_col < 0 || (size_t)end_col > len_at_end) {
    api_set_error(err, kErrorTypeValidation, "end_col out of bounds");
    return;
  }

  if (start_row > end_row || (end_row == start_row && start_col > end_col)) {
    api_set_error(err, kErrorTypeValidation, "start is higher than end");
    return;
  }

  bool disallow_nl = (channel_id != VIML_INTERNAL_CALL);
  if (!check_string_array(replacement, disallow_nl, err)) {
    return;
  }

  size_t new_len = replacement.size;

  bcount_t new_byte = 0;
  bcount_t old_byte = 0;

  // calculate byte size of old region before it gets modified/deleted
  if (start_row == end_row) {
      old_byte = (bcount_t)end_col - start_col;
  } else {
      const char *bufline;
      old_byte += (bcount_t)strlen(str_at_start) - start_col;
      for (int64_t i = 1; i < end_row - start_row; i++) {
          int64_t lnum = start_row + i;

          bufline = (char *)ml_get_buf(buf, lnum, false);
          old_byte += (bcount_t)(strlen(bufline))+1;
      }
      old_byte += (bcount_t)end_col+1;
  }

  String first_item = replacement.items[0].data.string;
  String last_item = replacement.items[replacement.size-1].data.string;

  size_t firstlen = (size_t)start_col+first_item.size;
  size_t last_part_len = strlen(str_at_end) - (size_t)end_col;
  if (replacement.size == 1) {
    firstlen += last_part_len;
  }
  char *first = xmallocz(firstlen), *last = NULL;
  memcpy(first, str_at_start, (size_t)start_col);
  memcpy(first+start_col, first_item.data, first_item.size);
  memchrsub(first+start_col, NUL, NL, first_item.size);
  if (replacement.size == 1) {
    memcpy(first+start_col+first_item.size, str_at_end+end_col, last_part_len);
  } else {
    last = xmallocz(last_item.size+last_part_len);
    memcpy(last, last_item.data, last_item.size);
    memchrsub(last, NUL, NL, last_item.size);
    memcpy(last+last_item.size, str_at_end+end_col, last_part_len);
  }

  char **lines = (new_len != 0) ? xcalloc(new_len, sizeof(char *)) : NULL;
  lines[0] = first;
  new_byte += (bcount_t)(first_item.size);
  for (size_t i = 1; i < new_len-1; i++) {
    const String l = replacement.items[i].data.string;

    // Fill lines[i] with l's contents. Convert NULs to newlines as required by
    // NL-used-for-NUL.
    lines[i] = xmemdupz(l.data, l.size);
    memchrsub(lines[i], NUL, NL, l.size);
    new_byte += (bcount_t)(l.size)+1;
  }
  if (replacement.size > 1) {
    lines[replacement.size-1] = last;
    new_byte += (bcount_t)(last_item.size)+1;
  }

  try_start();
  aco_save_T aco;
  aucmd_prepbuf(&aco, (buf_T *)buf);

  if (!MODIFIABLE(buf)) {
    api_set_error(err, kErrorTypeException, "Buffer is not 'modifiable'");
    goto end;
  }

  // Small note about undo states: unlike set_lines, we want to save the
  // undo state of one past the end_row, since end_row is inclusive.
  if (u_save((linenr_T)start_row - 1, (linenr_T)end_row + 1) == FAIL) {
    api_set_error(err, kErrorTypeException, "Failed to save undo information");
    goto end;
  }

  ptrdiff_t extra = 0;  // lines added to text, can be negative
  size_t old_len = (size_t)(end_row-start_row+1);

  // If the size of the range is reducing (ie, new_len < old_len) we
  // need to delete some old_len. We do this at the start, by
  // repeatedly deleting line "start".
  size_t to_delete = (new_len < old_len) ? (size_t)(old_len - new_len) : 0;
  for (size_t i = 0; i < to_delete; i++) {
    if (ml_delete((linenr_T)start_row, false) == FAIL) {
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
    int64_t lnum = start_row + (int64_t)i;

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
    int64_t lnum = start_row + (int64_t)i - 1;

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
  mark_adjust((linenr_T)start_row,
              (linenr_T)end_row,
              MAXLNUM,
              (long)extra,
              kExtmarkNOOP);

  colnr_T col_extent = (colnr_T)(end_col
                                 - ((end_row == start_row) ? start_col : 0));
  extmark_splice(buf, (int)start_row-1, (colnr_T)start_col,
                 (int)(end_row-start_row), col_extent, old_byte,
                 (int)new_len-1, (colnr_T)last_item.size, new_byte,
                 kExtmarkUndo);


  changed_lines((linenr_T)start_row, 0, (linenr_T)end_row + 1,
                (long)extra, true);

  // adjust cursor like an extmark ( i e it was inside last_part_len)
  if (curwin->w_cursor.lnum == end_row && curwin->w_cursor.col > end_col) {
    curwin->w_cursor.col -= col_extent - (colnr_T)last_item.size;
  }
  fix_cursor((linenr_T)start_row, (linenr_T)end_row, (linenr_T)extra);

end:
  for (size_t i = 0; i < new_len; i++) {
    xfree(lines[i]);
  }
  xfree(lines);
  aucmd_restbuf(&aco);
  try_end(err);
}

/// Returns the byte offset of a line (0-indexed). |api-indexing|
///
/// Line 1 (index=0) has offset 0. UTF-8 bytes are counted. EOL is one byte.
/// 'fileformat' and 'fileencoding' are ignored. The line index just after the
/// last line gives the total byte-count of the buffer. A final EOL byte is
/// counted if it would be written, see 'eol'.
///
/// Unlike |line2byte()|, throws error for out-of-bounds indexing.
/// Returns -1 for unloaded buffer.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param index      Line index
/// @param[out] err   Error details, if any
/// @return Integer byte offset, or -1 for unloaded buffer.
Integer nvim_buf_get_offset(Buffer buffer, Integer index, Error *err)
  FUNC_API_SINCE(5)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }

  // return sentinel value if the buffer isn't loaded
  if (buf->b_ml.ml_mfp == NULL) {
    return -1;
  }

  if (index < 0 || index > buf->b_ml.ml_line_count) {
    api_set_error(err, kErrorTypeValidation, "Index out of bounds");
    return 0;
  }

  return ml_find_line_or_offset(buf, (int)index+1, NULL, true);
}

/// Gets a buffer-scoped (b:) variable.
///
/// @param buffer     Buffer handle, or 0 for current buffer
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
/// @param[in]  buffer  Buffer handle, or 0 for current buffer
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

  return buf_get_changedtick(buf);
}

/// Gets a list of buffer-local |mapping| definitions.
///
/// @param  mode       Mode short-name ("n", "i", "v", ...)
/// @param  buffer     Buffer handle, or 0 for current buffer
/// @param[out]  err   Error details, if any
/// @returns Array of maparg()-like dictionaries describing mappings.
///          The "buffer" key holds the associated buffer handle.
ArrayOf(Dictionary) nvim_buf_get_keymap(Buffer buffer, String mode, Error *err)
  FUNC_API_SINCE(3)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Array)ARRAY_DICT_INIT;
  }

  return keymap_array(mode, buf);
}

/// Sets a buffer-local |mapping| for the given mode.
///
/// @see |nvim_set_keymap()|
///
/// @param  buffer  Buffer handle, or 0 for current buffer
void nvim_buf_set_keymap(Buffer buffer, String mode, String lhs, String rhs,
                         Dictionary opts, Error *err)
  FUNC_API_SINCE(6)
{
  modify_keymap(buffer, false, mode, lhs, rhs, opts, err);
}

/// Unmaps a buffer-local |mapping| for the given mode.
///
/// @see |nvim_del_keymap()|
///
/// @param  buffer  Buffer handle, or 0 for current buffer
void nvim_buf_del_keymap(Buffer buffer, String mode, String lhs, Error *err)
  FUNC_API_SINCE(6)
{
  String rhs = { .data = "", .size = 0 };
  Dictionary opts = ARRAY_DICT_INIT;
  modify_keymap(buffer, true, mode, lhs, rhs, opts, err);
}

/// Gets a map of buffer-local |user-commands|.
///
/// @param  buffer  Buffer handle, or 0 for current buffer
/// @param  opts  Optional parameters. Currently not used.
/// @param[out]  err   Error details, if any.
///
/// @returns Map of maps describing commands.
Dictionary nvim_buf_get_commands(Buffer buffer, Dictionary opts, Error *err)
  FUNC_API_SINCE(4)
{
  bool global = (buffer == -1);
  bool builtin = false;

  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object v = opts.items[i].value;
    if (!strequal("builtin", k.data)) {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      return (Dictionary)ARRAY_DICT_INIT;
    }
    if (strequal("builtin", k.data)) {
      builtin = v.data.boolean;
    }
  }

  if (global) {
    if (builtin) {
      api_set_error(err, kErrorTypeValidation, "builtin=true not implemented");
      return (Dictionary)ARRAY_DICT_INIT;
    }
    return commands_array(NULL);
  }

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (builtin || !buf) {
    return (Dictionary)ARRAY_DICT_INIT;
  }
  return commands_array(buf);
}

/// Sets a buffer-scoped (b:) variable
///
/// @param buffer     Buffer handle, or 0 for current buffer
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
/// @param buffer     Buffer handle, or 0 for current buffer
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


/// Gets a buffer option value
///
/// @param buffer     Buffer handle, or 0 for current buffer
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
/// @param channel_id
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Option name
/// @param value      Option value
/// @param[out] err   Error details, if any
void nvim_buf_set_option(uint64_t channel_id, Buffer buffer,
                         String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  set_option_to(channel_id, buf, SREQ_BUF, name, value, err);
}

/// Gets the full file name for the buffer
///
/// @param buffer     Buffer handle, or 0 for current buffer
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
/// @param buffer     Buffer handle, or 0 for current buffer
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

/// Checks if a buffer is valid and loaded. See |api-buffer| for more info
/// about unloaded buffers.
///
/// @param buffer Buffer handle, or 0 for current buffer
/// @return true if the buffer is valid and loaded, false otherwise.
Boolean nvim_buf_is_loaded(Buffer buffer)
  FUNC_API_SINCE(5)
{
  Error stub = ERROR_INIT;
  buf_T *buf = find_buffer_by_handle(buffer, &stub);
  api_clear_error(&stub);
  return buf && buf->b_ml.ml_mfp != NULL;
}

/// Deletes the buffer. See |:bwipeout|
///
/// @param buffer Buffer handle, or 0 for current buffer
/// @param opts  Optional parameters. Keys:
///          - force:  Force deletion and ignore unsaved changes.
///          - unload: Unloaded only, do not delete. See |:bunload|
void nvim_buf_delete(Buffer buffer, Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_CHECK_TEXTLOCK
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (ERROR_SET(err)) {
    return;
  }

  bool force = false;
  bool unload = false;
  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object v = opts.items[i].value;
    if (strequal("force", k.data)) {
      force = api_object_to_bool(v, "force", false, err);
    } else if (strequal("unload", k.data)) {
      unload = api_object_to_bool(v, "unload", false, err);
    } else {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      return;
    }
  }

  if (ERROR_SET(err)) {
    return;
  }

  int result = do_buffer(
      unload ? DOBUF_UNLOAD : DOBUF_WIPE,
      DOBUF_FIRST,
      FORWARD,
      buf->handle,
      force);

  if (result == FAIL) {
    api_set_error(err, kErrorTypeException, "Failed to unload buffer.");
    return;
  }
}

/// Checks if a buffer is valid.
///
/// @note Even if a buffer is valid it may have been unloaded. See |api-buffer|
/// for more info about unloaded buffers.
///
/// @param buffer Buffer handle, or 0 for current buffer
/// @return true if the buffer is valid, false otherwise.
Boolean nvim_buf_is_valid(Buffer buffer)
  FUNC_API_SINCE(1)
{
  Error stub = ERROR_INIT;
  Boolean ret = find_buffer_by_handle(buffer, &stub) != NULL;
  api_clear_error(&stub);
  return ret;
}

/// Return a tuple (row,col) representing the position of the named mark.
///
/// Marks are (1,0)-indexed. |api-indexing|
///
/// @param buffer     Buffer handle, or 0 for current buffer
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

static Array extmark_to_array(ExtmarkInfo extmark, bool id, bool add_dict)
{
  Array rv = ARRAY_DICT_INIT;
  if (id) {
    ADD(rv, INTEGER_OBJ((Integer)extmark.mark_id));
  }
  ADD(rv, INTEGER_OBJ(extmark.row));
  ADD(rv, INTEGER_OBJ(extmark.col));

  if (add_dict) {
    Dictionary dict = ARRAY_DICT_INIT;

    if (extmark.end_row >= 0) {
      PUT(dict, "end_row", INTEGER_OBJ(extmark.end_row));
      PUT(dict, "end_col", INTEGER_OBJ(extmark.end_col));
    }

    if (extmark.decor) {
      Decoration *decor = extmark.decor;
      if (decor->hl_id) {
        String name = cstr_to_string((const char *)syn_id2name(decor->hl_id));
        PUT(dict, "hl_group", STRING_OBJ(name));
      }
      if (kv_size(decor->virt_text)) {
        Array chunks = ARRAY_DICT_INIT;
        for (size_t i = 0; i < decor->virt_text.size; i++) {
          Array chunk = ARRAY_DICT_INIT;
          VirtTextChunk *vtc = &decor->virt_text.items[i];
          ADD(chunk, STRING_OBJ(cstr_to_string(vtc->text)));
          if (vtc->hl_id > 0) {
            ADD(chunk,
                STRING_OBJ(cstr_to_string(
                    (const char *)syn_id2name(vtc->hl_id))));
          }
          ADD(chunks, ARRAY_OBJ(chunk));
        }
        PUT(dict, "virt_text", ARRAY_OBJ(chunks));
      }

      PUT(dict, "priority", INTEGER_OBJ(decor->priority));
    }

    if (dict.size) {
      ADD(rv, DICTIONARY_OBJ(dict));
    }
  }

  return rv;
}

/// Returns position for a given extmark id
///
/// @param buffer  Buffer handle, or 0 for current buffer
/// @param ns_id  Namespace id from |nvim_create_namespace()|
/// @param id  Extmark id
/// @param opts  Optional parameters. Keys:
///          - details: Whether to include the details dict
/// @param[out] err   Error details, if any
/// @return (row, col) tuple or empty list () if extmark id was absent
ArrayOf(Integer) nvim_buf_get_extmark_by_id(Buffer buffer, Integer ns_id,
                                            Integer id, Dictionary opts,
                                            Error *err)
  FUNC_API_SINCE(7)
{
  Array rv = ARRAY_DICT_INIT;

  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return rv;
  }

  if (!ns_initialized((uint64_t)ns_id)) {
    api_set_error(err, kErrorTypeValidation, "Invalid ns_id");
    return rv;
  }

  bool details = false;
  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("details", k.data)) {
      if (v->type == kObjectTypeBoolean) {
        details = v->data.boolean;
      } else if (v->type == kObjectTypeInteger) {
        details = v->data.integer;
      } else {
        api_set_error(err, kErrorTypeValidation, "details is not an boolean");
        return rv;
      }
    } else {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      return rv;
    }
  }


  ExtmarkInfo extmark = extmark_from_id(buf, (uint64_t)ns_id, (uint64_t)id);
  if (extmark.row < 0) {
    return rv;
  }
  return extmark_to_array(extmark, false, (bool)details);
}

/// Gets extmarks in "traversal order" from a |charwise| region defined by
/// buffer positions (inclusive, 0-indexed |api-indexing|).
///
/// Region can be given as (row,col) tuples, or valid extmark ids (whose
/// positions define the bounds). 0 and -1 are understood as (0,0) and (-1,-1)
/// respectively, thus the following are equivalent:
///
/// <pre>
///   nvim_buf_get_extmarks(0, my_ns, 0, -1, {})
///   nvim_buf_get_extmarks(0, my_ns, [0,0], [-1,-1], {})
/// </pre>
///
/// If `end` is less than `start`, traversal works backwards. (Useful
/// with `limit`, to get the first marks prior to a given position.)
///
/// Example:
///
/// <pre>
///   local a   = vim.api
///   local pos = a.nvim_win_get_cursor(0)
///   local ns  = a.nvim_create_namespace('my-plugin')
///   -- Create new extmark at line 1, column 1.
///   local m1  = a.nvim_buf_set_extmark(0, ns, 0, 0, 0, {})
///   -- Create new extmark at line 3, column 1.
///   local m2  = a.nvim_buf_set_extmark(0, ns, 0, 2, 0, {})
///   -- Get extmarks only from line 3.
///   local ms  = a.nvim_buf_get_extmarks(0, ns, {2,0}, {2,0}, {})
///   -- Get all marks in this buffer + namespace.
///   local all = a.nvim_buf_get_extmarks(0, ns, 0, -1, {})
///   print(vim.inspect(ms))
/// </pre>
///
/// @param buffer  Buffer handle, or 0 for current buffer
/// @param ns_id  Namespace id from |nvim_create_namespace()|
/// @param start  Start of range, given as (row, col) or valid extmark id
///               (whose position defines the bound)
/// @param end  End of range, given as (row, col) or valid extmark id
///             (whose position defines the bound)
/// @param opts  Optional parameters. Keys:
///          - limit:  Maximum number of marks to return
///          - details Whether to include the details dict
/// @param[out] err   Error details, if any
/// @return List of [extmark_id, row, col] tuples in "traversal order".
Array nvim_buf_get_extmarks(Buffer buffer, Integer ns_id,
                            Object start, Object end,
                            Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
{
  Array rv = ARRAY_DICT_INIT;

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return rv;
  }

  if (!ns_initialized((uint64_t)ns_id)) {
    api_set_error(err, kErrorTypeValidation, "Invalid ns_id");
    return rv;
  }

  Integer limit = -1;
  bool details = false;

  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("limit", k.data)) {
      if (v->type != kObjectTypeInteger) {
        api_set_error(err, kErrorTypeValidation, "limit is not an integer");
        return rv;
      }
      limit = v->data.integer;
    } else if (strequal("details", k.data)) {
      if (v->type == kObjectTypeBoolean) {
        details = v->data.boolean;
      } else if (v->type == kObjectTypeInteger) {
        details = v->data.integer;
      } else {
        api_set_error(err, kErrorTypeValidation, "details is not an boolean");
        return rv;
      }
    } else {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      return rv;
    }
  }

  if (limit == 0) {
    return rv;
  } else if (limit < 0) {
    limit = INT64_MAX;
  }


  bool reverse = false;

  int l_row;
  colnr_T l_col;
  if (!extmark_get_index_from_obj(buf, ns_id, start, &l_row, &l_col, err)) {
    return rv;
  }

  int u_row;
  colnr_T u_col;
  if (!extmark_get_index_from_obj(buf, ns_id, end, &u_row, &u_col, err)) {
    return rv;
  }

  if (l_row > u_row || (l_row == u_row && l_col > u_col)) {
    reverse = true;
  }


  ExtmarkInfoArray marks = extmark_get(buf, (uint64_t)ns_id, l_row, l_col,
                                       u_row, u_col, (int64_t)limit, reverse);

  for (size_t i = 0; i < kv_size(marks); i++) {
    ADD(rv, ARRAY_OBJ(extmark_to_array(kv_A(marks, i), true, (bool)details)));
  }

  kv_destroy(marks);
  return rv;
}

/// Creates or updates an extmark.
///
/// To create a new extmark, pass id=0. The extmark id will be returned.
/// To move an existing mark, pass its id.
///
/// It is also allowed to create a new mark by passing in a previously unused
/// id, but the caller must then keep track of existing and unused ids itself.
/// (Useful over RPC, to avoid waiting for the return value.)
///
/// Using the optional arguments, it is possible to use this to highlight
/// a range of text, and also to associate virtual text to the mark.
///
/// @param buffer  Buffer handle, or 0 for current buffer
/// @param ns_id  Namespace id from |nvim_create_namespace()|
/// @param line  Line number where to place the mark
/// @param col  Column where to place the mark
/// @param opts  Optional parameters.
///               - id : id of the extmark to edit.
///               - end_line : ending line of the mark, 0-based inclusive.
///               - end_col : ending col of the mark, 0-based inclusive.
///               - hl_group : name of the highlight group used to highlight
///                   this mark.
///               - virt_text : virtual text to link to this mark.
///               - virt_text_pos : positioning of virtual text. Possible
///                                 values:
///                 - "eol": right after eol character (default)
///                 - "overlay": display over the specified column, without
///                              shifting the underlying text.
///               - virt_text_hide : hide the virtual text when the background
///                                  text is selected or hidden due to
///                                  horizontal scroll 'nowrap'
///               - hl_mode : control how highlights are combined with the
///                           highlights of the text. Currently only affects
///                           virt_text highlights, but might affect `hl_group`
///                           in later versions.
///                 - "replace": only show the virt_text color. This is the
///                              default
///                 - "combine": combine with background text color
///                 - "blend": blend with background text color.
///
///               - ephemeral : for use with |nvim_set_decoration_provider|
///                   callbacks. The mark will only be used for the current
///                   redraw cycle, and not be permantently stored in the
///                   buffer.
///               - right_gravity : boolean that indicates the direction
///                   the extmark will be shifted in when new text is inserted
///                   (true for right, false for left).  defaults to true.
///               - end_right_gravity : boolean that indicates the direction
///                   the extmark end position (if it exists) will be shifted
///                   in when new text is inserted (true for right, false
///                   for left). Defaults to false.
/// @param[out]  err   Error details, if any
/// @return Id of the created/updated extmark
Integer nvim_buf_set_extmark(Buffer buffer, Integer ns_id,
                             Integer line, Integer col,
                             Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    api_set_error(err, kErrorTypeValidation, "Invalid buffer id");
    return 0;
  }

  if (!ns_initialized((uint64_t)ns_id)) {
    api_set_error(err, kErrorTypeValidation, "Invalid ns_id");
    return 0;
  }

  size_t len = 0;
  if (line < 0 || line > buf->b_ml.ml_line_count) {
    api_set_error(err, kErrorTypeValidation, "line value outside range");
    return 0;
  } else if (line < buf->b_ml.ml_line_count) {
    len = STRLEN(ml_get_buf(buf, (linenr_T)line+1, false));
  }

  if (col == -1) {
    col = (Integer)len;
  } else if (col < -1 || col > (Integer)len) {
    api_set_error(err, kErrorTypeValidation, "col value outside range");
    return 0;
  }

  bool ephemeral = false;

  uint64_t id = 0;
  int line2 = -1;
  Decoration decor = DECORATION_INIT;
  colnr_T col2 = -1;

  bool right_gravity = true;
  bool end_right_gravity = false;
  bool end_gravity_set = false;

  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("id", k.data)) {
      if (v->type != kObjectTypeInteger || v->data.integer <= 0) {
        api_set_error(err, kErrorTypeValidation,
                      "id is not a positive integer");
        goto error;
      }

      id = (uint64_t)v->data.integer;
    } else if (strequal("end_line", k.data)) {
      if (v->type != kObjectTypeInteger) {
        api_set_error(err, kErrorTypeValidation,
                      "end_line is not an integer");
        goto error;
      }
      if (v->data.integer < 0 || v->data.integer > buf->b_ml.ml_line_count) {
        api_set_error(err, kErrorTypeValidation,
                      "end_line value outside range");
        goto error;
      }

      line2 = (int)v->data.integer;
    } else if (strequal("end_col", k.data)) {
      if (v->type != kObjectTypeInteger) {
        api_set_error(err, kErrorTypeValidation,
                      "end_col is not an integer");
        goto error;
      }
      if (v->data.integer < 0 || v->data.integer > MAXCOL) {
        api_set_error(err, kErrorTypeValidation,
                      "end_col value outside range");
        goto error;
      }

      col2 = (colnr_T)v->data.integer;
    } else if (strequal("hl_group", k.data)) {
      String hl_group;
      switch (v->type) {
        case kObjectTypeString:
          hl_group = v->data.string;
          decor.hl_id = syn_check_group(
              (char_u *)(hl_group.data),
              (int)hl_group.size);
          break;
        case kObjectTypeInteger:
          decor.hl_id = (int)v->data.integer;
          break;
        default:
          api_set_error(err, kErrorTypeValidation,
                        "hl_group is not valid.");
          goto error;
      }
    } else if (strequal("virt_text", k.data)) {
      if (v->type != kObjectTypeArray) {
        api_set_error(err, kErrorTypeValidation,
                      "virt_text is not an Array");
        goto error;
      }
      decor.virt_text = parse_virt_text(v->data.array, err);
      if (ERROR_SET(err)) {
        goto error;
      }
    } else if (strequal("virt_text_pos", k.data)) {
      if (v->type != kObjectTypeString) {
        api_set_error(err, kErrorTypeValidation,
                      "virt_text_pos is not a String");
        goto error;
      }
      String str = v->data.string;
      if (strequal("eol", str.data)) {
        decor.virt_text_pos = kVTEndOfLine;
      } else if (strequal("overlay", str.data)) {
        decor.virt_text_pos = kVTOverlay;
      } else {
        api_set_error(err, kErrorTypeValidation,
                      "virt_text_pos: invalid value");
        goto error;
      }
    } else if (strequal("virt_text_hide", k.data)) {
      decor.virt_text_hide = api_object_to_bool(*v,
                                                "virt_text_hide", false, err);
      if (ERROR_SET(err)) {
        goto error;
      }
    } else if (strequal("hl_mode", k.data)) {
      if (v->type != kObjectTypeString) {
        api_set_error(err, kErrorTypeValidation,
                      "hl_mode is not a String");
        goto error;
      }
      String str = v->data.string;
      if (strequal("replace", str.data)) {
        decor.hl_mode = kHlModeReplace;
      } else if (strequal("combine", str.data)) {
        decor.hl_mode = kHlModeCombine;
      } else if (strequal("blend", str.data)) {
        decor.hl_mode = kHlModeBlend;
      } else {
        api_set_error(err, kErrorTypeValidation,
                      "virt_text_pos: invalid value");
        goto error;
      }
    } else if (strequal("ephemeral", k.data)) {
      ephemeral = api_object_to_bool(*v, "ephemeral", false, err);
      if (ERROR_SET(err)) {
        goto error;
      }
    } else if (strequal("priority",  k.data)) {
      if (v->type != kObjectTypeInteger) {
        api_set_error(err, kErrorTypeValidation,
                      "priority is not a Number of the correct size");
        goto error;
      }

      if (v->data.integer < 0 || v->data.integer > UINT16_MAX) {
        api_set_error(err, kErrorTypeValidation,
                      "priority is not a valid value");
        goto error;
      }
      decor.priority = (DecorPriority)v->data.integer;
    } else if (strequal("right_gravity", k.data)) {
      if (v->type != kObjectTypeBoolean) {
        api_set_error(err, kErrorTypeValidation,
                      "right_gravity must be a boolean");
        goto error;
      }
      right_gravity = v->data.boolean;
    } else if (strequal("end_right_gravity", k.data)) {
      if (v->type != kObjectTypeBoolean) {
        api_set_error(err, kErrorTypeValidation,
                      "end_right_gravity must be a boolean");
        goto error;
      }
      end_right_gravity = v->data.boolean;
      end_gravity_set = true;
    } else {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      goto error;
    }
  }

  // Only error out if they try to set end_right_gravity without
  // setting end_col or end_line
  if (line2 == -1 && col2 == -1 && end_gravity_set) {
    api_set_error(err, kErrorTypeValidation,
                  "cannot set end_right_gravity "
                  "without setting end_line or end_col");
  }

  if (col2 >= 0) {
    if (line2 >= 0 && line2 < buf->b_ml.ml_line_count) {
      len = STRLEN(ml_get_buf(buf, (linenr_T)line2 + 1, false));
    } else if (line2 == buf->b_ml.ml_line_count) {
      // We are trying to add an extmark past final newline
      len = 0;
    } else {
      // reuse len from before
      line2 = (int)line;
    }
    if (col2 > (Integer)len) {
      api_set_error(err, kErrorTypeValidation, "end_col value outside range");
      goto error;
    }
  } else if (line2 >= 0) {
    col2 = 0;
  }

  Decoration *d = NULL;

  if (ephemeral) {
    d = &decor;
  } else if (kv_size(decor.virt_text)
             || decor.priority != DECOR_PRIORITY_BASE) {
    // TODO(bfredl): this is a bit sketchy. eventually we should
    // have predefined decorations for both marks/ephemerals
    d = xcalloc(1, sizeof(*d));
    *d = decor;
  } else if (decor.hl_id) {
    d = decor_hl(decor.hl_id);
  }

  // TODO(bfredl): synergize these two branches even more
  if (ephemeral && decor_state.buf == buf) {
    decor_add_ephemeral((int)line, (int)col, line2, col2, &decor, 0);
  } else {
    if (ephemeral) {
      api_set_error(err, kErrorTypeException, "not yet implemented");
      goto error;
    }

    id = extmark_set(buf, (uint64_t)ns_id, id, (int)line, (colnr_T)col,
                     line2, col2, d, right_gravity,
                     end_right_gravity, kExtmarkNoUndo);
  }

  return (Integer)id;

error:
  clear_virttext(&decor.virt_text);
  return 0;
}

/// Removes an extmark.
///
/// @param buffer Buffer handle, or 0 for current buffer
/// @param ns_id Namespace id from |nvim_create_namespace()|
/// @param id Extmark id
/// @param[out] err   Error details, if any
/// @return true if the extmark was found, else false
Boolean nvim_buf_del_extmark(Buffer buffer,
                             Integer ns_id,
                             Integer id,
                             Error *err)
  FUNC_API_SINCE(7)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return false;
  }
  if (!ns_initialized((uint64_t)ns_id)) {
    api_set_error(err, kErrorTypeValidation, "Invalid ns_id");
    return false;
  }

  return extmark_del(buf, (uint64_t)ns_id, (uint64_t)id);
}

/// Adds a highlight to buffer.
///
/// Useful for plugins that dynamically generate highlights to a buffer
/// (like a semantic highlighter or linter). The function adds a single
/// highlight to a buffer. Unlike |matchaddpos()| highlights follow changes to
/// line numbering (as lines are inserted/removed above the highlighted line),
/// like signs and marks do.
///
/// Namespaces are used for batch deletion/updating of a set of highlights. To
/// create a namespace, use |nvim_create_namespace()| which returns a namespace
/// id. Pass it in to this function as `ns_id` to add highlights to the
/// namespace. All highlights in the same namespace can then be cleared with
/// single call to |nvim_buf_clear_namespace()|. If the highlight never will be
/// deleted by an API call, pass `ns_id = -1`.
///
/// As a shorthand, `ns_id = 0` can be used to create a new namespace for the
/// highlight, the allocated id is then returned. If `hl_group` is the empty
/// string no highlight is added, but a new `ns_id` is still returned. This is
/// supported for backwards compatibility, new code should use
/// |nvim_create_namespace()| to create a new empty namespace.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param ns_id      namespace to use or -1 for ungrouped highlight
/// @param hl_group   Name of the highlight group to use
/// @param line       Line to highlight (zero-indexed)
/// @param col_start  Start of (byte-indexed) column range to highlight
/// @param col_end    End of (byte-indexed) column range to highlight,
///                   or -1 to highlight to end of line
/// @param[out] err   Error details, if any
/// @return The ns_id that was used
Integer nvim_buf_add_highlight(Buffer buffer,
                               Integer ns_id,
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

  uint64_t ns = src2ns(&ns_id);

  if (!(line < buf->b_ml.ml_line_count)) {
    // safety check, we can't add marks outside the range
    return ns_id;
  }

  int hl_id = 0;
  if (hl_group.size > 0) {
    hl_id = syn_check_group((char_u *)hl_group.data, (int)hl_group.size);
  } else {
    return ns_id;
  }

  int end_line = (int)line;
  if (col_end == MAXCOL) {
    col_end = 0;
    end_line++;
  }

  extmark_set(buf, ns, 0,
              (int)line, (colnr_T)col_start,
              end_line, (colnr_T)col_end,
              decor_hl(hl_id), true, false, kExtmarkNoUndo);
  return ns_id;
}

/// Clears namespaced objects (highlights, extmarks, virtual text) from
/// a region.
///
/// Lines are 0-indexed. |api-indexing|  To clear the namespace in the entire
/// buffer, specify line_start=0 and line_end=-1.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param ns_id      Namespace to clear, or -1 to clear all namespaces.
/// @param line_start Start of range of lines to clear
/// @param line_end   End of range of lines to clear (exclusive) or -1 to clear
///                   to end of buffer.
/// @param[out] err   Error details, if any
void nvim_buf_clear_namespace(Buffer buffer,
                              Integer ns_id,
                              Integer line_start,
                              Integer line_end,
                              Error *err)
  FUNC_API_SINCE(5)
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
  extmark_clear(buf, (ns_id < 0 ? 0 : (uint64_t)ns_id),
                (int)line_start, 0,
                (int)line_end-1, MAXCOL);
}

/// Set the virtual text (annotation) for a buffer line.
///
/// By default (and currently the only option) the text will be placed after
/// the buffer text. Virtual text will never cause reflow, rather virtual
/// text will be truncated at the end of the screen line. The virtual text will
/// begin one cell (|lcs-eol| or space) after the ordinary text.
///
/// Namespaces are used to support batch deletion/updating of virtual text.
/// To create a namespace, use |nvim_create_namespace()|. Virtual text is
/// cleared using |nvim_buf_clear_namespace()|. The same `ns_id` can be used for
/// both virtual text and highlights added by |nvim_buf_add_highlight()|, both
/// can then be cleared with a single call to |nvim_buf_clear_namespace()|. If
/// the virtual text never will be cleared by an API call, pass `ns_id = -1`.
///
/// As a shorthand, `ns_id = 0` can be used to create a new namespace for the
/// virtual text, the allocated id is then returned.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param ns_id      Namespace to use or 0 to create a namespace,
///                   or -1 for a ungrouped annotation
/// @param line       Line to annotate with virtual text (zero-indexed)
/// @param chunks     A list of [text, hl_group] arrays, each representing a
///                   text chunk with specified highlight. `hl_group` element
///                   can be omitted for no highlight.
/// @param opts       Optional parameters. Currently not used.
/// @param[out] err   Error details, if any
/// @return The ns_id that was used
Integer nvim_buf_set_virtual_text(Buffer buffer,
                                  Integer src_id,
                                  Integer line,
                                  Array chunks,
                                  Dictionary opts,
                                  Error *err)
  FUNC_API_SINCE(5)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }

  if (line < 0 || line >= MAXLNUM) {
    api_set_error(err, kErrorTypeValidation, "Line number outside range");
    return 0;
  }

  if (opts.size > 0) {
    api_set_error(err, kErrorTypeValidation, "opts dict isn't empty");
    return 0;
  }

  uint64_t ns_id = src2ns(&src_id);

  VirtText virt_text = parse_virt_text(chunks, err);
  if (ERROR_SET(err)) {
    return 0;
  }


  VirtText *existing = decor_find_virttext(buf, (int)line, ns_id);

  if (existing) {
    clear_virttext(existing);
    *existing = virt_text;
    return src_id;
  }

  Decoration *decor = xcalloc(1, sizeof(*decor));
  decor->virt_text = virt_text;

  extmark_set(buf, ns_id, 0, (int)line, 0, -1, -1, decor, true,
              false, kExtmarkNoUndo);
  return src_id;
}

/// call a function with buffer as temporary current buffer
///
/// This temporarily switches current buffer to "buffer".
/// If the current window already shows "buffer", the window is not switched
/// If a window inside the current tabpage (including a float) already shows the
/// buffer One of these windows will be set as current window temporarily.
/// Otherwise a temporary scratch window (calleed the "autocmd window" for
/// historical reasons) will be used.
///
/// This is useful e.g. to call vimL functions that only work with the current
/// buffer/window currently, like |termopen()|.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param fun        Function to call inside the buffer (currently lua callable
///                   only)
/// @param[out] err   Error details, if any
/// @return           Return value of function. NB: will deepcopy lua values
///                   currently, use upvalues to send lua references in and out.
Object nvim_buf_call(Buffer buffer, LuaRef fun, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_LUA_ONLY
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return NIL;
  }
  try_start();
  aco_save_T aco;
  aucmd_prepbuf(&aco, (buf_T *)buf);

  Array args = ARRAY_DICT_INIT;
  Object res = nlua_call_ref(fun, NULL, args, true, err);

  aucmd_restbuf(&aco);
  try_end(err);
  return res;
}

Dictionary nvim__buf_stats(Buffer buffer, Error *err)
{
  Dictionary rv = ARRAY_DICT_INIT;

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return rv;
  }

  // Number of times the cached line was flushed.
  // This should generally not increase while editing the same
  // line in the same mode.
  PUT(rv, "flush_count", INTEGER_OBJ(buf->flush_count));
  // lnum of current line
  PUT(rv, "current_lnum", INTEGER_OBJ(buf->b_ml.ml_line_lnum));
  // whether the line has unflushed changes.
  PUT(rv, "line_dirty", BOOLEAN_OBJ(buf->b_ml.ml_flags & ML_LINE_DIRTY));
  // NB: this should be zero at any time API functions are called,
  // this exists to debug issues
  PUT(rv, "dirty_bytes", INTEGER_OBJ((Integer)buf->deleted_bytes));
  PUT(rv, "dirty_bytes2", INTEGER_OBJ((Integer)buf->deleted_bytes2));

  u_header_T *uhp = NULL;
  if (buf->b_u_curhead != NULL) {
    uhp = buf->b_u_curhead;
  } else if (buf->b_u_newhead) {
    uhp = buf->b_u_newhead;
  }
  if (uhp) {
    PUT(rv, "uhp_extmark_size", INTEGER_OBJ((Integer)kv_size(uhp->uh_extmark)));
  }

  return rv;
}

// Check if deleting lines made the cursor position invalid.
// Changed lines from `lo` to `hi`; added `extra` lines (negative if deleted).
static void fix_cursor(linenr_T lo, linenr_T hi, linenr_T extra)
{
  if (curwin->w_cursor.lnum >= lo) {
    // Adjust cursor position if it's in/after the changed lines.
    if (curwin->w_cursor.lnum >= hi) {
      curwin->w_cursor.lnum += extra;
      check_cursor_col();
    } else if (extra < 0) {
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
