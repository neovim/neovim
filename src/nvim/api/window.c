// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/lua/executor.h"
#include "nvim/ex_docmd.h"
#include "nvim/vim.h"
#include "nvim/api/window.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/cursor.h"
#include "nvim/globals.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/screen.h"
#include "nvim/syntax.h"
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

/// Sets the current buffer in a window, without side-effects
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

/// Gets the (1,0)-indexed cursor position in the window. |api-indexing|
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

  // make sure cursor is in visible range even if win != curwin
  update_topline_win(win);

  redraw_later(win, VALID);
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

/// Sets the window height. This will only succeed if the screen is split
/// horizontally.
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

  win_T *savewin = curwin;
  curwin = win;
  try_start();
  win_setheight((int)height);
  curwin = savewin;
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

  win_T *savewin = curwin;
  curwin = win;
  try_start();
  win_setwidth((int)width);
  curwin = savewin;
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
    return (Object) OBJECT_INIT;
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

/// Gets a window option value
///
/// @param window   Window handle, or 0 for current window
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
/// @param channel_id
/// @param window   Window handle, or 0 for current window
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


/// Configures window layout. Currently only for floating and external windows
/// (including changing a split window to those layouts).
///
/// When reconfiguring a floating window, absent option keys will not be
/// changed.  `row`/`col` and `relative` must be reconfigured together.
///
/// @see |nvim_open_win()|
///
/// @param      window  Window handle, or 0 for current window
/// @param      config  Map defining the window configuration,
///                     see |nvim_open_win()|
/// @param[out] err     Error details, if any
void nvim_win_set_config(Window window, Dictionary config, Error *err)
  FUNC_API_SINCE(6)
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return;
  }
  bool new_float = !win->w_floating;
  // reuse old values, if not overridden
  FloatConfig fconfig = new_float ? FLOAT_CONFIG_INIT : win->w_float_config;

  if (!parse_float_config(config, &fconfig, !new_float, false, err)) {
    return;
  }
  if (new_float) {
    if (!win_new_float(win, fconfig, err)) {
      return;
    }
    redraw_later(win, NOT_VALID);
  } else {
    win_config_float(win, fconfig);
    win->w_pos_changed = true;
  }
  if (fconfig.style == kWinStyleMinimal) {
    win_set_minimal_style(win);
    didset_window_options(win);
  }
}

/// Gets window configuration.
///
/// The returned value may be given to |nvim_open_win()|.
///
/// `relative` is empty for normal windows.
///
/// @param      window Window handle, or 0 for current window
/// @param[out] err Error details, if any
/// @return     Map defining the window configuration, see |nvim_open_win()|
Dictionary nvim_win_get_config(Window window, Error *err)
  FUNC_API_SINCE(6)
{
  Dictionary rv = ARRAY_DICT_INIT;

  win_T *wp = find_window_by_handle(window, err);
  if (!wp) {
    return rv;
  }

  FloatConfig *config = &wp->w_float_config;

  PUT(rv, "focusable", BOOLEAN_OBJ(config->focusable));
  PUT(rv, "external", BOOLEAN_OBJ(config->external));

  if (wp->w_floating) {
    PUT(rv, "width", INTEGER_OBJ(config->width));
    PUT(rv, "height", INTEGER_OBJ(config->height));
    if (!config->external) {
      if (config->relative == kFloatRelativeWindow) {
        PUT(rv, "win", INTEGER_OBJ(config->window));
        if (config->bufpos.lnum >= 0) {
          Array pos = ARRAY_DICT_INIT;
          ADD(pos, INTEGER_OBJ(config->bufpos.lnum));
          ADD(pos, INTEGER_OBJ(config->bufpos.col));
          PUT(rv, "bufpos", ARRAY_OBJ(pos));
        }
      }
      PUT(rv, "anchor", STRING_OBJ(cstr_to_string(
          float_anchor_str[config->anchor])));
      PUT(rv, "row", FLOAT_OBJ(config->row));
      PUT(rv, "col", FLOAT_OBJ(config->col));
      PUT(rv, "zindex", INTEGER_OBJ(config->zindex));
    }
    if (config->border) {
      Array border = ARRAY_DICT_INIT;
      for (size_t i = 0; i < 8; i++) {
        Array tuple = ARRAY_DICT_INIT;

        String s = cstrn_to_string(
            (const char *)config->border_chars[i], sizeof(schar_T));

        int hi_id = config->border_hl_ids[i];
        char_u *hi_name = syn_id2name(hi_id);
        if (hi_name[0]) {
          ADD(tuple, STRING_OBJ(s));
          ADD(tuple, STRING_OBJ(cstr_to_string((const char *)hi_name)));
          ADD(border, ARRAY_OBJ(tuple));
        } else {
          ADD(border, STRING_OBJ(s));
        }
      }
      PUT(rv, "border", ARRAY_OBJ(border));
    }
  }

  const char *rel = (wp->w_floating && !config->external
                     ? float_relative_str[config->relative] : "");
  PUT(rv, "relative", STRING_OBJ(cstr_to_string(rel)));

  return rv;
}

/// Closes the window and hide the buffer it contains (like |:hide| with a
/// |window-ID|).
///
/// Like |:hide| the buffer becomes hidden unless another window is editing it,
/// or 'bufhidden' is `unload`, `delete` or `wipe` as opposed to |:close| or
/// |nvim_win_close|, which will close the buffer.
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
  if (tabpage == curtab) {
    win_close(win, false);
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
/// @param fun        Function to call inside the window (currently lua callable
///                   only)
/// @param[out] err   Error details, if any
/// @return           Return value of function. NB: will deepcopy lua values
///                   currently, use upvalues to send lua references in and out.
Object nvim_win_call(Window window, LuaRef fun, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_LUA_ONLY
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return NIL;
  }
  tabpage_T *tabpage = win_find_tabpage(win);

  win_T *save_curwin;
  tabpage_T *save_curtab;

  try_start();
  Object res = OBJECT_INIT;
  if (switch_win_noblock(&save_curwin, &save_curtab, win, tabpage, true) ==
      OK) {
    Array args = ARRAY_DICT_INIT;
    res = nlua_call_ref(fun, NULL, args, true, err);
  }
  restore_win_noblock(save_curwin, save_curtab, true);
  try_end(err);
  return res;
}
