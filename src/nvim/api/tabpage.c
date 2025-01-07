#include <stdbool.h>
#include <stdlib.h>

#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/tabpage.h"
#include "nvim/api/vim.h"
#include "nvim/autocmd.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/window.h"
#include "nvim/globals.h"
#include "nvim/lib/queue_defs.h"
#include "nvim/lua/executor.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/types_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/tabpage.c.generated.h"  // IWYU pragma: keep
#endif

/// Gets the config of a tabpage.
///
/// @param tabpage Tabpage handle, or 0 for current tabpage
/// @param config Configuration options. Reserved for future use.
/// @param[out] err Error details, if any.
/// @return Tabpage configuration object. Keys:
///   - layout: Window layout tree.
///
///     For a leaf window, it returns: `["leaf", {winid}]`
///     For horizontally split windows, which form a column, it
///     returns: `["col", [{nested list of windows}]]`
///     For vertically split windows, which form a row, it returns: `["row", [{nested list of windows}]]`
///     Example:
///     ```vim
///     	" Only one window in the tab page
///     	echo nvim_tabpage_get(0, {}) " ['leaf', 1000]
///     	" Two horizontally split windows
///     	echo nvim_tabpage_get(0, {}) " ['col', [['leaf', 1000], ['leaf', 1001]]]
///     	" The second tab page, with three horizontally split
///     	" windows, with two vertically split windows in the
///     	" middle window
///     	echo nvim_tabpage_get(2, {}) " ['col', [['leaf', 1002], ['row', [['leaf', 1003], ['leaf', 1001]]], ['leaf', 1000]]]
///     ```
Dict(tabpage_config) nvim_tabpage_get(Tabpage tabpage, Dict(tabpage_get) *config, Arena *arena,
                                      Error *err)
  FUNC_API_SINCE(13)
{
  tabpage_T *tab;
  if (tabpage == 0) {
    tab = curtab;
  } else {
    tab = find_tab_by_handle(tabpage, err);
  }

  Dict(tabpage_config) rv = KEYDICT_INIT;

  if (!tab) {
    rv.layout = (Array)ARRAY_DICT_INIT;
    return rv;
  }

  list_T *fr_list = tv_list_alloc(2);

  get_framelayout(tab->tp_topframe, fr_list, true);

  typval_T list_tv = {
    .vval.v_list = fr_list,
    .v_type = VAR_LIST,
  };

  Array layout = vim_to_object(&list_tv, arena, false).data.array;
  tv_clear(&list_tv);

  PUT_KEY(rv, tabpage_config, layout, layout);

  return rv;
}

/// Manages configuration for a tabpage.
///
/// @param tabpage Tabpage handle, or 0 for current tabpage
/// @param config The tabpage's intended configuration.  keys:
///   - layout: The intended layout as a nested list
///
///     The layout param expects a nested list, similar to the result of `nvim_tabpage_get(...).layout`.
///     Each element in the list is either a frame or a window.
///
///     Frames are represented by a list with two elements:
///     - The first element is the type of the frame, either "row" or "col"
///     - The second element is a list of the child frames/windows
///
///     Windows are represented by a list with three elements:
///     - The first element is the type, always "leaf" for windows
///     - The second element is a buffer handle or filename to be opened in the window
///     - The third elemnt is a dictionary containing information about the window
///       - "focused" (Boolean): Whether the window is focused
///
///     The following example creates two vertical splits, and focuses the one on the right:
///
///     ```lua
///         vim.api.nvim_tabpage_set(0, {
///           layout = {
///             "row",
///             {
///                 { "leaf", vim.api.nvim_get_current_buf() },
///                 { "leaf", vim.api.nvim_get_current_buf(), { focused = true } },
///             }
///           }
///         })
///     ```
///
/// @param[out] err Error details, if any.
void nvim_tabpage_set(Tabpage tabpage, Dict(tabpage_config) *config, Arena *arena, Error *err)
  FUNC_API_SINCE(13)
{
  tabpage_T *tab;

  if (tabpage == 0) {
    tab = curtab;
  } else {
    tab = find_tab_by_handle(tabpage, err);
  }

  if (!tab) {
    return;
  }

  if (HAS_KEY(config, tabpage_config, layout)) {
    RedrawingDisabled++;

    FOR_ALL_WINDOWS_IN_TAB(wp, tab) {
      if (wp != tab->tp_curwin) {
        if (tab == curtab) {
          win_close(wp, false, true);
        } else {
          win_close_othertab(wp, false, tab);
        }
      }
    }

    MAXSIZE_TEMP_ARRAY(a, 2);
    ADD(a, TABPAGE_OBJ(tabpage));
    ADD(a, ARRAY_OBJ(config->layout));

    NLUA_EXEC_STATIC("vim._set_layout(...)", a, kRetNilBool, arena, err);

    RedrawingDisabled--;
  }
}

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
