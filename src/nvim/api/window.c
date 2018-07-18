// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>

#include "nvim/api/window.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/vim.h"
#include "nvim/cursor.h"
#include "nvim/window.h"
#include "nvim/screen.h"
#include "nvim/move.h"


/// Gets the current buffer in a window
///
/// @param window   Window handle
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

/// Gets the cursor position in the window
///
/// @param window   Window handle
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

/// Sets the cursor position in the window
///
/// @param window   Window handle
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

  // make sure cursor is in visible range even if win != curwin
  update_topline_win(win);

  update_screen(VALID);
}

/// Gets the window height
///
/// @param window   Window handle
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

/// Sets the window height. This will only succeed if the screen is split
/// horizontally.
///
/// @param window   Window handle
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

  win_T *savewin = curwin;
  curwin = win;
  try_start();
  win_setheight((int)height);
  curwin = savewin;
  try_end(err);
}

/// Gets the window width
///
/// @param window   Window handle
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
/// @param window   Window handle
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

  win_T *savewin = curwin;
  curwin = win;
  try_start();
  win_setwidth((int)width);
  curwin = savewin;
  try_end(err);
}

/// Gets a window-scoped (w:) variable
///
/// @param window   Window handle
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_win_get_var(Window window, String name, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object) OBJECT_INIT;
  }

  return dict_get_value(win->w_vars, name, err);
}

/// Sets a window-scoped (w:) variable
///
/// @param window   Window handle
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
/// @param window   Window handle
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

/// Sets a window-scoped (w:) variable
///
/// @deprecated
///
/// @param window   Window handle
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
/// @return Old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object window_set_var(Window window, String name, Object value, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_var(win->w_vars, name, value, false, true, err);
}

/// Removes a window-scoped (w:) variable
///
/// @deprecated
///
/// @param window   Window handle
/// @param name     variable name
/// @param[out] err Error details, if any
/// @return Old value
Object window_del_var(Window window, String name, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_var(win->w_vars, name, NIL, true, true, err);
}

/// Gets a window option value
///
/// @param window   Window handle
/// @param name     Option name
/// @param[out] err Error details, if any
/// @return Option value
Object nvim_win_get_option(Window window, String name, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object) OBJECT_INIT;
  }

  return get_option_from(win, SREQ_WIN, name, err);
}

/// Sets a window option value. Passing 'nil' as value deletes the option(only
/// works if there's a global fallback)
///
/// @param window   Window handle
/// @param name     Option name
/// @param value    Option value
/// @param[out] err Error details, if any
void nvim_win_set_option(uint64_t channel_id, Window window,
                         String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  set_option_to(channel_id, win, SREQ_WIN, name, value, err);
}

/// Gets the window position in display cells. First position is zero.
///
/// @param window   Window handle
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
/// @param window   Window handle
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
/// @param window   Window handle
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
  win_get_tabwin(window, &tabnr, &rv);

  return rv;
}

/// Checks if a window is valid
///
/// @param window Window handle
/// @return true if the window is valid, false otherwise
Boolean nvim_win_is_valid(Window window)
  FUNC_API_SINCE(1)
{
  Error stub = ERROR_INIT;
  Boolean ret = find_window_by_handle(window, &stub) != NULL;
  api_clear_error(&stub);
  return ret;
}

