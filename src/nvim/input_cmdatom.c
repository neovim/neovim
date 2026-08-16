// input_cmdatom.c: The input engine "policy layer" (input.c. is the "bytes layer").
//
// Decides _structure_ of user input and captures it as a "CmdAtom": a repeatable unit (edit,
// motion, visual sequence, insert session, mapping), a dot-repeat-style keysequence plus structured
// fields (CmdSpec).
//
// Every "user action" is an atom (emits CmdAtom event), but not every atom is "replayable".
// - Replayable (cascade, dot-repeat) requires the full command grammar.
// - No atoms for: mouse drag/release (TODO(justinmk)?), terminal-mode input, aborted operations,
//   command fragments (counts, register prefixes).

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
#include "nvim/register.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/vim_defs.h"

#include "input_cmdatom.c.generated.h"

CmdAtomVec g_atoms = KV_INITIAL_VALUE;
/// Total atoms ever pushed: so atom_cmd_start() can detect if a cmd already pushed its own atom.
static uint64_t atom_pushes = 0;
/// Suppresses atom pushes.
static bool atom_suppressed = false;
/// Mapping edited the buffer, or its insert-session cascaded: cascades as one unit, incl. motions.
static bool map_edit = false;

/// Accumulating composite atom: the executing mapping/macro's subatoms, collected while it runs and
/// collapsed at the command end. See `vatom` for Visual composite.
static struct {
  CmdAtomVec atoms;
  char *lhs;          ///< Label: mapping LHS or macro "@x" (NULL: not collecting).
  bool queued;        ///< A cascadable atom was queued (g_atoms) while collecting.
  bool macro;         ///< Macro execution: captured as an "@x"-labeled atom.
  varnumber_T tick;   ///< b:changedtick at start.
} composite;

/// Staged atom, will be pushed at command end.
static struct {
  CmdAtom atom;      ///< One is staged when `keys` is non-NULL.
  varnumber_T tick;  ///< b:changedtick when the atom was staged
} stage;

/// State of a Visual composite atom.
typedef enum {
  // Nothing to replay:
  kVatomNone,      ///< No pending visual atom.
  kVatomVoid,      ///< Visual keyseq was tainted/poisoned (by mouse, gv, …), not replayable.

  // Accumulating, replayable:
  kVatomTyped,     ///< User input (typed, or mapping/macro): emitted/cascaded at end.
  kVatomFed,       ///< Fed input (":norm! vjd", scheduled feedkeys): preps redo, no emit/cascade.
} VatomState;

/// Accumulating Visual composite: the full Visual keysequence, including the selection steps.
static struct {
  CmdAtomVec atoms;  ///< Accumulated atoms during Visual mode.
  VatomState state;
} vatom;

/// Per-command capture scratch.
static struct {
  bool redo_pending;  ///< The command prepped the change atom (prep_redo*()).
  char *cmdline;      ///< The ":" payload captured at cmdline accept. NULL: none.
                      ///< Note: search payloads ("/pat<CR>") travel on `cmdarg.searchbuf`.
  bool ins_cascaded;  ///< Did the command's insert-session already cascade?
  bool op_global;     ///< Already applied to every cursor (undo, "g CTRL-A"): must not cascade.
} curcmd;

/// Interactively typed keys of the executing command. Two slices mark keys read by getchar(), which
/// the redo body never sees: 'operatorfunc' input, and the mapping payload ("ds'" reads "'").
static struct {
  kvec_t(uint8_t) keys;
  bool opfunc_active;               ///< Collecting 'operatorfunc' input.
  size_t opfunc_start, opfunc_end;  ///< opfunc slice: keys[opfunc_start..opfunc_end)
  size_t map_start;                 ///< mapping slice: keys[map_start..kv_size(keys))
} typed;

static const char *const type_names[] = {
  [kACommand] = "command",
  [kAEx] = "ex",
  [kAInsert] = "insert",
  [kAInsertSpan] = "insert",  // spans display as "insert" (as a composite's `atoms`)
  [kAJump] = "jump",
  [kAMapping] = "mapping",
  [kAMotion] = "motion",
  [kAMouse] = "mouse",
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
  atom_stage_drop();
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
    .arg = operand ? cap->nchar : NUL,
  };
}

/// Composes "redo keys" (allocated) from `spec`, as prep_redo() + "." would: for commands
/// that never prep (motions, "u", "zz"). NULL during a cascade.
static char *atom_compose_keys(CmdSpec spec)
{
  StringBuilder sb = KV_INITIAL_VALUE;
  redo_prefix(&spec, &sb, false);
  redo_chars(&spec, &sb, false);
  if (sb.size == 0) {
    return NULL;
  }
  assert(sb.items != NULL);  // Coverity false-positive (already checked `size` above).
  kv_push(sb, NUL);
  return sb.items;
}

/// The pending change as a CmdAtom: the composed keysequence plus the structured fields.
/// Caller owns `keys`.
static CmdAtom atom_from_redo(CmdAtomType type)
{
  String keys = redo_keys();
  return (CmdAtom){ .type = type, .spec = redo_spec(), .keys = keys.data };
}

/// Builds a CmdAtom whose `keys` (atom_compose_keys()) and fields both come from `spec`.
static CmdAtom atom_from_spec(CmdAtomType type, CmdSpec spec)
{
  return (CmdAtom){ .type = type, .spec = spec, .keys = atom_compose_keys(spec) };
}

/// Builds the atom of a typed cmdline:
///   ":cnext<CR>" => CmdAtom{ kAEx, keys=":cnext<NL>", text="cnext" }
static CmdAtom atom_from_cmdline(CmdAtomType type, cmdarg_T *ca, const char *line)
{
  StringBuilder sb = KV_INITIAL_VALUE;
  if (type != kAEx && ca->count0 != 0) {
    kv_printf(sb, "%d", ca->count0);
  }
  sb_add_char(&sb, ca->cmdchar);
  sb_add_lit(&sb, line, -1);
  sb_add_char(&sb, NL);
  kv_push(sb, NUL);
  return (CmdAtom){
    .type = type,
    .spec = { .count = ca->count0, .cmd = ca->cmdchar },
    .keys = sb.items,
    .text = xstrdup(line),
  };
}

/// Concatenates the keys of multiple atoms into one (allocated) string.
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
  char *arg = atom_key_name(spec->arg);
  if (arg != NULL && *arg != NUL) {
    PUT(d, "arg", CSTR_AS_OBJ(arg));
  } else {
    xfree(arg);
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
  // keys/lhs are RAW bytes (typeahead encoding).
  PUT(d, "keys", CSTR_TO_OBJ(atom->keys != NULL ? atom->keys : ""));
  if (atom->lhs != NULL && *atom->lhs != NUL) {
    PUT(d, "lhs", CSTR_TO_OBJ(atom->lhs));
  }
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
static void atom_emit(const CmdAtom *atom, const char *pending, bool cascade)
{
  if (!has_event(EVENT_CMDATOM)) {
    return;
  }
  Dict data = atom_dict(atom);
  PUT(data, "cascade", BOOLEAN_OBJ(cascade));
  if (kv_size(atom->atoms) > 0) {
    Array atoms = ARRAY_DICT_INIT;
    for (size_t i = 0; i < kv_size(atom->atoms); i++) {
      ADD(atoms, DICT_OBJ(atom_dict(&kv_A(atom->atoms, i))));
    }
    PUT(data, "atoms", ARRAY_OBJ(atoms));
  }
  if (*pending != NUL) {
    PUT(data, "pending", CSTR_TO_OBJ(pending));
  }
  aucmd_defer(EVENT_CMDATOM, (char *)type_names[atom->type], NULL, AUGROUP_ALL, curbuf, NULL,
              &DICT_OBJ(data));
  api_free_dict(data);
}

/// Emits a CmdAtom event, or collects it as a subatom of a composite. If `cascade` is true, queues
/// a copy for mcursor cascade.
///
/// Takes ownership of the atom's allocated members. Caller sets `atom.changed`.
void atom_push_raw(bool cascade, CmdAtom atom)
{
  assert(atom.keys != NULL);
  atom_pushes++;
  if (atom.type == kAVisual && kv_size(atom.atoms) > 0) {
    // The completing operator is the only subatom that could have edited.
    CmdAtom *last = &kv_A(atom.atoms, kv_size(atom.atoms) - 1);
    if (last->type == kAOperator) {
      last->changed = atom.changed;
    }
  }
  if (cascade && composite.lhs != NULL) {
    composite.queued = true;
  }
  if (composite.lhs != NULL) {
    kv_push(composite.atoms, atom);
  } else {
    if (atom.type != kAInsertSpan) {
      // Spans are cascade-internal; only emit the whole session (kAInsert).
      atom_emit(&atom, "", cascade);
    }
    atom_free(&atom);
  }
}

/// Pushes an atom (emit + maybe cascade), or drops it if replay/Visual/internal-op already
/// in-progress.
static void atom_push(bool cascade, CmdAtom atom)
{
  if (atom_blocked()) {
    atom_free(&atom);
    return;
  }
  atom_push_raw(cascade, atom);
}

/// Stages an atom built before its command executes (do_pending_operator() prep-exempt, Visual
/// ops); will be pushed at command end, once `changed` is known.
static void atom_stage_set(CmdAtom atom)
{
  assert(!atom_staged());  // If this happens, the stage may need to become a stack...
  atom_stage_drop();
  if (atom_blocked()) {
    // Now, not at flush: drop the atom of an internal operator (atom_suppress()).
    atom_free(&atom);
    return;
  }
  assert(atom.keys != NULL);
  stage.atom = atom;
  stage.tick = buf_get_changedtick(curbuf);
}

/// True if an atom is staged for the current command.
static bool atom_staged(void)
{
  return stage.atom.keys != NULL;
}

/// Discards the staged atom.
static void atom_stage_drop(void)
{
  atom_free(&stage.atom);  // `keys=NULL` means "nothing staged".
}

/// Pushes the staged atom (no-op if none).
static void atom_stage_flush(void)
{
  if (!atom_staged()) {
    return;
  }
  stage.atom.changed = buf_get_changedtick(curbuf) != stage.tick;
  atom_push(true, stage.atom);  // Staged commands are always edits (cascadable).
  stage.atom = (CmdAtom){ 0 };
}

/// Queues an LHS-replay atom: a mapping that edited invisibly (:normal/:call, "ds'") re-runs
/// per cursor from its LHS + payload keys. Cascade only.
void atom_lhs_replay_queue(void)
{
  StringBuilder keys = KV_INITIAL_VALUE;
  kv_concat(keys, composite.lhs);
  kv_concat_len(keys, (char *)typed.keys.items + typed.map_start,
                kv_size(typed.keys) - typed.map_start);
  kv_push(keys, NUL);
  kv_push(g_atoms, ((CmdAtom){ .type = kAMapping, .keys = keys.items, .remap = true }));
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
  composite.tick = buf_get_changedtick(curbuf);
}

/// Collapses the collected subatoms (`CmdAtom.atoms`) and emits the composite atom.
///
///      :nnoremap gj i<C-J><Esc>k$
///      "gj" => CmdAtom{ .lhs="gj", .keys="1i<NL><Esc>k$", kAMapping }
static void atom_composite_end(const char *pending)
{
  composite.macro = false;  // "@x" capture ends with its composite.
  if (composite.lhs == NULL) {
    return;
  }
  char *lhs = composite.lhs;
  composite.lhs = NULL;
  CmdAtom atom;
  if (kv_size(composite.atoms) == 0) {
    // The mapping's commands captured nothing (Ex/Lua commands, no-ops): but it is still a user
    // action, so emit it with empty keys (identified by `lhs`).
    atom = (CmdAtom){ .type = kAMapping, .keys = xstrdup(""), .lhs = lhs,
                      .changed = buf_get_changedtick(curbuf) != composite.tick };
  } else if (kv_size(composite.atoms) == 1) {
    // Single subatom. "Unwrap" it so e.g. a motion mapping reports kAMotion, not kAMapping.
    atom = kv_pop(composite.atoms);
    xfree(atom.lhs);
    atom.lhs = lhs;
  } else {
    atom = (CmdAtom){ .type = kAMapping, .keys = atoms_concat_keys(composite.atoms).data,
                      .lhs = lhs, .changed = buf_get_changedtick(curbuf) != composite.tick };
    atom.atoms = composite.atoms;  // Subatoms.
    composite.atoms = (CmdAtomVec)KV_INITIAL_VALUE;  // Reset.
  }
  atom_emit(&atom, pending, composite.queued);
  atom_free(&atom);
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
  return KeyTyped || (atom_is_user_cmd() && typebuf_maplen() > 0);
}

/// Suppresses atom pushes. For internal operators.
void atom_suppress(bool suppress)
{
  atom_suppressed = suppress;
}

/// Block atom pushes if: cascade in-progress, internal op is executing, or vatom is accumulating.
static bool atom_blocked(void)
{
  return atom_suppressed || (vatom.state != kVatomNone && Visual.active);
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
  case K_COMMAND:
  case K_LUA:
    return kKeySynthetic;
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
  case 'g':
    return (arg == ';' || arg == ',') ? kKeyJump : 0;
  case '[':
  case ']':
    return arg == 'C' ? kKeyJump : 0;  // "]C"/"[C": jump to the next/previous cursor
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

/// Captures an accepted ":" cmdline payload.
void atom_cmdline_set(int firstc, const char *line, size_t len)
{
  // Not for nested cmdlines opened by a command's own execution (":normal", macros): they would
  // overwrite the user command's payload, e.g. `:exe "normal! :echo 1\r"`.
  if (!atom_is_user_cmd() || firstc != ':') {
    return;
  }
  xfree(curcmd.cmdline);
  curcmd.cmdline = xmemdupz(line, len);
}

/// Opens/closes the 'operatorfunc' slice of the typed-key stream.
void atom_opfunc_slice(bool active)
{
  typed.opfunc_active = active;
  if (active) {
    typed.opfunc_start = kv_size(typed.keys);
  }
  typed.opfunc_end = kv_size(typed.keys);
}

/// Collects a typed key (gotchars()) into the stream.
void atom_typed_add(const uint8_t *chars, size_t len)
{
  if (!typed.opfunc_active && !atom_composite_active()) {
    return;
  }
  for (size_t i = 0; i < len; i++) {
    kv_push(typed.keys, chars[i]);
  }
}

/// Undoes atom_typed_add() for the last `len` bytes: a key that was read is being re-queued
/// into typeahead and will be collected again (ungetchars()).
void atom_typed_del(size_t len)
{
  if (!typed.opfunc_active && !atom_composite_active()) {
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
  curcmd.redo_pending = false;
  curcmd.ins_cascaded = false;
  XFREE_CLEAR(curcmd.cmdline);
  // The opfunc slice resets per command; the stream itself is truncated only once the
  // mapping slice ends too (with its composite).
  if (!atom_composite_active()) {
    kv_size(typed.keys) = 0;
    typed.map_start = 0;
  }
  typed.opfunc_start = typed.opfunc_end = kv_size(typed.keys);
}

/// Marks the running command as already applying to every cursor (see `curcmd.op_global`).
/// Called by u_doit() and mc_counter().
void atom_op_global_set(void)
{
  curcmd.op_global = true;
}

/// Claims the prepped redo as the command's atom. Only toplevel user commands (a nested redo-prep
/// is not an atom). Declines Ex/Lua operators.
void atom_redo_set(CmdSpec spec)
{
  if (spec.cmd == ':' || spec.cmd == K_COMMAND || spec.cmd == K_LUA) {
    atom_redo_reset();
    return;
  }
  if (atom_is_user_cmd()) {
    curcmd.redo_pending = true;
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

/// Starts accumulating a composite for a mapping resolved from typed keys (vgetorpeek()).
void atom_map_start(const char *lhs, size_t len)
{
  if (!atom_has_consumers()
      || reg_executing != 0 || ex_normal_busy != 0 || !(State & MODE_NORMAL)
      || Visual.active) {
    return;
  }
  atom_composite_start(lhs, len);
  typed.map_start = kv_size(typed.keys);
}

/// Discards the pending visual atom. Not a lifecycle end: also runs before a session starts.
static void atom_visual_reset(void)
{
  vatom.state = kVatomNone;
  atoms_free(&vatom.atoms);
}

/// True if the pending visual atom is replayable (accumulating, not voided).
bool atom_visual_replayable(void)
{
  return vatom.state == kVatomTyped || vatom.state == kVatomFed;
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

/// Captures a typed Visual-mode command into the pending visual atom (vatom): one subatom of
/// the accumulating "viwee"-style keysequence.
static void atom_capture_visual(cmdarg_T *ca, const CmdBaseline *old)
{
  if (!atom_visual_replayable()) {
    return;
  }
  unsigned keycls = atom_key_class(ca->cmdchar, ca->nchar);
  if (Visual.select || ca->cmdchar >= 0x100
      || (keycls & (kKeyPayload | kKeyScrollMove)) != 0
      || (ca->cmdchar == 'g' && ca->nchar == 'v')) {
    // Not replayable: mouse/special keys, motions with an interactively-typed payload, Select mode,
    // "gv" (an absolute region), scrolling that moves the cursor (viewport-dependent extents).
    vatom.state = kVatomVoid;
    return;
  }
  if ((keycls & kKeyScrollView) != 0) {
    // A viewport scroll (C-E/C-Y) does not change the selection, UNLESS it dragged the cursor along
    // (viewport edge, 'scrolloff'), which moved the selection end.
    if (!equalpos(old->pos, curwin->w_cursor)) {
      vatom.state = kVatomVoid;
    }
    return;
  }
  if (ca->cmdchar == 'Q' || ca->cmdchar == 'q' || ca->cmdchar == '"') {
    // Skip: recording/replay commands are meta (not part of the edit); a register spec ('"x') is
    // re-added by the operator that ends the selection (redo_prefix()).
    return;
  }
  bool operand = nv_nchar_is_arg(ca->cmdchar);
  // Omit `regname`, it would prefix '"x' to every command captured after a register spec.
  CmdSpec spec = { .count = ca->count0, .cmd = ca->cmdchar,
                   .cmd2 = operand ? NUL : ca->nchar, .arg = operand ? ca->nchar : NUL };
  char *keys = atom_compose_keys(spec);
  if (keys == NULL) {
    return;
  }
  kv_push(vatom.atoms, ((CmdAtom){ .type = kAMotion, .spec = spec, .keys = keys }));
}

/// Ends the pending visual atom, appends `suffix`, and stages it. Or discards it if selection is
/// unreplayable (void/absent).
///
/// @param suffix  Owned.
/// @param spec  The completing operator, or NULL.
/// @param redoable  Prep redo so "." re-executes the selection. Unreplayable (void/absent)
///                  selection preps "1v" + operator instead (Vim's fixed-size visual-repeat).
/// @return  True if the redo was prepped.
static bool atom_visual_end_suffix(char *suffix, const CmdSpec *spec, bool redoable)
{
  if (atom_suppressed) {
    // Replay, or internal operator applied as part of another command.
    xfree(suffix);
    return false;
  }
  const bool prep = redoable && spec != NULL;
  if (suffix == NULL || !atom_visual_replayable()) {
    bool prepped = prep && spec->op != NUL && suffix != NULL;
    if (prepped) {
      prep_redo("1v", 2, false, (CmdSpec){ 0 });  // Equal-size fallback.
      redo_append_str(suffix, -1);
    }
    xfree(suffix);
    atom_visual_reset();
    return prepped;
  }
  String v = atoms_concat_keys(vatom.atoms);
  char *vkeys = v.data;
  size_t prefix = v.size;
  if (prep) {
    // Get the redo tail (register/count, op chars) from the suffix. Prevents divergence of prep vs
    // atom, and suffixes inexpressible as spec chars ("r<C-V><CR>") stay replayable.
    prep_redo(vkeys, prefix, false, (CmdSpec){ 0 });
    redo_append_str(suffix, -1);
  }
  if (!atom_is_user_cmd() || vatom.state != kVatomTyped) {
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
  };
  if (spec != NULL) {
    kv_push(vatom.atoms, ((CmdAtom){ .type = kAOperator, .spec = *spec, .keys = suffix }));
  } else {
    xfree(suffix);
  }
  atom.atoms = vatom.atoms;
  vatom.atoms = (CmdAtomVec)KV_INITIAL_VALUE;
  atom_visual_reset();
  atom_stage_set(atom);
  return prep;
}

/// Ends the pending visual atom with the operator `spec` ("viwee" + "x").
///
/// @return  True if the redo was prepped.
bool atom_visual_end(CmdSpec spec, bool redoable)
{
  return atom_visual_end_suffix(atom_compose_keys(spec), &spec, redoable);
}

/// Captures a pending operator's atom before it executes. Prep-exempt commands (yank without cpo-y,
/// "D", folds) build no redo, so atom_cmd_end() cannot derive their atom from redobuff; reconstruct
/// it here (staged).
///
/// Not for:
/// - OP_CHANGE/OP_INSERT/OP_APPEND
/// - motions with an interactively-typed payload (search, Ex, Lua)
///
/// @param redo_yank  True when a yank builds a redo ("y" in 'cpoptions', not a GUI yank).
void atom_capture_op(oparg_T *oap, cmdarg_T *cap, bool redo_yank)
{
  if (oap->op_type == OP_CHANGE || oap->op_type == OP_INSERT || oap->op_type == OP_APPEND) {
    return;
  }
  bool payload_motion = cap->cmdchar >= 0x100
                        || (cap->cmdchar != NUL && strchr("/?:!", cap->cmdchar) != NULL);
  if (payload_motion) {
    return;
  }
  const bool redoable = op_redoable(oap->op_type, redo_yank);
  bool prep_exempt = !redoable || cap->cmdchar == 'D';
  CmdSpec spec = {
    .regname = oap->regname, .count = cap->count0,
    .op = get_op_char(oap->op_type), .op_extra = get_extra_op_char(oap->op_type),
  };
  if (prep_exempt && (!Visual.active || oap->motion_force)) {
    // Only capture _user_ input.
    if (atom_buf_has_consumers() && atom_is_user_cmd() && (KeyTyped || atom_composite_active())) {
      bool operand = nv_nchar_is_arg(cap->cmdchar);
      spec.motion_force = oap->motion_force;
      spec.cmd = cap->cmdchar;
      spec.cmd2 = operand ? NUL : cap->nchar;
      spec.arg = operand ? cap->nchar : NUL;
      atom_stage_set(atom_from_spec(kAOperator, spec));
    }
  } else if (!Visual.active || oap->motion_force) {
    // Prepped: atom_cmd_end() derives the atom from redobuff.
  } else if (oap->op_type == OP_REPLACE && cap->nchar <= 0) {
    // Visual "r<C-V><CR>": `spec.arg` cannot represent the sentinel nchar (REPLACE_CR_NCHAR), so
    // hand-compose the literal suffix keys.
    char suffix[4] = { 'r', Ctrl_V, cap->nchar == REPLACE_CR_NCHAR ? CAR : NL, NUL };
    atom_visual_end_suffix(xstrdup(suffix), &spec, redoable);
  } else {
    // Visual-mode op: complete the accumulated visual atom with the operator keys.
    spec.arg = oap->op_type == OP_REPLACE ? cap->nchar : NUL;
    if ((oap->op_type == OP_NR_ADD || oap->op_type == OP_NR_SUB) && cap->arg) {
      // g<C-A>: the "g" variant is distinguished by cap->arg, not the op char: compose it back.
      spec.op_extra = spec.op;
      spec.op = 'g';
    }
    atom_visual_end(spec, redoable);
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
    .tick = buf_get_changedtick(curbuf),
  };
  if (vis != kVInsNone) {
    if (vis == kVInsKeys && vatom.state != kVatomTyped) {
      // The selection came from fed keys (":norm", scheduled feedkeys).
      session.typed = false;
    }
    // The selection is consumed: already in the redo body. Also clears selection display.
    atom_visual_reset();
  }
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
  atom.changed = buf_get_changedtick(curbuf) != session->tick;
  atom_push_raw(cascade, atom);
}

/// Samples the pre-command state at normal_execute() entry; atom_cmd_end() diffs against it to
/// classify the command (motion, Visual-mode transition, edit).
void atom_cmd_start(CmdBaseline *old)
{
  old->pos = curwin->w_cursor;
  old->buf = curbuf;
  old->tick = buf_get_changedtick(curbuf);
  old->visual = Visual;
  old->keytyped = KeyTyped;
  old->pushes = atom_pushes;
  // Sampled: "q=" toggled DURING a command must not apply to it retroactively.
  old->follow = false;
  old->consumers = atom_buf_has_consumers();
  // Diffed at command end: detects a register-write (yank).
  old->reg_ts = old->consumers ? reg_max_ts(true) : 0;
  old->staged = atom_staged();
  curcmd.op_global = false;
  atom_redo_reset();
}

/// Captures the typed command's atom: in Visual mode into `vatom`, else one atom per command.
///
/// Skipped for a command that stuffed keys ("x" stuffs "dl": its resolution is the atom), or that
/// already captured its own atom (do_pending_operator(), insert spans).
static void atom_capture_cmd(cmdarg_T *ca, const CmdBaseline *old, bool toplevel)
{
  // Not atom_blocked(): Visual capture must run while the vatom accumulates.
  if (atom_suppressed) {
    return;
  }
  // Non-user input (":normal", scripted macro) pushes no atoms, but still accumulates the vatom,
  // so its operator can prep a redo: ":normal! vjd" is dot-repeatable.
  const bool user = atom_is_user_cmd();
  const unsigned keycls = atom_key_class(ca->cmdchar, ca->nchar);
  // Synthetic commands (timers, RPC, plugin callbacks) are not user-input: one that changes
  // nothing is invisible; one that changes the buffer/selection voids the pending visual atom.
  //
  // XXX: This "state diff" is ad hoc: a synthetic change to unobserved state (e.g. only w_curswant)
  // counts as no-op. Extend this (or atom_key_class()) when such a case is reported...
  bool synthetic = (keycls & kKeySynthetic) != 0;
  bool unchanged = curbuf == old->buf
                   && equalpos(old->pos, curwin->w_cursor)
                   && buf_get_changedtick(curbuf) == old->tick
                   && Visual.active == old->visual.active
                   && (!Visual.active
                       || (equalpos(old->visual.start, Visual.start)
                           && old->visual.mode == Visual.mode));
  if (synthetic && unchanged) {
    return;
  }
  bool ins_cascaded = user && curcmd.ins_cascaded;
  // Command from a mapping's RHS (typed keys have KeyTyped set).
  bool mapped = user && !old->keytyped && !synthetic;
  if (mapped
      // NOT if cursor-global op: cascading (e.g. vim-repeat "nmap u") would undo at every cursor.
      && !curcmd.op_global
      && ((
           // NOT if it ended in another buffer: a navigation mapping ("nnoremap <M-l> <C-w>l")
           // entering a buffer with cursors must not cascade.
           curbuf == old->buf
           && buf_get_changedtick(curbuf) != old->tick) || ins_cascaded)) {
    map_edit = true;
  }
  if (Visual.active) {
    if (!old->visual.active) {
      atom_visual_reset();
      // Decided once, at session start.
      vatom.state = (old->keytyped || atom_composite_active()) ? kVatomTyped : kVatomFed;
    }
    atom_capture_visual(ca, old);
  } else if (old->visual.active) {
    if (user && old->follow && atom_visual_replayable() && kv_size(vatom.atoms) > 0) {
      // Follow-motion ("q="): a selection abandoned without an operator (<Esc>, "v" toggle) still
      // moved the primary cursor to the selection end: replay it at every cursor.
      char suffix[2] = { ESC, NUL };
      atom_visual_end_suffix(xstrdup(suffix), NULL, false);
    } else {
      atom_visual_reset();
    }
  } else if (user && old->consumers && atom_pushes == old->pushes && !atom_staged()
             && ca->oap->op_type == OP_NOP
             && stuff_empty() && !ins_cascaded
             && (old->keytyped || atom_composite_active())) {
    // KeyTyped survives stuffing but not macro playback; mapping/macro-fed commands are covered by
    // atom_composite_active().
    bool special_motion = (keycls & kKeyMotion) != 0;
    bool scroll_cmd = (keycls & (kKeyScrollMove | kKeyScrollView)) != 0;
    bool mouse_cmd = (keycls & kKeyMouse) != 0;
    bool jump_cmd = (keycls & kKeyJump) != 0;
    // Replayable? Register prefix ('"x') is captured as part of the command it prefixes; "@x"/"Q"
    // are translations, their resolution is the atom stream.
    bool capturable = (ca->cmdchar > 0 && ca->cmdchar < 0x100
                       && ca->cmdchar != '"' && ca->cmdchar != '@' && ca->cmdchar != 'Q'
                       && !scroll_cmd)
                      || special_motion;
    bool changed = buf_get_changedtick(curbuf) != old->tick;
    bool motion = curbuf == old->buf
                  && !equalpos(old->pos, curwin->w_cursor)
                  && !changed
                  && !finish_op && !jump_cmd
                  && ((ca->cmdchar > 0 && ca->cmdchar < 0x100
                       && strchr("/?:!Qq", ca->cmdchar) == NULL)
                      || special_motion);
    // Mapping-internal motions are part of its recipe: queue them, the clock edge decides.
    bool follow = mapped && motion;
    if (curcmd.redo_pending && !mouse_cmd) {
      // Not for mouse commands (middle-click paste): pasting at every cursor would use
      // viewport-dependent positions.
      CmdAtom atom = atom_from_redo(kAOperator);
      size_t plen = typed.opfunc_end - typed.opfunc_start;
      if (atom.keys != NULL && plen > 0) {
        // The opfunc's payload is absent from the captured redo: append it.
        size_t klen = strlen(atom.keys);
        atom.keys = xrealloc(atom.keys, klen + plen + 1);
        memcpy(atom.keys + klen, typed.keys.items + typed.opfunc_start, plen);
        atom.keys[klen + plen] = NUL;
      }
      // Cascade only on an OBSERVABLE effect: an edit or register write. A redoable operator that
      // did neither is a no-op (vim-surround "ysa[" whose surround char was <Esc>).
      bool effect = changed || reg_max_ts(true) > old->reg_ts;
      if (atom.keys != NULL && *atom.keys != NUL) {
        atom.changed = changed;
        atom_push(effect, atom);
      } else {
        atom_free(&atom);
      }
    } else if (ca->searchbuf != NULL && (ca->cmdchar == '/' || ca->cmdchar == '?')) {
      // Payload typed in the cmdline ("/pat<CR>"). Emit-only.
      CmdAtom atom = atom_from_cmdline(kAMotion, ca, ca->searchbuf);
      atom.changed = changed;
      atom_push(false, atom);
    } else if (curcmd.cmdline != NULL && ca->cmdchar == ':') {
      // Same for ":cnext<CR>".
      CmdAtom atom = atom_from_cmdline(kAEx, ca, curcmd.cmdline);
      atom.changed = changed;
      atom_push(false, atom);
    } else if (capturable) {
      // Non-redoable command (u, zz, q=): never cascaded as an edit.
      CmdAtom atom = atom_from_spec(motion ? kAMotion : jump_cmd ? kAJump : kACommand,
                                    atom_cmd_spec(ca));
      atom.changed = changed;
      atom_push(follow, atom);
    } else if ((scroll_cmd || mouse_cmd) && !atom_composite_active()) {
      // Emit-only (viewport-dependent), and never a subatom. Composite keys must stay replayable.
      CmdSpec spec = atom_cmd_spec(ca);
      if (IS_SPECIAL(ca->cmdchar)) {
        // Wheel/mouse count is never typed: do_mousescroll() wrote its internal step there.
        spec.count = 0;
      }
      CmdAtom atom = atom_from_spec(scroll_cmd ? kAScroll : kAMouse, spec);
      atom.changed = changed;
      atom_push(false, atom);
    }
  }
}

/// Completes a cmd at normal_execute() exit: captures its atom, pushes the staged one, ends the
/// composite.
void atom_cmd_end(cmdarg_T *ca, const CmdBaseline *old, bool toplevel)
{
  atom_capture_cmd(ca, old, toplevel);
  if (!old->staged) {
    // Flush only what this cmd staged. In case of nested :norm (e.g. 'indentexpr' during "gq").
    atom_stage_flush();
  }

  // The clock edge. Only at toplevel: cascading from a nested normal_execute() would recurse.
  // Deferred while a mapping executes (its keys are still in typebuf), so its commands collapse as
  // one unit; likewise for a macro's LAST command, which may stuff a translation ("x" => "dl").
  if (toplevel && typebuf_typed() && stuff_empty()) {
    map_edit = false;
    atom_composite_end(ca->oap->op_type != OP_NOP ? "operator" : Visual.active ? "visual" : "");
  }
}
