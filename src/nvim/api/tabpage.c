// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/tabpage.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/memory.h"
#include "nvim/window.h"

/// Gets the windows in a tabpage
///
/// @param tabpage  Tabpage
/// @param[out] err Error details, if any
/// @return List of windows in `tabpage`
ArrayOf(Window) nvim_tabpage_list_wins(Tabpage tabpage, Error *err)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab || !valid_tabpage(tab)) {
    return rv;
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, tab) {
    rv.size++;
  }

  rv.items = xmalloc(sizeof(Object) * rv.size);
  size_t i = 0;

  FOR_ALL_WINDOWS_IN_TAB(wp, tab) {
    rv.items[i++] = WINDOW_OBJ(wp->handle);
  }

  return rv;
}

/// Gets a tab-scoped (t:) variable
///
/// @param tabpage  Tabpage handle
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_tabpage_get_var(Tabpage tabpage, String name, Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return (Object) OBJECT_INIT;
  }

  return dict_get_value(tab->tp_vars, name, err);
}

/// Sets a tab-scoped (t:) variable
///
/// @param tabpage  Tabpage handle
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_tabpage_set_var(Tabpage tabpage,
                          String name,
                          Object value,
                          Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return;
  }

  dict_set_var(tab->tp_vars, name, value, false, false, err);
}

/// Removes a tab-scoped (t:) variable
///
/// @param tabpage  Tabpage handle
/// @param name     Variable name
/// @param[out] err Error details, if any
void nvim_tabpage_del_var(Tabpage tabpage, String name, Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return;
  }

  dict_set_var(tab->tp_vars, name, NIL, true, false, err);
}

/// Sets a tab-scoped (t:) variable
///
/// @deprecated
///
/// @param tabpage  Tabpage handle
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
/// @return Old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object tabpage_set_var(Tabpage tabpage, String name, Object value, Error *err)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_var(tab->tp_vars, name, value, false, true, err);
}

/// Removes a tab-scoped (t:) variable
///
/// @deprecated
///
/// @param tabpage  Tabpage handle
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Old value
Object tabpage_del_var(Tabpage tabpage, String name, Error *err)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_var(tab->tp_vars, name, NIL, true, true, err);
}

/// Gets the current window in a tabpage
///
/// @param tabpage  Tabpage handle
/// @param[out] err Error details, if any
/// @return Window handle
Window nvim_tabpage_get_win(Tabpage tabpage, Error *err)
  FUNC_API_SINCE(1)
{
  Window rv = 0;
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab || !valid_tabpage(tab)) {
    return rv;
  }

  if (tab == curtab) {
    return nvim_get_current_win();
  } else {
    FOR_ALL_WINDOWS_IN_TAB(wp, tab) {
      if (wp == tab->tp_curwin) {
        return wp->handle;
      }
    }
    // There should always be a current window for a tabpage
    abort();
  }
}

/// Gets the tabpage number
///
/// @param tabpage  Tabpage handle
/// @param[out] err Error details, if any
/// @return Tabpage number
Integer nvim_tabpage_get_number(Tabpage tabpage, Error *err)
  FUNC_API_SINCE(1)
{
  Integer rv = 0;
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return rv;
  }

  return tabpage_index(tab);
}

/// Checks if a tabpage is valid
///
/// @param tabpage Tabpage handle
/// @return true if the tabpage is valid, false otherwise
Boolean nvim_tabpage_is_valid(Tabpage tabpage)
  FUNC_API_SINCE(1)
{
  Error stub = ERROR_INIT;
  Boolean ret = find_tab_by_handle(tabpage, &stub) != NULL;
  api_clear_error(&stub);
  return ret;
}

