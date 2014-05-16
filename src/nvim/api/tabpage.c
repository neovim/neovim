#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/tabpage.h"
#include "nvim/api/vim.h"
#include "nvim/api/defs.h"
#include "nvim/api/helpers.h"

Integer tabpage_get_window_count(Tabpage tabpage, Error *err)
{
  Integer rv = 0;
  tabpage_T *tab = find_tab(tabpage, err);

  if (!tab) {
    return rv;
  }

  tabpage_T *tp;
  win_T *wp;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (tp != tab) {
      break;
    }
    rv++;
  }

  return rv;
}

Object tabpage_get_var(Tabpage tabpage, String name, Error *err)
{
  Object rv;
  tabpage_T *tab = find_tab(tabpage, err);

  if (!tab) {
    return rv;
  }

  return dict_get_value(tab->tp_vars, name, err);
}

Object tabpage_set_var(Tabpage tabpage, String name, Object value, Error *err)
{
  Object rv;
  tabpage_T *tab = find_tab(tabpage, err);

  if (!tab) {
    return rv;
  }

  return dict_set_value(tab->tp_vars, name, value, err);
}

Window tabpage_get_window(Tabpage tabpage, Error *err)
{
  Window rv = 0;
  tabpage_T *tab = find_tab(tabpage, err);

  if (!tab) {
    return rv;
  }

  if (tab == curtab) {
    return vim_get_current_window();
  } else {
    tabpage_T *tp;
    win_T *wp;
    rv = 1;

    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (tp == tab && wp == tab->tp_curwin) {
        return rv;
      }
      rv++;
    }
    // There should always be a current window for a tabpage
    abort();
  }
}

Boolean tabpage_is_valid(Tabpage tabpage)
{
  Error stub = {.set = false};
  return find_tab(tabpage, &stub) != NULL;
}

