// Context = "full app state" abstraction. (Note: it's named "Context" to disambiguate with state.c
// which is about the event-loop state-machine, not "total program state".)
//
// Unified interface of:
// + shada
// + CtxSwitch/ctx_switch (FKA: aucmd_prepbuf, switch_win, win_execute_T)
// + TODO: sessions
// + TODO: undo save/restore (for cmdpreview, multicursor)

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
#include "nvim/shada.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#include "context.c.generated.h"

int kCtxAll = (kCtxRegs | kCtxJumps | kCtxBufs | kCtxGVars | kCtxSFuncs | kCtxFuncs);

static ContextVec ctx_stack = KV_INITIAL_VALUE;

/// Nesting depth of ctx_switch() calls that changed curwin.
static int _ctx_switch_depth = 0;

/// curwin saved by the outermost curwin-changing ctx_switch() (0: none).
static handle_T _ctx_saved_curwin = 0;

/// Clears and frees the context stack
void ctx_free_all(void)
{
  for (size_t i = 0; i < kv_size(ctx_stack); i++) {
    ctx_free(&kv_A(ctx_stack, i));
  }
  kv_destroy(ctx_stack);
}

/// Returns the size of the context stack.
size_t ctx_size(void)
  FUNC_ATTR_PURE
{
  return kv_size(ctx_stack);
}

/// Returns pointer to Context object with given zero-based index from the top
/// of context stack or NULL if index is out of bounds.
Context *ctx_get(size_t index)
  FUNC_ATTR_PURE
{
  if (index < kv_size(ctx_stack)) {
    return &kv_Z(ctx_stack, index);
  }
  return NULL;
}

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

/// Saves the editor state to a context.
///
/// If "context" is NULL, pushes context on context stack.
/// Use "flags" to select particular types of context.
///
/// @param  ctx    Save to this context, or push on context stack if NULL.
/// @param  flags  Flags, see ContextTypeFlags enum.
void ctx_save(Context *ctx, const int flags)
{
  if (ctx == NULL) {
    kv_push(ctx_stack, CONTEXT_INIT);
    ctx = &kv_last(ctx_stack);
  }

  if (flags & kCtxRegs) {
    ctx->regs = shada_encode_regs();
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

/// Loads (restores) the editor state from a Context snapshot.
///
/// If "context" is NULL, pops context from context stack.
/// Use "flags" to select particular types of context.
///
/// @param  ctx    Load from this context. Pop from context stack if NULL.
/// @param  flags  Flags, see ContextTypeFlags enum.
///
/// @return true on success, false otherwise (i.e.: empty context stack).
bool ctx_load(Context *ctx, const int flags)
{
  bool free_ctx = false;
  if (ctx == NULL) {
    if (ctx_stack.size == 0) {
      return false;
    }
    ctx = &kv_pop(ctx_stack);
    free_ctx = true;
  }

  OptVal op_shada = get_option_value(kOptShada, OPT_GLOBAL);
  set_option_value(kOptShada, STATIC_CSTR_AS_OPTVAL("!,'100,%"), OPT_GLOBAL);

  if (flags & kCtxRegs) {
    shada_read_string(ctx->regs, kShaDaWantInfo | kShaDaForceit);
  }

  if (flags & kCtxJumps) {
    shada_read_string(ctx->jumps, kShaDaWantInfo | kShaDaForceit);
  }

  if (flags & kCtxBufs) {
    shada_read_string(ctx->bufs, kShaDaWantInfo | kShaDaForceit);
  }

  if (flags & kCtxGVars) {
    shada_read_string(ctx->gvars, kShaDaWantInfo | kShaDaForceit);
  }

  if (flags & kCtxFuncs) {
    for (size_t i = 0; i < ctx->funcs.size; i++) {
      do_cmdline_cmd(ctx->funcs.items[i].data.string.data);
    }
  }

  if (free_ctx) {
    ctx_free(ctx);
  }

  set_option_value(kOptShada, op_shada, OPT_GLOBAL);
  optval_free(op_shada);

  return true;
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
int ctx_from_dict(Dict dict, Context *ctx, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);

  int types = 0;
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

/// kCtxKeepCwd: remembers the cwd so that ctx_restore() can undo any directory change caused by
/// switching to "wp" ('autochdir', win/tab-local directories).
static void ctx_cwd_save(CtxSwitch *cs, win_T *wp, tabpage_T *tp)
{
  cs->cs_cwd_status = FAIL;

  // Getting and setting directory can be slow on some systems, only do
  // this when the current or target window/tab have a local directory or
  // 'acd' is set.
  char cwd[MAXPATHL];
  if (curwin != wp
      && (curwin->w_localdir != NULL || (wp != NULL && wp->w_localdir != NULL)
          || (curtab != tp && (curtab->tp_localdir != NULL || tp->tp_localdir != NULL))
          || p_acd)) {
    cs->cs_cwd_status = os_dirname(cwd, MAXPATHL);
    if (cs->cs_cwd_status == OK) {
      cs->cs_cwd = xstrdup(cwd);  // allocated on demand: keeps CtxSwitch small
    }
  }

  // If 'acd' is set, check we are using that directory.  If yes, then
  // apply 'acd' afterwards, otherwise restore the current directory.
  if (cs->cs_cwd_status == OK && p_acd) {
    if (curbuf->b_sfname != NULL && curbuf->b_fname == curbuf->b_sfname) {
      cs->cs_save_sfname = xstrdup(curbuf->b_sfname);
    }
    do_autochdir();
    char autocwd[MAXPATHL];
    if (os_dirname(autocwd, MAXPATHL) == OK) {
      cs->cs_apply_acd = strcmp(cwd, autocwd) == 0;
    }
  }
}

/// kCtxKeepCwd: restores the current directory.
static void ctx_cwd_restore(CtxSwitch *cs)
{
  if (cs->cs_apply_acd) {
    xfree(cs->cs_save_sfname);
    do_autochdir();
  } else if (cs->cs_cwd_status == OK) {
    os_chdir(cs->cs_cwd);
    if (cs->cs_save_sfname != NULL) {
      xfree(curbuf->b_sfname);
      curbuf->b_sfname = cs->cs_save_sfname;
      curbuf->b_fname = curbuf->b_sfname;
    }
  }
  XFREE_CLEAR(cs->cs_cwd);
}

/// Return true if "win" is an active entry in ctx_win[] (the pool of temporary scratch windows).
bool is_ctx_win(win_T *win)
{
  for (int i = 0; i < CTX_WIN_COUNT; i++) {
    if (ctx_win[i].cw_used && ctx_win[i].cw_win == win) {
      return true;
    }
  }
  return false;
}

/// Prepares a temporary "autocmd window" showing `buf`: allocated (or reused) from the `ctx_win[]`
/// pool, appended to the window list of the current tabpage, and entered, all without side effects
/// (autocommands, chdir, redraw).  Records what ctx_restore() needs to undo it in `cs`.
///
/// @return  the entered autocmd window (the new curwin).
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

  // Make sure w_localdir, tp_localdir and globaldir are NULL to avoid a
  // chdir() in win_enter_ext().
  XFREE_CLEAR(cw_win->w_localdir);
  cs->cs_tp_localdir = curtab->tp_localdir;
  curtab->tp_localdir = NULL;
  cs->cs_globaldir = globaldir;
  globaldir = NULL;

  block_autocmds();  // We don't want BufEnter/WinEnter autocommands.
  if (need_append) {
    win_append(lastwin, cw_win, NULL);
    pmap_put(int)(&window_handles, cw_win->handle, cw_win);
    win_config_float(cw_win, cw_win->w_config);
  }
  // Prevent chdir() call in win_enter_ext(), through do_autochdir()
  const int save_acd = p_acd;
  p_acd = false;
  // no redrawing and don't set the window title
  RedrawingDisabled++;
  win_enter(cw_win, false);
  RedrawingDisabled--;
  p_acd = save_acd;
  unblock_autocmds();

  return cw_win;
}

/// Removes the temporary "autocmd window" prepared by ctx_win_prep() from the window list (entering
/// it first if needed), and releases its pool slot.  Caller must restore curwin (the removed window
/// is curwin) and the directory state saved in "cs".
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

/// Prepares a temporary window or buffer as a temporary execution context. ctx_restore() MUST be
/// called afterwards, also when this returns false.
///
/// - Passing `wp` makes that window the curwin (in tabpage `tp`, or NULL for current tabpage).
///   - (Legacy: switch_win(), switch_win_noblock(), win_execute_before().)
/// - Passing `buf`, enters a window showing `buf` in the current tabpage, or prepares a temporary
///   "autocmd window" for it (never switches tabpage).
///   - (Legacy: aucmd_prepbuf().)
///
/// The switch itself never triggers autocommands; whether autocommands can fire _while_ switched
/// (until ctx_restore()) is the caller's choice via kCtxNoEvents.
///
/// @param wp     Target window, or NULL to target a buffer.
/// @param tp     Tabpage of `wp`, or NULL to not switch tabpage.
/// @param buf    Target buffer, or NULL to target a window.
/// @param flags  kCtx flags.
///
/// @return  false if switching failed (only possible for a window target).
bool ctx_switch(CtxSwitch *cs, win_T *wp, tabpage_T *tp, buf_T *buf, CtxSwitchFlags flags)
{
  assert((wp == NULL) != (buf == NULL));
  assert(buf == NULL || tp == NULL);  // a buffer target never switches tabpage
  CLEAR_POINTER(cs);
  cs->cs_flags = flags;
  cs->cs_mode = buf != NULL ? kCtxSwitchBuf : kCtxSwitchWin;
  cs->cs_ctxwin_idx = -1;

  // Resolve the target window.  A buffer target prefers a window already showing "buf" in the
  // current tabpage (least side effects, esp. if "buf" is curbuf); when there is none, an autocmd
  // window is prepared below, after the save (entering it changes curwin and prevwin).
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
  if (flags & kCtxKeepCwd) {
    ctx_cwd_save(cs, wp, tp == NULL ? curtab : tp);
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
    cs->cs_visual_active = VIsual_active;
    VIsual_active = false;
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
      // No window shows "buf": prepare an autocmd window.  Anything related to a window (e.g.,
      // setting folds) may have unexpected results.
      wp = ctx_win_prep(cs, buf);
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

    // Look up the window by handle: the user code may have closed it, and
    // its memory been reused for another window.
    win_T *const save_curwin = win_find_by_handle(cs->cs_curwin);
    if (save_curwin != NULL) {
      curwin = save_curwin;
      curbuf = curwin->w_buffer;
    }
  } else if (cs->cs_ctxwin_idx >= 0) {
    win_T *cwp = ctx_win_rest(cs);

    win_T *const save_curwin = win_find_by_handle(cs->cs_curwin);
    if (save_curwin != NULL) {
      curwin = save_curwin;
    } else {
      // Hmm, original window disappeared.  Just use the first one.
      curwin = firstwin;
    }
    curbuf = curwin->w_buffer;
    // May need to restore insert mode for a prompt buffer.
    entering_window(curwin);
    if (bt_prompt(curbuf)) {
      curbuf->b_prompt_insert = cs->cs_prompt_insert;
    }

    prevwin = win_find_by_handle(cs->cs_prevwin);
    vars_clear(&cwp->w_vars->dv_hashtab);         // free all w: variables
    hash_init(&cwp->w_vars->dv_hashtab);          // re-use the hashtab

    // If :lcd has been used in the autocommand window, correct current
    // directory before restoring tp_localdir and globaldir.
    if (cwp->w_localdir != NULL) {
      win_fix_current_dir();
    }
    xfree(curtab->tp_localdir);
    curtab->tp_localdir = cs->cs_tp_localdir;
    xfree(globaldir);
    globaldir = cs->cs_globaldir;

    // Buffer contents may have changed; cursor is checked below, AFTER restoring Visual state.
    if (curwin->w_topline > curbuf->b_ml.ml_line_count) {
      curwin->w_topline = curbuf->b_ml.ml_line_count;
      curwin->w_topfill = 0;
    }
  } else {
    // Restore curwin.  Use the window ID, a window may have been closed
    // and the memory re-used for another one.
    win_T *const save_curwin = win_find_by_handle(cs->cs_curwin);
    if (save_curwin != NULL) {
      // Restore the buffer which was previously edited by curwin, if it was
      // changed, we are still the same window and the buffer is valid.
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

      curwin = save_curwin;
      curbuf = curwin->w_buffer;
      prevwin = win_find_by_handle(cs->cs_prevwin);
    }
  }

  if (!cs->cs_same_win) {
    VIsual_active = cs->cs_visual_active;
  }
  if (cs->cs_mode == kCtxSwitchBuf) {
    check_cursor(curwin);  // just in case lines got deleted
    if (VIsual_active) {
      check_pos(curbuf, &VIsual);
    }
  }

  // Release what ctx_switch() engaged (any target kind).
  if (cs->cs_flags & kCtxNoEvents) {
    unblock_autocmds();
  }
  if (cs->cs_flags & kCtxKeepCwd) {
    ctx_cwd_restore(cs);
  }
  if (cs->cs_flags & kCtxValidate) {
    // Update the status line if the cursor moved in the target window.
    win_T *const wp = win_find_by_handle(cs->cs_target_win);
    if (wp != NULL && !equalpos(cs->cs_target_old_pos, wp->w_cursor)) {
      wp->w_redr_status = true;
    }
    // In case the code moved the cursor or changed the Visual area, check it is valid.
    check_cursor(curwin);
    if (VIsual_active) {
      check_pos(curbuf, &VIsual);
    }
  }
  if (cs->cs_mode == kCtxSwitchBuf && cs->cs_new_curwin != cs->cs_curwin) {
    assert(_ctx_switch_depth > 0);
    _ctx_switch_depth--;
    _ctx_saved_curwin = _ctx_switch_depth == 0 ? 0 : _ctx_saved_curwin;
  }
}
