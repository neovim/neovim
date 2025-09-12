// eval/buffer.c: Buffer related builtin functions

#include <stdbool.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/cursor.h"
#include "nvim/eval.h"
#include "nvim/eval/buffer.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/window.h"
#include "nvim/globals.h"
#include "nvim/macros_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/sign.h"
#include "nvim/types_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"

typedef struct {
  win_T *cob_curwin_save;
  aco_save_T cob_aco;
  int cob_using_aco;
  int cob_save_VIsual_active;
} cob_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/buffer.c.generated.h"
#endif

/// Find a buffer by number or exact name.
buf_T *find_buffer(typval_T *avar)
{
  buf_T *buf = NULL;

  if (avar->v_type == VAR_NUMBER) {
    buf = buflist_findnr((int)avar->vval.v_number);
  } else if (avar->v_type == VAR_STRING && avar->vval.v_string != NULL) {
    buf = buflist_findname_exp(avar->vval.v_string);
    if (buf == NULL) {
      // No full path name match, try a match with a URL or a "nofile"
      // buffer, these don't use the full path.
      FOR_ALL_BUFFERS(bp) {
        if (bp->b_fname != NULL
            && (path_with_url(bp->b_fname) || bt_nofilename(bp))
            && strcmp(bp->b_fname, avar->vval.v_string) == 0) {
          buf = bp;
          break;
        }
      }
    }
  }
  return buf;
}

/// If there is a window for "curbuf", make it the current window.
static void find_win_for_curbuf(void)
{
  // The b_wininfo list should have the windows that recently contained the
  // buffer, going over this is faster than going over all the windows.
  // Do check the buffer is still there.
  for (size_t i = 0; i < kv_size(curbuf->b_wininfo); i++) {
    WinInfo *wip = kv_A(curbuf->b_wininfo, i);
    if (wip->wi_win != NULL && wip->wi_win->w_buffer == curbuf) {
      curwin = wip->wi_win;
      break;
    }
  }
}

/// Used before making a change in "buf", which is not the current one: Make
/// "buf" the current buffer and find a window for this buffer, so that side
/// effects are done correctly (e.g., adjusting marks).
///
/// Information is saved in "cob" and MUST be restored by calling
/// change_other_buffer_restore().
static void change_other_buffer_prepare(cob_T *cob, buf_T *buf)
{
  CLEAR_POINTER(cob);

  // Set "curbuf" to the buffer being changed.  Then make sure there is a
  // window for it to handle any side effects.
  cob->cob_save_VIsual_active = VIsual_active;
  VIsual_active = false;
  cob->cob_curwin_save = curwin;
  curbuf = buf;
  find_win_for_curbuf();  // simplest: find existing window for "buf"

  if (curwin->w_buffer != buf) {
    // No existing window for this buffer.  It is dangerous to have
    // curwin->w_buffer differ from "curbuf", use the autocmd window.
    curbuf = curwin->w_buffer;
    aucmd_prepbuf(&cob->cob_aco, buf);
    cob->cob_using_aco = true;
  }
}

static void change_other_buffer_restore(cob_T *cob)
{
  if (cob->cob_using_aco) {
    aucmd_restbuf(&cob->cob_aco);
  } else {
    curwin = cob->cob_curwin_save;
    curbuf = curwin->w_buffer;
  }
  VIsual_active = cob->cob_save_VIsual_active;
}

/// Set line or list of lines in buffer "buf" to "lines".
/// Any type is allowed and converted to a string.
static void set_buffer_lines(buf_T *buf, linenr_T lnum_arg, bool append, typval_T *lines,
                             typval_T *rettv)
  FUNC_ATTR_NONNULL_ARG(4, 5)
{
  linenr_T lnum = lnum_arg + (append ? 1 : 0);
  int added = 0;

  // When using the current buffer ml_mfp will be set if needed.  Useful when
  // setline() is used on startup.  For other buffers the buffer must be
  // loaded.
  const bool is_curbuf = buf == curbuf;
  if (buf == NULL || (!is_curbuf && buf->b_ml.ml_mfp == NULL) || lnum < 1) {
    rettv->vval.v_number = 1;  // FAIL
    return;
  }

  // After this don't use "return", goto "cleanup"!
  cob_T cob;
  if (!is_curbuf) {
    // set "curbuf" to "buf" and find a window for this buffer
    change_other_buffer_prepare(&cob, buf);
  }

  linenr_T append_lnum;
  if (append) {
    // appendbufline() uses the line number below which we insert
    append_lnum = lnum - 1;
  } else {
    // setbufline() uses the line number above which we insert, we only
    // append if it's below the last line
    append_lnum = curbuf->b_ml.ml_line_count;
  }

  list_T *l = NULL;
  listitem_T *li = NULL;
  char *line = NULL;
  if (lines->v_type == VAR_LIST) {
    l = lines->vval.v_list;
    if (l == NULL || tv_list_len(l) == 0) {
      // not appending anything always succeeds
      goto cleanup;
    }
    li = tv_list_first(l);
  } else {
    line = typval_tostring(lines, false);
  }

  // Default result is zero == OK.
  while (true) {
    if (lines->v_type == VAR_LIST) {
      // List argument, get next string.
      if (li == NULL) {
        break;
      }
      xfree(line);
      line = typval_tostring(TV_LIST_ITEM_TV(li), false);
      li = TV_LIST_ITEM_NEXT(l, li);
    }

    rettv->vval.v_number = 1;  // FAIL
    if (line == NULL || lnum > curbuf->b_ml.ml_line_count + 1) {
      break;
    }

    // When coming here from Insert mode, sync undo, so that this can be
    // undone separately from what was previously inserted.
    if (u_sync_once == 2) {
      u_sync_once = 1;  // notify that u_sync() was called
      u_sync(true);
    }

    if (!append && lnum <= curbuf->b_ml.ml_line_count) {
      // Existing line, replace it.
      int old_len = (int)strlen(ml_get(lnum));
      if (u_savesub(lnum) == OK
          && ml_replace(lnum, line, true) == OK) {
        inserted_bytes(lnum, 0, old_len, (int)strlen(line));
        if (is_curbuf && lnum == curwin->w_cursor.lnum) {
          check_cursor_col(curwin);
        }
        rettv->vval.v_number = 0;  // OK
      }
    } else if (added > 0 || u_save(lnum - 1, lnum) == OK) {
      // append the line.
      added++;
      if (ml_append(lnum - 1, line, 0, false) == OK) {
        rettv->vval.v_number = 0;  // OK
      }
    }

    if (l == NULL) {  // only one string argument
      break;
    }
    lnum++;
  }
  xfree(line);

  if (added > 0) {
    appended_lines_mark(append_lnum, added);

    // Only adjust the cursor for buffers other than the current, unless it
    // is the current window. For curbuf and other windows it has been done
    // in mark_adjust_internal().
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp->w_buffer == buf
          && (wp->w_buffer != curbuf || wp == curwin)
          && wp->w_cursor.lnum > append_lnum) {
        wp->w_cursor.lnum += (linenr_T)added;
      }
    }
    check_cursor_col(curwin);
    update_topline(curwin);
  }

cleanup:
  if (!is_curbuf) {
    change_other_buffer_restore(&cob);
  }
}

/// "append(lnum, string/list)" function
void f_append(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const int did_emsg_before = did_emsg;
  const linenr_T lnum = tv_get_lnum(&argvars[0]);
  if (did_emsg == did_emsg_before) {
    set_buffer_lines(curbuf, lnum, true, &argvars[1], rettv);
  }
}

/// Set or append lines to a buffer.
static void buf_set_append_line(typval_T *argvars, typval_T *rettv, bool append)
{
  const int did_emsg_before = did_emsg;
  buf_T *const buf = tv_get_buf(&argvars[0], false);
  if (buf == NULL) {
    rettv->vval.v_number = 1;  // FAIL
  } else {
    const linenr_T lnum = tv_get_lnum_buf(&argvars[1], buf);
    if (did_emsg == did_emsg_before) {
      set_buffer_lines(buf, lnum, append, &argvars[2], rettv);
    }
  }
}

/// "appendbufline(buf, lnum, string/list)" function
void f_appendbufline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  buf_set_append_line(argvars, rettv, true);
}

/// "bufadd(expr)" function
void f_bufadd(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char *name = (char *)tv_get_string(&argvars[0]);

  rettv->vval.v_number = buflist_add(*name == NUL ? NULL : name, 0);
}

/// "bufexists(expr)" function
void f_bufexists(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = (find_buffer(&argvars[0]) != NULL);
}

/// "buflisted(expr)" function
void f_buflisted(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  buf_T *buf;

  buf = find_buffer(&argvars[0]);
  rettv->vval.v_number = (buf != NULL && buf->b_p_bl);
}

/// "bufload(expr)" function
void f_bufload(typval_T *argvars, typval_T *unused, EvalFuncData fptr)
{
  buf_T *buf = get_buf_arg(&argvars[0]);

  if (buf != NULL) {
    if (swap_exists_action != SEA_READONLY) {
      swap_exists_action = SEA_NONE;
    }
    buf_ensure_loaded(buf);
  }
}

/// "bufloaded(expr)" function
void f_bufloaded(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  buf_T *buf;

  buf = find_buffer(&argvars[0]);
  rettv->vval.v_number = (buf != NULL && buf->b_ml.ml_mfp != NULL);
}

/// "bufname(expr)" function
void f_bufname(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const buf_T *buf;
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;
  if (argvars[0].v_type == VAR_UNKNOWN) {
    buf = curbuf;
  } else {
    buf = tv_get_buf_from_arg(&argvars[0]);
  }
  if (buf != NULL && buf->b_fname != NULL) {
    rettv->vval.v_string = xstrdup(buf->b_fname);
  }
}

/// "bufnr(expr)" function
void f_bufnr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const buf_T *buf;
  bool error = false;

  rettv->vval.v_number = -1;

  if (argvars[0].v_type == VAR_UNKNOWN) {
    buf = curbuf;
  } else {
    // Don't use tv_get_buf_from_arg(); we continue if the buffer wasn't found
    // and the second argument isn't zero, but we want to return early if the
    // first argument isn't a string or number so only one error is shown.
    if (!tv_check_str_or_nr(&argvars[0])) {
      return;
    }
    emsg_off++;
    buf = tv_get_buf(&argvars[0], false);
    emsg_off--;
  }

  // If the buffer isn't found and the second argument is not zero create a
  // new buffer.
  const char *name;
  if (buf == NULL
      && argvars[1].v_type != VAR_UNKNOWN
      && tv_get_number_chk(&argvars[1], &error) != 0
      && !error
      && (name = tv_get_string_chk(&argvars[0])) != NULL) {
    buf = buflist_new((char *)name, NULL, 1, 0);
  }

  if (buf != NULL) {
    rettv->vval.v_number = buf->b_fnum;
  }
}

static void buf_win_common(typval_T *argvars, typval_T *rettv, bool get_nr)
{
  const buf_T *const buf = tv_get_buf_from_arg(&argvars[0]);
  if (buf == NULL) {  // no need to search if invalid arg or buffer not found
    rettv->vval.v_number = -1;
    return;
  }

  int winnr = 0;
  int winid;
  bool found_buf = false;
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    winnr += win_has_winnr(wp);
    if (wp->w_buffer == buf) {
      found_buf = true;
      winid = wp->handle;
      break;
    }
  }
  rettv->vval.v_number = (found_buf ? (get_nr ? winnr : winid) : -1);
}

/// "bufwinid(nr)" function
void f_bufwinid(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  buf_win_common(argvars, rettv, false);
}

/// "bufwinnr(nr)" function
void f_bufwinnr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  buf_win_common(argvars, rettv, true);
}

/// "deletebufline()" function
void f_deletebufline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const int did_emsg_before = did_emsg;
  rettv->vval.v_number = 1;   // FAIL by default
  buf_T *const buf = tv_get_buf(&argvars[0], false);
  if (buf == NULL) {
    return;
  }

  linenr_T last;
  const linenr_T first = tv_get_lnum_buf(&argvars[1], buf);
  if (did_emsg > did_emsg_before) {
    return;
  }
  if (argvars[2].v_type != VAR_UNKNOWN) {
    last = tv_get_lnum_buf(&argvars[2], buf);
  } else {
    last = first;
  }

  if (buf->b_ml.ml_mfp == NULL || first < 1
      || first > buf->b_ml.ml_line_count || last < first) {
    return;
  }

  // After this don't use "return", goto "cleanup"!
  const bool is_curbuf = buf == curbuf;
  cob_T cob;
  if (!is_curbuf) {
    // set "curbuf" to "buf" and find a window for this buffer
    change_other_buffer_prepare(&cob, buf);
  }

  if (last > curbuf->b_ml.ml_line_count) {
    last = curbuf->b_ml.ml_line_count;
  }
  const int count = last - first + 1;

  // When coming here from Insert mode, sync undo, so that this can be
  // undone separately from what was previously inserted.
  if (u_sync_once == 2) {
    u_sync_once = 1;  // notify that u_sync() was called
    u_sync(true);
  }

  if (u_save(first - 1, last + 1) == FAIL) {
    goto cleanup;
  }

  for (linenr_T lnum = first; lnum <= last; lnum++) {
    ml_delete(first, true);
  }

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == buf) {
      if (wp->w_cursor.lnum > last) {
        wp->w_cursor.lnum -= (linenr_T)count;
      } else if (wp->w_cursor.lnum > first) {
        wp->w_cursor.lnum = first;
      }
      if (wp->w_cursor.lnum > wp->w_buffer->b_ml.ml_line_count) {
        wp->w_cursor.lnum = wp->w_buffer->b_ml.ml_line_count;
      }
    }
  }
  check_cursor_col(curwin);
  deleted_lines_mark(first, count);
  rettv->vval.v_number = 0;  // OK

cleanup:
  if (!is_curbuf) {
    change_other_buffer_restore(&cob);
  }
}

/// @return  buffer options, variables and other attributes in a dictionary.
static dict_T *get_buffer_info(buf_T *buf)
{
  dict_T *const dict = tv_dict_alloc();

  tv_dict_add_nr(dict, S_LEN("bufnr"), buf->b_fnum);
  tv_dict_add_str(dict, S_LEN("name"), buf->b_ffname != NULL ? buf->b_ffname : "");
  tv_dict_add_nr(dict, S_LEN("lnum"),
                 buf == curbuf ? curwin->w_cursor.lnum : buflist_findlnum(buf));
  tv_dict_add_nr(dict, S_LEN("linecount"), buf->b_ml.ml_line_count);
  tv_dict_add_nr(dict, S_LEN("loaded"), buf->b_ml.ml_mfp != NULL);
  tv_dict_add_nr(dict, S_LEN("listed"), buf->b_p_bl);
  tv_dict_add_nr(dict, S_LEN("changed"), bufIsChanged(buf));
  tv_dict_add_nr(dict, S_LEN("changedtick"), buf_get_changedtick(buf));
  tv_dict_add_nr(dict, S_LEN("hidden"), buf->b_ml.ml_mfp != NULL && buf->b_nwindows == 0);
  tv_dict_add_nr(dict, S_LEN("command"), buf == cmdwin_buf);

  // Get a reference to buffer variables
  tv_dict_add_dict(dict, S_LEN("variables"), buf->b_vars);

  // List of windows displaying this buffer
  list_T *const windows = tv_list_alloc(kListLenMayKnow);
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == buf) {
      tv_list_append_number(windows, (varnumber_T)wp->handle);
    }
  }
  tv_dict_add_list(dict, S_LEN("windows"), windows);

  if (buf_has_signs(buf)) {
    // List of signs placed in this buffer
    tv_dict_add_list(dict, S_LEN("signs"), get_buffer_signs(buf));
  }

  tv_dict_add_nr(dict, S_LEN("lastused"), buf->b_last_used);

  return dict;
}

/// "getbufinfo()" function
void f_getbufinfo(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  buf_T *argbuf = NULL;
  bool filtered = false;
  bool sel_buflisted = false;
  bool sel_bufloaded = false;
  bool sel_bufmodified = false;

  tv_list_alloc_ret(rettv, kListLenMayKnow);

  // List of all the buffers or selected buffers
  if (argvars[0].v_type == VAR_DICT) {
    dict_T *sel_d = argvars[0].vval.v_dict;

    if (sel_d != NULL) {
      dictitem_T *di;

      filtered = true;

      di = tv_dict_find(sel_d, S_LEN("buflisted"));
      if (di != NULL && tv_get_number(&di->di_tv)) {
        sel_buflisted = true;
      }

      di = tv_dict_find(sel_d, S_LEN("bufloaded"));
      if (di != NULL && tv_get_number(&di->di_tv)) {
        sel_bufloaded = true;
      }
      di = tv_dict_find(sel_d, S_LEN("bufmodified"));
      if (di != NULL && tv_get_number(&di->di_tv)) {
        sel_bufmodified = true;
      }
    }
  } else if (argvars[0].v_type != VAR_UNKNOWN) {
    // Information about one buffer.  Argument specifies the buffer
    argbuf = tv_get_buf_from_arg(&argvars[0]);
    if (argbuf == NULL) {
      return;
    }
  }

  // Return information about all the buffers or a specified buffer
  FOR_ALL_BUFFERS(buf) {
    if (argbuf != NULL && argbuf != buf) {
      continue;
    }
    if (filtered && ((sel_bufloaded && buf->b_ml.ml_mfp == NULL)
                     || (sel_buflisted && !buf->b_p_bl)
                     || (sel_bufmodified && !buf->b_changed))) {
      continue;
    }

    dict_T *const d = get_buffer_info(buf);
    tv_list_append_dict(rettv->vval.v_list, d);
    if (argbuf != NULL) {
      return;
    }
  }
}

/// Get line or list of lines from buffer "buf" into "rettv".
///
/// @param retlist  if true, then the lines are returned as a Vim List.
///
/// @return  range (from start to end) of lines in rettv from the specified
///          buffer.
static void get_buffer_lines(buf_T *buf, linenr_T start, linenr_T end, bool retlist,
                             typval_T *rettv)
{
  rettv->v_type = (retlist ? VAR_LIST : VAR_STRING);
  rettv->vval.v_string = NULL;

  if (buf == NULL || buf->b_ml.ml_mfp == NULL || start < 0 || end < start) {
    if (retlist) {
      tv_list_alloc_ret(rettv, 0);
    }
    return;
  }

  if (retlist) {
    if (start < 1) {
      start = 1;
    }
    if (end > buf->b_ml.ml_line_count) {
      end = buf->b_ml.ml_line_count;
    }
    tv_list_alloc_ret(rettv, end - start + 1);
    while (start <= end) {
      tv_list_append_string(rettv->vval.v_list, ml_get_buf(buf, start++), -1);
    }
  } else {
    rettv->v_type = VAR_STRING;
    rettv->vval.v_string = ((start >= 1 && start <= buf->b_ml.ml_line_count)
                            ? xstrdup(ml_get_buf(buf, start)) : NULL);
  }
}

/// @param retlist  true: "getbufline()" function
///                 false: "getbufoneline()" function
static void getbufline(typval_T *argvars, typval_T *rettv, bool retlist)
{
  const int did_emsg_before = did_emsg;
  buf_T *const buf = tv_get_buf_from_arg(&argvars[0]);
  const linenr_T lnum = tv_get_lnum_buf(&argvars[1], buf);
  if (did_emsg > did_emsg_before) {
    return;
  }
  const linenr_T end = (argvars[2].v_type == VAR_UNKNOWN
                        ? lnum
                        : tv_get_lnum_buf(&argvars[2], buf));

  get_buffer_lines(buf, lnum, end, retlist, rettv);
}

/// "getbufline()" function
void f_getbufline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  getbufline(argvars, rettv, true);
}

/// "getbufoneline()" function
void f_getbufoneline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  getbufline(argvars, rettv, false);
}

/// "getline(lnum, [end])" function
void f_getline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  linenr_T end;
  bool retlist;

  const linenr_T lnum = tv_get_lnum(argvars);
  if (argvars[1].v_type == VAR_UNKNOWN) {
    end = lnum;
    retlist = false;
  } else {
    end = tv_get_lnum(&argvars[1]);
    retlist = true;
  }

  get_buffer_lines(curbuf, lnum, end, retlist, rettv);
}

/// "setbufline()" function
void f_setbufline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  buf_set_append_line(argvars, rettv, false);
}

/// "setline()" function
void f_setline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const int did_emsg_before = did_emsg;
  linenr_T lnum = tv_get_lnum(&argvars[0]);
  if (did_emsg == did_emsg_before) {
    set_buffer_lines(curbuf, lnum, false, &argvars[1], rettv);
  }
}

/// Make "buf" the current buffer.
///
/// restore_buffer() MUST be called to undo.
/// No autocommands will be executed. Use aucmd_prepbuf() if there are any.
void switch_buffer(bufref_T *save_curbuf, buf_T *buf)
{
  block_autocmds();
  set_bufref(save_curbuf, curbuf);
  curbuf->b_nwindows--;
  curbuf = buf;
  curwin->w_buffer = buf;
  curbuf->b_nwindows++;
}

/// Restore the current buffer after using switch_buffer().
void restore_buffer(bufref_T *save_curbuf)
{
  unblock_autocmds();
  // Check for valid buffer, just in case.
  if (bufref_valid(save_curbuf)) {
    curbuf->b_nwindows--;
    curwin->w_buffer = save_curbuf->br_buf;
    curbuf = save_curbuf->br_buf;
    curbuf->b_nwindows++;
  }
}

/// Find a window for buffer "buf".
/// If found true is returned and "wp" and "tp" are set to
/// the window and tabpage.
/// If not found, false is returned.
///
/// @param       buf  buffer to find a window for
/// @param[out]  wp   stores the found window
/// @param[out]  tp   stores the found tabpage
///
/// @return  true if a window was found for the buffer.
bool find_win_for_buf(buf_T *buf, win_T **wp, tabpage_T **tp)
{
  *wp = NULL;
  *tp = NULL;
  FOR_ALL_TAB_WINDOWS(tp2, wp2) {
    if (wp2->w_buffer == buf) {
      *tp = tp2;
      *wp = wp2;
      return true;
    }
  }
  return false;
}
