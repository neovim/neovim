// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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

/// Gets the windows in a tabpage
///
/// Example (lua): 'windo new'
/// <pre>lua
///  local windows = vim.api.nvim_tabpage_list_wins(0)
///  for _, win in ipairs(windows) do
///      vim.api.nvim_win_call(win, function()
///          vim.api.nvim_command("new")
///      end)
///  end
/// </pre>
///
/// @param tabpage  Tabpage handle, or 0 for current tabpage
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
/// Example (lua):
/// <pre>lua
///   local tabpage = vim.api.nvim_get_current_tabpage()
///   vim.api.nvim_tabpage_set_var(tabpage, "workspace", "nvim nightly")
///   print(vim.api.nvim_tabpage_get_var(tabpage, "workspace"))
/// </pre>
///
/// @param tabpage  Tabpage handle, or 0 for current tabpage
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_tabpage_get_var(Tabpage tabpage, String name, Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return (Object)OBJECT_INIT;
  }

  return dict_get_value(tab->tp_vars, name, err);
}

/// Sets a tab-scoped (t:) variable
///
/// Example (lua):
/// <pre>lua
///   vim.api.nvim_tabpage_set_var(0, "workspace", "vim nightly")
///   print(vim.api.nvim_tabpage_get_var(tabpage, "workspace"))
/// </pre>
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

  dict_set_var(tab->tp_vars, name, value, false, false, err);
}

/// Removes a tab-scoped (t:) variable
///
/// Example (lua):
/// <pre>lua
///   local tabpage = vim.api.nvim_get_current_tabpage()
///   vim.api.nvim_tabpage_set_var(tabpage, "workspace", "nvim nightly")
///   vim.api.nvim_tabpage_del_var(tabpage, "workspace")
/// </pre>
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

  dict_set_var(tab->tp_vars, name, NIL, true, false, err);
}

/// Gets the current window in a tabpage
///
/// Example (lua):
/// <pre>lua
///   local tabpage = vim.api.nvim_get_current_tabpage()
///   local win = vim.api.nvim_tabpage_get_win(tabpage)
///   local buf = vim.api.nvim_win_get_buf(win)
///   print(vim.api.nvim_buf_get_name(buf))
/// </pre>
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

/// Gets the tabpage number
///
/// Example (lua):
/// <pre>lua
///   vim.api.nvim_command("tabnew")
///   local tabpage = vim.api.nvim_get_current_tabpage()
///   print(vim.api.nvim_tabpage_get_number(tabpage))
/// </pre>
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
/// Example (lua):
/// <pre>lua
///   vim.api.nvim_command("tabnew")
///   local tabpage = vim.api.nvim_get_current_tabpage()
///   vim.api.nvim_command("tabclose!")
///   print(vim.api.nvim_tabpage_is_valid(tabpage))
/// </pre>
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
