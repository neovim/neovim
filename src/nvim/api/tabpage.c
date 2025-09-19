#include <stdbool.h>
#include <stdlib.h>

#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/tabpage.h"
#include "nvim/api/vim.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/errors.h"
#include "nvim/globals.h"
#include "nvim/memory_defs.h"
#include "nvim/types_defs.h"
#include "nvim/window.h"

#include "api/tabpage.c.generated.h"  // IWYU pragma: keep

/// Gets the windows in a tabpage
///
/// @param tabpage  |tab-ID|, or 0 for current tabpage
/// @param[out] err Error details, if any
/// @return List of windows in `tabpage`
ArrayOf(Window) nvim_tabpage_list_wins(Tabpage tabpage, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab || !valid_tabpage(tab)) {
    return rv;
  }

  size_t n = 0;
  FOR_ALL_WINDOWS_IN_TAB(wp, tab) {
    n++;
  }

  rv = arena_array(arena, n);

  FOR_ALL_WINDOWS_IN_TAB(wp, tab) {
    ADD_C(rv, WINDOW_OBJ(wp->handle));
  }

  return rv;
}

/// Gets a tab-scoped (t:) variable
///
/// @param tabpage  |tab-ID|, or 0 for current tabpage
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_tabpage_get_var(Tabpage tabpage, String name, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return (Object)OBJECT_INIT;
  }

  return dict_get_value(tab->tp_vars, name, arena, err);
}

/// Sets a tab-scoped (t:) variable
///
/// @param tabpage  |tab-ID|, or 0 for current tabpage
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_tabpage_set_var(Tabpage tabpage, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return;
  }

  dict_set_var(tab->tp_vars, name, value, false, false, NULL, err);
}

/// Removes a tab-scoped (t:) variable
///
/// @param tabpage  |tab-ID|, or 0 for current tabpage
/// @param name     Variable name
/// @param[out] err Error details, if any
void nvim_tabpage_del_var(Tabpage tabpage, String name, Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return;
  }

  dict_set_var(tab->tp_vars, name, NIL, true, false, NULL, err);
}

/// Gets the current window in a tabpage
///
/// @param tabpage  |tab-ID|, or 0 for current tabpage
/// @param[out] err Error details, if any
/// @return |window-ID|
Window nvim_tabpage_get_win(Tabpage tabpage, Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab || !valid_tabpage(tab)) {
    return 0;
  }

  if (tab == curtab) {
    return nvim_get_current_win();
  }
  FOR_ALL_WINDOWS_IN_TAB(wp, tab) {
    if (wp == tab->tp_curwin) {
      return wp->handle;
    }
  }
  // There should always be a current window for a tabpage
  abort();
}

/// Sets the current window in a tabpage
///
/// @param tabpage  |tab-ID|, or 0 for current tabpage
/// @param win |window-ID|, must already belong to {tabpage}
/// @param[out] err Error details, if any
void nvim_tabpage_set_win(Tabpage tabpage, Window win, Error *err)
  FUNC_API_SINCE(12)
{
  tabpage_T *tp = find_tab_by_handle(tabpage, err);
  if (!tp) {
    return;
  }

  win_T *wp = find_window_by_handle(win, err);
  if (!wp) {
    return;
  }

  if (!tabpage_win_valid(tp, wp)) {
    api_set_error(err, kErrorTypeException, "Window does not belong to tabpage %d", tp->handle);
    return;
  }

  if (tp == curtab) {
    TRY_WRAP(err, {
      win_goto(wp);
    });
  } else if (tp->tp_curwin != wp) {
    tp->tp_prevwin = tp->tp_curwin;
    tp->tp_curwin = wp;
  }
}

/// Gets the tabpage number
///
/// @param tabpage  |tab-ID|, or 0 for current tabpage
/// @param[out] err Error details, if any
/// @return Tabpage number
Integer nvim_tabpage_get_number(Tabpage tabpage, Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return 0;
  }

  return tabpage_index(tab);
}

/// Checks if a tabpage is valid
///
/// @param tabpage  |tab-ID|, or 0 for current tabpage
/// @return true if the tabpage is valid, false otherwise
Boolean nvim_tabpage_is_valid(Tabpage tabpage)
  FUNC_API_SINCE(1)
{
  Error stub = ERROR_INIT;
  Boolean ret = find_tab_by_handle(tabpage, &stub) != NULL;
  api_clear_error(&stub);
  return ret;
}

/// Opens a new tabpage
///
/// @param buffer Buffer to open in the first window of the new tabpage.
///               Use 0 for current buffer.
/// @param config Configuration for the new tabpage. Keys:
///   - enter: Whether to enter the new tabpage (default: true)
///   - after: Position to insert tabpage (default: 0).
///            0 = after current, 1 = first, N = before Nth.
/// @param[out] err Error details, if any
/// @return Tabpage handle of the created tabpage
Tabpage nvim_open_tabpage(Buffer buffer, Dict(tabpage_config) *config, Error *err)
  FUNC_API_SINCE(14)
{
#define HAS_KEY_X(d, key) HAS_KEY(d, tabpage_config, key)

  // Validate and get the buffer
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (buf == NULL) {
    return 0;
  }

  if (buf == cmdwin_buf) {
    api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
    return 0;
  }

  bool enter = true;  // Default to entering the new tabpage
  if (HAS_KEY_X(config, enter)) {
    enter = config->enter;
  }

  int after = 0;  // Default to after current tabpage
  if (HAS_KEY_X(config, after)) {
    after = (int)config->after;

    // Validate the after position
    if (after < 0) {
      api_set_error(err, kErrorTypeValidation, "Invalid 'after' position: %d", after);
      return 0;
    }

    // Note: No validation for after > number of tabs since the underlying
    // function handles this by appending at the end
  }

  tabpage_T *newtp;

  if (enter) {
    // Use the existing function if we want to enter the tabpage
    if (win_new_tabpage(after, NULL) == OK) {
      newtp = curtab;
    } else {
      api_set_error(err, kErrorTypeException, "Failed to create new tabpage");
      return 0;
    }
  } else {
    // Create tabpage without entering it
    newtp = win_new_tabpage_noenter(after, err);
    if (newtp == NULL) {
      api_set_error(err, kErrorTypeException, "Failed to create new tabpage");
      return 0;
    }
  }

  // Set the buffer in the new window if different from current
  if (newtp->tp_curwin->w_buffer != buf) {
    TRY_WRAP(err, {
      win_set_buf(newtp->tp_curwin, buf, err);
    });
    if (ERROR_SET(err)) {
      return 0;
    }
  }

  // Ensure tabpage wasn't immediately freed
  if (find_tab_by_handle(newtp->handle, err) == NULL) {
    api_clear_error(err);
    api_set_error(err, kErrorTypeException, "Tabpage was closed immediately");
    return 0;
  }
  if (!buf_valid(buf)) {
    api_set_error(err, kErrorTypeException, "Buffer was deleted by autocmd");
    return 0;
  }

  return newtp->handle;
#undef HAS_KEY_X
}
