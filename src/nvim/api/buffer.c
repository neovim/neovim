// Some of this code was adapted from 'if_py_both.h' from the original
// vim source

#include <lauxlib.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "klib/kvec.h"
#include "lua.h"
#include "nvim/api/buffer.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/buffer_updates.h"
#include "nvim/change.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/ex_cmds.h"
#include "nvim/extmark.h"
#include "nvim/extmark_defs.h"
#include "nvim/globals.h"
#include "nvim/lua/executor.h"
#include "nvim/mapping.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/marktree_defs.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/move.h"
#include "nvim/ops.h"
#include "nvim/option_vars.h"
#include "nvim/pos_defs.h"
#include "nvim/state_defs.h"
#include "nvim/types_defs.h"
#include "nvim/undo.h"
#include "nvim/undo_defs.h"
#include "nvim/vim_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/buffer.c.generated.h"
#endif

/// @brief <pre>help
/// For more information on buffers, see |buffers|.
///
/// Unloaded Buffers: ~
///
/// Buffers may be unloaded by the |:bunload| command or the buffer's
/// |'bufhidden'| option. When a buffer is unloaded its file contents are freed
/// from memory and vim cannot operate on the buffer lines until it is reloaded
/// (usually by opening the buffer again in a new window). API methods such as
/// |nvim_buf_get_lines()| and |nvim_buf_line_count()| will be affected.
///
/// You can use |nvim_buf_is_loaded()| or |nvim_buf_line_count()| to check
/// whether a buffer is loaded.
/// </pre>

/// Returns the number of lines in the given buffer.
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
/// (use "vim.print(events)" to see its contents):
///
/// ```lua
/// events = {}
/// vim.api.nvim_buf_attach(0, false, {
///   on_lines = function(...)
///     table.insert(events, {...})
///   end,
/// })
/// ```
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
///               Return a truthy value (not `false` or `nil`) to detach. Args:
///               - the string "lines"
///               - buffer handle
///               - b:changedtick
///               - first line that changed (zero-indexed)
///               - last line that was changed
///               - last line in the updated range
///               - byte count of previous contents
///               - deleted_codepoints (if `utf_sizes` is true)
///               - deleted_codeunits (if `utf_sizes` is true)
///             - on_bytes: Lua callback invoked on change.
///               This callback receives more granular information about the
///               change compared to on_lines.
///               Return a truthy value (not `false` or `nil`) to detach. Args:
///               - the string "bytes"
///               - buffer handle
///               - b:changedtick
///               - start row of the changed text (zero-indexed)
///               - start column of the changed text
///               - byte offset of the changed text (from the start of
///                   the buffer)
///               - old end row of the changed text (offset from start row)
///               - old end column of the changed text
///                 (if old end row = 0, offset from start column)
///               - old end byte length of the changed text
///               - new end row of the changed text (offset from start row)
///               - new end column of the changed text
///                 (if new end row = 0, offset from start column)
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
///               - the string "reload"
///               - buffer handle
///             - utf_sizes: include UTF-32 and UTF-16 size of the replaced
///               region, as args to `on_lines`.
///             - preview: also attach to command preview (i.e. 'inccommand')
///               events.
/// @param[out] err Error details, if any
/// @return False if attach failed (invalid parameter, or buffer isn't loaded);
///         otherwise True. TODO: LUA_API_NO_EVAL
Boolean nvim_buf_attach(uint64_t channel_id, Buffer buffer, Boolean send_buffer,
                        Dict(buf_attach) *opts, Error *err)
  FUNC_API_SINCE(4)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return false;
  }

  BufUpdateCallbacks cb = BUF_UPDATE_CALLBACKS_INIT;

  if (channel_id == LUA_INTERNAL_CALL) {
    if (HAS_KEY(opts, buf_attach, on_lines)) {
      cb.on_lines = opts->on_lines;
      opts->on_lines = LUA_NOREF;
    }

    if (HAS_KEY(opts, buf_attach, on_bytes)) {
      cb.on_bytes = opts->on_bytes;
      opts->on_bytes = LUA_NOREF;
    }

    if (HAS_KEY(opts, buf_attach, on_changedtick)) {
      cb.on_changedtick = opts->on_changedtick;
      opts->on_changedtick = LUA_NOREF;
    }

    if (HAS_KEY(opts, buf_attach, on_detach)) {
      cb.on_detach = opts->on_detach;
      opts->on_detach = LUA_NOREF;
    }

    if (HAS_KEY(opts, buf_attach, on_reload)) {
      cb.on_reload = opts->on_reload;
      opts->on_reload = LUA_NOREF;
    }

    cb.utf_sizes = opts->utf_sizes;

    cb.preview = opts->preview;
  }

  return buf_updates_register(buf, channel_id, cb, send_buffer);
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
Boolean nvim_buf_detach(uint64_t channel_id, Buffer buffer, Error *err)
  FUNC_API_SINCE(4) FUNC_API_REMOTE_ONLY
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return false;
  }

  buf_updates_unregister(buf, channel_id);
  return true;
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
/// @param end              Last line index, exclusive
/// @param strict_indexing  Whether out-of-bounds should be an error.
/// @param[out] err         Error details, if any
/// @return Array of lines, or empty array for unloaded buffer.
ArrayOf(String) nvim_buf_get_lines(uint64_t channel_id,
                                   Buffer buffer,
                                   Integer start,
                                   Integer end,
                                   Boolean strict_indexing,
                                   Arena *arena,
                                   lua_State *lstate,
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
  start = normalize_index(buf, start, true, &oob);
  end = normalize_index(buf, end, true, &oob);

  VALIDATE((!strict_indexing || !oob), "%s", "Index out of bounds", {
    return rv;
  });

  if (start >= end) {
    // Return 0-length array
    return rv;
  }

  size_t size = (size_t)(end - start);

  init_line_array(lstate, &rv, size, arena);

  buf_collect_lines(buf, size, (linenr_T)start, 0, (channel_id != VIML_INTERNAL_CALL), &rv,
                    lstate, arena);

  return rv;
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
/// @see |nvim_buf_set_text()|
///
/// @param channel_id
/// @param buffer           Buffer handle, or 0 for current buffer
/// @param start            First line index
/// @param end              Last line index, exclusive
/// @param strict_indexing  Whether out-of-bounds should be an error.
/// @param replacement      Array of lines to use as replacement
/// @param[out] err         Error details, if any
void nvim_buf_set_lines(uint64_t channel_id, Buffer buffer, Integer start, Integer end,
                        Boolean strict_indexing, ArrayOf(String) replacement, Arena *arena,
                        Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  // Load buffer if necessary. #22670
  if (!buf_ensure_loaded(buf)) {
    api_set_error(err, kErrorTypeException, "Failed to load buffer");
    return;
  }

  bool oob = false;
  start = normalize_index(buf, start, true, &oob);
  end = normalize_index(buf, end, true, &oob);

  VALIDATE((!strict_indexing || !oob), "%s", "Index out of bounds", {
    return;
  });
  VALIDATE((start <= end), "%s", "'start' is higher than 'end'", {
    return;
  });

  bool disallow_nl = (channel_id != VIML_INTERNAL_CALL);
  if (!check_string_array(replacement, "replacement string", disallow_nl, err)) {
    return;
  }

  size_t new_len = replacement.size;
  size_t old_len = (size_t)(end - start);
  ptrdiff_t extra = 0;  // lines added to text, can be negative
  char **lines = (new_len != 0) ? arena_alloc(arena, new_len * sizeof(char *), true) : NULL;

  for (size_t i = 0; i < new_len; i++) {
    const String l = replacement.items[i].data.string;

    // Fill lines[i] with l's contents. Convert NULs to newlines as required by
    // NL-used-for-NUL.
    lines[i] = arena_memdupz(arena, l.data, l.size);
    memchrsub(lines[i], NUL, NL, l.size);
  }

  TRY_WRAP(err, {
    if (!MODIFIABLE(buf)) {
      api_set_error(err, kErrorTypeException, "Buffer is not 'modifiable'");
      goto end;
    }

    if (u_save_buf(buf, (linenr_T)(start - 1), (linenr_T)end) == FAIL) {
      api_set_error(err, kErrorTypeException, "Failed to save undo information");
      goto end;
    }

    bcount_t deleted_bytes = get_region_bytecount(buf, (linenr_T)start, (linenr_T)end, 0, 0);

    // If the size of the range is reducing (ie, new_len < old_len) we
    // need to delete some old_len. We do this at the start, by
    // repeatedly deleting line "start".
    size_t to_delete = (new_len < old_len) ? old_len - new_len : 0;
    for (size_t i = 0; i < to_delete; i++) {
      if (ml_delete_buf(buf, (linenr_T)start, false) == FAIL) {
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
    bcount_t inserted_bytes = 0;
    for (size_t i = 0; i < to_replace; i++) {
      int64_t lnum = start + (int64_t)i;

      VALIDATE(lnum < MAXLNUM, "%s", "Index out of bounds", {
        goto end;
      });

      if (ml_replace_buf(buf, (linenr_T)lnum, lines[i], false, true) == FAIL) {
        api_set_error(err, kErrorTypeException, "Failed to replace line");
        goto end;
      }

      inserted_bytes += (bcount_t)strlen(lines[i]) + 1;
    }

    // Now we may need to insert the remaining new old_len
    for (size_t i = to_replace; i < new_len; i++) {
      int64_t lnum = start + (int64_t)i - 1;

      VALIDATE(lnum < MAXLNUM, "%s", "Index out of bounds", {
        goto end;
      });

      if (ml_append_buf(buf, (linenr_T)lnum, lines[i], 0, false) == FAIL) {
        api_set_error(err, kErrorTypeException, "Failed to insert line");
        goto end;
      }

      inserted_bytes += (bcount_t)strlen(lines[i]) + 1;

      extra++;
    }

    // Adjust marks. Invalidate any which lie in the
    // changed range, and move any in the remainder of the buffer.
    linenr_T adjust = end > start ? MAXLNUM : 0;
    mark_adjust_buf(buf, (linenr_T)start, (linenr_T)(end - 1), adjust, (linenr_T)extra,
                    true, true, kExtmarkNOOP);

    extmark_splice(buf, (int)start - 1, 0, (int)(end - start), 0,
                   deleted_bytes, (int)new_len, 0, inserted_bytes,
                   kExtmarkUndo);

    changed_lines(buf, (linenr_T)start, 0, (linenr_T)end, (linenr_T)extra, true);

    FOR_ALL_TAB_WINDOWS(tp, win) {
      if (win->w_buffer == buf) {
        fix_cursor(win, (linenr_T)start, (linenr_T)end, (linenr_T)extra);
      }
    }
    end:;
  });
}

/// Sets (replaces) a range in the buffer
///
/// This is recommended over |nvim_buf_set_lines()| when only modifying parts of
/// a line, as extmarks will be preserved on non-modified parts of the touched
/// lines.
///
/// Indexing is zero-based. Row indices are end-inclusive, and column indices
/// are end-exclusive.
///
/// To insert text at a given `(row, column)` location, use `start_row = end_row
/// = row` and `start_col = end_col = col`. To delete the text in a range, use
/// `replacement = {}`.
///
/// @note Prefer |nvim_buf_set_lines()| (for performance) to add or delete entire lines.
/// @note Prefer |nvim_paste()| or |nvim_put()| to insert (instead of replace) text at cursor.
///
/// @param channel_id
/// @param buffer           Buffer handle, or 0 for current buffer
/// @param start_row        First line index
/// @param start_col        Starting column (byte offset) on first line
/// @param end_row          Last line index, inclusive
/// @param end_col          Ending column (byte offset) on last line, exclusive
/// @param replacement      Array of lines to use as replacement
/// @param[out] err         Error details, if any
void nvim_buf_set_text(uint64_t channel_id, Buffer buffer, Integer start_row, Integer start_col,
                       Integer end_row, Integer end_col, ArrayOf(String) replacement, Arena *arena,
                       Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  MAXSIZE_TEMP_ARRAY(scratch, 1);
  if (replacement.size == 0) {
    ADD_C(scratch, STATIC_CSTR_AS_OBJ(""));
    replacement = scratch;
  }

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return;
  }

  // Load buffer if necessary. #22670
  if (!buf_ensure_loaded(buf)) {
    api_set_error(err, kErrorTypeException, "Failed to load buffer");
    return;
  }

  bool oob = false;

  // check range is ordered and everything!
  // start_row, end_row within buffer len (except add text past the end?)
  start_row = normalize_index(buf, start_row, false, &oob);
  VALIDATE_RANGE((!oob), "start_row", {
    return;
  });

  end_row = normalize_index(buf, end_row, false, &oob);
  VALIDATE_RANGE((!oob), "end_row", {
    return;
  });

  // Another call to ml_get_buf() may free the lines, so we make copies
  char *str_at_start = ml_get_buf(buf, (linenr_T)start_row);
  colnr_T len_at_start = ml_get_buf_len(buf, (linenr_T)start_row);
  str_at_start = arena_memdupz(arena, str_at_start, (size_t)len_at_start);
  start_col = start_col < 0 ? len_at_start + start_col + 1 : start_col;
  VALIDATE_RANGE((start_col >= 0 && start_col <= len_at_start), "start_col", {
    return;
  });

  char *str_at_end = ml_get_buf(buf, (linenr_T)end_row);
  colnr_T len_at_end = ml_get_buf_len(buf, (linenr_T)end_row);
  str_at_end = arena_memdupz(arena, str_at_end, (size_t)len_at_end);
  end_col = end_col < 0 ? len_at_end + end_col + 1 : end_col;
  VALIDATE_RANGE((end_col >= 0 && end_col <= len_at_end), "end_col", {
    return;
  });

  VALIDATE((start_row <= end_row && !(end_row == start_row && start_col > end_col)),
           "%s", "'start' is higher than 'end'", {
    return;
  });

  bool disallow_nl = (channel_id != VIML_INTERNAL_CALL);
  if (!check_string_array(replacement, "replacement string", disallow_nl, err)) {
    return;
  }

  size_t new_len = replacement.size;

  bcount_t new_byte = 0;
  bcount_t old_byte = 0;

  // calculate byte size of old region before it gets modified/deleted
  if (start_row == end_row) {
    old_byte = (bcount_t)end_col - start_col;
  } else {
    old_byte += len_at_start - start_col;
    for (int64_t i = 1; i < end_row - start_row; i++) {
      int64_t lnum = start_row + i;
      old_byte += ml_get_buf_len(buf, (linenr_T)lnum) + 1;
    }
    old_byte += (bcount_t)end_col + 1;
  }

  String first_item = replacement.items[0].data.string;
  String last_item = replacement.items[replacement.size - 1].data.string;

  size_t firstlen = (size_t)start_col + first_item.size;
  size_t last_part_len = (size_t)len_at_end - (size_t)end_col;
  if (replacement.size == 1) {
    firstlen += last_part_len;
  }
  char *first = arena_allocz(arena, firstlen);
  char *last = NULL;
  memcpy(first, str_at_start, (size_t)start_col);
  memcpy(first + start_col, first_item.data, first_item.size);
  memchrsub(first + start_col, NUL, NL, first_item.size);
  if (replacement.size == 1) {
    memcpy(first + start_col + first_item.size, str_at_end + end_col, last_part_len);
  } else {
    last = arena_allocz(arena, last_item.size + last_part_len);
    memcpy(last, last_item.data, last_item.size);
    memchrsub(last, NUL, NL, last_item.size);
    memcpy(last + last_item.size, str_at_end + end_col, last_part_len);
  }

  char **lines = arena_alloc(arena, new_len * sizeof(char *), true);
  lines[0] = first;
  new_byte += (bcount_t)(first_item.size);
  for (size_t i = 1; i < new_len - 1; i++) {
    const String l = replacement.items[i].data.string;

    // Fill lines[i] with l's contents. Convert NULs to newlines as required by
    // NL-used-for-NUL.
    lines[i] = arena_memdupz(arena, l.data, l.size);
    memchrsub(lines[i], NUL, NL, l.size);
    new_byte += (bcount_t)(l.size) + 1;
  }
  if (replacement.size > 1) {
    lines[replacement.size - 1] = last;
    new_byte += (bcount_t)(last_item.size) + 1;
  }

  TRY_WRAP(err, {
    if (!MODIFIABLE(buf)) {
      api_set_error(err, kErrorTypeException, "Buffer is not 'modifiable'");
      goto end;
    }

    // Small note about undo states: unlike set_lines, we want to save the
    // undo state of one past the end_row, since end_row is inclusive.
    if (u_save_buf(buf, (linenr_T)start_row - 1, (linenr_T)end_row + 1) == FAIL) {
      api_set_error(err, kErrorTypeException, "Failed to save undo information");
      goto end;
    }

    ptrdiff_t extra = 0;  // lines added to text, can be negative
    size_t old_len = (size_t)(end_row - start_row + 1);

    // If the size of the range is reducing (ie, new_len < old_len) we
    // need to delete some old_len. We do this at the start, by
    // repeatedly deleting line "start".
    size_t to_delete = (new_len < old_len) ? old_len - new_len : 0;
    for (size_t i = 0; i < to_delete; i++) {
      if (ml_delete_buf(buf, (linenr_T)start_row, false) == FAIL) {
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

      VALIDATE((lnum < MAXLNUM), "%s", "Index out of bounds", {
        goto end;
      });

      if (ml_replace_buf(buf, (linenr_T)lnum, lines[i], false, true) == FAIL) {
        api_set_error(err, kErrorTypeException, "Failed to replace line");
        goto end;
      }
    }

    // Now we may need to insert the remaining new old_len
    for (size_t i = to_replace; i < new_len; i++) {
      int64_t lnum = start_row + (int64_t)i - 1;

      VALIDATE((lnum < MAXLNUM), "%s", "Index out of bounds", {
        goto end;
      });

      if (ml_append_buf(buf, (linenr_T)lnum, lines[i], 0, false) == FAIL) {
        api_set_error(err, kErrorTypeException, "Failed to insert line");
        goto end;
      }

      extra++;
    }

    colnr_T col_extent = (colnr_T)(end_col
                                   - ((end_row == start_row) ? start_col : 0));

    // Adjust marks. Invalidate any which lie in the
    // changed range, and move any in the remainder of the buffer.
    // Do not adjust any cursors. need to use column-aware logic (below)
    linenr_T adjust = end_row >= start_row ? MAXLNUM : 0;
    mark_adjust_buf(buf, (linenr_T)start_row, (linenr_T)end_row, adjust, (linenr_T)extra,
                    true, true, kExtmarkNOOP);

    extmark_splice(buf, (int)start_row - 1, (colnr_T)start_col,
                   (int)(end_row - start_row), col_extent, old_byte,
                   (int)new_len - 1, (colnr_T)last_item.size, new_byte,
                   kExtmarkUndo);

    changed_lines(buf, (linenr_T)start_row, 0, (linenr_T)end_row + 1, (linenr_T)extra, true);

    FOR_ALL_TAB_WINDOWS(tp, win) {
      if (win->w_buffer == buf) {
        if (win->w_cursor.lnum >= start_row && win->w_cursor.lnum <= end_row) {
          fix_cursor_cols(win, (linenr_T)start_row, (colnr_T)start_col, (linenr_T)end_row,
                          (colnr_T)end_col, (linenr_T)new_len, (colnr_T)last_item.size);
        } else {
          fix_cursor(win, (linenr_T)start_row, (linenr_T)end_row, (linenr_T)extra);
        }
      }
    }
    end:;
  });
}

/// Gets a range from the buffer.
///
/// This differs from |nvim_buf_get_lines()| in that it allows retrieving only
/// portions of a line.
///
/// Indexing is zero-based. Row indices are end-inclusive, and column indices
/// are end-exclusive.
///
/// Prefer |nvim_buf_get_lines()| when retrieving entire lines.
///
/// @param channel_id
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param start_row  First line index
/// @param start_col  Starting column (byte offset) on first line
/// @param end_row    Last line index, inclusive
/// @param end_col    Ending column (byte offset) on last line, exclusive
/// @param opts       Optional parameters. Currently unused.
/// @param[out] err   Error details, if any
/// @return Array of lines, or empty array for unloaded buffer.
ArrayOf(String) nvim_buf_get_text(uint64_t channel_id, Buffer buffer,
                                  Integer start_row, Integer start_col,
                                  Integer end_row, Integer end_col,
                                  Dict(empty) *opts,
                                  Arena *arena, lua_State *lstate, Error *err)
  FUNC_API_SINCE(9)
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
  start_row = normalize_index(buf, start_row, false, &oob);
  end_row = normalize_index(buf, end_row, false, &oob);

  VALIDATE((!oob), "%s", "Index out of bounds", {
    return rv;
  });

  // nvim_buf_get_lines doesn't care if the start row is greater than the end
  // row (it will just return an empty array), but nvim_buf_get_text does in
  // order to maintain symmetry with nvim_buf_set_text.
  VALIDATE((start_row <= end_row), "%s", "'start' is higher than 'end'", {
    return rv;
  });

  bool replace_nl = (channel_id != VIML_INTERNAL_CALL);

  size_t size = (size_t)(end_row - start_row) + 1;

  init_line_array(lstate, &rv, size, arena);

  if (start_row == end_row) {
    String line = buf_get_text(buf, start_row, start_col, end_col, err);
    if (ERROR_SET(err)) {
      goto end;
    }
    push_linestr(lstate, &rv, line.data, line.size, 0, replace_nl, arena);
    return rv;
  }

  String str = buf_get_text(buf, start_row, start_col, MAXCOL - 1, err);
  if (ERROR_SET(err)) {
    goto end;
  }

  push_linestr(lstate, &rv, str.data, str.size, 0, replace_nl, arena);

  if (size > 2) {
    buf_collect_lines(buf, size - 2, (linenr_T)start_row + 1, 1, replace_nl, &rv, lstate, arena);
  }

  str = buf_get_text(buf, end_row, 0, end_col, err);
  if (ERROR_SET(err)) {
    goto end;
  }

  push_linestr(lstate, &rv, str.data, str.size, (int)(size - 1), replace_nl, arena);

end:
  if (ERROR_SET(err)) {
    return (Array)ARRAY_DICT_INIT;
  }

  return rv;
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

  VALIDATE((index >= 0 && index <= buf->b_ml.ml_line_count), "%s", "Index out of bounds", {
    return 0;
  });

  return ml_find_line_or_offset(buf, (int)index + 1, NULL, true);
}

/// Gets a buffer-scoped (b:) variable.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Variable name
/// @param[out] err   Error details, if any
/// @return Variable value
Object nvim_buf_get_var(Buffer buffer, String name, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object)OBJECT_INIT;
  }

  return dict_get_value(buf->b_vars, name, arena, err);
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
/// @param  buffer     Buffer handle, or 0 for current buffer
/// @param  mode       Mode short-name ("n", "i", "v", ...)
/// @param[out]  err   Error details, if any
/// @returns Array of |maparg()|-like dictionaries describing mappings.
///          The "buffer" key holds the associated buffer handle.
ArrayOf(Dict) nvim_buf_get_keymap(Buffer buffer, String mode, Arena *arena, Error *err)
  FUNC_API_SINCE(3)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Array)ARRAY_DICT_INIT;
  }

  return keymap_array(mode, buf, arena);
}

/// Sets a buffer-local |mapping| for the given mode.
///
/// @see |nvim_set_keymap()|
///
/// @param  buffer  Buffer handle, or 0 for current buffer
void nvim_buf_set_keymap(uint64_t channel_id, Buffer buffer, String mode, String lhs, String rhs,
                         Dict(keymap) *opts, Error *err)
  FUNC_API_SINCE(6)
{
  modify_keymap(channel_id, buffer, false, mode, lhs, rhs, opts, err);
}

/// Unmaps a buffer-local |mapping| for the given mode.
///
/// @see |nvim_del_keymap()|
///
/// @param  buffer  Buffer handle, or 0 for current buffer
void nvim_buf_del_keymap(uint64_t channel_id, Buffer buffer, String mode, String lhs, Error *err)
  FUNC_API_SINCE(6)
{
  String rhs = { .data = "", .size = 0 };
  modify_keymap(channel_id, buffer, true, mode, lhs, rhs, NULL, err);
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

  dict_set_var(buf->b_vars, name, value, false, false, NULL, err);
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

  dict_set_var(buf->b_vars, name, NIL, true, false, NULL, err);
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

  return cstr_as_string(buf->b_ffname);
}

/// Sets the full file name for a buffer, like |:file_f|
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

  int ren_ret = OK;
  TRY_WRAP(err, {
    const bool is_curbuf = buf == curbuf;
    const int save_acd = p_acd;
    if (!is_curbuf) {
      // Temporarily disable 'autochdir' when setting file name for another buffer.
      p_acd = false;
    }

    // Using aucmd_*: autocommands will be executed by rename_buffer
    aco_save_T aco;
    aucmd_prepbuf(&aco, buf);
    ren_ret = rename_buffer(name.data);
    aucmd_restbuf(&aco);

    if (!is_curbuf) {
      p_acd = save_acd;
    }
  });

  if (ERROR_SET(err)) {
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
void nvim_buf_delete(Buffer buffer, Dict(buf_delete) *opts, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_TEXTLOCK
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (ERROR_SET(err)) {
    return;
  }

  bool force = opts->force;

  bool unload = opts->unload;

  int result = do_buffer(unload ? DOBUF_UNLOAD : DOBUF_WIPE,
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

/// Deletes a named mark in the buffer. See |mark-motions|.
///
/// @note only deletes marks set in the buffer, if the mark is not set
/// in the buffer it will return false.
/// @param buffer     Buffer to set the mark on
/// @param name       Mark name
/// @return true if the mark was deleted, else false.
/// @see |nvim_buf_set_mark()|
/// @see |nvim_del_mark()|
Boolean nvim_buf_del_mark(Buffer buffer, String name, Error *err)
  FUNC_API_SINCE(8)
{
  bool res = false;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return res;
  }

  VALIDATE_S((name.size == 1), "mark name (must be a single char)", name.data, {
    return res;
  });

  fmark_T *fm = mark_get(buf, curwin, NULL, kMarkAllNoResolve, *name.data);

  // fm is NULL when there's no mark with the given name
  VALIDATE_S((fm != NULL), "mark name", name.data, {
    return res;
  });

  // mark.lnum is 0 when the mark is not valid in the buffer, or is not set.
  if (fm->mark.lnum != 0 && fm->fnum == buf->handle) {
    // since the mark belongs to the buffer delete it.
    res = set_mark(buf, name, 0, 0, err);
  }

  return res;
}

/// Sets a named mark in the given buffer, all marks are allowed
/// file/uppercase, visual, last change, etc. See |mark-motions|.
///
/// Marks are (1,0)-indexed. |api-indexing|
///
/// @note Passing 0 as line deletes the mark
///
/// @param buffer     Buffer to set the mark on
/// @param name       Mark name
/// @param line       Line number
/// @param col        Column/row number
/// @param opts       Optional parameters. Reserved for future use.
/// @return true if the mark was set, else false.
/// @see |nvim_buf_del_mark()|
/// @see |nvim_buf_get_mark()|
Boolean nvim_buf_set_mark(Buffer buffer, String name, Integer line, Integer col, Dict(empty) *opts,
                          Error *err)
  FUNC_API_SINCE(8)
{
  bool res = false;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return res;
  }

  VALIDATE_S((name.size == 1), "mark name (must be a single char)", name.data, {
    return res;
  });

  res = set_mark(buf, name, line, col, err);

  return res;
}

/// Returns a `(row,col)` tuple representing the position of the named mark.
/// "End of line" column position is returned as |v:maxcol| (big number).
/// See |mark-motions|.
///
/// Marks are (1,0)-indexed. |api-indexing|
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Mark name
/// @param[out] err   Error details, if any
/// @return (row, col) tuple, (0, 0) if the mark is not set, or is an
/// uppercase/file mark set in another buffer.
/// @see |nvim_buf_set_mark()|
/// @see |nvim_buf_del_mark()|
ArrayOf(Integer, 2) nvim_buf_get_mark(Buffer buffer, String name, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return rv;
  }

  VALIDATE_S((name.size == 1), "mark name (must be a single char)", name.data, {
    return rv;
  });

  fmark_T *fm;
  pos_T pos;
  char mark = *name.data;

  fm = mark_get(buf, curwin, NULL, kMarkAllNoResolve, mark);
  VALIDATE_S((fm != NULL), "mark name", name.data, {
    return rv;
  });
  // (0, 0) uppercase/file mark set in another buffer.
  if (fm->fnum != buf->handle) {
    pos.lnum = 0;
    pos.col = 0;
  } else {
    pos = fm->mark;
  }

  rv = arena_array(arena, 2);
  ADD_C(rv, INTEGER_OBJ(pos.lnum));
  ADD_C(rv, INTEGER_OBJ(pos.col));

  return rv;
}

/// Call a function with buffer as temporary current buffer.
///
/// This temporarily switches current buffer to "buffer".
/// If the current window already shows "buffer", the window is not switched.
/// If a window inside the current tabpage (including a float) already shows the
/// buffer, then one of these windows will be set as current window temporarily.
/// Otherwise a temporary scratch window (called the "autocmd window" for
/// historical reasons) will be used.
///
/// This is useful e.g. to call Vimscript functions that only work with the
/// current buffer/window currently, like |termopen()|.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param fun        Function to call inside the buffer (currently Lua callable
///                   only)
/// @param[out] err   Error details, if any
/// @return           Return value of function.
Object nvim_buf_call(Buffer buffer, LuaRef fun, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_LUA_ONLY
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return NIL;
  }

  Object res = OBJECT_INIT;
  TRY_WRAP(err, {
    aco_save_T aco;
    aucmd_prepbuf(&aco, buf);

    Array args = ARRAY_DICT_INIT;
    res = nlua_call_ref(fun, NULL, args, kRetLuaref, NULL, err);

    aucmd_restbuf(&aco);
  });

  return res;
}

/// @nodoc
Dict nvim__buf_stats(Buffer buffer, Arena *arena, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return (Dict)ARRAY_DICT_INIT;
  }

  Dict rv = arena_dict(arena, 7);
  // Number of times the cached line was flushed.
  // This should generally not increase while editing the same
  // line in the same mode.
  PUT_C(rv, "flush_count", INTEGER_OBJ(buf->flush_count));
  // lnum of current line
  PUT_C(rv, "current_lnum", INTEGER_OBJ(buf->b_ml.ml_line_lnum));
  // whether the line has unflushed changes.
  PUT_C(rv, "line_dirty", BOOLEAN_OBJ(buf->b_ml.ml_flags & ML_LINE_DIRTY));
  // NB: this should be zero at any time API functions are called,
  // this exists to debug issues
  PUT_C(rv, "dirty_bytes", INTEGER_OBJ((Integer)buf->deleted_bytes));
  PUT_C(rv, "dirty_bytes2", INTEGER_OBJ((Integer)buf->deleted_bytes2));
  PUT_C(rv, "virt_blocks", INTEGER_OBJ((Integer)buf_meta_total(buf, kMTMetaLines)));

  u_header_T *uhp = NULL;
  if (buf->b_u_curhead != NULL) {
    uhp = buf->b_u_curhead;
  } else if (buf->b_u_newhead) {
    uhp = buf->b_u_newhead;
  }
  if (uhp) {
    PUT_C(rv, "uhp_extmark_size", INTEGER_OBJ((Integer)kv_size(uhp->uh_extmark)));
  }

  return rv;
}

// Check if deleting lines made the cursor position invalid.
// Changed lines from `lo` to `hi`; added `extra` lines (negative if deleted).
static void fix_cursor(win_T *win, linenr_T lo, linenr_T hi, linenr_T extra)
{
  if (win->w_cursor.lnum >= lo) {
    // Adjust cursor position if it's in/after the changed lines.
    if (win->w_cursor.lnum >= hi) {
      win->w_cursor.lnum += extra;
    } else if (extra < 0) {
      check_cursor_lnum(win);
    }
    check_cursor_col(win);
    changed_cline_bef_curs(win);
    win->w_valid &= ~(VALID_BOTLINE_AP);
    update_topline(win);
  } else {
    invalidate_botline(win);
  }
}

/// Fix cursor position after replacing text
/// between (start_row, start_col) and (end_row, end_col).
///
/// win->w_cursor.lnum is assumed to be >= start_row and <= end_row.
static void fix_cursor_cols(win_T *win, linenr_T start_row, colnr_T start_col, linenr_T end_row,
                            colnr_T end_col, linenr_T new_rows, colnr_T new_cols_at_end_row)
{
  colnr_T mode_col_adj = win == curwin && (State & MODE_INSERT) ? 0 : 1;

  colnr_T end_row_change_start = new_rows == 1 ? start_col : 0;
  colnr_T end_row_change_end = end_row_change_start + new_cols_at_end_row;

  // check if cursor is after replaced range or not
  if (win->w_cursor.lnum == end_row && win->w_cursor.col + mode_col_adj > end_col) {
    // if cursor is after replaced range, it's shifted
    // to keep it's position the same, relative to end_col

    linenr_T old_rows = end_row - start_row + 1;
    win->w_cursor.lnum += new_rows - old_rows;
    win->w_cursor.col += end_row_change_end - end_col;
  } else {
    // if cursor is inside replaced range
    // and the new range got smaller,
    // it's shifted to keep it inside the new range
    //
    // if cursor is before range or range did not
    // got smaller, position is not changed

    colnr_T old_coladd = win->w_cursor.coladd;

    // it's easier to work with a single value here.
    // col and coladd are fixed by a later call
    // to check_cursor_col when necessary
    win->w_cursor.col += win->w_cursor.coladd;
    win->w_cursor.coladd = 0;

    linenr_T new_end_row = start_row + new_rows - 1;

    // make sure cursor row is in the new row range
    if (win->w_cursor.lnum > new_end_row) {
      win->w_cursor.lnum = new_end_row;

      // don't simply move cursor up, but to the end
      // of new_end_row, if it's not at or after
      // it already (in case virtualedit is active)
      // column might be additionally adjusted below
      // to keep it inside col range if needed
      colnr_T len = ml_get_buf_len(win->w_buffer, new_end_row);
      if (win->w_cursor.col < len) {
        win->w_cursor.col = len;
      }
    }

    // if cursor is at the last row and
    // it wasn't after eol before, move it exactly
    // to end_row_change_end
    if (win->w_cursor.lnum == new_end_row
        && win->w_cursor.col > end_row_change_end && old_coladd == 0) {
      win->w_cursor.col = end_row_change_end;

      // make sure cursor is inside range, not after it,
      // except when doing so would move it before new range
      if (win->w_cursor.col - mode_col_adj >= end_row_change_start) {
        win->w_cursor.col -= mode_col_adj;
      }
    }
  }

  check_cursor_col(win);
  changed_cline_bef_curs(win);
  invalidate_botline(win);
}

/// Initialise a string array either:
/// - on the Lua stack (as a table) (if lstate is not NULL)
/// - as an API array object (if lstate is NULL).
///
/// @param lstate  Lua state. When NULL the Array is initialized instead.
/// @param a       Array to initialize
/// @param size    Size of array
static inline void init_line_array(lua_State *lstate, Array *a, size_t size, Arena *arena)
{
  if (lstate) {
    lua_createtable(lstate, (int)size, 0);
  } else {
    *a = arena_array(arena, size);
  }
}

/// Push a string onto either the Lua stack (as a table element) or an API array object.
///
/// For Lua, a table of the correct size must be created first.
/// API array objects must be pre allocated.
///
/// @param lstate      Lua state. When NULL the Array is pushed to instead.
/// @param a           Array to push onto when not using Lua
/// @param s           String to push
/// @param len         Size of string
/// @param idx         0-based index to place s (only used for Lua)
/// @param replace_nl  Replace newlines ('\n') with null (NUL)
static void push_linestr(lua_State *lstate, Array *a, const char *s, size_t len, int idx,
                         bool replace_nl, Arena *arena)
{
  if (lstate) {
    // Vim represents NULs as NLs
    if (s && replace_nl && strchr(s, '\n')) {
      // TODO(bfredl): could manage scratch space in the arena, for the NUL case
      char *tmp = xmemdupz(s, len);
      strchrsub(tmp, '\n', NUL);
      lua_pushlstring(lstate, tmp, len);
      xfree(tmp);
    } else {
      lua_pushlstring(lstate, s, len);
    }
    lua_rawseti(lstate, -2, idx + 1);
  } else {
    String str = STRING_INIT;
    if (len > 0) {
      str = CBUF_TO_ARENA_STR(arena, s, len);
      if (replace_nl) {
        // Vim represents NULs as NLs, but this may confuse clients.
        strchrsub(str.data, '\n', NUL);
      }
    }

    ADD_C(*a, STRING_OBJ(str));
  }
}

/// Collects `n` buffer lines into array `l` and/or lua_State `lstate`, optionally replacing
/// newlines with NUL.
///
/// @param buf Buffer to get lines from
/// @param n Number of lines to collect
/// @param replace_nl Replace newlines ("\n") with NUL
/// @param start Line number to start from
/// @param start_idx First index to push to (only used for Lua)
/// @param[out] l If not NULL, Lines are copied here
/// @param[out] lstate If not NULL, Lines are pushed into a table onto the stack
/// @param err[out] Error, if any
/// @return true unless `err` was set
void buf_collect_lines(buf_T *buf, size_t n, linenr_T start, int start_idx, bool replace_nl,
                       Array *l, lua_State *lstate, Arena *arena)
{
  for (size_t i = 0; i < n; i++) {
    linenr_T lnum = start + (linenr_T)i;
    char *bufstr = ml_get_buf(buf, lnum);
    size_t bufstrlen = (size_t)ml_get_buf_len(buf, lnum);
    push_linestr(lstate, l, bufstr, bufstrlen, start_idx + (int)i, replace_nl, arena);
  }
}
