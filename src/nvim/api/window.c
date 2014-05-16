#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/window.h"
#include "nvim/api/defs.h"
#include "nvim/api/helpers.h"
#include "nvim/vim.h"
#include "nvim/window.h"
#include "nvim/screen.h"
#include "nvim/misc2.h"


Buffer window_get_buffer(Window window, Error *err)
{
  win_T *win = find_window(window, err);

  if (!win) {
    return 0;
  }

  return win->w_buffer->b_fnum;
}

Position window_get_cursor(Window window, Error *err)
{
  Position rv = {.row = 0, .col = 0};
  win_T *win = find_window(window, err);

  if (win) {
    rv.row = win->w_cursor.lnum;
    rv.col = win->w_cursor.col;
  }

  return rv;
}

void window_set_cursor(Window window, Position pos, Error *err)
{
  win_T *win = find_window(window, err);

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

Integer window_get_height(Window window, Error *err)
{
  win_T *win = find_window(window, err);

  if (!win) {
    return 0;
  }

  return win->w_height;
}

void window_set_height(Window window, Integer height, Error *err)
{
  win_T *win = find_window(window, err);

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

Integer window_get_width(Window window, Error *err)
{
  win_T *win = find_window(window, err);

  if (!win) {
    return 0;
  }

  return win->w_width;
}

void window_set_width(Window window, Integer width, Error *err)
{
  win_T *win = find_window(window, err);

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

Object window_get_var(Window window, String name, Error *err)
{
  Object rv;
  win_T *win = find_window(window, err);

  if (!win) {
    return rv;
  }

  return dict_get_value(win->w_vars, name, err);
}

Object window_set_var(Window window, String name, Object value, Error *err)
{
  Object rv;
  win_T *win = find_window(window, err);

  if (!win) {
    return rv;
  }

  return dict_set_value(win->w_vars, name, value, err);
}

Object window_get_option(Window window, String name, Error *err)
{
  Object rv;
  win_T *win = find_window(window, err);

  if (!win) {
    return rv;
  }

  return get_option_from(win, SREQ_WIN, name, err);
}

void window_set_option(Window window, String name, Object value, Error *err)
{
  win_T *win = find_window(window, err);

  if (!win) {
    return;
  }

  set_option_to(win, SREQ_WIN, name, value, err);
}

Position window_get_position(Window window, Error *err)
{
  Position rv;
  win_T *win = find_window(window, err);

  if (win) {
    rv.col = win->w_wincol;
    rv.row = win->w_winrow;
  }

  return rv;
}

Tabpage window_get_tabpage(Window window, Error *err)
{
  set_api_error("Not implemented", err);
  return 0;
}

Boolean window_is_valid(Window window)
{
  Error stub = {.set = false};
  return find_window(window, &stub) != NULL;
}

