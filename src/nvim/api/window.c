// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/window.h"
#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/eval/window.h"
#include "nvim/ex_docmd.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/lua/executor.h"
#include "nvim/memline_defs.h"
#include "nvim/move.h"
#include "nvim/pos.h"
#include "nvim/types.h"
#include "nvim/window.h"

/// Gets the current buffer in a window
///
/// @param window   Window handle, or 0 for current window
/// @param[out] err Error details, if any
/// @return Buffer handle
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
/// @param window   Window handle, or 0 for current window
/// @param buffer   Buffer handle
/// @param[out] err Error details, if any
void nvim_win_set_buf(Window window, Buffer buffer, Error *err)
  FUNC_API_SINCE(5)
  FUNC_API_CHECK_TEXTLOCK
{
  win_set_buf(window, buffer, false, err);
}

/// Gets the (1,0)-indexed, buffer-relative cursor position for a given window
/// (different windows showing the same buffer have independent cursor
/// positions). |api-indexing|
///
/// @see |getcurpos()|
///
/// @param window   Window handle, or 0 for current window
/// @param[out] err Error details, if any
/// @return (row, col) tuple
ArrayOf(Integer, 2) nvim_win_get_cursor(Window window, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  win_T *win = find_window_by_handle(window, err);

  if (win) {
    ADD(rv, INTEGER_OBJ(win->w_cursor.lnum));
    ADD(rv, INTEGER_OBJ(win->w_cursor.col));
  }

  return rv;
}

/// Sets the (1,0)-indexed cursor position in the window. |api-indexing|
/// This scrolls the window even if it is not the current one.
///
/// @param window   Window handle, or 0 for current window
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
  check_cursor_col_win(win);

  // Make sure we stick in this column.
  win->w_set_curswant = true;

  // make sure cursor is in visible range and
  // cursorcolumn and cursorline are updated even if win != curwin
  switchwin_T switchwin;
  switch_win(&switchwin, win, NULL, true);
  update_topline(curwin);
  validate_cursor();
  restore_win(&switchwin, true);

  redraw_later(win, UPD_VALID);
  win->w_redr_status = true;
}

/// Gets the window height
///
/// @param window   Window handle, or 0 for current window
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
/// @param window   Window handle, or 0 for current window
/// @param height   Height as a count of rows
/// @param[out] err Error details, if any
void nvim_win_set_height(Window window, Integer height, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  if (height > INT_MAX || height < INT_MIN) {
    api_set_error(err, kErrorTypeValidation, "Height value outside range");
    return;
  }

  try_start();
  win_setheight_win((int)height, win);
  try_end(err);
}

/// Gets the window width
///
/// @param window   Window handle, or 0 for current window
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
/// @param window   Window handle, or 0 for current window
/// @param width    Width as a count of columns
/// @param[out] err Error details, if any
void nvim_win_set_width(Window window, Integer width, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  if (width > INT_MAX || width < INT_MIN) {
    api_set_error(err, kErrorTypeValidation, "Width value outside range");
    return;
  }

  try_start();
  win_setwidth_win((int)width, win);
  try_end(err);
}

/// Gets a window-scoped (w:) variable
///
/// @param window   Window handle, or 0 for current window
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_win_get_var(Window window, String name, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object)OBJECT_INIT;
  }

  return dict_get_value(win->w_vars, name, err);
}

/// Sets a window-scoped (w:) variable
///
/// @param window   Window handle, or 0 for current window
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

  dict_set_var(win->w_vars, name, value, false, false, err);
}

/// Removes a window-scoped (w:) variable
///
/// @param window   Window handle, or 0 for current window
/// @param name     Variable name
/// @param[out] err Error details, if any
void nvim_win_del_var(Window window, String name, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  dict_set_var(win->w_vars, name, NIL, true, false, err);
}

/// Gets the window position in display cells. First position is zero.
///
/// @param window   Window handle, or 0 for current window
/// @param[out] err Error details, if any
/// @return (row, col) tuple with the window position
ArrayOf(Integer, 2) nvim_win_get_position(Window window, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  win_T *win = find_window_by_handle(window, err);

  if (win) {
    ADD(rv, INTEGER_OBJ(win->w_winrow));
    ADD(rv, INTEGER_OBJ(win->w_wincol));
  }

  return rv;
}

/// Gets the window tabpage
///
/// @param window   Window handle, or 0 for current window
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
/// @param window   Window handle, or 0 for current window
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
/// @param window Window handle, or 0 for current window
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
/// @param window   Window handle, or 0 for current window
/// @param[out] err Error details, if any
void nvim_win_hide(Window window, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_CHECK_TEXTLOCK
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return;
  }

  tabpage_T *tabpage = win_find_tabpage(win);
  TryState tstate;
  try_enter(&tstate);

  // Never close the autocommand window.
  if (is_aucmd_win(win)) {
    emsg(_(e_autocmd_close));
  } else if (tabpage == curtab) {
    win_close(win, false, false);
  } else {
    win_close_othertab(win, false, tabpage);
  }

  vim_ignored = try_leave(&tstate, err);
}

/// Closes the window (like |:close| with a |window-ID|).
///
/// @param window   Window handle, or 0 for current window
/// @param force    Behave like `:close!` The last window of a buffer with
///                 unwritten changes can be closed. The buffer will become
///                 hidden, even if 'hidden' is not set.
/// @param[out] err Error details, if any
void nvim_win_close(Window window, Boolean force, Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_CHECK_TEXTLOCK
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return;
  }

  if (cmdwin_type != 0) {
    if (win == curwin) {
      cmdwin_result = Ctrl_C;
    } else {
      api_set_error(err, kErrorTypeException, "%s", _(e_cmdwin));
    }
    return;
  }

  tabpage_T *tabpage = win_find_tabpage(win);
  TryState tstate;
  try_enter(&tstate);
  ex_win_close(force, win, tabpage == curtab ? NULL : tabpage);
  vim_ignored = try_leave(&tstate, err);
}

/// Calls a function with window as temporary current window.
///
/// @see |win_execute()|
/// @see |nvim_buf_call()|
///
/// @param window     Window handle, or 0 for current window
/// @param fun        Function to call inside the window (currently Lua callable
///                   only)
/// @param[out] err   Error details, if any
/// @return           Return value of function. NB: will deepcopy Lua values
///                   currently, use upvalues to send Lua references in and out.
Object nvim_win_call(Window window, LuaRef fun, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_LUA_ONLY
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return NIL;
  }
  tabpage_T *tabpage = win_find_tabpage(win);

  try_start();
  Object res = OBJECT_INIT;
  WIN_EXECUTE(win, tabpage, {
    Array args = ARRAY_DICT_INIT;
    res = nlua_call_ref(fun, NULL, args, true, err);
  });
  try_end(err);
  return res;
}

/// Set highlight namespace for a window. This will use highlights defined with
/// |nvim_set_hl()| for this namespace, but fall back to global highlights (ns=0) when
/// missing.
///
/// This takes precedence over the 'winhighlight' option.
///
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
  win->w_hl_needs_update = true;
  redraw_later(win, UPD_NOT_VALID);
}
