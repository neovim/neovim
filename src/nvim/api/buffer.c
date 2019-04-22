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
#include "nvim/charset.h"
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
#include "nvim/ex_docmd.h"
#include "nvim/buffer_updates.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/buffer.c.generated.h"
#endif


/// \defgroup api-buffer
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

/// Activates buffer-update events on the channel.
///
/// @param channel_id
/// @param buffer Buffer handle, or 0 for current buffer
/// @param send_buffer Set to true if the initial notification should contain
///        the whole buffer. If so, the first notification will be a
///        `nvim_buf_lines_event`. Otherwise, the first notification will be
///        a `nvim_buf_changedtick_event`
/// @param  opts  Optional parameters. Reserved for future use.
/// @param[out] err Error details, if any
/// @return False when updates couldn't be enabled because the buffer isn't
///         loaded or `opts` contained an invalid key; otherwise True.
Boolean nvim_buf_attach(uint64_t channel_id,
                        Buffer buffer,
                        Boolean send_buffer,
                        Dictionary opts,
                        Error *err)
  FUNC_API_SINCE(4) FUNC_API_REMOTE_ONLY
{
  if (opts.size > 0) {
      api_set_error(err, kErrorTypeValidation, "dict isn't empty");
      return false;
  }

  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return false;
  }

  return buf_updates_register(buf, channel_id, send_buffer);
}

/// Deactivates buffer-update events on the channel.
///
/// @param channel_id
/// @param buffer Buffer handle, or 0 for current buffer
/// @param[out] err Error details, if any
/// @return False when updates couldn't be disabled because the buffer
///         isn't loaded; otherwise True.
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


/// Replaces a line range on the buffer
///
/// @deprecated use nvim_buf_set_lines(buffer, newstart, newend, false, lines)
///             where newstart = start + int(not include_start) + int(start < 0)
///                   newend = end + int(include_end) + int(end < 0)
///                   int(bool) = 1 if bool is true else 0
///
/// @param buffer         Buffer handle, or 0 for current buffer
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
              false);

  changed_lines((linenr_T)start, 0, (linenr_T)end, (long)extra, true);

end:
  for (size_t i = 0; i < new_len; i++) {
    xfree(lines[i]);
  }

  xfree(lines);
  aucmd_restbuf(&aco);
  try_end(err);
}

/// Returns the byte offset for a line.
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

/// Sets a buffer-scoped (b:) variable
///
/// @deprecated
///
/// @param buffer     Buffer handle, or 0 for current buffer
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
/// @param buffer     Buffer handle, or 0 for current buffer
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

/// Gets the buffer number
///
/// @deprecated The buffer number now is equal to the object id,
///             so there is no need to use this function.
///
/// @param buffer     Buffer handle, or 0 for current buffer
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

/// Adds a highlight to buffer.
///
/// Useful for plugins that dynamically generate highlights to a buffer
/// (like a semantic highlighter or linter). The function adds a single
/// highlight to a buffer. Unlike |matchaddpos()| highlights follow changes to
/// line numbering (as lines are inserted/removed above the highlighted line),
/// like signs and marks do.
///
/// Namespaces are used for batch deletion/updating of a set of highlights. To
/// create a namespace, use |nvim_create_namespace| which returns a namespace
/// id. Pass it in to this function as `ns_id` to add highlights to the
/// namespace. All highlights in the same namespace can then be cleared with
/// single call to |nvim_buf_clear_namespace|. If the highlight never will be
/// deleted by an API call, pass `ns_id = -1`.
///
/// As a shorthand, `ns_id = 0` can be used to create a new namespace for the
/// highlight, the allocated id is then returned. If `hl_group` is the empty
/// string no highlight is added, but a new `ns_id` is still returned. This is
/// supported for backwards compatibility, new code should use
/// |nvim_create_namespace| to create a new empty namespace.
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

  int hlg_id = 0;
  if (hl_group.size > 0) {
    hlg_id = syn_check_group((char_u *)hl_group.data, (int)hl_group.size);
  }

  ns_id = bufhl_add_hl(buf, (int)ns_id, hlg_id, (linenr_T)line+1,
                       (colnr_T)col_start+1, (colnr_T)col_end);
  return ns_id;
}

/// Clears namespaced objects, highlights and virtual text, from a line range
///
/// To clear the namespace in the entire buffer, pass in 0 and -1 to
/// line_start and line_end respectively.
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

  bufhl_clear_line_range(buf, (int)ns_id, (int)line_start+1, (int)line_end);
}

/// Clears highlights and virtual text from namespace and range of lines
///
/// @deprecated use |nvim_buf_clear_namespace|.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param ns_id      Namespace to clear, or -1 to clear all.
/// @param line_start Start of range of lines to clear
/// @param line_end   End of range of lines to clear (exclusive) or -1 to clear
///                   to end of file.
/// @param[out] err   Error details, if any
void nvim_buf_clear_highlight(Buffer buffer,
                              Integer ns_id,
                              Integer line_start,
                              Integer line_end,
                              Error *err)
  FUNC_API_SINCE(1)
{
  nvim_buf_clear_namespace(buffer, ns_id, line_start, line_end, err);
}


/// Set the virtual text (annotation) for a buffer line.
///
/// By default (and currently the only option) the text will be placed after
/// the buffer text. Virtual text will never cause reflow, rather virtual
/// text will be truncated at the end of the screen line. The virtual text will
/// begin one cell (|lcs-eol| or space) after the ordinary text.
///
/// Namespaces are used to support batch deletion/updating of virtual text.
/// To create a namespace, use |nvim_create_namespace|. Virtual text is
/// cleared using |nvim_buf_clear_namespace|. The same `ns_id` can be used for
/// both virtual text and highlights added by |nvim_buf_add_highlight|, both
/// can then be cleared with a single call to |nvim_buf_clear_namespace|. If the
/// virtual text never will be cleared by an API call, pass `ns_id = -1`.
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
                                  Integer ns_id,
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

  VirtText virt_text = KV_INITIAL_VALUE;
  for (size_t i = 0; i < chunks.size; i++) {
    if (chunks.items[i].type != kObjectTypeArray) {
      api_set_error(err, kErrorTypeValidation, "Chunk is not an array");
      goto free_exit;
    }
    Array chunk = chunks.items[i].data.array;
    if (chunk.size == 0 || chunk.size > 2
        || chunk.items[0].type != kObjectTypeString
        || (chunk.size == 2 && chunk.items[1].type != kObjectTypeString)) {
      api_set_error(err, kErrorTypeValidation,
                    "Chunk is not an array with one or two strings");
      goto free_exit;
    }

    String str = chunk.items[0].data.string;
    char *text = transstr(str.size > 0 ? str.data : "");  // allocates

    int hl_id = 0;
    if (chunk.size == 2) {
      String hl = chunk.items[1].data.string;
      if (hl.size > 0) {
        hl_id = syn_check_group((char_u *)hl.data, (int)hl.size);
      }
    }
    kv_push(virt_text, ((VirtTextChunk){ .text = text, .hl_id = hl_id }));
  }

  ns_id = bufhl_add_virt_text(buf, (int)ns_id, (linenr_T)line+1,
                              virt_text);
  return ns_id;

free_exit:
  kv_destroy(virt_text);
  return 0;
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
