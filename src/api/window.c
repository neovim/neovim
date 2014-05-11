#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "api/window.h"
#include "api/defs.h"
#include "api/helpers.h"


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
  abort();
}

void window_set_cursor(Window window, Position pos, Error *err)
{
  abort();
}

int64_t window_get_height(Window window, Error *err)
{
  abort();
}

void window_set_height(Window window, int64_t height, Error *err)
{
  abort();
}

int64_t window_get_width(Window window, Error *err)
{
  abort();
}

Object window_get_var(Window window, String name, Error *err)
{
  abort();
}

void window_set_var(Window window, String name, Object value, Error *err)
{
  abort();
}

String window_get_option(Window window, String name, Error *err)
{
  abort();
}

void window_set_option(Window window, String name, String value, Error *err)
{
  abort();
}

Position window_get_pos(Window window, Error *err)
{
  abort();
}

Tabpage window_get_tabpage(Window window, Error *err)
{
  abort();
}

bool window_is_valid(Window window)
{
  abort();
}

