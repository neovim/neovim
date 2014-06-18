#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/tabpage.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/memory.h"

/// Gets the number of windows in a tabpage
///
/// @param tabpage The tabpage
/// @param[out] err Details of an error that may have occurred
/// @return The number of windows in `tabpage`
WindowArray tabpage_get_windows(Tabpage tabpage, Error *err)
{
  WindowArray rv = ARRAY_DICT_INIT;
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return rv;
  }

  tabpage_T *tp;
  win_T *wp;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (tp != tab) {
      break;
    }
    rv.size++;
  }

  rv.items = xmalloc(sizeof(Window) * rv.size);
  size_t i = 0;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (tp != tab) {
      break;
    }
    rv.items[i++] = wp->handle;
  }

  return rv;
}

/// Gets a tabpage variable
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

/// Sets a tabpage variable. Passing 'nil' as value deletes the variable.
///
/// @param tabpage handle
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return The tab page handle
Object tabpage_set_var(Tabpage tabpage, String name, Object value, Error *err)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return (Object) OBJECT_INIT;
  }

  return dict_set_value(tab->tp_vars, name, value, err);
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

  if (!tab) {
    return rv;
  }

  if (tab == curtab) {
    return vim_get_current_window();
  } else {
    tabpage_T *tp;
    win_T *wp;

    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (tp == tab && wp == tab->tp_curwin) {
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
  Error stub = {.set = false};
  return find_tab_by_handle(tabpage, &stub) != NULL;
}

