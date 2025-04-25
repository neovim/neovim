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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/window.c.generated.h"  // IWYU pragma: keep
#endif

/// Gets the current buffer in a window
///
/// @param window   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Buffer id
Buffer nvim_win_get_buf(Window window, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return 0;
  }

  return win->w_buffer->handle;
}

/// Sets the current buffer in a window, without side effects
///
/// @param window   |window-ID|, or 0 for current window
/// @param buffer   Buffer id
/// @param[out] err Error details, if any
void nvim_win_set_buf(Window window, Buffer buffer, Error *err)
  FUNC_API_SINCE(5)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  win_T *win = find_window_by_handle(window, err);
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!win || !buf) {
    return;
  }

  if (win == cmdwin_win || win == cmdwin_old_curwin || buf == cmdwin_buf) {
    api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
    return;
  }
  win_set_buf(win, buf, err);
}

/// Gets the (1,0)-indexed, buffer-relative cursor position for a given window
/// (different windows showing the same buffer have independent cursor
/// positions). |api-indexing|
///
/// @see |getcurpos()|
///
/// @param window   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return (row, col) tuple
ArrayOf(Integer, 2) nvim_win_get_cursor(Window window, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  win_T *win = find_window_by_handle(window, err);

  if (win) {
    rv = arena_array(arena, 2);
    ADD_C(rv, INTEGER_OBJ(win->w_cursor.lnum));
    ADD_C(rv, INTEGER_OBJ(win->w_cursor.col));
  }

  return rv;
}

/// Sets the (1,0)-indexed cursor position in the window. |api-indexing|
/// This scrolls the window even if it is not the current one.
///
/// @param window   |window-ID|, or 0 for current window
/// @param pos      (row, col) tuple representing the new position
/// @param[out] err Error details, if any
void nvim_win_set_cursor(Window window, ArrayOf(Integer, 2) pos, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  if (pos.size != 2 || pos.items[0].type != kObjectTypeInteger
      || pos.items[1].type != kObjectTypeInteger) {
    api_set_error(err,
                  kErrorTypeValidation,
                  "Argument \"pos\" must be a [row, col] array");
    return;
  }

  int64_t row = pos.items[0].data.integer;
  int64_t col = pos.items[1].data.integer;

  if (row <= 0 || row > win->w_buffer->b_ml.ml_line_count) {
    api_set_error(err, kErrorTypeValidation, "Cursor position outside buffer");
    return;
  }

  if (col > MAXCOL || col < 0) {
    api_set_error(err, kErrorTypeValidation, "Column value outside range");
    return;
  }

  win->w_cursor.lnum = (linenr_T)row;
  win->w_cursor.col = (colnr_T)col;
  win->w_cursor.coladd = 0;
  // When column is out of range silently correct it.
  check_cursor_col(win);

  // Make sure we stick in this column.
  win->w_set_curswant = true;

  // make sure cursor is in visible range and
  // cursorcolumn and cursorline are updated even if win != curwin
  switchwin_T switchwin;
  switch_win(&switchwin, win, NULL, true);
  update_topline(curwin);
  validate_cursor(curwin);
  restore_win(&switchwin, true);

  redraw_later(win, UPD_VALID);
  win->w_redr_status = true;
}

/// Gets the window height
///
/// @param window   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Height as a count of rows
Integer nvim_win_get_height(Window window, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return 0;
  }

  return win->w_height;
}

/// Sets the window height.
///
/// @param window   |window-ID|, or 0 for current window
/// @param height   Height as a count of rows
/// @param[out] err Error details, if any
void nvim_win_set_height(Window window, Integer height, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  TRY_WRAP(err, {
    win_setheight_win((int)height, win);
  });
}

/// Gets the window width
///
/// @param window   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Width as a count of columns
Integer nvim_win_get_width(Window window, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return 0;
  }

  return win->w_width;
}

/// Sets the window width. This will only succeed if the screen is split
/// vertically.
///
/// @param window   |window-ID|, or 0 for current window
/// @param width    Width as a count of columns
/// @param[out] err Error details, if any
void nvim_win_set_width(Window window, Integer width, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  TRY_WRAP(err, {
    win_setwidth_win((int)width, win);
  });
}

/// Gets a window-scoped (w:) variable
///
/// @param window   |window-ID|, or 0 for current window
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_win_get_var(Window window, String name, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object)OBJECT_INIT;
  }

  return dict_get_value(win->w_vars, name, arena, err);
}

/// Sets a window-scoped (w:) variable
///
/// @param window   |window-ID|, or 0 for current window
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_win_set_var(Window window, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  dict_set_var(win->w_vars, name, value, false, false, NULL, err);
}

/// Removes a window-scoped (w:) variable
///
/// @param window   |window-ID|, or 0 for current window
/// @param name     Variable name
/// @param[out] err Error details, if any
void nvim_win_del_var(Window window, String name, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  dict_set_var(win->w_vars, name, NIL, true, false, NULL, err);
}

/// Gets the window position in display cells. First position is zero.
///
/// @param window   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return (row, col) tuple with the window position
ArrayOf(Integer, 2) nvim_win_get_position(Window window, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  win_T *win = find_window_by_handle(window, err);

  if (win) {
    rv = arena_array(arena, 2);
    ADD_C(rv, INTEGER_OBJ(win->w_winrow));
    ADD_C(rv, INTEGER_OBJ(win->w_wincol));
  }

  return rv;
}

/// Gets the window tabpage
///
/// @param window   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Tabpage that contains the window
Tabpage nvim_win_get_tabpage(Window window, Error *err)
  FUNC_API_SINCE(1)
{
  Tabpage rv = 0;
  win_T *win = find_window_by_handle(window, err);

  if (win) {
    rv = win_find_tabpage(win)->handle;
  }

  return rv;
}

/// Gets the window number
///
/// @param window   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return Window number
Integer nvim_win_get_number(Window window, Error *err)
  FUNC_API_SINCE(1)
{
  int rv = 0;
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return rv;
  }

  int tabnr;
  win_get_tabwin(win->handle, &tabnr, &rv);

  return rv;
}

/// Checks if a window is valid
///
/// @param window |window-ID|, or 0 for current window
/// @return true if the window is valid, false otherwise
Boolean nvim_win_is_valid(Window window)
  FUNC_API_SINCE(1)
{
  Error stub = ERROR_INIT;
  Boolean ret = find_window_by_handle(window, &stub) != NULL;
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
/// @param window   |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
void nvim_win_hide(Window window, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  win_T *win = find_window_by_handle(window, err);
  if (!win || !can_close_in_cmdwin(win, err)) {
    return;
  }

  tabpage_T *tabpage = win_find_tabpage(win);
  TRY_WRAP(err, {
    // Never close the autocommand window.
    if (is_aucmd_win(win)) {
      emsg(_(e_autocmd_close));
    } else if (tabpage == curtab) {
      win_close(win, false, false);
    } else {
      win_close_othertab(win, false, tabpage);
    }
  });
}

/// Closes the window (like |:close| with a |window-ID|).
///
/// @param window   |window-ID|, or 0 for current window
/// @param force    Behave like `:close!` The last window of a buffer with
///                 unwritten changes can be closed. The buffer will become
///                 hidden, even if 'hidden' is not set.
/// @param[out] err Error details, if any
void nvim_win_close(Window window, Boolean force, Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  win_T *win = find_window_by_handle(window, err);
  if (!win || !can_close_in_cmdwin(win, err)) {
    return;
  }

  tabpage_T *tabpage = win_find_tabpage(win);
  TRY_WRAP(err, {
    ex_win_close(force, win, tabpage == curtab ? NULL : tabpage);
  });
}

/// Calls a function with window as temporary current window.
///
/// @see |win_execute()|
/// @see |nvim_buf_call()|
///
/// @param window     |window-ID|, or 0 for current window
/// @param fun        Function to call inside the window (currently Lua callable
///                   only)
/// @param[out] err   Error details, if any
/// @return           Return value of function.
Object nvim_win_call(Window window, LuaRef fun, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_LUA_ONLY
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return NIL;
  }
  tabpage_T *tabpage = win_find_tabpage(win);

  Object res = OBJECT_INIT;
  TRY_WRAP(err, {
    win_execute_T win_execute_args;
    if (win_execute_before(&win_execute_args, win, tabpage)) {
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
/// @param window
/// @param ns_id the namespace to use
/// @param[out] err Error details, if any
void nvim_win_set_hl_ns(Window window, Integer ns_id, Error *err)
  FUNC_API_SINCE(10)
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return;
  }

  // -1 is allowed as inherit global namespace
  if (ns_id < -1) {
    api_set_error(err, kErrorTypeValidation, "no such namespace");
  }

  win->w_ns_hl = (NS)ns_id;
  win->w_ns_hl_winhl = -1;
  win->w_hl_needs_update = true;
  redraw_later(win, UPD_NOT_VALID);
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
/// @param window  |window-ID|, or 0 for current window.
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
Dict nvim_win_text_height(Window window, Dict(win_text_height) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(12)
{
  Dict rv = arena_dict(arena, 2);

  win_T *const win = find_window_by_handle(window, err);
  if (!win) {
    return rv;
  }
  buf_T *const buf = win->w_buffer;
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
  int64_t all = win_text_height(win, start_lnum, start_vcol, &end_lnum, &end_vcol, &fill, max);
  if (!HAS_KEY(opts, win_text_height, end_row)) {
    const int64_t end_fill = win_get_fill(win, line_count + 1);
    fill += end_fill;
    all += end_fill;
  }
  PUT_C(rv, "all", INTEGER_OBJ(all));
  PUT_C(rv, "fill", INTEGER_OBJ(fill));
  PUT_C(rv, "end_row", INTEGER_OBJ(end_lnum - 1));
  PUT_C(rv, "end_vcol", INTEGER_OBJ(end_vcol));
  return rv;
}
