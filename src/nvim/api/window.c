#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/window.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/vim.h"
#include "nvim/cursor.h"
#include "nvim/window.h"
#include "nvim/screen.h"
#include "nvim/misc2.h"


/// Gets the current buffer in a window
///
/// @param window The window handle
/// @param[out] err Details of an error that may have occurred
/// @return The buffer handle
Buffer window_get_buffer(Window window, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return 0;
  }

  return win->w_buffer->handle;
}

/// Gets the cursor position in the window
///
/// @param window The window handle
/// @param[out] err Details of an error that may have occurred
/// @return the (row, col) tuple
Position window_get_cursor(Window window, Error *err)
{
  Position rv = POSITION_INIT;
  win_T *win = find_window_by_handle(window, err);

  if (win) {
    rv.row = win->w_cursor.lnum;
    rv.col = win->w_cursor.col;
  }

  return rv;
}

/// Sets the cursor position in the window
///
/// @param window The window handle
/// @param pos the (row, col) tuple representing the new position
/// @param[out] err Details of an error that may have occurred
void window_set_cursor(Window window, Position pos, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  if (pos.row <= 0 || pos.row > win->w_buffer->b_ml.ml_line_count) {
    set_api_error("cursor position outside buffer", err);
    return;
  }

  if (pos.row > LONG_MAX || pos.row < LONG_MIN) {
    set_api_error("Row value outside range", err);
    return;
  }

  if (pos.col > INT_MAX || pos.col < INT_MIN) {
    set_api_error("Column value outside range", err);
    return;
  }

  win->w_cursor.lnum = (linenr_T)pos.row;
  win->w_cursor.col = (colnr_T)pos.col;
  win->w_cursor.coladd = 0;
  // When column is out of range silently correct it.
  check_cursor_col_win(win);
  update_screen(VALID);
}

/// Gets the window height
///
/// @param window The window handle
/// @param[out] err Details of an error that may have occurred
/// @return the height in rows
Integer window_get_height(Window window, Error *err)
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
/// @param window The window handle
/// @param height the new height in rows
/// @param[out] err Details of an error that may have occurred
void window_set_height(Window window, Integer height, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  if (height > INT_MAX || height < INT_MIN) {
    set_api_error("Height value outside range", err);
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
/// @param window The window handle
/// @param[out] err Details of an error that may have occurred
/// @return the width in columns
Integer window_get_width(Window window, Error *err)
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
/// @param window The window handle
/// @param width the new width in columns
/// @param[out] err Details of an error that may have occurred
void window_set_width(Window window, Integer width, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  if (width > INT_MAX || width < INT_MIN) {
    set_api_error("Width value outside range", err);
    return;
  }

  win_T *savewin = curwin;
  curwin = win;
  try_start();
  win_setwidth((int)width);
  curwin = savewin;
  try_end(err);
}

/// Gets a window variable
///
/// @param window The window handle
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object window_get_var(Window window, String name, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object) OBJECT_INIT;
  }

  return dict_get_value(win->w_vars, name, err);
}

/// Sets a window variable. Passing 'nil' as value deletes the variable.
///
/// @param window The window handle
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return The old value
Object window_set_var(Window window, String name, Object value, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_value(win->w_vars, name, value, err);
}

/// Gets a window option value
///
/// @param window The window handle
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return The option value
Object window_get_option(Window window, String name, Error *err)
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
/// @param window The window handle
/// @param name The option name
/// @param value The option value
/// @param[out] err Details of an error that may have occurred
void window_set_option(Window window, String name, Object value, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  set_option_to(win, SREQ_WIN, name, value, err);
}

/// Gets the window position in display cells. First position is zero.
///
/// @param window The window handle
/// @param[out] err Details of an error that may have occurred
/// @return The (row, col) tuple with the window position
Position window_get_position(Window window, Error *err)
{
  Position rv = POSITION_INIT;
  win_T *win = find_window_by_handle(window, err);

  if (win) {
    rv.col = win->w_wincol;
    rv.row = win->w_winrow;
  }

  return rv;
}

/// Gets the window tab page
///
/// @param window The window handle
/// @param[out] err Details of an error that may have occurred
/// @return The tab page that contains the window
Tabpage window_get_tabpage(Window window, Error *err)
{
  Tabpage rv = 0;
  win_T *win = find_window_by_handle(window, err);

  if (win) {
    rv = win_find_tabpage(win)->handle;
  }

  return rv;
}

/// Checks if a window is valid
///
/// @param window The window handle
/// @return true if the window is valid, false otherwise
Boolean window_is_valid(Window window)
{
  Error stub = {.set = false};
  return find_window_by_handle(window, &stub) != NULL;
}

