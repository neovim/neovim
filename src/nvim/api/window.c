#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/api/window.h"
#include "nvim/autocmd.h"
#include "nvim/buffer_defs.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval/window.h"
#include "nvim/ex_docmd.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/lua/executor.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"
#include "nvim/window.h"

#include "api/window.c.generated.h"  // IWYU pragma: keep

/// Gets the current buffer in a window
///
/// @param win   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Buffer id
Buffer nvim_win_get_buf(Window win, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return 0;
  }

  return w->w_buffer->handle;
}

/// Sets the current buffer in a window.
///
/// Note: As a side-effect, this executes |BufEnter| and |BufLeave| autocommands.
/// @param win   |window-ID|, or 0 for current window
/// @param buf   Buffer id
/// @param[out] err Error details, if any
void nvim_win_set_buf(Window win, Buffer buf, Error *err)
  FUNC_API_SINCE(5)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  win_T *w = find_window_by_handle(win, err);
  buf_T *b = find_buffer_by_handle(buf, err);
  if (!w || !b) {
    return;
  }

  if (w == cmdwin_win || w == cmdwin_old_curwin || b == cmdwin_buf) {
    api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
    return;
  }
  win_set_buf(w, b, err);
}

/// Gets the (1,0)-indexed, buffer-relative cursor position for a given window
/// (different windows showing the same buffer have independent cursor
/// positions). |api-indexing|
///
/// @see |getcurpos()|
///
/// @param win   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return (row, col) tuple
ArrayOf(Integer, 2) nvim_win_get_cursor(Window win, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  win_T *w = find_window_by_handle(win, err);

  if (w) {
    rv = arena_array(arena, 2);
    ADD_C(rv, INTEGER_OBJ(w->w_cursor.lnum));
    ADD_C(rv, INTEGER_OBJ(w->w_cursor.col));
  }

  return rv;
}

/// Sets the (1,0)-indexed cursor position (byte offset) in the window. |api-indexing|
/// This scrolls the window even if it is not the current one.
///
/// @param win   |window-ID|, or 0 for current window
/// @param pos      (row, col) tuple representing the new position
/// @param[out] err Error details, if any
void nvim_win_set_cursor(Window win, ArrayOf(Integer, 2) pos, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return;
  }

  VALIDATE_EXP(!(pos.size != 2 || pos.items[0].type != kObjectTypeInteger
                 || pos.items[1].type != kObjectTypeInteger), "pos", "[row, col] array", NULL, {
    return;
  });

  int64_t row = pos.items[0].data.integer;
  int64_t col = pos.items[1].data.integer;

  VALIDATE_RANGE(!(row <= 0 || row > w->w_buffer->b_ml.ml_line_count), "cursor line", {
    return;
  });

  VALIDATE_RANGE(!(col > MAXCOL || col < 0), "cursor column", {
    return;
  });

  w->w_cursor.lnum = (linenr_T)row;
  w->w_cursor.col = (colnr_T)col;
  w->w_cursor.coladd = 0;
  // When column is out of range silently correct it.
  check_cursor_col(w);

  // Make sure we stick in this column.
  w->w_set_curswant = true;

  // make sure cursor is in visible range and
  // cursorcolumn and cursorline are updated even if w != curwin
  switchwin_T switchwin;
  switch_win(&switchwin, w, NULL, true);
  update_topline(curwin);
  validate_cursor(curwin);
  restore_win(&switchwin, true);

  redraw_later(w, UPD_VALID);
  w->w_redr_status = true;
}

/// Gets the window height
///
/// @param win   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Height as a count of rows
Integer nvim_win_get_height(Window win, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return 0;
  }

  return w->w_height;
}

/// Sets the window height.
///
/// @param win   |window-ID|, or 0 for current window
/// @param height   Height as a count of rows
/// @param[out] err Error details, if any
void nvim_win_set_height(Window win, Integer height, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return;
  }

  TRY_WRAP(err, {
    win_setheight_win((int)height, w);
  });
}

/// Gets the window width
///
/// @param win   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Width as a count of columns
Integer nvim_win_get_width(Window win, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return 0;
  }

  return w->w_width;
}

/// Sets the window width. This will only succeed if the screen is split
/// vertically.
///
/// @param win   |window-ID|, or 0 for current window
/// @param width    Width as a count of columns
/// @param[out] err Error details, if any
void nvim_win_set_width(Window win, Integer width, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return;
  }

  TRY_WRAP(err, {
    win_setwidth_win((int)width, w);
  });
}

/// Gets a window-scoped (w:) variable
///
/// @param win   |window-ID|, or 0 for current window
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_win_get_var(Window win, String name, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return (Object)OBJECT_INIT;
  }

  return dict_get_value(w->w_vars, name, arena, err);
}

/// Sets a window-scoped (w:) variable
///
/// @param win   |window-ID|, or 0 for current window
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_win_set_var(Window win, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return;
  }

  dict_set_var(w->w_vars, name, value, false, false, NULL, err);
}

/// Removes a window-scoped (w:) variable
///
/// @param win   |window-ID|, or 0 for current window
/// @param name     Variable name
/// @param[out] err Error details, if any
void nvim_win_del_var(Window win, String name, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return;
  }

  dict_set_var(w->w_vars, name, NIL, true, false, NULL, err);
}

/// Gets the window position in display cells. First position is zero.
///
/// @param win   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return (row, col) tuple with the window position
ArrayOf(Integer, 2) nvim_win_get_position(Window win, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  win_T *w = find_window_by_handle(win, err);

  if (w) {
    rv = arena_array(arena, 2);
    ADD_C(rv, INTEGER_OBJ(w->w_winrow));
    ADD_C(rv, INTEGER_OBJ(w->w_wincol));
  }

  return rv;
}

/// Gets the window tabpage
///
/// @param win   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Tabpage that contains the window
Tabpage nvim_win_get_tabpage(Window win, Error *err)
  FUNC_API_SINCE(1)
{
  Tabpage rv = 0;
  win_T *w = find_window_by_handle(win, err);

  if (w) {
    rv = win_find_tabpage(w)->handle;
  }

  return rv;
}

/// Gets the window number
///
/// @param win   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Window number
Integer nvim_win_get_number(Window win, Error *err)
  FUNC_API_SINCE(1)
{
  int rv = 0;
  win_T *w = find_window_by_handle(win, err);

  if (!w) {
    return rv;
  }

  int tabnr;
  win_get_tabwin(w->handle, &tabnr, &rv);

  return rv;
}

/// Checks if a window is valid
///
/// @param win |window-ID|, or 0 for current window
/// @return true if the window is valid, false otherwise
Boolean nvim_win_is_valid(Window win)
  FUNC_API_SINCE(1)
{
  Error stub = ERROR_INIT;
  Boolean ret = find_window_by_handle(win, &stub) != NULL;
  api_clear_error(&stub);
  return ret;
}

/// Closes the window and hide the buffer it contains (like |:hide| with a
/// |window-ID|).
///
/// Like |:hide| the buffer becomes hidden unless another window is editing it,
/// or 'bufhidden' is `unload`, `delete` or `wipe` as opposed to |:close| or
/// |nvim_win_close()|, which will close the buffer.
///
/// @param win   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
void nvim_win_hide(Window win, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  win_T *w = find_window_by_handle(win, err);
  if (!w || !can_close_in_cmdwin(w, err)) {
    return;
  }

  tabpage_T *tabpage = win_find_tabpage(w);
  TRY_WRAP(err, {
    // Never close the autocommand window.
    if (is_aucmd_win(w)) {
      emsg(_(e_autocmd_close));
    } else if (tabpage == curtab) {
      win_close(w, false, false);
    } else {
      win_close_othertab(w, false, tabpage, false);
    }
  });
}

/// Closes the window (like |:close| with a |window-ID|).
///
/// @param win   |window-ID|, or 0 for current window
/// @param force    Behave like `:close!` The last window of a buffer with
///                 unwritten changes can be closed. The buffer will become
///                 hidden, even if 'hidden' is not set.
/// @param[out] err Error details, if any
void nvim_win_close(Window win, Boolean force, Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  win_T *w = find_window_by_handle(win, err);
  if (!w || !can_close_in_cmdwin(w, err)) {
    return;
  }

  tabpage_T *tabpage = win_find_tabpage(w);
  TRY_WRAP(err, {
    ex_win_close(force, w, tabpage == curtab ? NULL : tabpage);
  });
}

/// Calls a function with window as temporary current window.
///
/// @see |win_execute()|
/// @see |nvim_buf_call()|
///
/// @param win     |window-ID|, or 0 for current window
/// @param fun        Function to call inside the window (currently Lua callable
///                   only)
/// @param[out] err   Error details, if any
/// @return           Return value of function.
Object nvim_win_call(Window win, LuaRef fun, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_LUA_ONLY
{
  win_T *w = find_window_by_handle(win, err);
  if (!w) {
    return NIL;
  }
  tabpage_T *tabpage = win_find_tabpage(w);

  Object res = OBJECT_INIT;
  TRY_WRAP(err, {
    win_execute_T win_execute_args;
    if (win_execute_before(&win_execute_args, w, tabpage)) {
      Array args = ARRAY_DICT_INIT;
      res = nlua_call_ref(fun, NULL, args, kRetLuaref, NULL, err);
    }
    win_execute_after(&win_execute_args);
  });
  return res;
}

/// Set highlight namespace for a window. This will use highlights defined with
/// |nvim_set_hl()| for this namespace, but fall back to global highlights (ns=0) when
/// missing.
///
/// This takes precedence over the 'winhighlight' option.
///
/// @param win
/// @param ns_id the namespace to use
/// @param[out] err Error details, if any
void nvim_win_set_hl_ns(Window win, Integer ns_id, Error *err)
  FUNC_API_SINCE(10)
{
  win_T *w = find_window_by_handle(win, err);
  if (!w) {
    return;
  }

  // -1 is allowed as inherit global namespace
  VALIDATE_S((ns_id >= -1), "namespace", "", {
    return;
  });

  w->w_ns_hl = (NS)ns_id;
  w->w_hl_needs_update = true;
  redraw_later(w, UPD_NOT_VALID);
}

/// Computes the number of screen lines occupied by a range of text in a given window.
/// Works for off-screen text and takes folds into account.
///
/// Diff filler or virtual lines above a line are counted as a part of that line,
/// unless the line is on "start_row" and "start_vcol" is specified.
///
/// Diff filler or virtual lines below the last buffer line are counted in the result
/// when "end_row" is omitted.
///
/// Line indexing is similar to |nvim_buf_get_text()|.
///
/// @param win  |window-ID|, or 0 for current window.
/// @param opts    Optional parameters:
///                - start_row: Starting line index, 0-based inclusive.
///                             When omitted start at the very top.
///                - end_row: Ending line index, 0-based inclusive.
///                           When omitted end at the very bottom.
///                - start_vcol: Starting virtual column index on "start_row",
///                              0-based inclusive, rounded down to full screen lines.
///                              When omitted include the whole line.
///                - end_vcol: Ending virtual column index on "end_row",
///                            0-based exclusive, rounded up to full screen lines.
///                            When 0 only include diff filler and virtual lines above
///                            "end_row". When omitted include the whole line.
///                - max_height: Don't add the height of lines below the row
///                              for which this height is reached. Useful to e.g. limit the
///                              height to the window height, avoiding unnecessary work. Or
///                              to find out how many buffer lines beyond "start_row" take
///                              up a certain number of logical lines (returned in
///                              "end_row" and "end_vcol").
/// @return  Dict containing text height information, with these keys:
///          - all: The total number of screen lines occupied by the range.
///          - fill: The number of diff filler or virtual lines among them.
///          - end_row: The row on which the returned height is reached (first row of
///            a closed fold).
///          - end_vcol: Ending virtual column in "end_row" where "max_height" or the returned
///            height is reached. 0 if "end_row" is a closed fold.
///
/// @see |virtcol()| for text width.
DictAs(win_text_height_ret) nvim_win_text_height(Window win, Dict(win_text_height) *opts,
                                                 Arena *arena, Error *err)
  FUNC_API_SINCE(12)
{
  Dict rv = arena_dict(arena, 2);

  win_T *const w = find_window_by_handle(win, err);
  if (!w) {
    return rv;
  }
  buf_T *const buf = w->w_buffer;
  const linenr_T line_count = buf->b_ml.ml_line_count;

  linenr_T start_lnum = 1;
  linenr_T end_lnum = line_count;
  int64_t start_vcol = -1;
  int64_t end_vcol = -1;

  bool oob = false;

  if (HAS_KEY(opts, win_text_height, start_row)) {
    start_lnum = (linenr_T)normalize_index(buf, opts->start_row, false, &oob);
  }

  if (HAS_KEY(opts, win_text_height, end_row)) {
    end_lnum = (linenr_T)normalize_index(buf, opts->end_row, false, &oob);
  }

  VALIDATE(!oob, "%s", "Line index out of bounds", {
    return rv;
  });
  VALIDATE((start_lnum <= end_lnum), "%s", "'start_row' is higher than 'end_row'", {
    return rv;
  });

  if (HAS_KEY(opts, win_text_height, start_vcol)) {
    VALIDATE(HAS_KEY(opts, win_text_height, start_row),
             "%s", "'start_vcol' specified without 'start_row'", {
      return rv;
    });
    start_vcol = opts->start_vcol;
    VALIDATE_RANGE((start_vcol >= 0 && start_vcol <= MAXCOL), "start_vcol", {
      return rv;
    });
  }

  if (HAS_KEY(opts, win_text_height, end_vcol)) {
    VALIDATE(HAS_KEY(opts, win_text_height, end_row),
             "%s", "'end_vcol' specified without 'end_row'", {
      return rv;
    });
    end_vcol = opts->end_vcol;
    VALIDATE_RANGE((end_vcol >= 0 && end_vcol <= MAXCOL), "end_vcol", {
      return rv;
    });
  }

  int64_t max = INT64_MAX;
  if (HAS_KEY(opts, win_text_height, max_height)) {
    VALIDATE_RANGE(opts->max_height > 0, "max_height", {
      return rv;
    });
    max = opts->max_height;
  }

  if (start_lnum == end_lnum && start_vcol >= 0 && end_vcol >= 0) {
    VALIDATE((start_vcol <= end_vcol), "%s", "'start_vcol' is higher than 'end_vcol'", {
      return rv;
    });
  }

  int64_t fill = 0;
  int64_t all = win_text_height(w, start_lnum, start_vcol, &end_lnum, &end_vcol, &fill, max);
  if (!HAS_KEY(opts, win_text_height, end_row)) {
    const int64_t end_fill = win_get_fill(w, line_count + 1);
    fill += end_fill;
    all += end_fill;
  }
  PUT_C(rv, "all", INTEGER_OBJ(all));
  PUT_C(rv, "fill", INTEGER_OBJ(fill));
  PUT_C(rv, "end_row", INTEGER_OBJ(end_lnum - 1));
  PUT_C(rv, "end_vcol", INTEGER_OBJ(end_vcol));
  return rv;
}
