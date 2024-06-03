// eval/window.c: Window related builtin functions

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/cursor.h"
#include "nvim/errors.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/window.h"
#include "nvim/ex_getln.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/macros_defs.h"
#include "nvim/mark_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/window.c.generated.h"
#endif

static const char *e_invalwindow = N_("E957: Invalid window number");
static const char e_cannot_resize_window_in_another_tab_page[]
  = N_("E1308: Cannot resize a window in another tab page");

static int win_getid(typval_T *argvars)
{
  if (argvars[0].v_type == VAR_UNKNOWN) {
    return curwin->handle;
  }
  int winnr = (int)tv_get_number(&argvars[0]);
  win_T *wp;
  if (winnr <= 0) {
    return 0;
  }

  if (argvars[1].v_type == VAR_UNKNOWN) {
    wp = firstwin;
  } else {
    tabpage_T *tp = NULL;
    int tabnr = (int)tv_get_number(&argvars[1]);
    FOR_ALL_TABS(tp2) {
      if (--tabnr == 0) {
        tp = tp2;
        break;
      }
    }
    if (tp == NULL) {
      return -1;
    }
    if (tp == curtab) {
      wp = firstwin;
    } else {
      wp = tp->tp_firstwin;
    }
  }
  for (; wp != NULL; wp = wp->w_next) {
    if (--winnr == 0) {
      return wp->handle;
    }
  }
  return 0;
}

static void win_id2tabwin(typval_T *const argvars, typval_T *const rettv)
{
  handle_T id = (handle_T)tv_get_number(&argvars[0]);

  int winnr = 1;
  int tabnr = 1;
  win_get_tabwin(id, &tabnr, &winnr);

  list_T *const list = tv_list_alloc_ret(rettv, 2);
  tv_list_append_number(list, tabnr);
  tv_list_append_number(list, winnr);
}

win_T *win_id2wp(int id)
{
  return win_id2wp_tp(id, NULL);
}

/// Return the window and tab pointer of window "id".
/// Returns NULL when not found.
win_T *win_id2wp_tp(int id, tabpage_T **tpp)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->handle == id) {
      if (tpp != NULL) {
        *tpp = tp;
      }
      return wp;
    }
  }

  return NULL;
}

static int win_id2win(typval_T *argvars)
{
  int nr = 1;
  int id = (int)tv_get_number(&argvars[0]);

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->handle == id) {
      return nr;
    }
    nr++;
  }
  return 0;
}

void win_findbuf(typval_T *argvars, list_T *list)
{
  int bufnr = (int)tv_get_number(&argvars[0]);

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer->b_fnum == bufnr) {
      tv_list_append_number(list, wp->handle);
    }
  }
}

/// Find window specified by "vp" in tabpage "tp".
///
/// @param tp  NULL for current tab page
/// @return  current window if "vp" is number zero.
///          NULL if not found.
win_T *find_win_by_nr(typval_T *vp, tabpage_T *tp)
{
  int nr = (int)tv_get_number_chk(vp, NULL);

  if (nr < 0) {
    return NULL;
  }

  if (nr == 0) {
    return curwin;
  }

  // This method accepts NULL as an alias for curtab.
  if (tp == NULL) {
    tp = curtab;
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
    if (nr >= LOWEST_WIN_ID) {
      if (wp->handle == nr) {
        return wp;
      }
    } else if (--nr <= 0) {
      return wp;
    }
  }
  return NULL;
}

/// Find a window: When using a Window ID in any tab page, when using a number
/// in the current tab page.
win_T *find_win_by_nr_or_id(typval_T *vp)
{
  int nr = (int)tv_get_number_chk(vp, NULL);

  if (nr >= LOWEST_WIN_ID) {
    return win_id2wp((int)tv_get_number(vp));
  }

  return find_win_by_nr(vp, NULL);
}

/// Find window specified by "wvp" in tabpage "tvp".
win_T *find_tabwin(typval_T *wvp, typval_T *tvp)
{
  win_T *wp = NULL;
  tabpage_T *tp = NULL;

  if (wvp->v_type != VAR_UNKNOWN) {
    if (tvp->v_type != VAR_UNKNOWN) {
      int n = (int)tv_get_number(tvp);
      if (n >= 0) {
        tp = find_tabpage(n);
      }
    } else {
      tp = curtab;
    }

    if (tp != NULL) {
      wp = find_win_by_nr(wvp, tp);
    }
  } else {
    wp = curwin;
  }

  return wp;
}

/// Get the layout of the given tab page for winlayout().
static void get_framelayout(const frame_T *fr, list_T *l, bool outer)
{
  if (fr == NULL) {
    return;
  }

  list_T *fr_list;
  if (outer) {
    // outermost call from f_winlayout()
    fr_list = l;
  } else {
    fr_list = tv_list_alloc(2);
    tv_list_append_list(l, fr_list);
  }

  if (fr->fr_layout == FR_LEAF) {
    if (fr->fr_win != NULL) {
      tv_list_append_string(fr_list, "leaf", -1);
      tv_list_append_number(fr_list, fr->fr_win->handle);
    }
  } else {
    tv_list_append_string(fr_list, fr->fr_layout == FR_ROW ? "row" : "col", -1);

    list_T *const win_list = tv_list_alloc(kListLenUnknown);
    tv_list_append_list(fr_list, win_list);
    const frame_T *child = fr->fr_child;
    while (child != NULL) {
      get_framelayout(child, win_list, false);
      child = child->fr_next;
    }
  }
}

/// Common code for tabpagewinnr() and winnr().
static int get_winnr(tabpage_T *tp, typval_T *argvar)
{
  int nr = 1;

  win_T *twin = (tp == curtab) ? curwin : tp->tp_curwin;
  if (argvar->v_type != VAR_UNKNOWN) {
    bool invalid_arg = false;
    const char *const arg = tv_get_string_chk(argvar);
    if (arg == NULL) {
      nr = 0;  // Type error; errmsg already given.
    } else if (strcmp(arg, "$") == 0) {
      twin = (tp == curtab) ? lastwin : tp->tp_lastwin;
    } else if (strcmp(arg, "#") == 0) {
      twin = (tp == curtab) ? prevwin : tp->tp_prevwin;
      if (twin == NULL) {
        nr = 0;
      }
    } else {
      // Extract the window count (if specified). e.g. winnr('3j')
      char *endp;
      int count = (int)strtol(arg, &endp, 10);
      if (count <= 0) {
        // if count is not specified, default to 1
        count = 1;
      }
      if (endp != NULL && *endp != NUL) {
        if (strequal(endp, "j")) {
          twin = win_vert_neighbor(tp, twin, false, count);
        } else if (strequal(endp, "k")) {
          twin = win_vert_neighbor(tp, twin, true, count);
        } else if (strequal(endp, "h")) {
          twin = win_horz_neighbor(tp, twin, true, count);
        } else if (strequal(endp, "l")) {
          twin = win_horz_neighbor(tp, twin, false, count);
        } else {
          invalid_arg = true;
        }
      } else {
        invalid_arg = true;
      }
    }

    if (invalid_arg) {
      semsg(_(e_invexpr2), arg);
      nr = 0;
    }
  }

  if (nr <= 0) {
    return 0;
  }

  for (win_T *wp = (tp == curtab) ? firstwin : tp->tp_firstwin;
       wp != twin; wp = wp->w_next) {
    if (wp == NULL) {
      // didn't find it in this tabpage
      nr = 0;
      break;
    }
    nr++;
  }
  return nr;
}

/// @return  information about a window as a dictionary.
static dict_T *get_win_info(win_T *wp, int16_t tpnr, int16_t winnr)
{
  dict_T *const dict = tv_dict_alloc();

  // make sure w_botline is valid
  validate_botline(wp);

  tv_dict_add_nr(dict, S_LEN("tabnr"), tpnr);
  tv_dict_add_nr(dict, S_LEN("winnr"), winnr);
  tv_dict_add_nr(dict, S_LEN("winid"), wp->handle);
  tv_dict_add_nr(dict, S_LEN("height"), wp->w_height_inner);
  tv_dict_add_nr(dict, S_LEN("winrow"), wp->w_winrow + 1);
  tv_dict_add_nr(dict, S_LEN("topline"), wp->w_topline);
  tv_dict_add_nr(dict, S_LEN("botline"), wp->w_botline - 1);
  tv_dict_add_nr(dict, S_LEN("winbar"), wp->w_winbar_height);
  tv_dict_add_nr(dict, S_LEN("width"), wp->w_width_inner);
  tv_dict_add_nr(dict, S_LEN("bufnr"), wp->w_buffer->b_fnum);
  tv_dict_add_nr(dict, S_LEN("wincol"), wp->w_wincol + 1);
  tv_dict_add_nr(dict, S_LEN("textoff"), win_col_off(wp));
  tv_dict_add_nr(dict, S_LEN("terminal"), bt_terminal(wp->w_buffer));
  tv_dict_add_nr(dict, S_LEN("quickfix"), bt_quickfix(wp->w_buffer));
  tv_dict_add_nr(dict, S_LEN("loclist"),
                 (bt_quickfix(wp->w_buffer) && wp->w_llist_ref != NULL));

  // Add a reference to window variables
  tv_dict_add_dict(dict, S_LEN("variables"), wp->w_vars);

  return dict;
}

/// @return  information (variables, options, etc.) about a tab page
///          as a dictionary.
static dict_T *get_tabpage_info(tabpage_T *tp, int tp_idx)
{
  dict_T *const dict = tv_dict_alloc();

  tv_dict_add_nr(dict, S_LEN("tabnr"), tp_idx);

  list_T *const l = tv_list_alloc(kListLenMayKnow);
  FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
    tv_list_append_number(l, (varnumber_T)wp->handle);
  }
  tv_dict_add_list(dict, S_LEN("windows"), l);

  // Make a reference to tabpage variables
  tv_dict_add_dict(dict, S_LEN("variables"), tp->tp_vars);

  return dict;
}

/// "gettabinfo()" function
void f_gettabinfo(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tabpage_T *tparg = NULL;

  tv_list_alloc_ret(rettv, (argvars[0].v_type == VAR_UNKNOWN
                            ? 1
                            : kListLenMayKnow));

  if (argvars[0].v_type != VAR_UNKNOWN) {
    // Information about one tab page
    tparg = find_tabpage((int)tv_get_number_chk(&argvars[0], NULL));
    if (tparg == NULL) {
      return;
    }
  }

  // Get information about a specific tab page or all tab pages
  int tpnr = 0;
  FOR_ALL_TABS(tp) {
    tpnr++;
    if (tparg != NULL && tp != tparg) {
      continue;
    }
    dict_T *const d = get_tabpage_info(tp, tpnr);
    tv_list_append_dict(rettv->vval.v_list, d);
    if (tparg != NULL) {
      return;
    }
  }
}

/// "getwininfo()" function
void f_getwininfo(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  win_T *wparg = NULL;

  tv_list_alloc_ret(rettv, kListLenMayKnow);

  if (argvars[0].v_type != VAR_UNKNOWN) {
    wparg = win_id2wp((int)tv_get_number(&argvars[0]));
    if (wparg == NULL) {
      return;
    }
  }

  // Collect information about either all the windows across all the tab
  // pages or one particular window.
  int16_t tabnr = 0;
  FOR_ALL_TABS(tp) {
    tabnr++;
    int16_t winnr = 0;
    FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
      winnr++;
      if (wparg != NULL && wp != wparg) {
        continue;
      }
      dict_T *const d = get_win_info(wp, tabnr, winnr);
      tv_list_append_dict(rettv->vval.v_list, d);
      if (wparg != NULL) {
        // found information about a specific window
        return;
      }
    }
  }
}

/// "getwinpos({timeout})" function
void f_getwinpos(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, 2);
  tv_list_append_number(rettv->vval.v_list, -1);
  tv_list_append_number(rettv->vval.v_list, -1);
}

/// "getwinposx()" function
void f_getwinposx(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;
}

/// "getwinposy()" function
void f_getwinposy(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;
}

/// "tabpagenr()" function
void f_tabpagenr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int nr = 1;

  if (argvars[0].v_type != VAR_UNKNOWN) {
    const char *const arg = tv_get_string_chk(&argvars[0]);
    nr = 0;
    if (arg != NULL) {
      if (strcmp(arg, "$") == 0) {
        nr = tabpage_index(NULL) - 1;
      } else if (strcmp(arg, "#") == 0) {
        nr = valid_tabpage(lastused_tabpage) ? tabpage_index(lastused_tabpage) : 0;
      } else {
        semsg(_(e_invexpr2), arg);
      }
    }
  } else {
    nr = tabpage_index(curtab);
  }
  rettv->vval.v_number = nr;
}

/// "tabpagewinnr()" function
void f_tabpagewinnr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int nr = 1;
  tabpage_T *const tp = find_tabpage((int)tv_get_number(&argvars[0]));
  if (tp == NULL) {
    nr = 0;
  } else {
    nr = get_winnr(tp, &argvars[1]);
  }
  rettv->vval.v_number = nr;
}

/// Switch to a window for executing user code.
/// Caller must call win_execute_after() later regardless of return value.
///
/// @return  whether switching the window succeeded.
bool win_execute_before(win_execute_T *args, win_T *wp, tabpage_T *tp)
{
  args->wp = wp;
  args->curpos = wp->w_cursor;
  args->cwd_status = FAIL;
  args->apply_acd = false;

  // Getting and setting directory can be slow on some systems, only do
  // this when the current or target window/tab have a local directory or
  // 'acd' is set.
  if (curwin != wp
      && (curwin->w_localdir != NULL || wp->w_localdir != NULL
          || (curtab != tp && (curtab->tp_localdir != NULL || tp->tp_localdir != NULL))
          || p_acd)) {
    args->cwd_status = os_dirname(args->cwd, MAXPATHL);
  }

  // If 'acd' is set, check we are using that directory.  If yes, then
  // apply 'acd' afterwards, otherwise restore the current directory.
  if (args->cwd_status == OK && p_acd) {
    do_autochdir();
    char autocwd[MAXPATHL];
    if (os_dirname(autocwd, MAXPATHL) == OK) {
      args->apply_acd = strcmp(args->cwd, autocwd) == 0;
    }
  }

  if (switch_win_noblock(&args->switchwin, wp, tp, true) == OK) {
    check_cursor(curwin);
    return true;
  }
  return false;
}

/// Restore the previous window after executing user code.
void win_execute_after(win_execute_T *args)
{
  restore_win_noblock(&args->switchwin, true);

  if (args->apply_acd) {
    do_autochdir();
  } else if (args->cwd_status == OK) {
    os_chdir(args->cwd);
  }

  // Update the status line if the cursor moved.
  if (win_valid(args->wp) && !equalpos(args->curpos, args->wp->w_cursor)) {
    args->wp->w_redr_status = true;
  }

  // In case the command moved the cursor or changed the Visual area,
  // check it is valid.
  check_cursor(curwin);
  if (VIsual_active) {
    check_pos(curbuf, &VIsual);
  }
}

/// "win_execute(win_id, command)" function
void f_win_execute(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  // Return an empty string if something fails.
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  int id = (int)tv_get_number(argvars);
  tabpage_T *tp;
  win_T *wp = win_id2wp_tp(id, &tp);
  if (wp == NULL || tp == NULL) {
    return;
  }

  win_execute_T win_execute_args;
  if (win_execute_before(&win_execute_args, wp, tp)) {
    execute_common(argvars, rettv, 1);
  }
  win_execute_after(&win_execute_args);
}

/// "win_findbuf()" function
void f_win_findbuf(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, kListLenMayKnow);
  win_findbuf(argvars, rettv->vval.v_list);
}

/// "win_getid()" function
void f_win_getid(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = win_getid(argvars);
}

/// "win_gotoid()" function
void f_win_gotoid(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int id = (int)tv_get_number(&argvars[0]);
  if (curwin->handle == id) {
    // Nothing to do.
    rettv->vval.v_number = 1;
    return;
  }

  if (text_or_buf_locked()) {
    return;
  }
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->handle == id) {
      goto_tabpage_win(tp, wp);
      rettv->vval.v_number = 1;
      return;
    }
  }
}

/// "win_id2tabwin()" function
void f_win_id2tabwin(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  win_id2tabwin(argvars, rettv);
}

/// "win_id2win()" function
void f_win_id2win(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = win_id2win(argvars);
}

/// "win_move_separator()" function
void f_win_move_separator(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = false;

  win_T *wp = find_win_by_nr_or_id(&argvars[0]);
  if (wp == NULL || wp->w_floating) {
    return;
  }
  if (!win_valid(wp)) {
    emsg(_(e_cannot_resize_window_in_another_tab_page));
    return;
  }

  int offset = (int)tv_get_number(&argvars[1]);
  win_drag_vsep_line(wp, offset);
  rettv->vval.v_number = true;
}

/// "win_move_statusline()" function
void f_win_move_statusline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  win_T *wp;
  int offset;

  rettv->vval.v_number = false;

  wp = find_win_by_nr_or_id(&argvars[0]);
  if (wp == NULL || wp->w_floating) {
    return;
  }
  if (!win_valid(wp)) {
    emsg(_(e_cannot_resize_window_in_another_tab_page));
    return;
  }

  offset = (int)tv_get_number(&argvars[1]);
  win_drag_status_line(wp, offset);
  rettv->vval.v_number = true;
}

/// "win_screenpos()" function
void f_win_screenpos(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, 2);
  const win_T *const wp = find_win_by_nr_or_id(&argvars[0]);
  tv_list_append_number(rettv->vval.v_list, wp == NULL ? 0 : wp->w_winrow + 1);
  tv_list_append_number(rettv->vval.v_list, wp == NULL ? 0 : wp->w_wincol + 1);
}

/// "win_splitmove()" function
void f_win_splitmove(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  win_T *wp = find_win_by_nr_or_id(&argvars[0]);
  win_T *targetwin = find_win_by_nr_or_id(&argvars[1]);
  win_T *oldwin = curwin;

  rettv->vval.v_number = -1;

  if (wp == NULL || targetwin == NULL || wp == targetwin
      || !win_valid(wp) || !win_valid(targetwin)
      || targetwin->w_floating) {
    emsg(_(e_invalwindow));
    return;
  }

  int flags = 0;
  int size = 0;

  if (argvars[2].v_type != VAR_UNKNOWN) {
    dict_T *d;
    dictitem_T *di;

    if (tv_check_for_nonnull_dict_arg(argvars, 2) == FAIL) {
      return;
    }

    d = argvars[2].vval.v_dict;
    if (tv_dict_get_number(d, "vertical")) {
      flags |= WSP_VERT;
    }
    if ((di = tv_dict_find(d, "rightbelow", -1)) != NULL) {
      flags |= tv_get_number(&di->di_tv) ? WSP_BELOW : WSP_ABOVE;
    }
    size = (int)tv_dict_get_number(d, "size");
  }

  // Check if we're allowed to continue before we bother switching windows.
  if (is_aucmd_win(wp) || text_or_buf_locked() || check_split_disallowed(wp) == FAIL) {
    return;
  }

  if (curwin != targetwin) {
    win_goto(targetwin);
  }

  // Autocommands may have sent us elsewhere or closed "wp" or "oldwin".
  if (curwin == targetwin && win_valid(wp)) {
    if (win_splitmove(wp, size, flags) == OK) {
      rettv->vval.v_number = 0;
    }
  } else {
    emsg(_(e_auabort));
  }

  if (oldwin != curwin && win_valid(oldwin)) {
    win_goto(oldwin);
  }
}

/// "win_gettype(nr)" function
void f_win_gettype(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  win_T *wp = curwin;

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;
  if (argvars[0].v_type != VAR_UNKNOWN) {
    wp = find_win_by_nr_or_id(&argvars[0]);
    if (wp == NULL) {
      rettv->vval.v_string = xstrdup("unknown");
      return;
    }
  }
  if (is_aucmd_win(wp)) {
    rettv->vval.v_string = xstrdup("autocmd");
  } else if (wp->w_p_pvw) {
    rettv->vval.v_string = xstrdup("preview");
  } else if (wp->w_floating) {
    rettv->vval.v_string = xstrdup("popup");
  } else if (wp == cmdwin_win) {
    rettv->vval.v_string = xstrdup("command");
  } else if (bt_quickfix(wp->w_buffer)) {
    rettv->vval.v_string = xstrdup((wp->w_llist_ref != NULL ? "loclist" : "quickfix"));
  }
}

/// "getcmdwintype()" function
void f_getcmdwintype(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;
  rettv->vval.v_string = xmallocz(1);
  rettv->vval.v_string[0] = (char)cmdwin_type;
}

/// "winbufnr(nr)" function
void f_winbufnr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  win_T *wp = find_win_by_nr_or_id(&argvars[0]);
  if (wp == NULL) {
    rettv->vval.v_number = -1;
  } else {
    rettv->vval.v_number = wp->w_buffer->b_fnum;
  }
}

/// "wincol()" function
void f_wincol(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  validate_cursor(curwin);
  rettv->vval.v_number = curwin->w_wcol + 1;
}

/// "winheight(nr)" function
void f_winheight(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  win_T *wp = find_win_by_nr_or_id(&argvars[0]);
  if (wp == NULL) {
    rettv->vval.v_number = -1;
  } else {
    rettv->vval.v_number = wp->w_height_inner;
  }
}

/// "winlayout()" function
void f_winlayout(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tabpage_T *tp;

  tv_list_alloc_ret(rettv, 2);

  if (argvars[0].v_type == VAR_UNKNOWN) {
    tp = curtab;
  } else {
    tp = find_tabpage((int)tv_get_number(&argvars[0]));
    if (tp == NULL) {
      return;
    }
  }

  get_framelayout(tp->tp_topframe, rettv->vval.v_list, true);
}

/// "winline()" function
void f_winline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  validate_cursor(curwin);
  rettv->vval.v_number = curwin->w_wrow + 1;
}

/// "winnr()" function
void f_winnr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = get_winnr(curtab, &argvars[0]);
}

/// "winrestcmd()" function
void f_winrestcmd(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char buf[50];

  garray_T ga;
  ga_init(&ga, (int)sizeof(char), 70);

  // Do this twice to handle some window layouts properly.
  for (int i = 0; i < 2; i++) {
    int winnr = 1;
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      snprintf(buf, sizeof(buf), "%dresize %d|", winnr,
               wp->w_height);
      ga_concat(&ga, buf);
      snprintf(buf, sizeof(buf), "vert %dresize %d|", winnr,
               wp->w_width);
      ga_concat(&ga, buf);
      winnr++;
    }
  }
  ga_append(&ga, NUL);

  rettv->vval.v_string = ga.ga_data;
  rettv->v_type = VAR_STRING;
}

/// "winrestview()" function
void f_winrestview(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (tv_check_for_nonnull_dict_arg(argvars, 0) == FAIL) {
    return;
  }

  dict_T *dict = argvars[0].vval.v_dict;
  dictitem_T *di;
  if ((di = tv_dict_find(dict, S_LEN("lnum"))) != NULL) {
    curwin->w_cursor.lnum = (linenr_T)tv_get_number(&di->di_tv);
  }
  if ((di = tv_dict_find(dict, S_LEN("col"))) != NULL) {
    curwin->w_cursor.col = (colnr_T)tv_get_number(&di->di_tv);
  }
  if ((di = tv_dict_find(dict, S_LEN("coladd"))) != NULL) {
    curwin->w_cursor.coladd = (colnr_T)tv_get_number(&di->di_tv);
  }
  if ((di = tv_dict_find(dict, S_LEN("curswant"))) != NULL) {
    curwin->w_curswant = (colnr_T)tv_get_number(&di->di_tv);
    curwin->w_set_curswant = false;
  }
  if ((di = tv_dict_find(dict, S_LEN("topline"))) != NULL) {
    set_topline(curwin, (linenr_T)tv_get_number(&di->di_tv));
  }
  if ((di = tv_dict_find(dict, S_LEN("topfill"))) != NULL) {
    curwin->w_topfill = (int)tv_get_number(&di->di_tv);
  }
  if ((di = tv_dict_find(dict, S_LEN("leftcol"))) != NULL) {
    curwin->w_leftcol = (colnr_T)tv_get_number(&di->di_tv);
  }
  if ((di = tv_dict_find(dict, S_LEN("skipcol"))) != NULL) {
    curwin->w_skipcol = (colnr_T)tv_get_number(&di->di_tv);
  }

  check_cursor(curwin);
  win_new_height(curwin, curwin->w_height);
  win_new_width(curwin, curwin->w_width);
  changed_window_setting(curwin);

  if (curwin->w_topline <= 0) {
    curwin->w_topline = 1;
  }
  if (curwin->w_topline > curbuf->b_ml.ml_line_count) {
    curwin->w_topline = curbuf->b_ml.ml_line_count;
  }
  check_topfill(curwin, true);
}

/// "winsaveview()" function
void f_winsaveview(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_dict_alloc_ret(rettv);
  dict_T *dict = rettv->vval.v_dict;

  tv_dict_add_nr(dict, S_LEN("lnum"), (varnumber_T)curwin->w_cursor.lnum);
  tv_dict_add_nr(dict, S_LEN("col"), (varnumber_T)curwin->w_cursor.col);
  tv_dict_add_nr(dict, S_LEN("coladd"), (varnumber_T)curwin->w_cursor.coladd);
  update_curswant();
  tv_dict_add_nr(dict, S_LEN("curswant"), (varnumber_T)curwin->w_curswant);

  tv_dict_add_nr(dict, S_LEN("topline"), (varnumber_T)curwin->w_topline);
  tv_dict_add_nr(dict, S_LEN("topfill"), (varnumber_T)curwin->w_topfill);
  tv_dict_add_nr(dict, S_LEN("leftcol"), (varnumber_T)curwin->w_leftcol);
  tv_dict_add_nr(dict, S_LEN("skipcol"), (varnumber_T)curwin->w_skipcol);
}

/// "winwidth(nr)" function
void f_winwidth(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  win_T *wp = find_win_by_nr_or_id(&argvars[0]);
  if (wp == NULL) {
    rettv->vval.v_number = -1;
  } else {
    rettv->vval.v_number = wp->w_width_inner;
  }
}

/// Set "win" to be the curwin and "tp" to be the current tab page.
/// restore_win() MUST be called to undo, also when FAIL is returned.
/// No autocommands will be executed until restore_win() is called.
///
/// @param no_display  if true the display won't be affected, no redraw is
///                    triggered, another tabpage access is limited.
///
/// @return FAIL if switching to "win" failed.
int switch_win(switchwin_T *switchwin, win_T *win, tabpage_T *tp, bool no_display)
{
  block_autocmds();
  return switch_win_noblock(switchwin, win, tp, no_display);
}

// As switch_win() but without blocking autocommands.
int switch_win_noblock(switchwin_T *switchwin, win_T *win, tabpage_T *tp, bool no_display)
{
  CLEAR_POINTER(switchwin);
  switchwin->sw_curwin = curwin;
  if (win == curwin) {
    switchwin->sw_same_win = true;
  } else {
    // Disable Visual selection, because redrawing may fail.
    switchwin->sw_visual_active = VIsual_active;
    VIsual_active = false;
  }

  if (tp != NULL) {
    switchwin->sw_curtab = curtab;
    if (no_display) {
      unuse_tabpage(curtab);
      use_tabpage(tp);
    } else {
      goto_tabpage_tp(tp, false, false);
    }
  }
  if (!win_valid(win)) {
    return FAIL;
  }
  curwin = win;
  curbuf = curwin->w_buffer;
  return OK;
}

/// Restore current tabpage and window saved by switch_win(), if still valid.
/// When "no_display" is true the display won't be affected, no redraw is
/// triggered.
void restore_win(switchwin_T *switchwin, bool no_display)
{
  restore_win_noblock(switchwin, no_display);
  unblock_autocmds();
}

/// As restore_win() but without unblocking autocommands.
void restore_win_noblock(switchwin_T *switchwin, bool no_display)
{
  if (switchwin->sw_curtab != NULL && valid_tabpage(switchwin->sw_curtab)) {
    if (no_display) {
      win_T *const old_tp_curwin = curtab->tp_curwin;

      unuse_tabpage(curtab);
      // Don't change the curwin of the tabpage we temporarily visited.
      curtab->tp_curwin = old_tp_curwin;
      use_tabpage(switchwin->sw_curtab);
    } else {
      goto_tabpage_tp(switchwin->sw_curtab, false, false);
    }
  }

  if (!switchwin->sw_same_win) {
    VIsual_active = switchwin->sw_visual_active;
  }

  if (win_valid(switchwin->sw_curwin)) {
    curwin = switchwin->sw_curwin;
    curbuf = curwin->w_buffer;
  }
}
