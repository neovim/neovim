// Context = "full app state" abstraction. (Note: it's named "Context" to disambiguate with state.c
// which is about the event-loop state-machine, not "total program state".)
//
// Unified interface of:
// + shada
// + CtxSwitch/ctx_switch (FKA: aucmd_prepbuf, switch_win, win_execute_T)
// + TODO: sessions
// + TODO: undo save/restore (for cmdpreview, multicursor)
// + TODO: TRY_WRAP ?
//
// Related:
// - vim.with()
// - switch_option_context(), restore_option_context()
// - McSandbox: input-replay guard. Sibling axis to ctx_switch() and ctx_save().

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vimscript.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/context.h"
#include "nvim/cursor.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_docmd.h"
#include "nvim/fileio.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/keycodes.h"
#include "nvim/mark.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/register.h"
#include "nvim/shada.h"
#include "nvim/state_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#include "context.c.generated.h"

/// Nesting depth of ctx_switch() calls that changed curwin.
static int _ctx_switch_depth = 0;

/// curwin saved by the outermost curwin-changing ctx_switch() (0: none).
static handle_T _ctx_saved_curwin = 0;

/// Whether an explicit :cd/:tcd/:lcd/:bcd/chdir() happened since the innermost ctx_switch().
static bool _ctx_did_chdir = false;

/// Free resources used by Context object.
///
/// param[in]  ctx  pointer to Context object to free.
void ctx_free(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  api_free_string(ctx->regs);
  api_free_string(ctx->jumps);
  api_free_string(ctx->bufs);
  api_free_string(ctx->gvars);
  api_free_array(ctx->funcs);
}

/// Saves the editor state (ALL THE THINGS!!!1) to a context.
///
/// @param  ctx    Save to this context.
/// @param  flags  State types to save.
void ctx_save(Context *ctx, const CtxStateFlags flags)
  FUNC_ATTR_NONNULL_ALL
{
  ctx->buf = curbuf->handle;
  ctx->pos = (pos_T) {
    .lnum = curwin->w_cursor.lnum,
    .col = curwin->w_cursor.col,
    .coladd = curwin->w_cursor.coladd,
  };

  if (flags & kCtxRegs) {
    ctx->regs = shada_encode_regs(false, 0);
  }

  if (flags & kCtxJumps) {
    ctx->jumps = shada_encode_jumps();
  }

  if (flags & kCtxBufs) {
    ctx->bufs = shada_encode_buflist();
  }

  if (flags & kCtxGVars) {
    ctx->gvars = shada_encode_gvars();
  }

  if (flags & (kCtxFuncs | kCtxSFuncs)) {
    const bool scriptonly = !(flags & kCtxFuncs);  // kCtxSFuncs: s: functions only
    ctx->funcs = (Array)ARRAY_DICT_INIT;
    Error err = ERROR_INIT;

    HASHTAB_ITER(func_tbl_get(), hi, {
      const char *const name = hi->hi_key;
      bool islambda = (strncmp(name, "<lambda>", 8) == 0);
      bool isscript = ((uint8_t)name[0] == K_SPECIAL);

      if (!islambda && (!scriptonly || isscript)) {
        size_t cmd_len = sizeof("func! ") + strlen(name);
        char *cmd = xmalloc(cmd_len);
        snprintf(cmd, cmd_len, "func! %s", name);
        Dict(exec_opts) opts = { .output = true };
        String func_body = exec_impl(VIML_INTERNAL_CALL, cstr_as_string(cmd), &opts, &err);
        xfree(cmd);
        if (!ERROR_SET(&err)) {
          ADD(ctx->funcs, STRING_OBJ(func_body));
        }
        api_clear_error(&err);
      }
    });
  }
}

/// Loads (restores) the editor state from a Context snapshot. Restores registers EXACTLY, unless
/// kCtxMergeReg is specified.
///
/// @param  ctx    Load from this context.
/// @param  flags  State types to load.
/// @param  loadflags  Controls load behavior.
void ctx_load(Context *ctx, const CtxStateFlags flags, const CtxLoadFlags loadflags)
  FUNC_ATTR_NONNULL_ALL
{
  // TODO(jkeyes): restore window, mode, pos?

  if (flags & kCtxRegs) {
    if (!(loadflags & kCtxMergeReg)) {
      // Avoid shada "merge" behavior for registers; restore "exact", don't merge.
      for (int i = 0; i < NUM_SAVED_REGISTERS; i++) {
        free_register(get_y_register(i));
      }
    }
    shada_read_string(ctx->regs, kShaDaWantInfo | kShaDaForceit | kShaDaNanos | kShaDaNoHistory);
  }

  if (flags & kCtxJumps) {
    shada_read_string(ctx->jumps, kShaDaWantInfo | kShaDaForceit | kShaDaNoHistory);
  }

  if (flags & kCtxBufs) {
    shada_read_string(ctx->bufs, kShaDaWantInfo | kShaDaForceit | kShaDaNoHistory | kShaDaNoOpt);
  }

  if (flags & kCtxGVars) {
    shada_read_string(ctx->gvars, kShaDaWantInfo | kShaDaForceit | kShaDaNoHistory | kShaDaNoOpt);
  }

  if (flags & kCtxFuncs) {
    for (size_t i = 0; i < ctx->funcs.size; i++) {
      do_cmdline_cmd(ctx->funcs.items[i].data.string.data);
    }
  }
}

/// Convert readfile()-style array to String
///
/// @param[in]  array  readfile()-style array to convert.
/// @param[out]  err   Error object.
///
/// @return String with conversion result.
static inline String array_to_string(Array array, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  String sbuf = STRING_INIT;

  typval_T list_tv;
  object_to_vim(ARRAY_OBJ(array), &list_tv, err);

  assert(list_tv.v_type == VAR_LIST);
  if (!encode_vim_list_to_buf(list_tv.vval.v_list, &sbuf.size, &sbuf.data)) {
    api_set_error(err, kErrorTypeException, "%s",
                  "E474: Failed to convert list to msgpack string buffer");
  }

  tv_clear(&list_tv);
  return sbuf;
}

/// Converts Context to Dict representation.
///
/// @param[in]  ctx  Context to convert.
///
/// @return Dict representing "ctx".
Dict ctx_to_dict(Context *ctx, Arena *arena)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);

  Dict rv = arena_dict(arena, 5);

  PUT_C(rv, "regs", ARRAY_OBJ(string_to_array(ctx->regs, false, arena)));
  PUT_C(rv, "jumps", ARRAY_OBJ(string_to_array(ctx->jumps, false, arena)));
  PUT_C(rv, "bufs", ARRAY_OBJ(string_to_array(ctx->bufs, false, arena)));
  PUT_C(rv, "gvars", ARRAY_OBJ(string_to_array(ctx->gvars, false, arena)));
  PUT_C(rv, "funcs", ARRAY_OBJ(copy_array(ctx->funcs, arena)));

  return rv;
}

/// Converts Dict representation of Context back to Context object.
///
/// @param[in]   dict  Context Dict representation.
/// @param[out]  ctx   Context object to store conversion result into.
/// @param[out]  err   Error object.
///
/// @return types of included context items.
CtxStateFlags ctx_from_dict(Dict dict, Context *ctx, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);

  CtxStateFlags types = 0;
  for (size_t i = 0; i < dict.size && !ERROR_SET(err); i++) {
    KeyValuePair item = dict.items[i];
    if (item.value.type != kObjectTypeArray) {
      continue;
    }
    if (strequal(item.key.data, "regs")) {
      types |= kCtxRegs;
      ctx->regs = array_to_string(item.value.data.array, err);
    } else if (strequal(item.key.data, "jumps")) {
      types |= kCtxJumps;
      ctx->jumps = array_to_string(item.value.data.array, err);
    } else if (strequal(item.key.data, "bufs")) {
      types |= kCtxBufs;
      ctx->bufs = array_to_string(item.value.data.array, err);
    } else if (strequal(item.key.data, "gvars")) {
      types |= kCtxGVars;
      ctx->gvars = array_to_string(item.value.data.array, err);
    } else if (strequal(item.key.data, "funcs")) {
      types |= kCtxFuncs;
      ctx->funcs = copy_object(item.value, NULL).data.array;
    }
  }

  return types;
}

/// Moves CWD state aside, so that the temporary "autocmd window" starts clean.
/// Undone by ctx_localdirs_restore().
static void ctx_win_dirs_save(CtxSwitch *cs, win_T *cw_win, buf_T *buf)
{
  // A pooled tmp-window must not carry a stale w_localdir.
  XFREE_CLEAR(cw_win->w_localdir);
  cs->cs_b_localdir = buf->b_localdir;
  buf->b_localdir = NULL;
  cs->cs_tp_localdir = curtab->tp_localdir;
  curtab->tp_localdir = NULL;
  cs->cs_globaldir = globaldir;
  globaldir = NULL;
}

/// Restores the dir scopes saved in `cs`. With `persist`, a scope explicitly changed
/// (user :bcd/:tcd/:cd) keeps its new value instead.
///
/// @param cwp  The discarded temp win of a hidden buf, or NULL. If given, also fix the process CWD.
/// @param tp   Tabpage that owns cs_tp_localdir, or NULL if it no longer exists.
static void ctx_localdirs_restore(CtxSwitch *cs, win_T *cwp, tabpage_T *tp, bool persist)
{
  const bool did_chdir = _ctx_did_chdir;
  _ctx_did_chdir = persist && did_chdir;

  win_T *dirs_win = win_find_by_handle(cs->cs_new_curwin);
  if (dirs_win != NULL) {
    xfree(dirs_win->w_localdir);
    dirs_win->w_localdir = cs->cs_w_localdir;
  } else {
    xfree(cs->cs_w_localdir);
  }

  buf_T *b = bufref_valid(&cs->cs_new_curbuf) ? cs->cs_new_curbuf.br_buf : NULL;
  if (b != NULL && !(persist && b->b_localdir != NULL)) {
    xfree(b->b_localdir);
    b->b_localdir = cs->cs_b_localdir;
  } else {
    xfree(cs->cs_b_localdir);
  }

  if (tp != NULL && !(persist && tp->tp_localdir != NULL)) {
    xfree(tp->tp_localdir);
    tp->tp_localdir = cs->cs_tp_localdir;
  } else {
    xfree(cs->cs_tp_localdir);
  }

  // Correct the directory before restoring globaldir: the first chdir during the switch saved
  // the pre-switch cwd in `globaldir` (see `post_chdir`), which update_cwd() uses as fallback.
  if (cwp != NULL && (did_chdir || cwp->w_localdir != NULL)) {
    update_cwd(kCdCauseWindow);
  }

  // Keep-case: the globaldir set during the switch (pre-switch cwd, see `post_chdir`).
  if (!(persist && cs->cs_globaldir == NULL && globaldir != NULL)) {
    xfree(globaldir);
    globaldir = cs->cs_globaldir;
    cs->cs_globaldir = NULL;
  }
}

/// Saves the dir state to be restored by ctx_dirs_restore():
/// - kCtxKeepCwd or kCtxKeepDirs: the CWD and `globaldir`, so any directory change caused by
///   switching to `wp` ('autochdir', win/tab-local directories) can be undone.
/// - kCtxKeepDirs: also copies of the target context's dir scopes (w/b/tp-local).
static void ctx_dirs_save(CtxSwitch *cs, win_T *wp, tabpage_T *tp, buf_T *buf)
  FUNC_ATTR_NONNULL_ARG(1, 2, 3)
{
  if (!(cs->cs_flags & (kCtxKeepCwd | kCtxKeepDirs))) {
    return;
  }

  // `globaldir` is where to return when no local dir applies (NULL: the CWD is already there).
  cs->cs_globaldir = globaldir == NULL ? NULL : xstrdup(globaldir);

  // kCtxKeepDirs: also save copies of the target context's dir scopes.
  if (cs->cs_flags & kCtxKeepDirs) {
    buf_T *target_buf = buf != NULL ? buf : wp->w_buffer;
    cs->cs_dirs_tab = tp->handle;
    cs->cs_w_localdir = wp->w_localdir == NULL ? NULL : xstrdup(wp->w_localdir);
    cs->cs_b_localdir = target_buf->b_localdir == NULL ? NULL : xstrdup(target_buf->b_localdir);
    cs->cs_tp_localdir = tp->tp_localdir == NULL ? NULL : xstrdup(tp->tp_localdir);
  }

  char cwd[MAXPATHL];
  if ((cs->cs_flags & kCtxKeepDirs) || curwin != wp) {
    if (os_dirname(cwd, MAXPATHL) == OK) {
      cs->cs_cwd = xstrdup(cwd);  // allocated on demand: keeps CtxSwitch small
    }
  }

  // If 'acd' is set, check we are using that directory.  If yes, then
  // apply 'acd' afterwards, otherwise restore the current directory.
  if (cs->cs_cwd != NULL && p_acd) {
    do_autochdir();
    char autocwd[MAXPATHL];
    if (os_dirname(autocwd, MAXPATHL) == OK) {
      cs->cs_apply_acd = strcmp(cs->cs_cwd, autocwd) == 0;
    }
  }
}

/// Restores the dir state saved by ctx_dirs_save(), undoing any chdir made while switched. The
/// target window/buffer/tab may have been closed meanwhile.
static void ctx_dirs_restore(CtxSwitch *cs)
{
  if (cs->cs_ctxwin_idx >= 0) {
    return;  // Hidden-buffer target: ctx_localdirs_restore() already restored dirs.
  }

  // kCtxKeepDirs: restore the saved dir scopes.
  if (cs->cs_flags & kCtxKeepDirs) {
    tabpage_T *dirs_tab = NULL;
    FOR_ALL_TABS(tp) {
      if (tp->handle == cs->cs_dirs_tab) {
        dirs_tab = tp;
        break;
      }
    }
    ctx_localdirs_restore(cs, NULL, dirs_tab, false);
  } else if (cs->cs_cwd != NULL && !_ctx_did_chdir) {
    // Pairs with the CWD restore below.
    xfree(globaldir);
    globaldir = cs->cs_globaldir;
    cs->cs_globaldir = NULL;
  }
  XFREE_CLEAR(cs->cs_globaldir);

  // Restore the CWD itself. After an explicit chdir, ctx_restore() re-derives it instead.
  if (cs->cs_apply_acd) {
    do_autochdir();
  } else if (cs->cs_cwd != NULL && ((cs->cs_flags & kCtxKeepDirs) || !_ctx_did_chdir)) {
    os_chdir(cs->cs_cwd);
    // Buffer names are relative to the CWD, so they must follow it back. #41424
    shorten_fnames(true);
  }
  XFREE_CLEAR(cs->cs_cwd);
}

void ctx_did_chdir(void)
{
  _ctx_did_chdir = true;
}

/// Return true if `win` is an active entry in ctx_win[] (the pool of temporary scratch windows).
bool is_ctx_win(win_T *win)
{
  for (int i = 0; i < CTX_WIN_COUNT; i++) {
    if (ctx_win[i].cw_used && ctx_win[i].cw_win == win) {
      return true;
    }
  }
  return false;
}

/// Prepares a temporary "autocmd window" showing `buf`: allocated/reused from the `ctx_win[]` pool
/// and appended to the window list of curtab. Records what ctx_restore() needs to undo in `cs`.
///
/// Window lifecycle only: does not enter the window, no side effects (autocmds, chdir, redraw).
///
/// @return  the prepared autocmd window.
static win_T *ctx_win_prep(CtxSwitch *cs, buf_T *buf)
{
  bool need_append = true;  // Append `cw_win` to the window list.

  // Allocate a window when needed.
  int idx;
  for (idx = 0; idx < CTX_WIN_COUNT; idx++) {
    if (!ctx_win[idx].cw_used) {
      break;
    }
  }
  if (idx == CTX_WIN_COUNT) {
    kv_push(ctx_win_vec, ((CtxWin){
      .cw_win = NULL,
      .cw_used = false,
    }));
  }
  if (ctx_win[idx].cw_win == NULL) {
    win_alloc_ctx_win(idx);
    need_append = false;
  }
  win_T *cw_win = ctx_win[idx].cw_win;
  ctx_win[idx].cw_used = true;
  cs->cs_ctxwin_idx = idx;

  cw_win->w_buffer = buf;
  cw_win->w_s = &buf->b_s;
  buf->b_nwindows++;
  win_init_empty(cw_win);  // set cursor and topline to safe values

  ctx_win_dirs_save(cs, cw_win, buf);

  if (need_append) {
    win_append(lastwin, cw_win, NULL);
    pmap_put(int)(&window_handles, cw_win->handle, cw_win);
    win_config_float(cw_win, cw_win->w_config);
  }

  return cw_win;
}

/// Removes the temp win (FKA "autocmd win") prepared by ctx_win_prep() from the window list
/// (entering it if needed), and releases its pool slot. Caller must restore curwin (the removed
/// window is curwin) and the directory state saved in "cs".
///
/// @return  the removed autocmd window.
static win_T *ctx_win_rest(CtxSwitch *cs)
{
  win_T *cwp = ctx_win[cs->cs_ctxwin_idx].cw_win;

  // Find `cwp`, it can't be closed, but it may be in another tab page.
  // Do not trigger autocommands here.
  block_autocmds();
  if (curwin != cwp) {
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp == cwp) {
        if (tp != curtab) {
          goto_tabpage_tp(tp, true, true);
        }
        win_goto(cwp);
        goto win_found;
      }
    }
  }
win_found:
  curbuf->b_nwindows--;
  // Remove the window.
  win_remove(curwin, NULL);
  pmap_del(int)(&window_handles, curwin->handle, NULL);

  // Mark window as "not used", but don't free, it can be used again.
  ctx_win[cs->cs_ctxwin_idx].cw_used = false;

  if (!valid_tabpage_win(curtab)) {
    // no valid window in current tabpage
    close_tabpage(curtab);
  }

  unblock_autocmds();
  return cwp;
}

/// Window saved by the outermost curwin-changing ctx_switch(), or NULL.  Used to restore the
/// actual current window when redrawing.
win_T *ctx_saved_curwin(void)
{
  return _ctx_saved_curwin == 0 ? NULL : win_find_by_handle(_ctx_saved_curwin);
}

/// Prepares a temporary execution context. ctx_restore() MUST be called afterwards, also when this
/// returns false.
///
/// - Passing `wp` makes that window the curwin (in tabpage `tp`, or NULL for current tabpage).
///   - (Legacy: switch_win(), switch_win_noblock(), win_execute_before().)
/// - Passing `buf`, enters a window showing `buf` in the current tabpage, or prepares a temporary
///   "autocmd window" for it (never switches tabpage).
///   - (Legacy: aucmd_prepbuf().)
/// - Passing neither: only CWD state is saved; flags must include `kCtxKeepDirs`.
///
/// The switch itself never triggers autocommands; whether autocommands can fire _while_ switched
/// (until ctx_restore()) is the caller's choice via kCtxNoEvents.
///
/// @param wp     Target window, or NULL.
/// @param tp     Tabpage of `wp`, or NULL to not switch tabpage.
/// @param buf    Target buffer, or NULL.
/// @param flags  kCtx flags.
///
/// @return  false if switching failed (only possible for a window target).
bool ctx_switch(CtxSwitch *cs, win_T *wp, tabpage_T *tp, buf_T *buf, CtxSwitchFlags flags)
{
  // Exactly one target, or none with kCtxKeepDirs (which only saves the CWD state).
  assert(((wp == NULL) != (buf == NULL)) || (wp == NULL && (flags & kCtxKeepDirs)));
  assert(buf == NULL || tp == NULL);  // a buffer target never switches tabpage
  CLEAR_POINTER(cs);
  cs->cs_flags = flags;
  cs->cs_mode = buf != NULL ? kCtxSwitchBuf : wp != NULL ? kCtxSwitchWin : kCtxSwitchDirs;
  cs->cs_ctxwin_idx = -1;
  cs->cs_did_chdir = _ctx_did_chdir;
  _ctx_did_chdir = false;
  if (cs->cs_mode == kCtxSwitchDirs) {
    wp = curwin;  // No target: "switch" to curwin, i.e. stay put.
  }

  // Resolve the target window.  A buffer target prefers a window already showing it, in the current
  // tabpage (minimizes side effects); else a ctx_win is prepared below (ctx_win_prep).
  if (buf != NULL) {
    if (buf == curbuf) {  // be quick when buf is curbuf
      wp = curwin;
    } else {
      FOR_ALL_WINDOWS_IN_TAB(wp2, curtab) {
        if (wp2->w_buffer == buf) {
          wp = wp2;
          break;
        }
      }
    }
  }

  if ((flags & kCtxValidate) && wp != NULL) {
    cs->cs_target_win = wp->handle;
    cs->cs_target_old_pos = wp->w_cursor;
  }
  // The CWD-state snapshot is only for a real window target; hidden-buffer target is handled by the
  // ctx_win machinery (ctx_win_prep).
  if (wp != NULL) {
    ctx_dirs_save(cs, wp, tp == NULL ? curtab : tp, buf);
  }

  // Save the current state.
  cs->cs_curwin = curwin->handle;
  cs->cs_prevwin = prevwin == NULL ? 0 : prevwin->handle;
  cs->cs_same_win = wp == curwin;
  if (bt_prompt(curbuf)) {
    cs->cs_prompt_insert = curbuf->b_prompt_insert;
  }
  if (!cs->cs_same_win) {
    // Disable Visual selection, because redrawing may fail.
    cs->cs_visual_active = Visual.active;
    Visual.active = false;
  }

  if (flags & kCtxNoEvents) {
    block_autocmds();
  }
  if (tp != NULL) {
    cs->cs_curtab = curtab;
    if (flags & kCtxNoDisplay) {
      unuse_tabpage(curtab);
      use_tabpage(tp);
    } else {
      goto_tabpage_tp(tp, false, false);
    }
  }

  if (buf != NULL) {
    if (wp == NULL) {
      // Hidden buffer (`buf` not visible in any window): prepare a temp window.
      // Window behavior (e.g., setting folds) may have unexpected results.
      wp = ctx_win_prep(cs, buf);
      // Leave the window we entered "from".
      leaving_window(curwin);
      // We will soon enter "buf" and may have to copy buffer options.
      buf_copy_options(buf, BCO_ENTER | BCO_NOHELP);
      prevwin = curwin;
    }
    assert(win_valid(wp));
  } else if (!win_valid(wp)) {
    return false;
  }
  curwin = wp;
  curbuf = curwin->w_buffer;
  cs->cs_new_curwin = curwin->handle;
  set_bufref(&cs->cs_new_curbuf, curbuf);

  if (cs->cs_mode == kCtxSwitchBuf && cs->cs_new_curwin != cs->cs_curwin) {
    _ctx_saved_curwin = _ctx_switch_depth == 0 ? cs->cs_curwin : _ctx_saved_curwin;
    _ctx_switch_depth++;
  }
  if (flags & kCtxValidate) {
    check_cursor(curwin);
  }
  return true;
}

/// Restores curwin/curbuf and prevwin. If the saved window no longer exists, enters `fallback`.
static void ctx_restore_curwin(CtxSwitch *cs, win_T *fallback)
{
  win_T *save_curwin = win_find_by_handle(cs->cs_curwin);
  if (save_curwin == NULL) {
    save_curwin = fallback;  // Hmm, original window disappeared.
  }
  if (save_curwin != NULL) {
    curwin = save_curwin;
    curbuf = curwin->w_buffer;
  }
  prevwin = win_find_by_handle(cs->cs_prevwin);
}

/// Undoes ctx_switch(): restores the previous location (if possible) and the kept state.
///
/// No-op if `cs` was zero-initialized, even if ctx_switch() was not called on it:
///
///      CtxSwitch cs = { 0 };
///      if (some_condition) {
///        ctx_switch(&cs, NULL, NULL, buf, 0);
///      }
///      ...
///      ctx_restore(&cs);  // no-op if ctx_switch() was skipped.
///
/// Legacy: restore_win()/restore_win_noblock(), aucmd_restbuf(), win_execute_after().
void ctx_restore(CtxSwitch *cs)
{
  if (cs->cs_mode == kCtxSwitchNone) {
    return;  // zero-initialized: ctx_switch() was never called on `cs`.
  }

  if (cs->cs_mode == kCtxSwitchWin) {
    // Window target: restore tabpage and curwin.
    if (cs->cs_curtab != NULL && valid_tabpage(cs->cs_curtab)) {
      if (cs->cs_flags & kCtxNoDisplay) {
        win_T *const old_tp_curwin = curtab->tp_curwin;

        unuse_tabpage(curtab);
        // Don't change the curwin of the tabpage we temporarily visited.
        curtab->tp_curwin = old_tp_curwin;
        use_tabpage(cs->cs_curtab);
      } else {
        goto_tabpage_tp(cs->cs_curtab, false, false);
      }
    }

    ctx_restore_curwin(cs, NULL);
  } else if (cs->cs_ctxwin_idx >= 0) {
    win_T *cwp = ctx_win_rest(cs);

    ctx_restore_curwin(cs, firstwin);
    // May need to restore insert-mode for a prompt buffer.
    // Pairs with the leaving_window() in ctx_switch().
    entering_window(curwin);
    if (bt_prompt(curbuf)) {
      curbuf->b_prompt_insert = cs->cs_prompt_insert;
    }

    vars_clear(&cwp->w_vars->dv_hashtab);         // free all w: variables
    hash_init(&cwp->w_vars->dv_hashtab);          // re-use the hashtab

    ctx_localdirs_restore(cs, cwp, curtab, !(cs->cs_flags & kCtxKeepDirs));

    // Buffer contents may have changed; cursor is checked below, AFTER restoring Visual state.
    if (curwin->w_topline > curbuf->b_ml.ml_line_count) {
      curwin->w_topline = curbuf->b_ml.ml_line_count;
      curwin->w_topfill = 0;
    }
  } else if (cs->cs_mode == kCtxSwitchBuf) {
    // Restore the buffer previously edited by curwin.
    if (curwin->handle == cs->cs_new_curwin
        && curbuf != cs->cs_new_curbuf.br_buf
        && bufref_valid(&cs->cs_new_curbuf)
        && cs->cs_new_curbuf.br_buf->b_ml.ml_mfp != NULL) {
      if (curwin->w_s == &curbuf->b_s) {
        curwin->w_s = &cs->cs_new_curbuf.br_buf->b_s;
      }
      curbuf->b_nwindows--;
      curbuf = cs->cs_new_curbuf.br_buf;
      curwin->w_buffer = curbuf;
      curbuf->b_nwindows++;
    }

    ctx_restore_curwin(cs, NULL);
  }  // Else: only save CWD state.

  if (!cs->cs_same_win) {
    Visual.active = cs->cs_visual_active;
  }
  if (cs->cs_mode == kCtxSwitchBuf) {
    check_cursor(curwin);  // just in case lines got deleted
    if (Visual.active) {
      check_pos(curbuf, &Visual.start);
    }
  }

  // Release what ctx_switch() engaged (any target kind).
  if (cs->cs_flags & kCtxNoEvents) {
    unblock_autocmds();
  }
  ctx_dirs_restore(cs);  // No-op if ctx_dirs_save() saved nothing.
  // Re-apply the restored context's effective directory.
  if (cs->cs_ctxwin_idx < 0 && _ctx_did_chdir) {
    update_cwd(kCdCauseWindow);
  }
  _ctx_did_chdir = _ctx_did_chdir || cs->cs_did_chdir;
  if (cs->cs_flags & kCtxValidate) {
    // Update the status line if the cursor moved in the target window.
    win_T *const wp = win_find_by_handle(cs->cs_target_win);
    if (wp != NULL && !equalpos(cs->cs_target_old_pos, wp->w_cursor)) {
      wp->w_redr_status = true;
    }
    // In case the code moved the cursor or changed the Visual area, check it is valid.
    check_cursor(curwin);
    if (Visual.active) {
      check_pos(curbuf, &Visual.start);
    }
  }
  if (cs->cs_mode == kCtxSwitchBuf && cs->cs_new_curwin != cs->cs_curwin) {
    assert(_ctx_switch_depth > 0);
    _ctx_switch_depth--;
    _ctx_saved_curwin = _ctx_switch_depth == 0 ? 0 : _ctx_saved_curwin;
  }
}
