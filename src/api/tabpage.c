#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "api/tabpage.h"
#include "api/defs.h"
#include "api/helpers.h"

int64_t tabpage_get_window_count(Tabpage tabpage, Error *err)
{
  set_api_error("Not implemented", err);
  return 0;
}

Object tabpage_get_var(Tabpage tabpage, String name, Error *err)
{
  Object rv;
  tabpage_T *tab = find_tab(tabpage, err);

  if (!tab) {
    return rv;
  }

  return dict_get_value(tab->tp_vars, name, false, err);
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

Window tabpage_get_buffer(Tabpage tabpage, Error *err)
{
  abort();
}

bool tabpage_is_valid(Tabpage tabpage)
{
  abort();
}

