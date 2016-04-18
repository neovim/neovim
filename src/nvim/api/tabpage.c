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
/// @param tabpage The tabpage
/// @param[out] err Details of an error that may have occurred
/// @return The windows in `tabpage`
ArrayOf(Window) tabpage_get_windows(Tabpage tabpage, Error *err)
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
/// @param tabpage The tab page handle
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object tabpage_get_var(Tabpage tabpage, String name, Error *err)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return (Object) OBJECT_INIT;
  }

  return dict_get_value(tab->tp_vars, name, err);
}

/// Sets a tab-scoped (t:) variable
///
/// @param tabpage handle
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return The old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object tabpage_set_var(Tabpage tabpage, String name, Object value, Error *err)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_value(tab->tp_vars, name, value, false, err);
}

/// Removes a tab-scoped (t:) variable
///
/// @param tabpage handle
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object tabpage_del_var(Tabpage tabpage, String name, Error *err)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_value(tab->tp_vars, name, NIL, true, err);
}

/// Gets the current window in a tab page
///
/// @param tabpage The tab page handle
/// @param[out] err Details of an error that may have occurred
/// @return The Window handle
Window tabpage_get_window(Tabpage tabpage, Error *err)
{
  Window rv = 0;
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab || !valid_tabpage(tab)) {
    return rv;
  }

  if (tab == curtab) {
    return vim_get_current_window();
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

/// Checks if a tab page is valid
///
/// @param tabpage The tab page handle
/// @return true if the tab page is valid, false otherwise
Boolean tabpage_is_valid(Tabpage tabpage)
{
  Error stub = ERROR_INIT;
  return find_tab_by_handle(tabpage, &stub) != NULL;
}

