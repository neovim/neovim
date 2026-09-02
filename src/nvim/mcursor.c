// Multicursor. Cursors are Context snapshots (mc_cursors) tracked by extmarks; user actions
// (CmdAtoms) are replayed at each cursor at the "clock edge" (the cascade). See dev_arch.txt.

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/buffer.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/clipboard.h"
#include "nvim/context.h"
#include "nvim/cursor.h"
#include "nvim/decoration.h"
#include "nvim/drawscreen.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/extmark.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight_group.h"
#include "nvim/input.h"
#include "nvim/input_cmdatom.h"
#include "nvim/insert.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/marktree.h"
#include "nvim/mbyte.h"
#include "nvim/mcursor.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/register.h"
#include "nvim/register_defs.h"
#include "nvim/search.h"
#include "nvim/shada.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"

/// Primary-cursor state saved across a replay sandbox.
typedef struct {
  save_state_T sst;       ///< mode, typeahead, reg_executing, …
  RedoState redo;
  Context regs;           ///< Registers.
  handle_T bufnr;         ///< buffer at enter (revalidated on leave: autocmds may wipe it)
  pos_T cursor;
  colnr_T curswant;
  bool set_curswant;
  colnr_T leftcol;
  uint32_t cursor_mark;   ///< extmark tracking `cursor` across replay edits
  uint32_t topline_mark;  ///< extmark tracking `topline` across replay edits
  pos_T topline;
  VisualState visual;
  pos_T op_start;         ///< b_op_start: change marks belong to the primary's operation
  pos_T op_end;
  fmark_T last_change;
  visualinfo_T bvisual;
  int bvisual_mode;
} McSandbox;

/// Primary cursor's insert-session, saved across nested edit() sessions during insert-cascade.
typedef struct {
  InsState ins;
  varnumber_T last_changedtick;
  varnumber_T last_changedtick_i;
} McInsSaved;

#include "mcursor.c.generated.h"

/// Insert-cascade state.
///
/// PREVIEW/COMMIT model: the entry command ("A"/"cw") replays at each cursor on insert enter;
/// while the user types, the primary's inserted text (`region` extmark) previews as literal text
/// at each cursor; at session-end the previews are deleted and typed keys (batch) replay at each
/// cursor (the COMMIT: abbreviations, 'textwidth', … re-execute per cursor).
///
/// XXX: Why text preview instead of LHS-replay? Two things cannot LHS-replay:
/// 1. ins-completion
/// 2. pending keys are not an append-only stream (compl/abbrevs rewrite them mid-session)
///
/// The boundary:
/// - literal text is previewed
/// - non-literal keys (mc_ins_keys_nonliteral) have per-cursor effects, so flush (early commit).
static struct {
  bool active;      ///< Current insert-session is cascading.
  bool first;       ///< Entry-command not yet cascaded (no span pushed yet).
  size_t done_len;  ///< Bytes of the capture already consumed by replayed spans; tail is pending.
  varnumber_T tick;  ///< b:changedtick at session start: the session's atoms (spans, the whole
                     ///< session) diff against it for their `changed` field.
  uint32_t region;  ///< Extmark (pair) tracking the primary's inserted text.
  kvec_t(uint32_t) regions;  ///< Per-cursor extmarks (pairs, `mc_session_ns()`) tracking each
                             ///< cursor's preview region (anchor .. preview end).
} mc_ins_span;

/// Editor state when the mc session started, which every cursor replays against.
static struct {
  Timestamp time;  ///< When the session started (nanoseconds).
  Context regs;    ///< Registers. Perf: per-cursor registers are "sparse", merged later.
} mc_start = { .regs = CONTEXT_INIT };

/// Registers that can carry per-cursor values (skips the read-only/special ones).
static const char MC_REGS[] = "abcdefghijklmnopqrstuvwxyz0123456789\"-";

/// Buffer holding the fake Visual selections (0: none).
static handle_T mc_vsel_buf;
/// Primary cursor's current insert span deleted a line break (BS/CTRL-U at col 0).
static bool mc_ins_joined;
/// The mcursors, in creation order. Each is a Context snapshot: an extmark-tracked position
/// plus editor state (registers) scoped to that cursor.
static ContextVec mc_cursors = KV_INITIAL_VALUE;
/// Replay is in progress: keys re-executing internally, hooks suppressed.
static bool mc_replay = false;
/// "Follow motion" mode ("q="): cascade primary-cursor motions to all mcursors.
static bool mc_follow_motion = false;

/// Namespace for tracking multicursor positions.
static uint32_t mc_ns(void)
{
  static uint32_t ns = 0;
  if (ns == 0) {
    ns = (uint32_t)nvim_create_namespace(STATIC_CSTR_AS_STRING("nvim.multicursor"));
  }
  return ns;
}

/// Namespace for the selection-end cursors. While they exist they are the display positions;
/// "nvim.multicursor" holds the selection anchors.
static uint32_t mc_vcur_ns(void)
{
  static uint32_t ns = 0;
  if (ns == 0) {
    ns = (uint32_t)nvim_create_namespace(STATIC_CSTR_AS_STRING("nvim.multicursor.cursor"));
  }
  return ns;
}

/// Namespace for the fake Visual selections.
static uint32_t mc_vsel_ns(void)
{
  static uint32_t ns = 0;
  if (ns == 0) {
    ns = (uint32_t)nvim_create_namespace(STATIC_CSTR_AS_STRING("nvim.multicursor.visual"));
  }
  return ns;
}

/// Namespace for the previous session's cursor positions, snapshotted on clear ("gQ" restores).
static uint32_t mc_last_ns(void)
{
  static uint32_t ns = 0;
  if (ns == 0) {
    ns = (uint32_t)nvim_create_namespace(STATIC_CSTR_AS_STRING("nvim.multicursor.last"));
  }
  return ns;
}

/// Namespace for session-internal marks (live text region, transient primary-cursor tracker).
static uint32_t mc_session_ns(void)
{
  static uint32_t ns = 0;
  if (ns == 0) {
    ns = (uint32_t)nvim_create_namespace(STATIC_CSTR_AS_STRING("nvim.multicursor._session"));
  }
  return ns;
}

/// Number of mcursors, excluding the primary cursor. 0: no multicursor session.
size_t mc_count(void)
{
  return kv_size(mc_cursors);
}

/// Formats the multicursor 'showcmd' indicator ("=3× ") into `buf`.
///
/// @return  Length in bytes; 0 (buf="") if there are no cursors.
size_t mc_showcmd(char *buf, size_t size)
{
  if (kv_size(mc_cursors) == 0) {
    buf[0] = NUL;
    return 0;
  }
  return (size_t)snprintf(buf, size, "%s%zu× ", mc_follow_motion ? "=" : "", kv_size(mc_cursors));
}

/// True during a replay: re-executing keys internally, not new user input.
bool mc_replaying(void)
{
  return mc_replay;
}

/// Sets an extmark which tracks a position. Decor handled by mcursor.lua. TODO(justinmk): #41576
///
/// @param watched        Decorated (ui_watched): UIs receive the position per redraw (ui-event
///                       "win_extmark"), to draw the cursors themselves.
/// @param right_gravity  The mark moves with its text when an insert lands exactly at its
///                       position (e.g. "o" on the line above).
/// @param no_undo        Transient mark, undo must not restore it (a restored right-gravity mark
///                       drifts when undo re-inserts text at its position).
static void mc_mark_set(buf_T *buf, uint32_t ns, uint32_t *mark, pos_T pos, bool watched,
                        bool right_gravity, bool no_undo)
{
  DecorInline decor = DECOR_INLINE_INIT;
  if (watched) {
    decor.data.hl.flags = kSHUIWatched | kSHUIWatchedOverlay;
  }
  extmark_set(buf, ns, mark, (int)pos.lnum - 1, pos.col, (int)pos.lnum - 1, pos.col + 1,
              decor, watched ? MT_FLAG_DECOR_HL : 0, right_gravity, false, no_undo, false, NULL);
}

/// Creates or updates the extmark tracking a multicursor position.
static void mc_mark_upd(buf_T *buf, uint32_t *mark, pos_T pos)
{
  mc_mark_set(buf, mc_ns(), mark, pos, true, true, false);
}

/// Gets the position tracked by `mark`, adjusted for buffer edits since the mark was set.
///
/// @return false if the mark no longer exists.
static bool mc_mark_get(buf_T *buf, uint32_t ns, uint32_t mark, pos_T *pos)
{
  MTPair mtp = extmark_from_id(buf, ns, mark);
  if (mtp.start.id == 0) {
    return false;
  }
  pos->lnum = mtp.start.pos.row + 1;
  pos->col = mtp.start.pos.col;
  return true;
}

/// Session-internal variant of mc_mark_upd(): tracks a transient position (primary cursor/topline
/// across a cascade, the preview-apply cursor).
static void mc_track_upd(buf_T *buf, uint32_t *mark, pos_T pos)
{
  mc_mark_set(buf, mc_session_ns(), mark, pos, false, true, true);
}

/// Enters a replay sandbox, so keys fed (cascaded) per-cursor do not modify pending typeahead nor
/// the primary-cursor state.
///
/// @param save_regs  Registers too. Perf: skipped for pure motions.
static void mc_sandbox_enter(McSandbox *sb, bool save_regs)
{
  assert(!mc_replay);
  mc_replay = true;  // Capture hooks will ignore keys fed during the sandbox.
  sb->bufnr = curbuf->handle;
  sb->cursor = curwin->w_cursor;
  sb->curswant = curwin->w_curswant;
  sb->set_curswant = curwin->w_set_curswant;
  sb->leftcol = curwin->w_leftcol;
  sb->cursor_mark = 0;
  mc_track_upd(curbuf, &sb->cursor_mark, sb->cursor);
  sb->topline = (pos_T){ .lnum = curwin->w_topline, .col = 0 };
  sb->topline_mark = 0;
  mc_track_upd(curbuf, &sb->topline_mark, sb->topline);
  sb->visual = Visual;
  // Change/Visual marks belong to the primary cursor's (already executed) operation.
  // (jumplist/changelist are protected per replay, via CMOD_KEEPJUMPS.)
  sb->op_start = curbuf->b_op_start;
  sb->op_end = curbuf->b_op_end;
  sb->last_change = curbuf->b_last_change;
  sb->bvisual = curbuf->b_visual;
  sb->bvisual_mode = curbuf->b_visual_mode_eval;
  save_current_state(&sb->sst);  // hint: see call_user_func()
  save_search_patterns();
  save_redobuff(&sb->redo);
  sb->regs = (Context)CONTEXT_INIT;
  if (save_regs) {
    ctx_save(&sb->regs, kCtxRegs);
  }
}

/// @see mc_sandbox_enter
static void mc_sandbox_leave(McSandbox *sb)
{
  if (sb->regs.regs.data != NULL) {
    ctx_load(&sb->regs, kCtxRegs, 0);
  }
  ctx_free(&sb->regs);
  restore_redobuff(&sb->redo);
  restore_search_patterns();
  restore_current_state(&sb->sst);
  // Visual before the cursor restore: check_cursor() below must see the restored mode (a
  // blockwise 'virtualedit' selection would otherwise lose the cursor's coladd).
  Visual = sb->visual;
  buf_T *buf = handle_get_buffer(sb->bufnr);
  bool topline_valid = false;
  if (buf != NULL) {
    // mc_mark_get() updates lnum/col only, an unshifted position keeps its coladd.
    mc_mark_get(buf, mc_session_ns(), sb->cursor_mark, &sb->cursor);
    extmark_del_id(buf, mc_session_ns(), sb->cursor_mark);
    topline_valid = mc_mark_get(buf, mc_session_ns(), sb->topline_mark, &sb->topline);
    extmark_del_id(buf, mc_session_ns(), sb->topline_mark);
  }
  if (buf == curbuf) {
    curbuf->b_op_start = sb->op_start;
    curbuf->b_op_end = sb->op_end;
    curbuf->b_last_change = sb->last_change;
    curbuf->b_visual = sb->bvisual;
    curbuf->b_visual_mode_eval = sb->bvisual_mode;
    curwin->w_cursor = sb->cursor;
    check_cursor(curwin);
    curwin->w_curswant = sb->curswant;
    curwin->w_set_curswant = sb->set_curswant;
    if (topline_valid) {
      set_topline(curwin, MIN(sb->topline.lnum, curbuf->b_ml.ml_line_count));
      // Scroll (minimally) if an edit moved the primary cursor off-view.
      update_topline(curwin);
    }
    curwin->w_leftcol = sb->leftcol;
  }
  mc_replay = false;
}

/// Cascade step: replays an atom at `cursoridx`, then updates Context.
static void mc_execute(size_t cursoridx, size_t atomidx)
{
  Context ctx = kv_A(mc_cursors, cursoridx);
  CmdAtom atom = kv_A(g_atoms, atomidx);

  if (handle_get_buffer(ctx.buf) != curbuf) {
    // Cursors cascade only if their buffer is the current buffer.
    return;
  }

  // Get the tracked position: edits by other cursors (etc) may have shifted it since last update.
  if (ctx.mark != 0 && !mc_mark_get(curbuf, mc_ns(), ctx.mark, &ctx.pos)) {
    // The extmark was deleted, thus the cursor is deleted (swept by mc_dedupe()).
    return;
  }

  curwin->w_cursor = ctx.pos;
  // Edits by other cursors may have invalidated this cursor's position.
  if (atom.type == kAInsertSpan) {
    // The anchor may be one past EOL (the insertion point); edit() accepts that.
    // Not check_cursor(): would clamp onto last char (a previous span may have set MODE_NORMAL).
    check_pos(curbuf, &curwin->w_cursor);
  } else {
    check_cursor(curwin);
  }
  // Per-cursor `curswant`: vertical motions over short lines must not inherit the primary's column.
  // Unset: derive from the position, like a new cursor.
  if (ctx.curswant >= 0) {
    curwin->w_curswant = ctx.curswant;
    curwin->w_set_curswant = false;
  } else {
    curwin->w_set_curswant = true;
  }

  // Perf: skip register serialization for motions, so "l" in "follow mode" is fast.
  const bool swap_regs = atom.type != kAMotion;
  Timestamp regs_ts = 0;
  if (swap_regs) {
    if (reg_max_ts(false) >= mc_start.time) {
      // Registers written globally are the previous cursor's; reset to baseline.
      ctx_load(&mc_start.regs, kCtxRegs, 0);
    }
    if (ctx.regs.data != NULL) {
      ctx_load(&ctx, kCtxRegs, kCtxMergeReg);  // This cursor's own writes; merge w/ baseline.
    }
    regs_ts = reg_max_ts(false);
  }
  const int save_cmod_flags = cmdmod.cmod_flags;
  if (atom.type == kAInsertSpan) {
    // exec_normal() clamps a past-EOL cursor via check_cursor() unless Insert-mode; a previous span
    // replay may have left MODE_NORMAL, making later cursors insert one char left of their anchor.
    State = MODE_INSERT;
  } else {
    // Navigation state belongs to the primary, replays must not touch it. Not for insert-span
    // replays: their anchor needs '^, and the primary insert-session (re)sets these anyway.
    cmdmod.cmod_flags |= CMOD_KEEPJUMPS;
  }

  // Replay the atom using wholesome, tasty feedkeys. Usually noremap ("nix"), but `atom.remap=true`
  // means we must replay LHS (re-run the mapping at cursor, e.g. vim-surround "ds'").
  nvim_feedkeys(cstr_as_string(atom.keys), cstr_as_string(atom.remap ? "ix" : "nix"), false);
  cmdmod.cmod_flags = save_cmod_flags;

  // A failed command flushes remaining keys (beep_flush()), which can eat a visual atom's
  // terminating <Esc>/operator; end the leaked Visual mode.
  if (Visual.active) {
    Visual.active = false;
    Visual.select = false;
  }

  const bool wrote_regs = swap_regs && reg_max_ts(false) != regs_ts;

  if (cursoridx >= kv_size(mc_cursors)) {
    // Cursors were removed while replaying (e.g. gQ via autocmd); already freed.
    return;
  }

  if (wrote_regs) {
    // Re-encode this cursor's registers, as a delta vs mc_start.regs (for performance).
    api_free_string(ctx.regs);
    ctx.regs = shada_encode_regs(false, mc_start.time);
  }

  update_curswant();
  ctx.curswant = curwin->w_curswant;

  if (atom.type == kAInsertSpan && curbuf->b_last_insert.mark.lnum > 0) {
    // Anchor at the insertion point ('^ mark): this is where the primary cursor, still in Insert
    // mode, displays its cursor, and where the next span continues inserting.
    ctx.pos = curbuf->b_last_insert.mark;
  } else {
    ctx.pos = curwin->w_cursor;
  }
  // The extmark's decor redraws both the old and the new line (extmark_set()).
  mc_mark_upd(curbuf, &ctx.mark, ctx.pos);
  kv_A(mc_cursors, cursoridx) = ctx;  // Update the cursor info.
}

/// Runs the cascade: replays queued atoms (g_atoms) at every cursor, as one batch.
static void mc_cascade(void)
{
  assert(kv_size(g_atoms) >= 1);
  assert(kv_size(mc_cursors) > 0);
  assert(!mc_replaying());

  // Consume a pending interrupt: CTRL-C already did its job, it should not also abort the replays.
  // Note: a new CTRL-C still aborts the cascade; consume BEFORE the dedupe below.
  got_int = false;

  // Merge overlapping cursors before replaying an edit. Not for pure-motion cascades ("q=" follow):
  // an overlap with the primary is transient, that cursor is about to make the same move.
  bool edits = false;
  for (size_t i = 0; i < kv_size(g_atoms); i++) {
    edits |= kv_A(g_atoms, i).type != kAMotion;
  }
  if (edits) {
    mc_dedupe();
    if (kv_size(mc_cursors) == 0) {
      atoms_free(&g_atoms);
      return;
    }
  }
  // Optimization: one clipboard-provider sync for the whole cascade.
  start_batch_changes();
  McSandbox sb;
  mc_sandbox_enter(&sb, edits);

  // Replay each atom at each cursor (nested ":norm! xx" queues multiple atoms per clock edge).
  for (size_t ai = 0; ai < kv_size(g_atoms); ai++) {
    CmdAtom *atom = &kv_A(g_atoms, ai);
    if (atom->origin.buf.br_buf != NULL
        && (!bufref_valid(&atom->origin.buf) || atom->origin.buf.br_buf != curbuf)) {
      // Cascade only in the atom's origin buffer (a mapping may switch buffers).
      // Assume untagged atoms (atom_lhs_replay_queue()) are current-buffer.
      continue;
    }
    for (size_t ci = 0; ci < kv_size(mc_cursors); ci++) {
      // Replays consume `typebuf` only, so check for CTRL-C in OS/RPC input here.
      line_breakcheck();
      if (got_int) {
        // Interrupted (CTRL-C), abort the cascade. Keep the partial edit; a "u" will undo it.
        goto done;
      }
      mc_execute(ci, ai);
    }
  }
done:
  atoms_free(&g_atoms);
  mc_sandbox_leave(&sb);
  end_batch_changes();
  mc_dedupe();
  if (handle_get_buffer(sb.bufnr) == curbuf && !curbuf->b_u_synced
      && curbuf->b_u_newhead != NULL) {
    // Store the primary's post-cascade position in the still-open undo block; redo restores it.
    curbuf->b_u_newhead->uh_cursor_after = curwin->w_cursor;
  }
}

/// The clock edge: cascades the queued atoms (g_atoms) at every cursor. Called from
/// atom_cmd_end(), at the completion of a toplevel, typed command.
///
/// @param map_edit  A command fed by a mapping edited the buffer (or was insert-cascaded): the
///                  whole mapping cascades as one unit, including its motions.
void mc_clock_edge(bool map_edit)
{
  if (map_edit && !atom_composite_queued() && kv_size(g_atoms) == 0
      && atom_composite_active() && mc_buf_has_cursors(curbuf)) {
    // A payload mapping (vim-surround "ds'"/"S") edited the buffer via :norm/:call, invisible to
    // atom capture, so nothing was queued. Fallback to LHS-replay.
    atom_lhs_replay_queue();
  }
  if (mc_buf_has_cursors(curbuf) && kv_size(g_atoms) > 0) {
    bool has_edit = map_edit;
    for (size_t i = 0; !has_edit && i < kv_size(g_atoms); i++) {
      has_edit = kv_A(g_atoms, i).type != kAMotion;
    }
    if (has_edit || mc_follow_motion) {
      mc_cascade();
    } else {
      // A pure-motion mapping without "q=" follow-motion: do not cascade
      // (the atoms are still emitted as one composite CmdAtom).
      atoms_free(&g_atoms);
    }
  }
}

/// Prunes cursors that overlap others, so an edit does not apply N times at one position.
static void mc_dedupe(void)
{
  const bool had_cursors = kv_size(mc_cursors) > 0;
  size_t n = 0;
  for (size_t i = 0; i < kv_size(mc_cursors); i++) {
    Context *ctx = &kv_A(mc_cursors, i);
    buf_T *buf = handle_get_buffer(ctx->buf);
    if (buf == NULL
        || (ctx->mark != 0 && !mc_mark_get(buf, mc_ns(), ctx->mark, &ctx->pos))) {
      // Buffer was freed, or the cursor's extmark was deleted.
      ctx_free(ctx);
      continue;
    }
    // This cursor is a duplicate (to sweep) if it coincides with the primary (which always
    // wins), or another cursor's mark is first at its position (first-wins tiebreak).
    const bool dup = ctx->mark != 0
                     && ((curwin != NULL && buf == curbuf && equalpos(ctx->pos, curwin->w_cursor))
                         || mc_mark_at(buf, ctx->pos) != ctx->mark);
    if (dup) {
      extmark_del_id(buf, mc_ns(), ctx->mark);
      ctx_free(ctx);
    } else {
      kv_A(mc_cursors, n) = *ctx;
      n++;
    }
  }
  kv_size(mc_cursors) = n;
  if (n == 0) {
    // Session ended implicitly ("q=" + "G" deduped all cursors). Reset "q=".
    mc_follow_motion = false;
    if (had_cursors) {
      ctx_free(&mc_start.regs);
      mc_start.regs = (Context)CONTEXT_INIT;
      mc_start.time = 0;
      mc_lua_enable(false);
    }
  }
}

/// Called when insert-mode backspacing deletes a linebreak.
void mc_ins_join(void)
{
  if (!mc_replaying()) {
    mc_ins_joined = true;
  }
}

/// Decides if a replay may delete a linebreak: only if the primary's own span did. A replayed
/// BS/CTRL-U reaching col 0 where the primary's had more to delete must not join, it could collapse
/// other cursors' lines into one.
bool mc_ins_replay_can_join(void)
{
  return !mc_replaying() || mc_ins_joined;
}

/// Starts an insert-cascade. Call before entering insert mode from a normal-mode command.
///
/// @param cascade  The session qualifies for insert-cascading.
/// @param tick     b:changedtick at session start.
void mc_ins_cascade_start(bool cascade, varnumber_T tick)
{
  if (mc_replaying()) {
    // Nested replay session: don't clobber the primary session's state.
    return;
  }
  mc_ins_joined = false;
  mc_ins_span.active = cascade && mc_buf_has_cursors(curbuf) && kv_size(g_atoms) == 0;
  mc_ins_span.first = true;
  mc_ins_span.done_len = 0;
  mc_ins_span.tick = tick;
  mc_ins_span.region = 0;
  mc_ins_regions_clear();
}

/// True during a span replay. The replay's synthetic <Esc> does not end the primary insert-session,
/// so session-end cleanup must not run.
bool mc_ins_replaying(void)
{
  return mc_replaying() && mc_ins_span.active;
}

/// Saves the primary's insert-session state: each span replay runs a nested edit().
static McInsSaved mc_ins_save_state(void)
{
  McInsSaved saved;
  saved.ins = Ins;
  // The span replay starts clean, like a new session.
  Ins.did_ai = false;
  Ins.ai_col = 0;
  Ins.end_comment_pending = NUL;
  Ins.did_si = false;
  Ins.can_si = false;
  Ins.can_si_back = false;
  // The nested sessions advance these even with autocmds blocked; unrestored, the primary
  // session's pending TextChanged(I) would be swallowed (no tick delta left).
  saved.last_changedtick = curbuf->b_last_changedtick;
  saved.last_changedtick_i = curbuf->b_last_changedtick_i;
  return saved;
}

static void mc_ins_restore_state(const McInsSaved *saved)
{
  Ins = saved->ins;
  curbuf->b_last_changedtick = saved->last_changedtick;
  curbuf->b_last_changedtick_i = saved->last_changedtick_i;
}

/// Pushes one span and immediately cascades it. Takes ownership of `keys` and `text`.
static void mc_ins_span_push(char *keys, char *text)
{
  mc_ins_span.first = false;
  // If all cursors disappear mid-session (e.g. by dedupe), emit but don't cascade.
  bool cascade = mc_buf_has_cursors(curbuf);
  atom_push_raw(cascade, &(CmdAtom){
    .type = kAInsertSpan,
    .keys = keys,
    .text = text,
    .changed = buf_get_changedtick(curbuf) != mc_ins_span.tick,
  });
  if (!cascade) {
    return;
  }
  McInsSaved saved = mc_ins_save_state();
  block_autocmds();  // The span replay would fire InsertEnter/InsertLeave on every key.
  mc_cascade();
  unblock_autocmds();
  mc_ins_restore_state(&saved);
  mc_ins_joined = false;  // The next span decides whether its replays may join.
}

/// Deletes the per-cursor preview-region marks.
static void mc_ins_regions_clear(void)
{
  while (kv_size(mc_ins_span.regions) > 0) {
    extmark_del_id(curbuf, mc_session_ns(), kv_pop(mc_ins_span.regions));
  }
}

/// Resolves cursor's tracked position.
///
/// @return  False: the cursor is in another buffer, or its mark is gone.
static bool mc_ctx_resolve(const Context *ctx, pos_T *pos)
{
  return handle_get_buffer(ctx->buf) == curbuf && ctx->mark != 0
         && mc_mark_get(curbuf, mc_ns(), ctx->mark, pos);
}

/// Places a paired session mark at `pos` (left-gravity anchor .. right-gravity end): text
/// inserted at `pos` lands inside the pair.
static void mc_region_mark_set(uint32_t *mark, pos_T pos)
{
  // no_undo: an undo-recorded extmark op mid-session breaks stop_arrow().
  extmark_set(curbuf, mc_session_ns(), mark, (int)pos.lnum - 1, pos.col,
              (int)pos.lnum - 1, pos.col, (DecorInline)DECOR_INLINE_INIT, 0,
              false, true, true, false, NULL);
}

/// (Re)places the primary text-region mark at the cursor, and a per-cursor paired mark tracking
/// each cursor's preview region. The preview text lands between the pair, exactly like the
/// primary's `region` mark).
static void mc_ins_preview_rebase(void)
{
  mc_region_mark_set(&mc_ins_span.region, curwin->w_cursor);
  mc_ins_regions_clear();
  for (size_t i = 0; i < kv_size(mc_cursors); i++) {
    Context *ctx = &kv_A(mc_cursors, i);
    pos_T pos;
    uint32_t mark = 0;
    if (mc_ctx_resolve(ctx, &pos)) {
      mc_region_mark_set(&mark, pos);
      kv_push(mc_ins_span.regions, mark);
    }
  }
}

/// First live per-cursor preview region, or `start.id == 0` if none. A live region's buffer
/// content is the applied preview text, and start == end means no preview is applied.
static MTPair mc_ins_region_first(void)
{
  for (size_t i = 0; i < kv_size(mc_ins_span.regions); i++) {
    MTPair p = extmark_from_id(curbuf, mc_session_ns(), kv_A(mc_ins_span.regions, i));
    if (p.start.id != 0) {
      return p;
    }
  }
  return (MTPair){ 0 };
}

/// The buffer range of paired region mark `p`.
static void mc_region_range(MTPair p, pos_T *start, pos_T *end)
{
  *start = (pos_T){ .lnum = p.start.pos.row + 1, .col = p.start.pos.col };
  *end = (pos_T){ .lnum = p.end_pos.row + 1, .col = p.end_pos.col };
}

/// Replaces buffer text (end-exclusive) with `text` (multiline), preserving marks and undo.
static void mc_ins_preview_replace(pos_T start, pos_T end, const String *text)
{
  Arena arena = ARENA_EMPTY;
  Error err = ERROR_INIT;
  char *data = text->data != NULL ? text->data : (char *)"";  // Empty text (a delete) => NULL data.
  size_t nlines = 1;
  for (size_t i = 0; i < text->size; i++) {
    nlines += data[i] == NL;
  }
  Array lines = arena_array(&arena, nlines);
  size_t start_i = 0;
  for (size_t i = 0; i <= text->size; i++) {
    if (i == text->size || data[i] == NL) {
      ADD_C(lines, STRING_OBJ(cbuf_as_string(data + start_i, i - start_i)));
      start_i = i + 1;
    }
  }
  nvim_buf_set_text(LUA_INTERNAL_CALL, 0, start.lnum - 1, start.col,
                    end.lnum - 1, end.col, lines, &arena, &err);
  if (ERROR_SET(&err)) {
    DLOG("preview replace failed: %s", err.msg);
    api_clear_error(&err);
  }
  arena_mem_free(arena_finish(&arena));
}

/// Sets `text` as the preview at every cursor, replacing the previous one.
static void mc_ins_preview_set(const String *new)
{
  // The primary's own insert session must not notice the preview edits.
  McInsSaved saved = mc_ins_save_state();
  // Track the primary cursor across the preview edits.
  uint32_t primary = 0;
  mc_track_upd(curbuf, &primary, curwin->w_cursor);
  for (size_t i = 0; i < kv_size(mc_ins_span.regions); i++) {
    MTPair p = extmark_from_id(curbuf, mc_session_ns(), kv_A(mc_ins_span.regions, i));
    if (p.start.id == 0) {
      continue;  // A script deleted the extmark mid-session.
    }
    // Cursor display mark (right-gravity) is pushed by the replacement to the new preview end.
    pos_T rs, re;
    mc_region_range(p, &rs, &re);
    mc_ins_preview_replace(rs, re, new);
  }
  pos_T pos = curwin->w_cursor;
  if (mc_mark_get(curbuf, mc_session_ns(), primary, &pos)) {
    curwin->w_cursor = pos;
  }
  extmark_del_id(curbuf, mc_session_ns(), primary);
  mc_ins_restore_state(&saved);
}

/// Deletes the preview at every cursor.
static void mc_ins_preview_del(void)
{
  static const String empty = STRING_INIT;
  mc_ins_preview_set(&empty);
}

/// True if `keys` has a non-literal key (kKeyInsFlush): a literal preview cannot represent it.
static bool mc_ins_keys_nonliteral(const char *keys, size_t len)
{
  for (size_t i = 0; i < len; i++) {
    int key = (uint8_t)keys[i];
    if (key == K_SPECIAL && i + 2 < len) {
      key = TO_SPECIAL((uint8_t)keys[i + 1], (uint8_t)keys[i + 2]);
      i += 2;
    }
    if ((atom_key_class(key, NUL) & kKeyInsFlush) != 0) {
      return true;
    }
  }
  return false;
}

/// Capture restarted mid insert-session (stop_arrow(), after a non-captured cursor-move: mouse,
/// <PageUp>, …). The previews stay; rebase and continue the insert-cascade.
void mc_ins_cascade_restart(void)
{
  if (!mc_ins_span.active || mc_replaying() || !(State & MODE_INSERT)
      || !mc_buf_has_cursors(curbuf) || kv_size(g_atoms) != 0) {
    return;
  }
  String ins = redo_keys(NULL);
  mc_ins_span.done_len = ins.size;
  api_free_string(ins);
  mc_ins_preview_rebase();
}

/// Insert-cascades the session. Called after each key in insert-mode; extends the preview or
/// flushes a span and cascades it.
void mc_ins_cascade(void)
{
  if (!mc_ins_span.active || mc_replaying() || !(State & MODE_INSERT)
      || !mc_buf_has_cursors(curbuf) || kv_size(g_atoms) != 0) {
    return;
  }
  String ins = redo_keys(NULL);
  if (mc_ins_span.first) {
    // Not with a pending autoindent ("o" + 'autoindent'): the entry span's replay ends in <Esc>,
    // which would delete the indent.
    if (!Ins.did_ai && ins.data != NULL && ins.size > 0) {
      // Entry replay.
      StringBuilder keys = KV_INITIAL_VALUE;
      kv_concat_len(keys, ins.data, ins.size);
      kv_push(keys, ESC);
      kv_push(keys, NUL);
      mc_ins_span.done_len = ins.size;
      mc_ins_span_push(keys.items, NULL);
      mc_ins_preview_rebase();
    }
  } else if (ins.data != NULL && ins.size < mc_ins_span.done_len) {
    // Capture shrank without a restart signal, e.g. completion surgery rewrote the pending keys.
    mc_ins_cascade_restart();
  } else if (ins.size > mc_ins_span.done_len
             && mc_ins_keys_nonliteral(ins.data + mc_ins_span.done_len,
                                       ins.size - mc_ins_span.done_len)) {
    // Non-literal keys pending (BS, CTRL-U, …): re-execute instead of previewing.
    // Not during completion: edit() would raise E565. #41602
    if (!ins_compl_active() && !pum_visible()) {
      mc_ins_span_flush(&ins, false);
    }
  } else {
    MTPair p = extmark_from_id(curbuf, mc_session_ns(), mc_ins_span.region);
    if (p.start.id != 0) {
      pos_T rs, re;
      mc_region_range(p, &rs, &re);
      String text = ml_region_text(curbuf, rs, re);
      // Skip the re-apply if the previews already hold this text (first live region == primary's).
      bool applied = false;
      MTPair fp = mc_ins_region_first();
      if (fp.start.id != 0) {
        pos_T frs, fre;
        mc_region_range(fp, &frs, &fre);
        String cur = ml_region_text(curbuf, frs, fre);
        applied = cur.size == text.size
                  && (text.size == 0 || memcmp(cur.data, text.data, text.size) == 0);
        api_free_string(cur);
      }
      if (!applied) {
        mc_ins_preview_set(&text);
      }
      api_free_string(text);
    }
  }
  api_free_string(ins);
}

/// Flushes a span from the capture tail and cascades it: deletes the previews, then replays the
/// pending keys ("i" + tail) at each cursor.
///
/// @param commit  Session-end flush: the tail already ends with <Esc>; attach the "."-register text
///                and don't rebase. Else, mid-session flush: append <Esc> to end the replayed
///                session, and rebase for the continuing preview.
static void mc_ins_span_flush(const String *ins, bool commit)
{
  MTPair fp = mc_ins_region_first();
  if (fp.start.id != 0
      && (fp.start.pos.row != fp.end_pos.row || fp.start.pos.col != fp.end_pos.col)) {
    mc_ins_preview_del();
  }
  size_t dlen = ins->size - mc_ins_span.done_len;
  StringBuilder keys = KV_INITIAL_VALUE;
  kv_push(keys, 'i');
  kv_concat_len(keys, ins->data + mc_ins_span.done_len, dlen);
  if (!commit) {
    kv_push(keys, ESC);
  }
  kv_push(keys, NUL);
  char *text = commit && dlen > 1 ? xmemdupz(ins->data + mc_ins_span.done_len, dlen - 1) : NULL;
  mc_ins_span.done_len = ins->size;
  mc_ins_span_push(keys.items, text);
  if (!commit) {
    mc_ins_preview_rebase();
  }
}

/// Reads `reg` (current global state), allocated, one trailing newline stripped; "" if empty.
static char *mc_reg_read(int reg)
{
  char *s = get_reg_contents(reg, 0);
  if (s == NULL) {
    return xstrdup("");
  }
  size_t len = strlen(s);
  if (len > 0 && s[len - 1] == NL) {
    s[len - 1] = NUL;
  }
  return s;
}

/// qsort() comparator, document-order (lnum, then col).
static int mc_ctx_pos_cmp(const void *a, const void *b)
{
  const Context *ca = *(Context *const *)a;
  const Context *cb = *(Context *const *)b;
  if (ca->pos.lnum != cb->pos.lnum) {
    return ca->pos.lnum < cb->pos.lnum ? -1 : 1;
  }
  return ca->pos.col == cb->pos.col ? 0 : (ca->pos.col < cb->pos.col ? -1 : 1);
}

/// On exit, any registers the user yanked-to are newline-concatenated (document-order)
/// and written to the primary-cursor registers.
static void mc_reg_gather(void)
{
  if (kv_size(mc_cursors) == 0
      // Exiting: windows were freed, shada was already written.
      || exiting) {
    return;
  }
  // Decide which registers were written this session, before updating (which bumps timestamps).
  bool gather[sizeof(MC_REGS)] = { false };
  bool any = false;
  for (int i = 0; MC_REGS[i] != NUL; i++) {
    const int r = (uint8_t)MC_REGS[i];
    const int idx = r == '"' ? get_unname_register() : op_reg_index(r);
    if (idx >= 0 && get_y_register(idx)->timestamp >= mc_start.time) {
      gather[i] = any = true;
    }
  }
  if (!any) {
    return;
  }

  // Sort primary + cursors by position: the reg join below concatenates in document-order.
  Context primary = { .pos = curwin->w_cursor, .regs = shada_encode_regs(false, mc_start.time) };
  kvec_t(Context *) order = KV_INITIAL_VALUE;
  kv_push(order, &primary);
  for (size_t c = 0; c < kv_size(mc_cursors); c++) {
    Context *ctx = &kv_A(mc_cursors, c);
    if (ctx->regs.size > 0 && handle_get_buffer(ctx->buf) == curbuf) {
      kv_push(order, ctx);
    }
  }
  if (kv_size(order) == 1) {  // No cursor registers to join (buffer disappeared?).
    kv_destroy(order);
    api_free_string(primary.regs);
    return;
  }
  qsort(order.items, kv_size(order), sizeof(Context *), mc_ctx_pos_cmp);
  Context save = CONTEXT_INIT;
  ctx_save(&save, kCtxRegs);  // Primary's registers, restored after the reads.

  // Join each gathered register's non-empty values.
  kvec_t(char) joined[sizeof(MC_REGS)] = { { 0, 0, NULL } };
  for (size_t o = 0; o < kv_size(order); o++) {
    // Exact (not merged):
    ctx_load(kv_A(order, o), kCtxRegs, 0);
    for (int i = 0; MC_REGS[i] != NUL; i++) {
      if (!gather[i]) {
        continue;
      }
      char *text = mc_reg_read(MC_REGS[i]);
      if (*text != NUL) {
        if (kv_size(joined[i]) > 0) {
          kv_push(joined[i], NL);
        }
        kv_concat(joined[i], text);
      }
      xfree(text);
    }
  }
  kv_destroy(order);
  api_free_string(primary.regs);
  ctx_load(&save, kCtxRegs, 0);  // Restore the primary's registers.
  ctx_free(&save);

  // Write each register back linewise. Skip an empty join (every value was empty).
  for (int i = 0; MC_REGS[i] != NUL; i++) {
    if (gather[i] && kv_size(joined[i]) > 0) {
      write_reg_contents_ex(MC_REGS[i], joined[i].items, (ssize_t)kv_size(joined[i]), false,
                            kMTLineWise, 0);
    }
    kv_destroy(joined[i]);
  }
}

/// Removes the fake Visual selections, clears their namespaces.
void mc_vsel_clear(void)
{
  buf_T *buf = handle_get_buffer(mc_vsel_buf);
  if (buf != NULL) {
    extmark_clear(buf, mc_vsel_ns(), 0, 0, MAXLNUM, MAXCOL);
    extmark_clear(buf, mc_vcur_ns(), 0, 0, MAXLNUM, MAXCOL);
  }
  mc_vsel_buf = 0;
}

/// Stores a fake-selection range (end-exclusive) as an extmark.
static void mc_vsel_mark(linenr_T start_lnum, colnr_T start_col, linenr_T end_lnum, colnr_T end_col)
{
  DecorInline decor = DECOR_INLINE_INIT;
  decor.data.hl.hl_id = syn_check_group(S_LEN("MCursorVisual"));
  uint32_t mark = 0;
  extmark_set(curbuf, mc_vsel_ns(), &mark, (int)start_lnum - 1, start_col,
              (int)end_lnum - 1, end_col, decor, MT_FLAG_DECOR_HL,
              false, false, true, false, NULL);
  mc_vsel_buf = curbuf->handle;
}

/// Displays a fake Visual selection at each cursor, mirroring the primary cursor's selection.
void mc_vsel_refresh(void)
{
  mc_vsel_clear();
  String span = atom_visual_span();
  if (span.data == NULL || span.size == 0 || !mc_buf_has_cursors(curbuf)) {
    xfree(span.data);
    return;
  }

  McSandbox sb;  // Save the primary-cursor state (selection included), like a cascade replay.
  mc_sandbox_enter(&sb, false);
  block_autocmds();
  emsg_silent++;
  // Dry-run motions must not touch the jumplist/changelist ("%", "(", …).
  const int save_cmod_flags = cmdmod.cmod_flags;
  cmdmod.cmod_flags |= CMOD_KEEPJUMPS;

  for (size_t i = 0; i < kv_size(mc_cursors); i++) {
    Context *ctx = &kv_A(mc_cursors, i);
    pos_T pos;
    if (!mc_ctx_resolve(ctx, &pos)) {
      continue;
    }
    curwin->w_cursor = pos;
    check_cursor(curwin);
    Visual.active = false;
    Visual.select = false;
    nvim_feedkeys(span, cstr_as_string("nix"), false);
    if (!Visual.active) {
      continue;
    }
    pos_T s = Visual.start;
    pos_T e = curwin->w_cursor;
    if (lt(e, s)) {
      pos_T tmp = s;
      s = e;
      e = tmp;
    }
    if (Visual.mode == 'V') {
      mc_vsel_mark(s.lnum, 0, e.lnum, ml_get_len(e.lnum));
    } else if (Visual.mode == Ctrl_V) {
      // Blockwise: one range per line, computed by block_prep().
      colnr_T sv1, sv2, ev1, ev2;
      const bool lbr_saved = reset_lbr();
      getvvcol(curwin, &s, &sv1, NULL, &sv2, 0);
      getvvcol(curwin, &e, &ev1, NULL, &ev2, 0);
      restore_lbr(lbr_saved);
      oparg_T oa = {
        .op_type = OP_NOP,
        .motion_type = kMTBlockWise,
        .inclusive = true,
        .start = s,
        .end = e,
        .start_vcol = MIN(sv1, ev1),
        .end_vcol = curwin->w_curswant == MAXCOL ? MAXCOL : MAX(sv2, ev2),
      };
      for (linenr_T lnum = s.lnum; lnum <= e.lnum; lnum++) {
        struct block_def bd;
        block_prep(&oa, &bd, lnum, false);
        if (bd.textlen > 0) {
          mc_vsel_mark(lnum, bd.textcol, lnum, bd.textcol + bd.textlen);
        }
      }
    } else {
      // Charwise, inclusive: extend past the last selected char.
      char *line = ml_get(e.lnum);
      colnr_T ecol = e.col;
      if (line[ecol] != NUL) {
        ecol += utfc_ptr2len(line + ecol);
      } else {
        ecol++;
      }
      mc_vsel_mark(s.lnum, s.col, e.lnum, ecol);
    }
    // Selection-end cursor; the anchor extmark stays put (the eventual replay position).
    uint32_t cmark = 0;
    mc_mark_set(curbuf, mc_vcur_ns(), &cmark, curwin->w_cursor, true, false, true);
    mc_vsel_buf = curbuf->handle;
    Visual.active = false;
  }

  cmdmod.cmod_flags = save_cmod_flags;
  emsg_silent--;
  unblock_autocmds();
  mc_sandbox_leave(&sb);
  xfree(span.data);
}

/// Time-travel undo (g-/g+, :earlier/:later) crosses cascade boundaries, where per-cursor state is
/// meaningless: delete the buffer's cursors.
void mc_undo_time(void)
{
  atom_did_global_op();  // Undo must not cascade, even via a mapping.
  extmark_clear(curbuf, mc_ns(), 0, 0, MAXLNUM, MAXCOL);
}

/// Insert-cascade "commit": run at insert-session end (atom_ins_end()). Replaces the previews with
/// a real replay. No-op if the session did not insert-cascade.
bool mc_ins_commit(void)
{
  bool ins_cascaded = mc_ins_span.active && !mc_ins_span.first;
  mc_ins_span.active = false;

  if (ins_cascaded) {
    // COMMIT: replace the previews with a real replay: abbrev, 'textwidth', … re-exec per cursor.
    String ins = redo_keys(NULL);
    if (ins.data != NULL && ins.size > mc_ins_span.done_len
        // Not <Esc>-terminated, e.g. CTRL-C: the previews stay.
        && (uint8_t)ins.data[ins.size - 1] == ESC) {
      mc_ins_span_flush(&ins, true);
    }
    api_free_string(ins);
  }

  // Session is over, drop its marks. (region=0: none, and mc_session_ns() must not be created by
  // a plain insert: namespace ids are user-observable.)
  if (mc_ins_span.region != 0) {
    extmark_del_id(curbuf, mc_session_ns(), mc_ins_span.region);
    mc_ins_span.region = 0;
  }
  mc_ins_regions_clear();

  if (!ins_cascaded) {
    return false;
  }
  // The commit edits belong to the session (already reported in TextChangedI). Absorb their ticks,
  // for TextChanged(I) parity, once per action.
  curbuf->b_last_changedtick = buf_get_changedtick(curbuf);
  curbuf->b_last_changedtick_i = buf_get_changedtick(curbuf);
  // The mcursors were anchored at their insertion points; now that the session ended,
  // shift them onto the last-inserted char, like <Esc> did for the primary cursor.
  for (size_t i = 0; i < kv_size(mc_cursors); i++) {
    Context *ctx = &kv_A(mc_cursors, i);
    if (!mc_ctx_resolve(ctx, &ctx->pos)) {
      continue;
    }
    if (ctx->pos.col > 0) {
      dec(&ctx->pos);  // one char left, like <Esc> (but never crossing lines)
    }
    mc_mark_upd(curbuf, &ctx->mark, ctx->pos);
  }
  return true;
}

/// Whether `buf` has mcursors. Hot: called on every key.
bool mc_buf_has_cursors(buf_T *buf)
{
  for (size_t i = 0; i < kv_size(mc_cursors); i++) {
    if (kv_A(mc_cursors, i).buf == buf->handle) {
      return true;
    }
  }
  return false;
}

/// Whether "follow motion" mode ("q=") is enabled.
bool mc_following(void)
{
  return mc_follow_motion;
}

/// Notifies mcursor.lua that the session started (first cursor) or ended (last cursor removed).
static void mc_lua_enable(bool enable)
{
  if (exiting) {
    return;
  }
  typval_T tv_args[] = {
    { .v_type = VAR_BOOL, .vval.v_bool = enable ? kBoolVarTrue : kBoolVarFalse },
    { .v_type = VAR_UNKNOWN },
  };
  nlua_call_typval("vim._core.mcursor", "enable", tv_args, NULL);
}

/// The first cursor extmark at `pos` in `buf`, or 0 if none.
static uint32_t mc_mark_at(buf_T *buf, pos_T pos)
{
  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, (int32_t)pos.lnum - 1, pos.col, itr);
  MTKey k;
  // Perf: bisect the marktree, instead of scanning mc_cursors (quadratic).
  while ((k = marktree_itr_current(itr)).id != 0
         && k.pos.row == pos.lnum - 1 && k.pos.col == pos.col) {
    if (k.ns == mc_ns() && !mt_end(k)) {
      return k.id;
    }
    if (!marktree_itr_next(buf->b_marktree, itr)) {
      break;
    }
  }
  return 0;
}

/// "g CTRL-A": insert an ascending number at each cursor.
void mc_counter(long count1)
{
  atom_did_global_op();
  typval_T tv_args[] = {
    { .v_type = VAR_NUMBER, .vval.v_number = count1 },
    { .v_type = VAR_UNKNOWN },
  };
  nlua_call_typval("vim._core.mcursor", "number", tv_args, NULL);
}

/// "q=": toggles "follow motion" mode; [count] forces it: "1q=" on, "2q=" off.
///
/// @return  false on an invalid count (> 2).
bool mc_follow_toggle(long count0)
{
  if (count0 == 0) {
    mc_follow_motion = !mc_follow_motion;
  } else if (count0 <= 2) {
    mc_follow_motion = count0 == 1;
  } else {
    return false;
  }
  return true;
}

/// Places an mcursor, or removes the cursor already at the given position.
void mc_toggle(buf_T *buf, pos_T pos, bool end_follow)
{
  if (mc_replaying()) {
    // Replayed input ("Q" in a mapping's atom) must not manage cursors; see mc_add().
    return;
  }
  if (end_follow) {
    mc_follow_motion = false;
  }
  uint32_t mark = mc_mark_at(buf, pos);
  if (mark != 0) {
    extmark_del_id(buf, mc_ns(), mark);
    mc_dedupe();  // sweeps the mark-less cursor (and ends the session if it was the last)
    return;
  }
  mc_add(buf, pos);
}

/// Places an mcursor at position `pos` in `buf`.
void mc_add(buf_T *buf, pos_T pos)
{
  if (mc_replaying()) {
    // Can't add cursors while the cascade iterates them.
    return;
  }
  // Ignore duplicate cursor (e.g. repeated "[count]Q", nvim_mcursor()).
  if (mc_mark_at(buf, pos) != 0) {
    return;
  }
  if (kv_size(mc_cursors) == 0) {
    // Session start: snapshot the primary's regs; hand the display to mcursor.lua.
    mc_start.time = (Timestamp)os_realtime();
    ctx_save(&mc_start.regs, kCtxRegs);
    mc_lua_enable(true);
  }
  kv_push(mc_cursors, (Context)CONTEXT_INIT);
  Context *ctx = &kv_last(mc_cursors);
  ctx->buf = buf->handle;
  ctx->pos = pos;
  mc_mark_upd(buf, &ctx->mark, pos);
}

/// A reload/wipe invalidated the tracked positions: deletes the mcursors + "gQ" snapshot.
void mc_buf_clear(buf_T *buf)
{
  if (mc_replaying()) {
    return;
  }
  extmark_clear(buf, mc_ns(), 0, 0, MAXLNUM, MAXCOL);
  extmark_clear(buf, mc_last_ns(), 0, 0, MAXLNUM, MAXCOL);
}

/// Called when a buffer's extmarks were freed. Deleting a cursor's extmark deletes the cursor.
void mc_buf_free(buf_T *buf)
{
  if (mc_replaying()) {
    // Can't mutate mc_cursors during cascade. Entries are swept by mc_dedupe() after the cascade.
    return;
  }
  mc_dedupe();
  if (mc_vsel_buf == buf->handle) {
    // The selection extmarks died with the buffer too.
    mc_vsel_buf = 0;
  }
}

/// Called before extmark_clear() deletes a namespace's extmarks. Refreshes the cursor-position
/// cache, so mc_ns_cleared()'s "gQ" snapshot sees positions shifted by non-cascading edits.
void mc_ns_clearing(buf_T *buf, uint32_t ns_id)
{
  if ((ns_id != mc_ns() && ns_id != 0) || mc_replaying()) {
    return;
  }
  for (size_t i = 0; i < kv_size(mc_cursors); i++) {
    Context *ctx = &kv_A(mc_cursors, i);
    if (ctx->buf == buf->handle && ctx->mark != 0) {
      mc_mark_get(buf, mc_ns(), ctx->mark, &ctx->pos);
    }
  }
}

/// Deleting the "nvim.multicursor" namespace deletes its cursors. Saves snapshot for "gQ".
void mc_ns_cleared(buf_T *buf, uint32_t ns_id)
{
  if ((ns_id != mc_ns() && ns_id != 0) || mc_replaying() || !mc_buf_has_cursors(buf)) {
    return;
  }

  // End the session only if no cursors are alive.
  bool others = false;
  for (size_t i = 0; i < kv_size(mc_cursors) && !others; i++) {
    Context *ctx = &kv_A(mc_cursors, i);
    pos_T pos;
    others = ctx->buf != buf->handle
             || (ctx->mark != 0 && mc_mark_get(buf, mc_ns(), ctx->mark, &pos));
  }
  if (!others) {
    // "DWIM yank": before the multicursor session ends, join per-cursor yanks to primary.
    mc_reg_gather();
  }

  // Snapshot the positions into "nvim.multicursor.last" ("gQ").
  extmark_clear(buf, mc_last_ns(), 0, 0, MAXLNUM, MAXCOL);
  for (size_t i = 0; i < kv_size(mc_cursors); i++) {
    Context *ctx = &kv_A(mc_cursors, i);
    if (ctx->buf != buf->handle) {
      continue;
    }
    uint32_t mark = 0;
    mc_mark_set(buf, mc_last_ns(), &mark, ctx->pos, false, true, false);
  }
  mc_dedupe();  // Cleanup.
  if (kv_size(mc_cursors) == 0) {
    // Session ended; drop the pending cascade.
    atoms_free(&g_atoms);
  }
}

#ifdef EXITFREE
/// Frees all multicursor state on exit.
void mc_free_all(void)
{
  while (kv_size(mc_cursors) > 0) {
    Context ctx = kv_pop(mc_cursors);
    ctx_free(&ctx);
  }
  kv_destroy(mc_cursors);
  kv_destroy(mc_ins_span.regions);
  ctx_free(&mc_start.regs);
}
#endif
