// input_cmdatom.c: The input engine "policy layer" (input.c. is the "bytes layer").
//
// Decides _structure_ of user input and captures it as a "CmdAtom": a repeatable unit (edit,
// motion, visual sequence, insert session, mapping), a dot-repeat-style keysequence plus structured
// fields (CmdSpec).
//
// Every "user action" is an atom (emits CmdAtom event), but not every atom is "replayable".
// - Replayable (cascade, dot-repeat) requires the full command grammar.
// - No atoms for: mouse drag/release (TODO(justinmk)?), terminal-mode input, aborted operations.

#include <assert.h>
#include <stdint.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_docmd.h"
#include "nvim/globals.h"
#include "nvim/input.h"
#include "nvim/input_cmdatom.h"
#include "nvim/insert.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/normal.h"
#include "nvim/normal_defs.h"
#include "nvim/ops.h"
#include "nvim/option_vars.h"
#include "nvim/register.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#include "input_cmdatom.c.generated.h"

static bool mc_replaying(void)
{
  return false;
}

static void mc_vsel_refresh(void)
{
}

static void mc_vsel_clear(void)
{
}

static bool mc_following(void)
{
  return false;
}

static void mc_clock_edge(bool map_edit)
{
}

CmdAtomVec g_atoms = KV_INITIAL_VALUE;
/// Capture clock: ticks on any kind of capture (atom push, Visual subatom). Used to answer "was
/// anything captured during this command (including its nested frames)?".
static uint64_t atom_captures = 0;
/// Suppresses atom pushes.
static bool atom_suppressed = false;
/// Mapping edited the buffer, or its insert-session cascaded: cascades as one unit, incl. motions.
static bool map_edit = false;
/// Ticks per command frame (CmdFrame.id).
static uint64_t frame_id = 0;

/// Accumulating composite atom: an executing mapping/macro. See `vatom` for Visual composite.
static struct {
  CmdAtomVec atoms;   ///< Subatoms of the mapping/macro.
  char *lhs;          ///< Label: mapping LHS or macro "@x" (NULL: not collecting).
  bool queued;        ///< A cascadable atom was queued (g_atoms) while collecting.
  bool lossy;         ///< Capture lost part of the mapping (incomplete insert, payload with no
                      ///< capturing atom): `keys` cannot replay it, `lhs` can.
  bool macro;         ///< Macro execution: captured as an "@x"-labeled atom.
  uint64_t frame;     ///< CmdFrame already executing when a lookahead resolved this mapping
                      ///< ("f(" + mapped key in one batch). 0: none.
  CmdOrigin origin;   ///< State at start.
} composite;

/// The executing command's frame; its `parent` chain spans nested `normal_execute()`.
static CmdFrame *cur_frame = NULL;

/// State of a Visual composite atom.
typedef enum {
  kVatomNone = 0,   ///< No pending Visual atom.

  // Kind:
  kVatomTyped = 1,  ///< User input (typed, or mapping/macro): emitted/cascaded at end.
  kVatomFed = 2,    ///< Fed input (":norm! vjd", scheduled feedkeys): preps redo, no emit/cascade.

  kVatomVoid = 4,   ///< Not replayable: tainted/poisoned (by mouse, gv, …). But may emit CmdAtom.
} VatomState;

/// Accumulating Visual composite: the full Visual keysequence (selection keys + operator).
static struct {
  CmdAtomVec atoms;  ///< Accumulated subatoms. A void session collects them as the `lhs` label.
  VatomState state;
  CmdOrigin origin;  ///< State at session start (before the "v").
} vatom;

/// Per-command capture scratch.
static struct {
  uint64_t redo_frame;  ///< The CmdFrame that prepped redo (prep_redo*()). 0: none.
  char *cmdline;      ///< The ":" payload captured at cmdline accept. NULL: none.
                      ///< Note: search payloads ("/pat<CR>") travel on `cmdarg.searchbuf`.
  bool ins_cascaded;  ///< Did the command's insert-session already cascade?
  bool op_global;     ///< Already applied to every cursor (undo, "g CTRL-A"): must not cascade.
} curcmd;

/// Interactively typed keys of the executing command. Collected during a composite (its `lhs`
/// suffix) and eval-read (the frame's payload slice, see atom_payload_start()).
static struct {
  kvec_t(uint8_t) keys;
  size_t map_start;  ///< This composite's slice: keys[map_start..kv_size(keys)), its lhs suffix.
} typed;

static const char *const type_names[] = {
  [kAExcmd] = "excmd",
  [kAInsertSpan] = "insert",  // spans display as "insert" (as a composite's `atoms`)
  [kAInsert] = "insert",
  [kAJump] = "jump",
  [kAMapping] = "mapping",
  [kAMotion] = "motion",
  [kAMouse] = "mouse",
  [kANormal] = "normal",
  [kAOperator] = "operator",
  [kAScroll] = "scroll",
  [kAVisual] = "visual",
};

/// Frees a CmdAtom's allocated members.
void atom_free(CmdAtom *atom)
{
  XFREE_CLEAR(atom->keys);
  XFREE_CLEAR(atom->text);
  XFREE_CLEAR(atom->lhs);
  atoms_free(&atom->atoms);
  kv_destroy(atom->atoms);
}

/// Frees and removes all atoms in `v` (keeps the vector's storage).
void atoms_free(CmdAtomVec *v)
{
  while (kv_size(*v) > 0) {
    CmdAtom atom = kv_pop(*v);
    atom_free(&atom);
  }
}

#ifdef EXITFREE
void atom_free_all(void)
{
  atoms_free(&g_atoms);
  kv_destroy(g_atoms);
  // A mid-command exit (e.g. ":qa!" from an option-expr) leaves live frames with staged atoms.
  for (CmdFrame *frame = cur_frame; frame != NULL; frame = frame->parent) {
    atom_free(&frame->staged);
  }
  atom_composite_abort();
  kv_destroy(composite.atoms);
  XFREE_CLEAR(curcmd.cmdline);
  kv_destroy(typed.keys);
  atoms_free(&vatom.atoms);
  kv_destroy(vatom.atoms);
}
#endif

/// Gets a structured spec of a normal-mode command.
CmdSpec atom_cmd_spec(const cmdarg_T *cap)
{
  bool operand = nv_nchar_is_arg(cap->cmdchar);
  return (CmdSpec){
    .regname = cap->oap->regname,
    .count = cap->count0,
    .cmd = cap->cmdchar,
    .cmd2 = operand ? NUL : cap->nchar,
    .cmdarg = operand ? cap->nchar : NUL,
  };
}

/// Gets the current buffer/window/cursor state.
static CmdOrigin atom_origin(void)
{
  CmdOrigin origin = { .win = curwin, .pos = curwin->w_cursor,
                       .tick = buf_get_changedtick(curbuf) };
  set_bufref(&origin.buf, curbuf);
  return origin;
}

/// True if the buffer was edited. False if the buf disappeared.
static bool atom_origin_changed(CmdOrigin origin)
{
  return bufref_valid(&origin.buf) && buf_get_changedtick(origin.buf.br_buf) != origin.tick;
}

/// True if the cursor moved (in original buf). False if the win or buf disappeared.
static bool atom_origin_moved(CmdOrigin origin)
{
  return bufref_valid(&origin.buf) && win_valid(origin.win)
         && origin.win->w_buffer == origin.buf.br_buf
         && !equalpos(origin.pos, origin.win->w_cursor);
}

/// Undo state of the buffer now, or 0 if the buffer disappeared.
static int atom_origin_undoseq(CmdOrigin origin)
{
  return bufref_valid(&origin.buf) ? origin.buf.br_buf->b_u_seq_cur : 0;
}

/// Composes a CmdSpec into `redo_keys` format.
/// @return Allocated key sequence.
static char *atom_redo_keys(CmdSpec spec)
{
  char *keys = redo_keys(&spec).data;
  assert(keys != NULL);  // A spec with no chars/count/reg composes to nothing.
  return keys;
}

/// Gets the pending change as a CmdAtom. Caller owns `keys`.
static CmdAtom atom_from_redo(CmdAtomType type)
{
  String keys = redo_keys(NULL);
  return (CmdAtom){ .type = type, .spec = redo_spec(), .keys = keys.data };
}

/// Gets a CmdAtom from a CmdSpec.
static CmdAtom atom_from_spec(CmdAtomType type, CmdSpec spec)
{
  return (CmdAtom){ .type = type, .spec = spec, .keys = atom_redo_keys(spec) };
}

/// Gets a typed cmdline as a CmdAtom.
///   ":cnext<CR>" => CmdAtom{ kAExcmd, keys=":cnext<NL>", text="cnext" }
static CmdAtom atom_from_cmdline(CmdAtomType type, cmdarg_T *ca, const char *cmdline)
{
  StringBuilder sb = KV_INITIAL_VALUE;
  if (ca->cmdchar != ':' && ca->count0 != 0) {
    // Not for ":", its count already prefilled (":.,.+1"). But "<Cmd>" needs count in the keys.
    kv_printf(sb, "%d", ca->count0);
  }
  sb_add_char(&sb, ca->cmdchar);
  sb_add_lit(&sb, cmdline, -1);
  sb_add_char(&sb, NL);
  kv_push(sb, NUL);
  return (CmdAtom){
    .type = type,
    .spec = { .count = ca->count0, .cmd = ca->cmdchar },
    .keys = sb.items,
    .text = xstrdup(cmdline),
  };
}

/// Joins the `keys` of a list of (composite) subatoms. This is a plain concat (the `keys` field of
/// each subatom is assumed to be in `redo_keys` format).
///
/// @return Allocated keysequence, "" if `atoms` is empty (never NULL).
static String atoms_concat_keys(CmdAtomVec atoms)
{
  StringBuilder keys = KV_INITIAL_VALUE;
  for (size_t i = 0; i < kv_size(atoms); i++) {
    kv_concat(keys, kv_A(atoms, i).keys);
  }
  size_t len = kv_size(keys);
  kv_push(keys, NUL);
  return (String){ .data = keys.items, .size = len };
}

/// Renders a (cmd, arg, op) char for CmdAtom: key-notation for special keys, else UTF-8. NUL => "".
static char *atom_key_name(int c)
{
  if (c == NUL) {
    return xstrdup("");
  }
  if (IS_SPECIAL(c) || c < ' ') {
    // Covers <Tab>/<NL>/<CR>/<Esc> and the controls (as "<C-A>").
    return xstrdup(get_special_key_name(c, 0));
  }
  if (c == DEL) {
    return xstrdup("<Del>");  // key_names_table has K_DEL, not the ASCII byte.
  }
  char buf[MB_MAXBYTES + 1];
  buf[utf_char2bytes(c, buf)] = NUL;
  return xstrdup(buf);
}

/// Gets an atom's (allocated) event-data.
static Dict atom_dict(const CmdAtom *atom)
{
  const CmdSpec *spec = &atom->spec;
  char regname[2] = { (char)spec->regname, NUL };
  const char *force = spec->motion_force == Ctrl_V
                      ? "<C-V>" : (char[]){ (char)spec->motion_force, NUL };
  // The operator char can be a control char ("g<C-A>" counter op: CTRL-A).
  char *op = atom_key_name(spec->op);
  if (spec->op_extra != NUL) {
    char *extra = atom_key_name(spec->op_extra);
    op = xrealloc(op, strlen(op) + strlen(extra) + 1);
    strcat(op, extra);
    xfree(extra);
  }
  char *cmd = atom_key_name(spec->cmd);
  if (spec->cmd2 != NUL) {
    // Two-char command name ("gJ", "iw", "gn"): compose it.
    char *cmd2 = atom_key_name(spec->cmd2);
    cmd = xrealloc(cmd, strlen(cmd) + strlen(cmd2) + 1);
    strcat(cmd, cmd2);
    xfree(cmd2);
  }
  // Inapplicable fields are OMITTED, not defaulted.
  Dict d = ARRAY_DICT_INIT;
  char *cmdarg = atom_key_name(spec->cmdarg);
  if (cmdarg != NULL && *cmdarg != NUL) {
    PUT(d, "cmdarg", CSTR_AS_OBJ(cmdarg));
  } else {
    xfree(cmdarg);
  }
  PUT(d, "changed", BOOLEAN_OBJ(atom->changed));
  if (*cmd != NUL) {
    PUT(d, "cmd", CSTR_AS_OBJ(cmd));
  } else {
    xfree(cmd);
  }
  if (spec->count > 0) {
    PUT(d, "count", INTEGER_OBJ(spec->count));
  }
  // Note: origin is undefined for an insert-session span, its cursor effect is undefined.
  if (atom->origin.pos.lnum > 0) {
    PUT(d, "moved", BOOLEAN_OBJ(atom->moved));
    Array pos = ARRAY_DICT_INIT;
    ADD(pos, INTEGER_OBJ(atom->origin.pos.lnum));
    ADD(pos, INTEGER_OBJ(atom->origin.pos.col));
    PUT(d, "pos", ARRAY_OBJ(pos));
    PUT(d, "undoseq", INTEGER_OBJ(atom->undoseq));
  }
  // keys/lhs are RAW bytes (typeahead encoding).
  const char *keys = atom->keys != NULL ? atom->keys : "";
  if (!atom->remap) {
    PUT(d, "keys", CSTR_TO_OBJ(keys));
  }
  PUT(d, "lhs", CSTR_TO_OBJ(atom->lhs != NULL && *atom->lhs != NUL ? atom->lhs : keys));
  if (*force != NUL) {
    PUT(d, "motionforce", CSTR_TO_OBJ(force));
  }
  if (*op != NUL) {
    PUT(d, "operator", CSTR_AS_OBJ(op));
  } else {
    xfree(op);
  }
  if (spec->regname != 0) {
    PUT(d, "reg", CSTR_TO_OBJ(regname));
  }
  if (atom->text != NULL && *atom->text != NUL) {
    PUT(d, "text", CSTR_TO_OBJ(atom->text));
  }
  PUT(d, "type", CSTR_TO_OBJ(type_names[atom->type]));
  return d;
}

/// Schedules a CmdAtom event.
static void atom_emit(const CmdAtom *atom)
{
  if (!has_event(EVENT_CMDATOM)) {
    return;
  }
  Dict data = atom_dict(atom);
  if (kv_size(atom->atoms) > 0) {
    Array atoms = ARRAY_DICT_INIT;
    for (size_t i = 0; i < kv_size(atom->atoms); i++) {
      ADD(atoms, DICT_OBJ(atom_dict(&kv_A(atom->atoms, i))));
    }
    PUT(data, "atoms", ARRAY_OBJ(atoms));
  }
  buf_T *buf = atom->origin.buf.br_buf != NULL ? atom->origin.buf.br_buf : curbuf;
  aucmd_defer(EVENT_CMDATOM, (char *)type_names[atom->type], NULL, AUGROUP_ALL, buf, NULL,
              &DICT_OBJ(data));
  api_free_dict(data);
}

/// Emits a CmdAtom event, or collects it as a subatom of an open scope. If `cascade` is true,
/// queues a copy for mcursor cascade. Takes ownership: `*atom` is invalid after.
///
/// Both scopes (composite, Visual session) can be open. Routed by scope kind, not depth:
/// a collecting Visual session takes the atom, its atom then lands in the composite (",v"+"d").
/// Depth would invert "v@q", where the "@q" composite opened LAST yet collects nothing.
void atom_push_raw(bool cascade, CmdAtom *atom)
{
  assert(atom->keys != NULL);
  if (atom->origin.buf.br_buf != NULL) {
    // Calculated here, from the atom's own baseline.
    atom->changed = atom_origin_changed(atom->origin);
    atom->moved = atom_origin_moved(atom->origin);
    atom->undoseq = atom_origin_undoseq(atom->origin);
  }
  if (atom_visual_pending()) {
    if (vatom.state & kVatomTyped) {
      // Not for kVatomFed: redo-prep must not mark the enclosing span as captured.
      atom_captures++;
    }
    kv_push(vatom.atoms, *atom);
    return;
  }
  atom_captures++;
  if (atom->type == kAVisual && kv_size(atom->atoms) > 0) {
    // The completing operator is the only subatom that could have edited.
    CmdAtom *last = &kv_A(atom->atoms, kv_size(atom->atoms) - 1);
    if (last->type == kAOperator) {
      last->changed = atom->changed;
    }
  }
  // `composite.frame`: the command that was executing when a peek opened the composite is not part
  // of it.
  const bool collect = composite.lhs != NULL
                       && (cur_frame == NULL || cur_frame->id != composite.frame);
  if (cascade) {
    CmdAtom copy = *atom;
    copy.keys = xstrdup(atom->keys);
    copy.text = NULL;  // replay (mc_execute()) reads only type/keys/remap: not the text,
    copy.lhs = NULL;   // nor the label,
    copy.atoms = (CmdAtomVec)KV_INITIAL_VALUE;  // nor the decomposition
    kv_push(g_atoms, copy);
    if (collect) {
      composite.queued = true;
    }
  }
  if (collect) {
    kv_push(composite.atoms, *atom);
  } else {
    if (atom->type != kAInsertSpan) {
      // Spans are cascade-internal; only emit the whole session (kAInsert).
      atom_emit(atom);
    }
    atom_free(atom);
  }
}

/// Pushes an atom (emit + maybe cascade), or drops it if replay/Visual/internal-op already
/// in-progress.
static void atom_push(bool cascade, CmdAtom *atom)
{
  if (atom_blocked()) {
    atom_free(atom);
    return;
  }
  atom_push_raw(cascade, atom);
}

/// Stages an atom built before its command executes (do_pending_operator() prep-exempt, Visual
/// ops), in the command's frame; pushed at frame end, once `changed` is known.
static void atom_stage_set(CmdAtom *atom)
{
  assert(cur_frame != NULL);
  assert(!atom_staged());  // One stage per frame: a second would discard a captured command.
  atom_free(&cur_frame->staged);
  if (atom_blocked()) {
    // Now, not at flush: drop the atom of an internal operator (atom_suppress()).
    atom_free(atom);
    return;
  }
  assert(atom->keys != NULL);
  cur_frame->staged = *atom;
}

/// True if an atom is staged for the current command (frame).
static bool atom_staged(void)
{
  return cur_frame != NULL && cur_frame->staged.keys != NULL;
}

/// Pushes the frame's staged atom (no-op if none).
static void atom_stage_flush(CmdFrame *frame)
{
  if (frame->staged.keys == NULL) {
    return;
  }
  // Staged commands are edits, thus cascade. Except with no keys (poisoned Visual selection).
  bool cascade = *frame->staged.keys != NUL;
  atom_push(cascade, &frame->staged);
  frame->staged = (CmdAtom){ 0 };
}

/// The composite's trigger: its LHS plus the keys typed while it ran, i.e. the user "intention".
/// @return Allocated.
static char *atom_composite_lhs(void)
{
  StringBuilder keys = KV_INITIAL_VALUE;
  kv_concat(keys, composite.lhs);
  kv_concat_len(keys, (char *)typed.keys.items + typed.map_start,
                kv_size(typed.keys) - typed.map_start);
  kv_push(keys, NUL);
  return keys.items;
}

/// Queues an LHS-replay atom: a mapping that edited invisibly (:normal/:call, "ds'") re-runs
/// per cursor from its LHS + payload keys. Cascade only.
void atom_lhs_replay_queue(void)
{
  kv_push(g_atoms, ((CmdAtom){ .type = kAMapping, .keys = atom_composite_lhs(), .remap = true }));
}

/// True if the executing mapping queued a subatom: its edit was captured, no LHS-replay needed.
bool atom_composite_queued(void)
{
  return composite.queued;
}

/// True while a composite is collecting subatoms.
bool atom_composite_active(void)
{
  return composite.lhs != NULL;
}

/// Starts a composite: accumulate a mapping/macro's subatoms.
static void atom_composite_start(const char *lhs, size_t len)
{
  xfree(composite.lhs);
  composite.lhs = xmemdupz(lhs, len);
  composite.queued = false;
  composite.lossy = false;
  composite.frame = 0;
  composite.origin = atom_origin();
}

/// Emits the composite atom with its collected subatoms (`CmdAtom.atoms`).
///
///      :nnoremap gj i<C-J><Esc>k$
///      "gj" => CmdAtom{ .lhs="gj", .keys="1i<NL><Esc>k$", kAMapping }
static void atom_composite_end(void)
{
  composite.macro = false;  // "@x" capture ends with its composite.
  if (composite.lhs == NULL) {
    return;
  }
  // LHS-replay when the capture is lossy, or captured nothing (Ex/Lua edits).
  const bool remap = composite.lossy || kv_size(composite.atoms) == 0;
  char *lhs = atom_composite_lhs();
  XFREE_CLEAR(composite.lhs);
  CmdAtom atom;
  if (kv_size(composite.atoms) == 0) {
    // The mapping's commands captured nothing (Ex/Lua commands, no-ops): but it is still a user
    // action, so emit it with empty keys (identified by `lhs`).
    atom = (CmdAtom){ .type = kAMapping, .keys = xstrdup(""), .lhs = lhs, .remap = remap,
                      .origin = composite.origin,
                      .changed = atom_origin_changed(composite.origin),
                      .moved = atom_origin_moved(composite.origin),
                      .undoseq = atom_origin_undoseq(composite.origin) };
  } else if (kv_size(composite.atoms) == 1) {
    // Single subatom. "Unwrap" it so e.g. a motion mapping reports kAMotion, not kAMapping.
    atom = kv_pop(composite.atoms);
    xfree(atom.lhs);
    atom.lhs = lhs;
    atom.remap = remap;
  } else {
    atom = (CmdAtom){ .type = kAMapping, .keys = atoms_concat_keys(composite.atoms).data,
                      .lhs = lhs, .remap = remap, .origin = composite.origin,
                      .changed = atom_origin_changed(composite.origin),
                      .moved = atom_origin_moved(composite.origin),
                      .undoseq = atom_origin_undoseq(composite.origin) };
    atom.atoms = composite.atoms;  // Subatoms.
    composite.atoms = (CmdAtomVec)KV_INITIAL_VALUE;  // Reset.
  }
  atom_emit(&atom);
  atom_free(&atom);
}

/// Entering :terminal mode ends the composite.
void atom_term_enter(void)
{
  if (!mc_replaying()) {
    atom_composite_end();
  }
}

/// Discards the collecting composite (its subatoms): error/interrupt voided it.
void atom_composite_abort(void)
{
  composite.macro = false;
  XFREE_CLEAR(composite.lhs);
  atoms_free(&composite.atoms);
}

/// True if the just-executed command is user input. Excludes re-execution of captured
/// material: "@r" (unless composite.macro), ":normal", cascade replays.
bool atom_is_user_cmd(void)
{
  // reg_executing is already reset for a macro's LAST command (its trailing "x" stuffs "dl").
  return ((reg_executing == 0 && !pending_end_reg_executing) || composite.macro)
         && ex_normal_busy == 0;
}

/// Like atom_is_user_cmd(), for sampling before a command consumes its keys.
///   typed "i", mapped "gj" => true;  "." (stuffed redo), "@r" => false
static bool atom_is_user_input(void)
{
  // An open composite is user input even after its keys were consumed (":nnoremap ,i i").
  return KeyTyped
         || (atom_is_user_cmd() && (typebuf_maplen() > 0 || atom_composite_active()));
}

/// Suppresses atom pushes. For internal operators.
void atom_suppress(bool suppress)
{
  atom_suppressed = suppress;
}

/// Block atom pushes if: cascade in-progress, or internal op is executing.
static bool atom_blocked(void)
{
  return mc_replaying() || atom_suppressed;
}

/// Decides if the command is capturable.
static bool atom_capturable(bool consumers, bool keytyped)
{
  return consumers && atom_is_user_cmd() && (keytyped || atom_composite_active());
}

/// True if anything consumes atoms from `curbuf`. For performance: skip capture if no consumers.
static bool atom_buf_has_consumers(void)
{
  return has_event(EVENT_CMDATOM);
}

/// XXX: Checks consumers for ANY buffer: a mapping/macro may navigate into a buffer w/ cursors...
static bool atom_has_consumers(void)
{
  return has_event(EVENT_CMDATOM);
}

/// Classifies key/command `cmd` (`arg` is its argument char, for two-char commands like "g;").
///
/// @return  kKeyXx flags, or 0 for an ordinary key.
unsigned atom_key_class(int cmd, int arg)
{
  switch (cmd) {
  case K_EVENT:
  case K_IGNORE:
    return kKeyOpaque | kKeySynthetic;
  case K_COMMAND:
  case K_LUA:
    return kKeyOpaque;
  case '/':
  case '?':
  case ':':
  case '!':
    return kKeyPayload;
  case Ctrl_D:
  case Ctrl_U:
    return kKeyScrollMove | kKeyInsFlush;
  case Ctrl_F:
  case Ctrl_B:
    return kKeyScrollMove;
  case Ctrl_E:
  case Ctrl_Y:
    return kKeyScrollView;
  case Ctrl_O:
  case Ctrl_I:
    return kKeyJump;
  case Ctrl_T:
    return kKeyJump | kKeyInsFlush;
  // Multiplexed: one nv_cmds entry => many commands. NV_MOTION cannot tag them; char 2 decides.
  case 'g':
    if (arg == ';' || arg == ',') {
      return kKeyJump;
    }
    return strchr("gjk0^$_meEoM", arg) != NULL ? kKeyMotion : 0;
  case '[':
  case ']':
    if (arg == 'C') {
      return kKeyJump;  // "]C"/"[C": jump to the next/previous cursor
    }
    return strchr("[](){}mMcsz#*/", arg) != NULL ? kKeyMotion : 0;
  case 'z':
    return (arg == 'j' || arg == 'k') ? kKeyMotion : 0;
  case '*':
  case '#':
  case '\'':
  case '`':
    return kKeyJump;  // mark motions and "*"/"#": absolute/shared-state targets
  case K_UP:
  case K_DOWN:
  case K_LEFT:
  case K_RIGHT:
  case K_HOME:
  case K_END:
    return kKeyMotion | kKeyInsFlush;
  case K_S_LEFT:
  case K_S_RIGHT:
    return kKeyInsFlush;
  case K_BS:
  case K_DEL:
  case Ctrl_H:
  case Ctrl_W:
    return kKeyInsFlush;
  case Ctrl_G:
    return kKeyInsFlush;
  case K_LEFTMOUSE:
  case K_LEFTMOUSE_NM:
  case K_MIDDLEMOUSE:
  case K_RIGHTMOUSE:
  case K_X1MOUSE:
  case K_X2MOUSE:
    return kKeyMouse;
  case K_MOUSEDOWN:   // <ScrollWheelUp>
  case K_MOUSEUP:     // <ScrollWheelDown>
  case K_MOUSELEFT:
  case K_MOUSERIGHT:
    return kKeyScrollView;
  default:
    return 0;
  }
}

/// Captures an accepted ":" or "<Cmd>" cmdline payload.
void atom_cmdline_set(int firstc, const char *line, size_t len)
{
  // Not for nested cmdlines opened by a command's own execution (":normal", macros): they would
  // overwrite the user command's payload, e.g. `:exe "normal! :echo 1\r"`.
  if (!atom_is_user_cmd() || (firstc != ':' && firstc != K_COMMAND)) {
    return;
  }
  xfree(curcmd.cmdline);
  curcmd.cmdline = xmemdupz(line, len);
}

/// True while collecting typed keys: during a composite (for `lhs`), or a CmdFrame's payload slice.
static bool atom_typed_collecting(void)
{
  return atom_composite_active()
         || (cur_frame != NULL && cur_frame->payload_start != SIZE_MAX);
}

/// Opens the CmdFrame's payload slice: keys from getchar(), input() append to `CmdAtom.keys`.
void atom_payload_start(void)
{
  if (cur_frame != NULL && cur_frame->payload_start == SIZE_MAX && !mc_replaying()) {
    cur_frame->payload_start = cur_frame->payload_end = kv_size(typed.keys);
  }
}

/// Closes (or extends) the payload slice.
void atom_payload_end(void)
{
  if (cur_frame != NULL && cur_frame->payload_start != SIZE_MAX && !mc_replaying()) {
    cur_frame->payload_end = kv_size(typed.keys);
  }
}

/// Drains the CmdFrame's payload slice to `CmdAtom.keys`.
static void atom_payload_append(CmdAtom *atom, CmdFrame *frame)
{
  size_t plen = frame->payload_start == SIZE_MAX ? 0 : frame->payload_end - frame->payload_start;
  if (plen == 0 || atom->keys == NULL) {
    return;
  }
  size_t klen = strlen(atom->keys);
  atom->keys = xrealloc(atom->keys, klen + plen + 1);
  memcpy(atom->keys + klen, typed.keys.items + frame->payload_start, plen);
  atom->keys[klen + plen] = NUL;
  frame->payload_start = SIZE_MAX;
}

/// Collects a typed key (gotchars()) into the stream.
void atom_typed_add(const uint8_t *chars, size_t len)
{
  if (mc_replaying() || !atom_typed_collecting()) {
    return;
  }
  if (len == 3 && chars[0] == K_SPECIAL
      && (atom_key_class(TERMCAP2KEY(chars[1], chars[2]), NUL) & kKeySynthetic)) {
    return;  // Not user input: K_IGNORE from a mapping resolved during peek/K_EVENT/…
  }
  for (size_t i = 0; i < len; i++) {
    kv_push(typed.keys, chars[i]);
  }
}

/// Undoes atom_typed_add() for the last `len` bytes: a key that was read is being re-queued
/// into typeahead and will be collected again (ungetchars()).
void atom_typed_del(size_t len)
{
  if (mc_replaying() || !atom_typed_collecting()) {
    return;
  }
  kv_size(typed.keys) -= MIN(len, kv_size(typed.keys));
}

/// Forgets the redo-atom: new command, or a policy exclusion.
/// Only toplevel commands track it: a nested ":normal!" must not disturb it.
static void atom_redo_reset(void)
{
  if (!atom_is_user_cmd()) {
    return;
  }
  curcmd.redo_frame = 0;
  curcmd.ins_cascaded = false;
  XFREE_CLEAR(curcmd.cmdline);
  // The stream is truncated only once the mapping slice ends too (with its composite).
  if (!atom_composite_active()) {
    kv_size(typed.keys) = 0;
    typed.map_start = 0;
    // Truncation voids the payload slice.
    for (CmdFrame *frame = cur_frame; frame != NULL; frame = frame->parent) {
      frame->payload_start = SIZE_MAX;
    }
  }
}

/// Marks the running command as already applying to every cursor (see `curcmd.op_global`).
/// Called by u_doit() and mc_counter().
void atom_op_global_set(void)
{
  curcmd.op_global = true;
}

/// Sets `curcmd.redo_frame`: at frame end, the redobuf defines `CmdAtom.keys`.
/// Not for nested frames (":norm"), nor Lua operators.
void atom_redo_set(CmdSpec spec)
{
  if (spec.cmd == K_LUA) {
    atom_redo_reset();
    return;
  }
  if (atom_is_user_cmd()) {
    curcmd.redo_frame = cur_frame != NULL ? cur_frame->id : 0;
  }
}

/// Starts accumulating a composite for a macro's commands, labeled "@x".
void atom_macro_start(int regname)
{
  if (atom_is_user_input() && atom_has_consumers()) {
    composite.macro = true;
    if (!atom_composite_active()) {
      // The macro's commands collapse into one "@x"-labeled atom.
      char lhs[3] = { '@', (char)regname, NUL };
      atom_composite_start(lhs, 2);
    }
  }
}

/// Starts accumulating a composite for a command that stuffs its "translation" ("x" => "dl").
void atom_stuff_start(const cmdarg_T *cap)
{
  // Not while another composite collects: a mapping's own label wins ("nnoremap <F6> xw").
  if (!atom_has_consumers() || mc_replaying() || atom_composite_active() || !atom_is_user_input()) {
    return;
  }
  char *lhs = atom_redo_keys(atom_cmd_spec(cap));
  atom_composite_start(lhs, strlen(lhs));
  xfree(lhs);
}

/// Starts accumulating a composite for a mapping resolved from typed keys (vgetorpeek()).
///
/// @param peeked  Resolved by a peek: the executing command did not consume the mapping's keys.
void atom_map_start(const char *lhs, size_t len, bool peeked)
{
  if (!atom_has_consumers()
      || reg_executing != 0 || ex_normal_busy != 0 || !(State & MODE_NORMAL)
      || Visual.active) {
    return;
  }
  if (atom_composite_active()) {
    // Mapping resolved from another's trailing prefix ("nmap x j," + "nnoremap ,w w"): end the
    // pending composite, so each `lhs` owns only the keys it produced.
    typed.map_start = kv_size(typed.keys);
    atom_composite_end();
  }
  const char *op = get_vim_var_str(VV_OP);  // v:operator
  if (get_real_state() == MODE_OP_PENDING && *op != NUL) {
    // Op-pending mapping (:omap) continues the operator (vim-sneak "dz(b").
    assert(lhs[len] == NUL);
    char *full = concat_str(op, lhs);
    atom_composite_start(full, strlen(full));
    xfree(full);
    typed.map_start = kv_size(typed.keys);
    return;
  }
  atom_composite_start(lhs, len);
  if (peeked && cur_frame != NULL) {
    composite.frame = cur_frame->id;
  }
  typed.map_start = kv_size(typed.keys);
}

/// Discards the pending visual atom. Not a lifecycle end: also runs before a session starts.
static void atom_visual_reset(void)
{
  vatom.state = kVatomNone;
  atoms_free(&vatom.atoms);
  vatom.origin = (CmdOrigin){ 0 };
  mc_vsel_clear();
}

/// Visual atom is pending. A void session still accumulates, for the `lhs` label.
static bool atom_visual_pending(void)
{
  return vatom.state != kVatomNone;
}

/// Pending Visual atom is replayable (not voided).
bool atom_visual_replayable(void)
{
  return atom_visual_pending() && !(vatom.state & kVatomVoid);
}

/// The pending visual atom's accumulated keys (allocated), or NULL data if none is replayable
/// (inactive/void). For the selection dry-run (mc_vsel_refresh()).
String atom_visual_span(void)
{
  if (!atom_visual_replayable()) {
    return (String)STRING_INIT;
  }
  return atoms_concat_keys(vatom.atoms);
}

/// Ends the pending visual atom, appends `suffix`, and stages it. Or discards if unreplayable.
///
/// @param suffix  Owned.
/// @param spec  The completing operator, or NULL.
/// @param redoable  Prep redo. Unreplayable selection preps "1v" + op (fixed-size visual-repeat).
/// @return  True if the redo was prepped.
static bool atom_visual_end_suffix(char *suffix, const CmdSpec *spec, bool redoable)
{
  if (mc_replaying() || atom_suppressed) {  // Replay, or internal op applied during another cmd.
    xfree(suffix);
    return false;
  }
  const CmdOrigin origin = vatom.origin;  // atom_visual_reset() clears the session.
  const bool prep = redoable && spec != NULL;
  if (suffix == NULL || !atom_visual_replayable()) {
    bool prepped = prep && spec->op != NUL && suffix != NULL;
    if (prepped) {
      prep_redo_visual("1v", 2, (CmdSpec){ 0 });  // Equal-size fallback.
      redo_append_str(suffix, -1);
    }
    // A poisoned selection is still a user action: emit it with lhs + empty keys, like a mapping
    // whose commands captured nothing (atom_composite_end()).
    bool emit = (vatom.state & kVatomVoid) && (vatom.state & kVatomTyped) && spec != NULL
                && suffix != NULL && atom_is_user_cmd();
    char *label = NULL;
    if (emit) {
      String collected = atoms_concat_keys(vatom.atoms);
      label = xrealloc(collected.data, collected.size + strlen(suffix) + 1);
      STRCPY(label + collected.size, suffix);
    }
    xfree(suffix);
    atom_visual_reset();  // End the session before staging.
    if (emit) {
      atom_stage_set(&(CmdAtom){ .type = kAVisual, .spec = *spec, .keys = xstrdup(""),
                                 .lhs = label, .origin = origin });
    }
    return prepped;
  }
  String v = atoms_concat_keys(vatom.atoms);
  char *vkeys = v.data;
  size_t prefix = v.size;
  if (prep) {
    // Get the redo tail (register/count, op chars) from the suffix. Prevents divergence of prep vs
    // atom, and suffixes inexpressible as spec chars ("r<C-V><CR>") stay replayable.
    prep_redo_visual(vkeys, prefix, (CmdSpec){ 0 });
    redo_append_str(suffix, -1);
  }
  if (!atom_is_user_cmd() || !(vatom.state & kVatomTyped)) {
    // Not user input (":normal! vjd", fed keys): the redo prep above is the only effect; no emit.
    xfree(vkeys);
    xfree(suffix);
    atom_visual_reset();
    return prep;
  }
  char *keys = xrealloc(vkeys, prefix + strlen(suffix) + 1);
  STRCPY(keys + prefix, suffix);
  CmdAtom atom = {
    .type = kAVisual,
    // The completing operator's fields; per-command counts/registers are
    // embedded in `keys` (and decomposed in `atoms`).
    .spec = spec != NULL ? *spec : (CmdSpec){ 0 },
    .keys = keys,
    .origin = origin,
  };
  if (spec != NULL) {
    kv_push(vatom.atoms, ((CmdAtom){ .type = kAOperator, .spec = *spec, .keys = suffix,
                                     .origin = cur_frame->origin }));
  } else {
    xfree(suffix);
  }
  atom.atoms = vatom.atoms;
  vatom.atoms = (CmdAtomVec)KV_INITIAL_VALUE;
  atom_visual_reset();
  atom_stage_set(&atom);
  return prep;
}

/// Ends the pending visual atom with the operator `spec` ("viwee" + "x").
///
/// @return  True if redo was prepped.
bool atom_visual_end(CmdSpec spec, bool redoable)
{
  return atom_visual_end_suffix(atom_redo_keys(spec), &spec, redoable);
}

/// Captures a pending operator's atom and preps its redo, before it executes. Prep-exempt commands
/// (yank without cpo-y, "D", folds) build no redo, so atom_cmd_end() cannot derive their atom from
/// redobuff; reconstruct it here (staged).
///
/// Not captured (prep only):
/// - OP_CHANGE/OP_INSERT/OP_APPEND (the insert session is the atom)
/// - motions with an interactively-typed payload (search, Ex, Lua)
///
/// @param redo_yank  True when a yank builds a redo ("y" in 'cpoptions', not a GUI yank).
void atom_capture_op(oparg_T *oap, cmdarg_T *cap, bool redo_yank)
{
  const bool redoable = op_redoable(oap->op_type, redo_yank);
  bool ins_op = oap->op_type == OP_CHANGE || oap->op_type == OP_INSERT
                || oap->op_type == OP_APPEND;
  bool payload_motion = cap->cmdchar >= 0x100
                        || (cap->cmdchar != NUL && strchr("/?:!", cap->cmdchar) != NULL);
  bool excmd = cap->cmdchar == ':' || cap->cmdchar == K_COMMAND;
  if (!ins_op && !payload_motion) {
    bool prep_exempt = !redoable || cap->cmdchar == 'D';
    CmdSpec spec = {
      .regname = oap->regname, .count = cap->count0,
      .op = get_op_char(oap->op_type), .op_extra = get_extra_op_char(oap->op_type),
    };
    if (prep_exempt && (!Visual.active || oap->motion_force)) {
      // Only capture _user_ input.
      if (atom_capturable(atom_buf_has_consumers(), KeyTyped)) {
        bool operand = nv_nchar_is_arg(cap->cmdchar);
        spec.motion_force = oap->motion_force;
        spec.cmd = cap->cmdchar;
        spec.cmd2 = operand ? NUL : cap->nchar;
        spec.cmdarg = operand ? cap->nchar : NUL;
        CmdAtom op_atom = atom_from_spec(kAOperator, spec);
        op_atom.origin = cur_frame->origin;
        atom_stage_set(&op_atom);
      }
    } else if (!Visual.active || oap->motion_force) {
      // Prepped: atom_cmd_end() derives the atom from redobuff.
    } else if (oap->op_type == OP_REPLACE && cap->nchar <= 0) {
      // Visual "r<C-V><CR>": `spec.cmdarg` cannot represent the sentinel (REPLACE_CR_NCHAR), so
      // hand-compose the literal suffix keys.
      char suffix[4] = { 'r', Ctrl_V, cap->nchar == REPLACE_CR_NCHAR ? CAR : NL, NUL };
      atom_visual_end_suffix(xstrdup(suffix), &spec, redoable);
    } else {
      // Visual-mode op: complete the accumulated visual atom with the operator keys.
      spec.cmdarg = oap->op_type == OP_REPLACE ? cap->nchar : NUL;
      if ((oap->op_type == OP_NR_ADD || oap->op_type == OP_NR_SUB) && cap->arg) {
        // g<C-A>: the "g" variant is distinguished by cap->arg, not the op char: compose it back.
        spec.op_extra = spec.op;
        spec.op = 'g';
      }
      atom_visual_end(spec, redoable);
    }
  }

  // The prep decision. Runs after the capture above: a self-selecting op's prep overrides the
  // equal-size fallback the visual end may have prepped ("dgn").
  if (redoable && cap->cmdchar != 'D'
      && ((!Visual.active || oap->motion_force)
          // Also redo Operator-pending Visual mode mappings.
          || excmd || cap->cmdchar == K_LUA)) {
    prep_redo(true, false, (CmdSpec){
      .regname = oap->regname, .count = cap->count0,
      .op = get_op_char(oap->op_type), .op_extra = get_extra_op_char(oap->op_type),
      .motion_force = oap->motion_force, .cmd = cap->cmdchar, .cmd2 = cap->nchar,
    });
    if (cap->cmdchar == '/' || cap->cmdchar == '?') {     // was a search
      // If 'cpoptions' does not contain 'r', insert the search pattern to really repeat the
      // same command.
      if (vim_strchr(p_cpo, kCpoRedo) == NULL) {
        redo_append_lit(cap->searchbuf, -1);
      }
      redo_append_str(S_LEN(NL_STR));
    } else if (excmd) {
      // do_cmdline() has stored the first typed line in "repeat_cmdline". When several lines are
      // typed repeating won't be possible.
      if (repeat_cmdline == NULL) {
        redo_new((CmdSpec){ 0 });
      } else {
        if (cap->cmdchar == ':') {
          redo_append_lit(repeat_cmdline, -1);
        } else {
          redo_append_spec(repeat_cmdline);
        }
        redo_append_str(S_LEN(NL_STR));
        XFREE_CLEAR(repeat_cmdline);
      }
    } else if (cap->cmdchar == K_LUA) {
      redo_append_num(repeat_luaref);
      redo_append_str(S_LEN(NL_STR));
    }
  } else if (Visual.active && redoable && oap->motion_force == NUL) {
    if (op_self_select(cap)) {
      prep_redo(true, false, (CmdSpec){
        .regname = oap->regname, .count = cap->count0,
        .op = get_op_char(oap->op_type), .op_extra = get_extra_op_char(oap->op_type),
        .motion_force = oap->motion_force, .cmd = cap->cmdchar, .cmd2 = cap->nchar,
      });
    } else if (ins_op && !excmd && cap->cmdchar != K_LUA) {
      // Visual-entered Insert: redo body opens with the selection's captured keys; appends the
      // op+text+<Esc>. Unreplayable (void) selection falls back to "1v" (fixed-size reselect).
      // (Ex/Lua-motion selections were already prepped above, as the motion's keys.)
      String v = atom_visual_span();
      prep_redo_visual(v.data != NULL ? v.data : "1v", v.data != NULL ? v.size : 2, (CmdSpec){
        .regname = oap->regname,
        .op = get_op_char(oap->op_type), .op_extra = get_extra_op_char(oap->op_type),
      });
      xfree(v.data);
    }
  }
}

/// Delimits an insert-session, called before its edit(). The session either insert-cascades (spans
/// replay at every cursor) or is captured whole at <Esc>.
///
/// No insert-cascade when:
/// - Count is given ("[count]i…").
/// - Replace mode (R, gR, r<CR>, gr): continuation spans re-enter with "i".
/// - Blockwise ("1vI", CTRL-V+"jc").
/// - Entered from Visual without captured keys: cannot re-execute.
///
/// @param cmd     Entry command char, edit()-style ('i', 'a', 'R', 'v' = gr, …).
/// @param count   Count given to the entry command.
/// @param vis     How the session was entered from Visual mode.
/// @param vblock  The Visual selection was blockwise.
InsSession atom_ins_start(int cmd, long count, VisualIns vis, bool vblock)
{
  InsSession session = {
    .typed = atom_is_user_input(),  // Sampled before the session.
    .vis = vis,
    // A consumed selection opens the redo body, so the atom starts where the selection did.
    // Else the CmdFrame origin, from before the entry moved the cursor (a/A/…).
    .origin = vis == kVInsKeys ? vatom.origin
                               : cur_frame != NULL ? cur_frame->origin : atom_origin(),
  };
  if (vis != kVInsNone && !mc_replaying()) {
    if (vis == kVInsKeys && !(atom_visual_replayable() && (vatom.state & kVatomTyped))) {
      // The selection came from fed keys (":norm", scheduled feedkeys).
      session.typed = false;
    }
    // The selection is consumed: already in the redo body. Also clears selection display.
    atom_visual_reset();
  }
  // bool repl = cmd == 'R' || cmd == 'V' || cmd == 'r' || cmd == 'v';
  // mc_ins_cascade_start(session.typed && count <= 1 && !repl
  //                      && (vis == kVInsNone || (vis == kVInsKeys && !vblock)),
  //                      session.origin.tick);
  return session;
}

/// Ends the insert-session delimited by atom_ins_start(), capturing it as one atom. Replaying the
/// whole session (not spans), applies the entry cursor placement ("A", "o", "cw") and autocommands.
///
/// @param busy  True when edit() returned early (i_CTRL-O): session incomplete.
void atom_ins_end(const InsSession *session, bool busy)
{
  bool visual = session->vis != kVInsNone;
  if (!session->typed || busy || restart_edit != 0 || !atom_buf_has_consumers()
      || (visual && session->vis != kVInsKeys)) {
    if (session->typed && (busy || restart_edit != 0) && atom_composite_active()) {
      // Incomplete session (i_CTRL-O): its resolution is never captured.
      composite.lossy = true;
    }
    return;
  }
  atom_ins_push(session, true);
}

/// Pushes the ended insert-session as one atom. Skips a session not ending in <Esc>, except
/// self-terminating "r<CR>"/"grx".
static void atom_ins_push(const InsSession *session, bool cascade)
{
  CmdAtom atom = atom_from_redo(session->vis != kVInsNone ? kAVisual : kAInsert);
  size_t size = atom.keys != NULL ? strlen(atom.keys) : 0;
  bool replace = atom.spec.cmd == 'r' || (atom.spec.cmd == 'g' && atom.spec.cmd2 == 'r');
  if (size == 0 || (!replace && (uint8_t)atom.keys[size - 1] != ESC)) {
    atom_free(&atom);
    return;
  }
  atom.text = get_last_insert_save();
  atom.origin = session->origin;
  atom_push_raw(cascade, &atom);
}

/// Samples the pre-command state at normal_execute() entry; atom_cmd_end() diffs against it to
/// classify the command (motion, Visual-mode transition, edit). Pushes the frame (`cur_frame`).
void atom_cmd_start(CmdFrame *old)
{
  old->origin = atom_origin();
  old->visual = Visual;
  old->keytyped = KeyTyped;
  old->captures = atom_captures;
  old->id = ++frame_id;
  // Sampled: "q=" toggled DURING a command must not apply to it retroactively.
  old->follow = false;
  old->consumers = atom_buf_has_consumers();
  // Diffed at command end: detects a register-write (yank).
  old->reg_ts = old->consumers ? reg_max_ts(true) : 0;
  old->staged = (CmdAtom){ 0 };
  old->payload_start = SIZE_MAX;
  old->payload_end = 0;
  old->parent = cur_frame;
  cur_frame = old;
  curcmd.op_global = false;
  // A stuffed continuation frame keeps the redo-prep. "!ipsort<CR>" spans both frames.
  if (!(KeyStuffed && curcmd.redo_frame == old->id)) {
    atom_redo_reset();
  }
}

/// Captures the typed command's atom: one atom per command, produced from the CmdFrame diff and
/// routed by atom_push_raw() (emit, or collect as a mapping/Visual subatom).
///
/// Skipped for a command that stuffed keys ("x" stuffs "dl": its resolution is the atom), or that
/// already captured its own atom (do_pending_operator(), insert spans).
static void atom_capture_cmd(cmdarg_T *ca, CmdFrame *old)
{
  if (mc_replaying() || atom_suppressed) {
    return;
  }

  //
  // Classify
  //
  const bool user = atom_is_user_cmd();
  const unsigned keycls = atom_key_class(ca->cmdchar, ca->nchar);
  // Opaque cmd that changed nothing is invisible; one that changed the buffer/selection voids the
  // pending visual atom (see `kKeyOpaque`).
  //
  // XXX: This "state diff" is ad hoc: a synthetic change to unobserved state (e.g. only w_curswant)
  // counts as no-op. Extend this (or atom_key_class()) when such a case is reported...
  bool opaque = (keycls & kKeyOpaque) != 0;
  bool synthetic = (keycls & kKeySynthetic) != 0;
  bool unchanged = curbuf == old->origin.buf.br_buf && curwin == old->origin.win
                   && !atom_origin_moved(old->origin)
                   && !atom_origin_changed(old->origin)
                   && Visual.active == old->visual.active
                   && (!Visual.active
                       || (equalpos(old->visual.start, Visual.start)
                           && old->visual.mode == Visual.mode));
  if (opaque && unchanged) {
    return;
  }
  bool ins_cascaded = user && curcmd.ins_cascaded;
  // Command from a mapping's RHS (typed keys have KeyTyped set).
  bool mapped = user && !old->keytyped && !synthetic;
  if (mapped
      // NOT if cursor-global op: cascading (e.g. vim-repeat "nmap u") would undo at every cursor.
      && !curcmd.op_global
      // NOT if it ended in another buffer: a navigation mapping ("nnoremap <M-l> <C-w>l")
      // entering a buffer with cursors must not cascade.
      && ((curbuf == old->origin.buf.br_buf && atom_origin_changed(old->origin)) || ins_cascaded)) {
    map_edit = true;
  }

  //
  // Visual session: open/continue/close, and decide if this command is one of its subatoms.
  //
  bool vis = false;
  if (Visual.active) {
    if (!old->visual.active) {
      atom_visual_reset();
      // Decided once, at session start.
      vatom.state = (old->keytyped || (atom_composite_active() && atom_is_user_cmd()))
                    ? kVatomTyped : kVatomFed;
      vatom.origin = old->origin;
    }
    // Decided by the session (not atom_capturable()), so fed selections (":normal! vjd") still
    // accumulate for redo-prep. Recording/replay commands are meta (not part of the edit).
    vis = atom_visual_pending() && ca->cmdchar != 'Q' && ca->cmdchar != 'q';
    if (vis
        && (Visual.select
            || (ca->cmdchar == 'g' && ca->nchar == 'v')
            || ((keycls & (kKeyScrollMove | kKeyScrollView | kKeyMouse)) && !unchanged))) {
      // Not replayable: Select-mode input; "gv" (absolute region); the selection moved by
      // viewport-dependent keys.
      vatom.state |= kVatomVoid;
    }
  } else if (old->visual.active) {
    if (user && old->follow && atom_visual_replayable() && kv_size(vatom.atoms) > 0) {
      // Follow-motion ("q="): a selection abandoned without an operator (<Esc>, "v" toggle) still
      // moved the primary cursor to the selection end: replay it at every cursor.
      char suffix[2] = { ESC, NUL };
      atom_visual_end_suffix(xstrdup(suffix), NULL, false);
    } else {
      atom_visual_reset();
    }
  }

  //
  // Capture: does this command own an atom?
  //
  if (!stuff_empty() && curcmd.redo_frame == old->id && !Visual.active && !old->visual.active) {
    // The stuffed continuation completes the redo (op_filter/do_bang()), and is the next frame
    // (stuff precedes typeahead). Flushed instead? atom_cmd_start() checks KeyStuffed.
    curcmd.redo_frame = old->id + 1;
  }
  if ((vis && atom_captures == old->captures && ca->oap->op_type == OP_NOP)
      || (!Visual.active
          && !old->visual.active
          && atom_capturable(old->consumers, old->keytyped)
          && atom_captures == old->captures
          && !atom_staged()
          && ca->oap->op_type == OP_NOP
          && stuff_empty()
          && !ins_cascaded)) {
    const size_t collected = kv_size(vatom.atoms);
    // KeyTyped survives stuffing but not macro playback; mapping/macro-fed commands are covered by
    // atom_composite_active().
    bool special_motion = (keycls & kKeyMotion) != 0;
    bool scroll_cmd = (keycls & (kKeyScrollMove | kKeyScrollView)) != 0;
    bool mouse_cmd = (keycls & kKeyMouse) != 0;
    bool jump_cmd = (keycls & kKeyJump) != 0;
    // Replayable? Register prefix ('"x') is captured as part of the command it prefixes; "@x"/"Q"
    // are translations, their resolution is the atom stream.
    bool replayable = (ca->cmdchar > 0 && ca->cmdchar < 0x100
                       && ca->cmdchar != '"' && ca->cmdchar != '@' && ca->cmdchar != 'Q'
                       && !scroll_cmd)
                      || special_motion;
    bool changed = atom_origin_changed(old->origin);
    // Note: an operator's motion belongs to the operator (`finish_op`).
    bool motion = (nv_is_motion(ca->cmdchar) || special_motion) && !changed
                  && !finish_op && !jump_cmd;
    // Mapping-internal motions are part of its recipe: queue them, the clock edge decides.
    bool follow = (mc_following() || mapped) && motion;

    //
    // Route: decide the atom type and push it.
    //
    if (curcmd.redo_frame == old->id && !mouse_cmd) {
      // Not for mouse commands (middle-click paste): pasting at every cursor would use
      // viewport-dependent positions.
      CmdAtom atom = atom_from_redo(kAOperator);
      // The payload ('operatorfunc' getchar()) is not in the captured redo, append it.
      atom_payload_append(&atom, old);
      // Cascade only on an OBSERVABLE effect: an edit or register write. A redoable operator that
      // did neither is a no-op (vim-surround "ysa[" whose surround char was <Esc>).
      bool effect = changed || reg_max_ts(true) > old->reg_ts;
      if (atom.keys != NULL && *atom.keys != NUL) {
        atom.origin = old->origin;
        atom_push(effect, &atom);
      } else {
        atom_free(&atom);
      }
    } else if (ca->searchbuf != NULL && (ca->cmdchar == '/' || ca->cmdchar == '?')
               && !(vis && unchanged)) {
      // Payload typed in the cmdline ("/pat<CR>"). Emit-only. Not if pattern was not found.
      CmdAtom atom = atom_from_cmdline(kAMotion, ca, ca->searchbuf);
      atom.origin = old->origin;
      atom_push(false, &atom);
    } else if (!vis && curcmd.cmdline != NULL && (ca->cmdchar == ':' || ca->cmdchar == K_COMMAND)) {
      // Same for ":cnext<CR>" or "<Cmd>cnext<CR>". Never a Visual subatom.
      CmdAtom atom = atom_from_cmdline(kAExcmd, ca, curcmd.cmdline);
      // Payload read during the cmdline execution (`ds)` getchar() => ")").
      atom_payload_append(&atom, old);
      atom.origin = old->origin;
      atom_push(false, &atom);
    } else if (replayable && (!vis || (keycls & kKeyPayload) == 0)) {
      // Non-redoable command (u, zz, q=): never cascaded as an edit.
      CmdSpec spec = atom_cmd_spec(ca);
      if (vis) {
        // Omit `regname`: would prefix '"x' to every command collected; op-end re-adds it later.
        spec.regname = 0;
      }
      CmdAtom atom = atom_from_spec(motion ? kAMotion : jump_cmd ? kAJump : kANormal, spec);
      atom.origin = old->origin;
      atom_push(follow, &atom);
    } else if ((scroll_cmd || mouse_cmd) && !atom_composite_active()) {
      // Emit-only (viewport-dependent).
      CmdSpec spec = atom_cmd_spec(ca);
      if (IS_SPECIAL(ca->cmdchar)) {
        // Wheel/mouse count is never typed: do_mousescroll() wrote its internal step there.
        spec.count = 0;
      }
      CmdAtom atom = atom_from_spec(scroll_cmd ? kAScroll : kAMouse, spec);
      atom.origin = old->origin;
      atom_push(false, &atom);
    }
    if (vis && kv_size(vatom.atoms) == collected && !unchanged) {
      // Not replayable: moved the selection by non-collectible keys.
      vatom.state |= kVatomVoid;
    }
  }
  if (vis && (curbuf != old->origin.buf.br_buf || atom_origin_changed(old->origin))) {
    // Not replayable: edited buffer during selection, so the keys do not describe the change.
    vatom.state |= kVatomVoid;
  }
  if (Visual.active && user && old->parent == NULL) {
    mc_vsel_refresh();
  }
}

/// Completes a cmd at normal_execute() exit: captures its atom, pushes its staged one, ends the
/// composite. Pops the frame.
void atom_cmd_end(cmdarg_T *ca, CmdFrame *old)
{
  atom_capture_cmd(ca, old);
  atom_stage_flush(old);
  if (atom_composite_active() && old->payload_start != SIZE_MAX
      && old->payload_end > old->payload_start) {
    // An eval-read payload with no capturing atom (Lua mapping's getchar()).
    composite.lossy = true;
  }

  // The clock edge. Only at toplevel: cascading from a nested normal_execute() would recurse.
  // Deferred while a mapping executes (its keys are still in typebuf), so its commands collapse as
  // one unit; likewise for a macro's LAST command, which may stuff a translation ("x" => "dl").
  if (old->parent == NULL && !mc_replaying() && typebuf_typed() && stuff_empty()) {
    mc_clock_edge(map_edit);
    map_edit = false;
    // Mapping contains its continuation. While op-pending, selection-active, or insert-will-resume
    // (i_CTRL-O), composite keeps collecting: ",Dw" (":nnoremap ,D d") is one atom, `keys="dw"`.
    if (ca->oap->op_type == OP_NOP && !Visual.active && restart_edit == 0) {
      atom_composite_end();
    }
  }
  cur_frame = old->parent;
}
