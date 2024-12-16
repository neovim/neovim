#include <stdbool.h>
#include <stdlib.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/tabpage.h"
#include "nvim/api/vim.h"
#include "nvim/buffer_defs.h"
#include "nvim/globals.h"
#include "nvim/memory.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/tabpage.c.generated.h"
#endif

/// Gets the windows in a tabpage
///
/// @param tabpage  Tabpage handle, or 0 for current tabpage
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
/// @param tabpage  Tabpage handle, or 0 for current tabpage
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
/// @param tabpage  Tabpage handle, or 0 for current tabpage
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
/// @param tabpage  Tabpage handle, or 0 for current tabpage
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
/// @param tabpage  Tabpage handle, or 0 for current tabpage
/// @param[out] err Error details, if any
/// @return Window handle
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
/// @param tabpage  Tabpage handle, or 0 for current tabpage
/// @param win Window handle, must already belong to {tabpage}
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
/// @param tabpage  Tabpage handle, or 0 for current tabpage
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
/// @param tabpage  Tabpage handle, or 0 for current tabpage
/// @return true if the tabpage is valid, false otherwise
Boolean nvim_tabpage_is_valid(Tabpage tabpage)
  FUNC_API_SINCE(1)
{
  Error stub = ERROR_INIT;
  Boolean ret = find_tab_by_handle(tabpage, &stub) != NULL;
  api_clear_error(&stub);
  return ret;
}
