// input.c: The input engine "bytes layer" (input_cmdatom.c. is the "policy layer").
//
// - Get a character from the user, a script file, or the keybufs described below.
// - Apply mappings and abbreviations to typed keys (the :map tables live in mapping.c; the
//   matching loop is handle_mapping()).
// - Assemble K_SPECIAL/multibyte byte sequences into keys (vgetc()).
// - Record macros (recordbuff); capture the redo state (redobuff: "." capture and replay).
//
// Concepts:
// - "Stuffing" = when some internal logic pushes keys to execute next. This is how a cmd
//   "translates" into another cmd: "x" stuffs "dl" (nv_optrans()), "." stuffs the redo buf.
// - TYPEAHEAD vs READ-AHEAD:
//   - typeahead = external input that arrived faster than can be executed (user typed fast).
//   - readahead = Nvim's own self-input.
//     - vgetorpeek() drains it BEFORE typeahead.
//     - Its keys are never mapped (mappings apply only to the
//       typebuf; abbreviations are disabled too), though they count as typed for most purposes
//       (KeyStuffed).
//
// These buffers are used:
// - stuff buffers (`readbuf1`, `readbuf2`) are readahead buffers.
//   - TWO stuff buffers, because stuffing nests: a cmd executed FROM redo keys (readbuf2) may
//     itself stuff a translation (readbuf1), which must be consumed before the remaining redo.
// - `typebuf`: typeahead (see below).
// - `redobuff` (RedoState): the current + previous change.
// - `recordbuff`: accumulates the keys of a recording ("q").
//
// Buffer bytes use "typeahead encoding":
// - K_SPECIAL introduces a special key (two more bytes follow).
//   A literal K_SPECIAL is stored as K_SPECIAL KS_SPECIAL KE_FILLER.
// - These translations are also done on multi-byte characters!
// - Escaping K_SPECIAL is done by inchar().
// - Un-escaping is done by vgetc().

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/vars.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_getln_defs.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/input.h"
#include "nvim/input_cmdatom.h"
#include "nvim/insert.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/mapping.h"
#include "nvim/mapping_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/normal_defs.h"
#include "nvim/ops.h"
#include "nvim/option_vars.h"
#include "nvim/os/fileio.h"
#include "nvim/os/fileio_defs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/register.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"

/// State for adding bytes to a recording or 'showcmd'.
typedef struct {
  uint8_t buf[MB_MAXBYTES * 3 + 4];
  int prev_c;
  size_t buflen;
  unsigned pending_special;
  unsigned pending_mbyte;
} gotchars_state_T;

/// Index in scriptin
static int curscript = -1;
/// Streams to read script from
static FileDescriptor scriptin[NSCRIPT] = { 0 };

/// The current + previous change. redo_append_xx() captures in `redobuff.cur`; "." replays it.
static RedoState redobuff;
/// Macro recording.
static StringBuilder recordbuff = KV_INITIAL_VALUE;
/// First readahead buffer ("stuffbuf"): command translations ("x" => "dl"). Drains before readbuf2.
static StuffBuf readbuf1;
/// Second readahead buffer ("stuffbuf"): "." replay (start_redo()).
static StuffBuf readbuf2;
static UngotKey ungot = { .c = -1 };

/// Buffer used to store typed characters for vim.on_key().
static kvec_withinit_t(char, MAXMAPLEN + 1) on_key_buf = KVI_INITIAL_VALUE(on_key_buf);

/// Number of following bytes that should not be stored for vim.on_key().
static size_t on_key_ignore_len = 0;

static int typeahead_char = 0;  ///< typeahead char that's not flushed

/// When block_redo is true the redo buffer will not be changed.
/// Used by edit() to repeat insertions.
static bool block_redo = false;

static int KeyNoremap = 0;  ///< remapping flags

/// Variables used by vgetorpeek() and flush_buffers()
///
/// typebuf.tb_buf[] contains all characters that are not consumed yet.
/// typebuf.tb_buf[typebuf.tb_off] is the first valid character.
/// typebuf.tb_buf[typebuf.tb_off + typebuf.tb_len - 1] is the last valid char.
/// typebuf.tb_buf[typebuf.tb_off + typebuf.tb_len] must be NUL.
/// The head of the buffer may contain the result of mappings, abbreviations
/// and @a commands.  The length of this part is typebuf.tb_maplen.
/// typebuf.tb_silent is the part where <silent> applies.
/// After the head are characters that come from the terminal.
/// typebuf.tb_no_abbr_cnt is the number of characters in typebuf.tb_buf that
/// should not be considered for abbreviations.
/// Some parts of typebuf.tb_buf may not be mapped. These parts are remembered
/// in typebuf.tb_noremap[], which is the same length as typebuf.tb_buf and
/// contains RM_NONE for the characters that are not to be remapped.
/// typebuf.tb_noremap[typebuf.tb_off] is the first valid flag.
enum {
  RM_YES    = 0,  ///< tb_noremap: remap
  RM_NONE   = 1,  ///< tb_noremap: don't remap
  RM_SCRIPT = 2,  ///< tb_noremap: remap local script mappings
  RM_ABBR   = 4,  ///< tb_noremap: don't remap, do abbrev.
};

// typebuf.tb_buf has three parts: room in front (for result of mappings), the
// middle for typeahead and room for new characters (which needs to be 3 *
// MAXMAPLEN for the Amiga).
#define TYPELEN_INIT    (5 * (MAXMAPLEN + 3))
static uint8_t typebuf_init[TYPELEN_INIT];     ///< initial typebuf.tb_buf
static uint8_t noremapbuf_init[TYPELEN_INIT];  ///< initial typebuf.tb_noremap

static size_t last_recorded_len = 0;  ///< number of last recorded chars

enum {
  KEYLEN_PART_KEY = -1,  ///< keylen value for incomplete key-code
  KEYLEN_PART_MAP = -2,  ///< keylen value for incomplete mapping
};

#include "input.c.generated.h"

static const char e_recursive_mapping[] = N_("E223: Recursive mapping");
static const char e_cmd_mapping_must_end_with_cr[]
  = N_("E1255: <Cmd> mapping must end with <CR>");
static const char e_cmd_mapping_must_end_with_cr_before_second_cmd[]
  = N_("E1136: <Cmd> mapping must end with <CR> before second <Cmd>");

/// Frees the buffer's memory; it becomes empty.
static void free_buff(StuffBuf *buf)
  FUNC_ATTR_NONNULL_ALL
{
  kv_destroy(buf->keys);
  *buf = (StuffBuf){ 0 };
}

/// Gets the contents of the record buffer as a string (typeahead encoding) and clears the buffer.
char *get_recorded(void)
{
  size_t len = recordbuff.size;
  kv_push(recordbuff, NUL);
  char *p = recordbuff.items;  // ownership moves to the caller
  recordbuff = (StringBuilder)KV_INITIAL_VALUE;

  // Remove the characters that were added the last time, these must be the
  // (possibly mapped) characters that stopped the recording.
  if (len >= last_recorded_len) {
    len -= last_recorded_len;
    p[len] = NUL;
  }

  // When stopping recording from Insert mode with CTRL-O q, also remove the
  // CTRL-O.
  if (len > 0 && restart_edit != 0 && p[len - 1] == Ctrl_O) {
    p[len - 1] = NUL;
  }

  return p;
}

/// Composes a `["x][count]` prefix from `spec` and appends it to `buf`.
/// This is "Step 1" of redo-composition ("Step 2" is either `redobuff.cur.body` or `redo_chars`).
///
/// @param replay  Composing an actual replay (start_redo()): a `"=` register spec appends <CR>,
///                re-evaluating the last expression.
static void redo_prefix(const CmdSpec *spec, StringBuilder *buf, bool replay)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (spec->regname != 0) {
    sb_add_char(buf, '"');
    sb_add_char(buf, spec->regname);
    if (replay && spec->regname == '=') {
      sb_add_char(buf, CAR);
    }
  }
  if (spec->count != 0) {
    kv_printf(*buf, "%d", (int)spec->count);
  }
}

/// Composes a command keysequence from `spec` and appends it to `buf`.
/// This is "Step 2" of redo-composition ("Step 1" is `redo_prefix`).
///
/// @param arg_meta  Skip the `arg` byte (see prep_redo()).
static void redo_chars(const CmdSpec *spec, StringBuilder *buf, bool arg_meta)
  FUNC_ATTR_NONNULL_ALL
{
  if (spec->op != NUL) {
    sb_add_char(buf, spec->op);
  }
  if (spec->op_extra != NUL) {
    sb_add_char(buf, spec->op_extra);
  }
  if (spec->motion_force != NUL) {
    sb_add_char(buf, spec->motion_force);
  }
  if (spec->cmd != NUL) {
    sb_add_char(buf, spec->cmd);
  }
  if (spec->cmd2 != NUL) {
    sb_add_char(buf, spec->cmd2);
  }
  if (spec->arg != NUL && !arg_meta) {
    sb_add_char(buf, spec->arg);
  }
}

/// Takes `buf`'s bytes as an allocated, NUL-terminated String, and clears `buf`.
///
/// @return  String; .data=NULL if `buf` is empty.
static String sb_take_string(StringBuilder *buf)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (buf->size == 0) {
    kv_destroy(*buf);
    return (String)STRING_INIT;
  }
  size_t len = buf->size;
  assert(buf->items != NULL);  // Coverity false-positive (already checked `size` above).
  kv_push(*buf, NUL);
  char *items = buf->items;  // ownership moves to the caller
  *buf = (StringBuilder)KV_INITIAL_VALUE;
  return cbuf_as_string(items, len);
}

/// Gets `spec` (or current pending change, if `spec` is NULL), composed into a "redo" keyseq
/// `["x][count][body]`, where `[body]` is `spec.body`, or composed from the spec if body is empty.
///
/// @return Allocated key sequence; .data == NULL if the result is empty.
String redo_keys(const CmdSpec *spec)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  spec = spec ? spec : &redobuff.cur;

  StringBuilder buf = KV_INITIAL_VALUE;
  redo_prefix(spec, &buf, false);
  if (spec->body.size > 0) {
    kv_splice(buf, spec->body);
  } else {
    redo_chars(spec, &buf, false);
  }
  return sb_take_string(&buf);
}

/// Gets the pending change's CmdSpec (without `body`).
CmdSpec redo_spec(void)
{
  CmdSpec spec = redobuff.cur;
  spec.body = (StringBuilder)KV_INITIAL_VALUE;
  return spec;
}

/// Inserts string `s` at `buf.insert`: the end, or ahead of not-yet-read keys (see start_stuff()).
///
/// `s` must be in typeahead encoding, and must not point into `buf->keys`.
///
/// @param slen  String length, or -1 for a NUL-terminated string.
static void add_buff(StuffBuf *const buf, const char *const s, ptrdiff_t slen)
{
  if (slen < 0) {
    slen = (ptrdiff_t)strlen(s);
  }
  if (slen == 0) {                              // don't add empty strings
    return;
  }

  kv_ensure_space(buf->keys, (size_t)slen);
  char *at = buf->keys.items + buf->insert;
  memmove(at + slen, at, buf->keys.size - buf->insert);
  memcpy(at, s, (size_t)slen);
  buf->keys.size += (size_t)slen;
  buf->insert += (size_t)slen;
}

/// Append number "n" to buffer "buf".
static void add_num_buff(StuffBuf *buf, int n)
  FUNC_ATTR_NONNULL_ALL
{
  char number[32];
  int numberlen = snprintf(number, sizeof(number), "%d", n);
  add_buff(buf, number, numberlen);
}

/// Encodes byte or special key `c` into `temp`: the K_SPECIAL three-byte sequence for special
/// keys, NUL and K_SPECIAL itself; the byte otherwise.
///
/// @return  Encoded length.
static ptrdiff_t key_byte_encode(int c, char temp[4])
  FUNC_ATTR_NONNULL_ALL
{
  if (IS_SPECIAL(c) || c == K_SPECIAL || c == NUL) {
    // Translate special key code into three byte sequence.
    temp[0] = (char)K_SPECIAL;
    temp[1] = (char)K_SECOND(c);
    temp[2] = (char)K_THIRD(c);
    temp[3] = NUL;
    return 3;
  }
  temp[0] = (char)c;
  temp[1] = NUL;
  return 1;
}

/// Encodes char `c` into `buf` (at least `MB_MAXBYTES * 3 + 1` bytes): a special key as its
/// K_SPECIAL sequence, a multibyte char byte-wise with K_SPECIAL escaping.
///
/// @return  Encoded length.
static size_t key_char_encode(int c, char *buf)
  FUNC_ATTR_NONNULL_ALL
{
  uint8_t bytes[MB_MAXBYTES + 1];
  int len = IS_SPECIAL(c) ? 1 : utf_char2bytes(c, (char *)bytes);
  size_t off = 0;
  for (int i = 0; i < len; i++) {
    off += (size_t)key_byte_encode(IS_SPECIAL(c) ? c : bytes[i], buf + off);
  }
  return off;
}

/// Append character `c` to `buf`, translated to typeahead encoding.
static void add_char_buff(StuffBuf *buf, int c)
  FUNC_ATTR_NONNULL_ALL
{
  char temp[MB_MAXBYTES * 3 + 1];
  add_buff(buf, temp, (ptrdiff_t)key_char_encode(c, temp));
}

/// Appends byte or special key `c` to `sb`.
static void sb_add_byte(StringBuilder *sb, int c)
  FUNC_ATTR_NONNULL_ALL
{
  char temp[4];
  size_t templen = (size_t)key_byte_encode(c, temp);
  kv_concat_len(*sb, temp, templen);
}

/// Dual of add_char_buff(), for a StringBuilder.
void sb_add_char(StringBuilder *sb, int c)
  FUNC_ATTR_NONNULL_ALL
{
  char temp[MB_MAXBYTES * 3 + 1];
  size_t len = key_char_encode(c, temp);
  kv_concat_len(*sb, temp, len);
}

/// Gets one byte (typeahead encoding, no translation) from the read buffers.  Uses `readbuf1` one
/// first, or `readbuf2` if that one is empty.
///
/// @param advance Go to the next char.
static int read_readbuffers(bool advance)
{
  int c = read_readbuf(&readbuf1, advance);
  if (c == NUL) {
    c = read_readbuf(&readbuf2, advance);
  }
  return c;
}

static int read_readbuf(StuffBuf *buf, bool advance)
  FUNC_ATTR_NONNULL_ALL
{
  if (buf->read == buf->keys.size) {  // buffer is empty
    return NUL;
  }

  uint8_t c = (uint8_t)buf->keys.items[buf->read];

  if (advance) {
    buf->read++;
    if (buf->read == buf->keys.size) {  // drained: reset positions, keep capacity for reuse
      buf->keys.size = 0;
      buf->read = 0;
      buf->insert = 0;
    } else {
      buf->insert = MAX(buf->insert, buf->read);
    }
  }
  return c;
}

/// Makes the next stuffed text be read before the existing readahead.
static void start_stuff(void)
{
  readbuf1.insert = readbuf1.read;
  readbuf2.insert = readbuf2.read;
}

/// @return  true if the readahead ("stuff") buffer is empty.
bool stuff_empty(void)
  FUNC_ATTR_PURE
{
  return readbuf1.keys.size == 0 && readbuf2.keys.size == 0;
}

/// @return  true if readbuf1 is empty.  There may still be redo characters in
///          readbuf2.
bool readbuf1_empty(void)
  FUNC_ATTR_PURE
{
  return readbuf1.keys.size == 0;
}

/// Set a typeahead character that won't be flushed.
void typeahead_noflush(int c)
{
  typeahead_char = c;
}

/// Remove the contents of the stuff buffer and the mapped characters in the typeahead buffer (used
/// in case of an error).
///
/// @param flush_typeahead Flush all typeahead characters (used when interrupted by CTRL-C).
void flush_buffers(flush_buffers_T flush_typeahead)
{
  init_typebuf();

  if (typebuf.tb_maplen > 0) {
    // Discarding a mapping's unconsumed keys: the mapping will never
    // complete, discard its subatoms.
    atom_composite_abort();
  }

  free_buff(&readbuf1);
  free_buff(&readbuf2);

  if (flush_typeahead == FLUSH_MINIMAL) {
    // remove mapped characters at the start only,
    // but only when enough space left in typebuf
    if (typebuf.tb_off + typebuf.tb_maplen >= typebuf.tb_buflen) {
      typebuf.tb_off = MAXMAPLEN;
      typebuf.tb_len = 0;
    } else {
      typebuf.tb_off += typebuf.tb_maplen;
      typebuf.tb_len -= typebuf.tb_maplen;
    }
    if (typebuf.tb_len == 0) {
      typebuf_was_filled = false;
    }
  } else {
    // remove typeahead
    if (flush_typeahead == FLUSH_INPUT) {
      // We have to get all characters, because we may delete the first
      // part of an escape sequence.  In an xterm we get one char at a
      // time and we have to get them all.
      while (inchar(typebuf.tb_buf, typebuf.tb_buflen - 1, 10) != 0) {}
    }
    typebuf.tb_off = MAXMAPLEN;
    typebuf.tb_len = 0;
    // Reset the flag that text received from a client or from feedkeys()
    // was inserted in the typeahead buffer.
    typebuf_was_filled = false;
  }
  typebuf.tb_maplen = 0;
  typebuf.tb_silent = 0;
  cmd_silent = false;
  typebuf.tb_no_abbr_cnt = 0;
  if (++typebuf.tb_change_cnt == 0) {
    typebuf.tb_change_cnt = 1;
  }
}

/// flush map and typeahead buffers and give a warning for an error
void beep_flush(void)
{
  if (emsg_silent == 0) {
    flush_buffers(FLUSH_MINIMAL);
    vim_beep(kOptBoFlagError);
  }
}

/// Starts capturing a new change: stores `spec`, caller appends the body (redo_append_x). The
/// outgoing change moves to `redobuff.old`, which may be repeated by "CTRL-O ." in Insert mode,
/// or restored by redo_cancel() if this change aborts.
///
/// @param spec  Structured command fields; zeroed if the caller only appends keys.
void redo_new(CmdSpec spec)
{
  assert(spec.body.size == 0);
  if (block_redo) {
    return;
  }

  kv_destroy(redobuff.old.body);
  redobuff.old = redobuff.cur;
  redobuff.cur = spec;
}

#ifdef EXITFREE
/// Frees both redo buffers.
void redo_free_all(void)
{
  kv_destroy(redobuff.cur.body);
  kv_destroy(redobuff.old.body);
  redobuff = (RedoState){ 0 };
}
#endif

/// Prepare for redo of any command: stores `spec` and appends its command chars.
///
/// @param claim     Claim it as the atom. False if the atom is captured by other means
///                  (insert-session entry/restart, "z=").
/// @param arg_meta  Skip the `arg` byte: an interactively-typed operand may need CTRL-V quoting
///                  or its composing-char string form, which the caller appends itself.
void prep_redo(bool claim, bool arg_meta, CmdSpec spec)
{
  if (claim) {
    atom_redo_set(spec);
  }
  redo_new(spec);
  if (block_redo) {
    return;
  }
  redo_chars(&spec, &redobuff.cur.body, arg_meta);
}

/// Prepare for redo of a Visual-mode command: the body opens with `keys` (the captured selection),
/// so "." re-executes the selection at cursor; the `["x][count]` prefix and command chars of
/// `spec` compose into the body after them (zeroed in the stored spec, so replay doesn't also
/// prefix them). Always claims (see prep_redo()).
void prep_redo_visual(const char *keys, size_t len, CmdSpec spec)
{
  CmdSpec stored = spec;
  stored.regname = 0;
  stored.count = 0;
  atom_redo_set(stored);
  redo_new(stored);
  if (block_redo) {
    return;
  }
  kv_concat_len(redobuff.cur.body, keys, len);
  redo_prefix(&spec, &redobuff.cur.body, false);
  redo_chars(&spec, &redobuff.cur.body, false);
}

/// Discard the contents of the redo buffer and restore the previous redo
/// buffer.
void redo_cancel(void)
{
  if (block_redo) {
    return;
  }

  kv_destroy(redobuff.cur.body);
  redobuff.cur = redobuff.old;
  redobuff.old = (CmdSpec){ 0 };
  free_buff(&readbuf1);
  free_buff(&readbuf2);
}

/// Saves the redo state to "save_redo" and detaches it.
/// Used before executing autocommands and user functions.
void save_redobuff(RedoState *save_redo)
  FUNC_ATTR_NONNULL_ALL
{
  *save_redo = redobuff;
  redobuff.cur.body = (StringBuilder)KV_INITIAL_VALUE;
  redobuff.old = (CmdSpec){ 0 };

  // Make a copy (the fields stayed, copy the body), so that ":normal ." in a
  // function works.
  kv_splice(redobuff.cur.body, save_redo->cur.body);
}

/// Restores the redo state from "save_redo".
/// Used after executing autocommands and user functions.
void restore_redobuff(RedoState *save_redo)
  FUNC_ATTR_NONNULL_ALL
{
  kv_destroy(redobuff.cur.body);
  kv_destroy(redobuff.old.body);
  redobuff = *save_redo;
}

/// Append `len` bytes of `s` (-1: up to the NUL) to the redo buffer.
/// `s` must be in typeahead encoding.
void redo_append_str(const char *s, ptrdiff_t len)
{
  if (!block_redo) {
    size_t slen = len < 0 ? strlen(s) : (size_t)len;
    kv_concat_len(redobuff.cur.body, s, slen);
  }
}

/// Appends `str` to `buf` literally, escaping special characters with CTRL-V.
/// K_SPECIAL is escaped as well.
///
/// @param str  String to append.
/// @param len  Length of `str` or -1 for up to the NUL.
void sb_add_lit(StringBuilder *buf, const char *str, int len)
{
  const char *s = str;
  while (len < 0 ? *s != NUL : s - str < len) {
    // Put a string of normal characters in the buffer (that's faster).
    const char *start = s;
    while (*s >= ' ' && *s < DEL && (len < 0 || s - str < len)) {
      s++;
    }

    // Don't put '0' or '^' as last character, just in case a CTRL-D is
    // typed next.
    if (*s == NUL && (s[-1] == '0' || s[-1] == '^')) {
      s--;
    }
    if (s > start) {
      kv_concat_len(*buf, start, (size_t)(s - start));
    }

    if (*s == NUL || (len >= 0 && s - str >= len)) {
      break;
    }

    // Handle a special or multibyte character.
    // Composing chars separately are handled separately.
    const int c = mb_cptr2char_adv(&s);
    if (c < ' ' || c == DEL || (*s == NUL && (c == '0' || c == '^'))) {
      sb_add_char(buf, Ctrl_V);
    }

    // CTRL-V '0' must be inserted as CTRL-V 048.
    if (*s == NUL && c == '0') {
      kv_concat_len(*buf, "048", 3);
    } else {
      sb_add_char(buf, c);
    }
  }
}

/// Append to redo literally; no-op if `block_redo` is set; Insert dot-repeat consumes
/// the redo buffer and must not append to it while doing so.
void redo_append_lit(const char *str, int len)
{
  if (block_redo) {
    return;
  }
  sb_add_lit(&redobuff.cur.body, str, len);
}

/// Append "s" to the redo buffer, leaving 3-byte special key codes unmodified
/// and escaping other K_SPECIAL bytes.
void redo_append_spec(const char *s)
{
  if (block_redo) {
    return;
  }

  while (*s != NUL) {
    if ((uint8_t)(*s) == K_SPECIAL && s[1] != NUL && s[2] != NUL) {
      // Insert special key literally.
      kv_concat_len(redobuff.cur.body, s, 3);
      s += 3;
    } else {
      sb_add_char(&redobuff.cur.body, mb_cptr2char_adv(&s));
    }
  }
}

/// Appends character `c` to the redo buffer, translated to typeahead encoding.
void redo_append_char(int c)
{
  if (!block_redo) {
    sb_add_char(&redobuff.cur.body, c);
  }
}

// Append a number to the redo buffer.
void redo_append_num(int n)
{
  if (!block_redo) {
    kv_printf(redobuff.cur.body, "%d", n);
  }
}

/// Appends string `s` (must be typeahead encoding) to the stuff buffer.
void stuffReadbuff(const char *s)
  FUNC_ATTR_NONNULL_ALL
{
  add_buff(&readbuf1, s, -1);
}

/// Appends string `s` (must be typeahead encoding) to the redo stuff buffer.
void stuffRedoReadbuff(const char *s)
  FUNC_ATTR_NONNULL_ALL
{
  add_buff(&readbuf2, s, -1);
}

void stuffReadbuffLen(const char *s, ptrdiff_t len)
{
  if (add_last_insert == 1) {  // Only add if this is the first call, for
                               // recursive calls, ignore.
    ga_concat_len(&last_insert_ga, s, (size_t)len);
  }
  add_buff(&readbuf1, s, len);
}

/// Stuff "s" into the stuff buffer, leaving special key codes unmodified and
/// escaping other K_SPECIAL bytes.
/// Change CR, LF and ESC into a space.
void stuffReadbuffSpec(const char *s)
  FUNC_ATTR_NONNULL_ALL
{
  while (*s != NUL) {
    if ((uint8_t)(*s) == K_SPECIAL && s[1] != NUL && s[2] != NUL) {
      // Insert special key literally.
      stuffReadbuffLen(s, 3);
      s += 3;
    } else {
      int c = mb_cptr2char_adv(&s);
      if (c == CAR || c == NL || c == ESC) {
        c = ' ';
      }
      stuffcharReadbuff(c);
    }
  }
}

/// Appends character `c` to the stuff buffer, translated to typeahead encoding.
void stuffcharReadbuff(int c)
{
  add_char_buff(&readbuf1, c);
}

// Append a number to the stuff buffer.
void stuffnumReadbuff(int n)
{
  add_num_buff(&readbuf1, n);
}

/// Stuff a string into the typeahead buffer, such that edit() will insert it
/// literally ("literally" true) or interpret is as typed characters.
void stuffescaped(const char *arg, bool literally)
  FUNC_ATTR_NONNULL_ALL
{
  while (*arg != NUL) {
    // Stuff a sequence of normal ASCII characters, that's fast.  Also
    // stuff K_SPECIAL to get the effect of a special key when "literally"
    // is true.
    const char *const start = arg;
    while ((*arg >= ' ' && *arg < DEL) || ((uint8_t)(*arg) == K_SPECIAL
                                           && !literally)) {
      arg++;
    }
    if (arg > start) {
      stuffReadbuffLen(start, arg - start);
    }

    // stuff a single special character
    if (*arg != NUL) {
      const int c = mb_cptr2char_adv(&arg);
      if (literally && ((c < ' ' && c != TAB) || c == DEL)) {
        stuffcharReadbuff(Ctrl_V);
      }
      stuffcharReadbuff(c);
    }
  }
}

/// Dot-repeat "." command: repeats the last change by composing the redo into readbuf2. "3."
/// replaces count; a numbered-register redo increments regname ('"1p' then "." pastes '"2'), so "."
/// steps through the delete history. A Visual-mode change re-executes its captured selection keys
/// (embedded in the body, see prep_redo()).
///
/// @param old_redo  repeat the last-but-one change (i_CTRL-O ".": the insert
///                  session's own prep moved the last change to redobuff.old)
/// @return  FAIL for failure, OK otherwise
int start_redo(int count, bool old_redo)
{
  CmdSpec *rd = old_redo ? &redobuff.old : &redobuff.cur;
  if (rd->body.size == 0 && rd->regname == 0 && rd->count == 0) {
    return FAIL;  // nothing to redo
  }

  // Tweak the captured spec for replay:
  CmdSpec spec = *rd;
  spec.body = (StringBuilder)KV_INITIAL_VALUE;
  if (spec.regname >= '1' && spec.regname < '9') {
    spec.regname++;  // numbered register: "." steps through the delete history
  }
  if (count != 0) {
    spec.count = count;  // the new count replaces the captured one
  }
  StringBuilder prefix = KV_INITIAL_VALUE;
  redo_prefix(&spec, &prefix, true);
  // coverity[var_deref_model] `items` is NULL only when size=0, which add_buff() ignores.
  add_buff(&readbuf2, prefix.items, (ptrdiff_t)prefix.size);
  kv_destroy(prefix);
  if (spec.regname == '=') {
    cmd_silent = true;
  }

  add_buff(&readbuf2, rd->body.items, (ptrdiff_t)rd->body.size);
  return OK;
}

/// Repeats the last insert (R, o, O, a, A, i or I command) by stuffing the redo body's inserted
/// text into readbuf2 (counted inserts: "3iZ<Esc>").
///
/// @return  FAIL for failure, OK otherwise
int start_redo_ins(void)
{
  if (redobuff.cur.body.size == 0) {
    return FAIL;
  }
  start_stuff();

  // Skip to the insert command; the rest of the keys is the inserted text.
  const char *p = redobuff.cur.body.items;
  const char *const end = p + redobuff.cur.body.size;
  while (p < end) {
    if ((uint8_t)(*p) == K_SPECIAL && end - p >= 3) {
      p += 3;  // a special key is never the insert command
      continue;
    }
    if (vim_strchr("AaIiRrOo", (uint8_t)(*p)) != NULL) {
      if (*p == 'O' || *p == 'o') {
        add_buff(&readbuf2, NL_STR, -1);
      }
      p++;
      break;
    }
    p++;
  }

  // copy the typed text from the redo buffer into the stuff buffer
  add_buff(&readbuf2, p, end - p);
  block_redo = true;
  return OK;
}

void stop_redo_ins(void)
{
  block_redo = false;
}

/// Initialize typebuf.tb_buf to point to typebuf_init.
/// alloc() cannot be used here: In out-of-memory situations it would
/// be impossible to type anything.
static void init_typebuf(void)
{
  if (typebuf.tb_buf != NULL) {
    return;
  }

  typebuf.tb_buf = typebuf_init;
  typebuf.tb_noremap = noremapbuf_init;
  typebuf.tb_buflen = TYPELEN_INIT;
  typebuf.tb_len = 0;
  typebuf.tb_off = MAXMAPLEN + 4;
  typebuf.tb_change_cnt = 1;
}

/// @return true when keys cannot be remapped.
bool noremap_keys(void)
  FUNC_ATTR_PURE
{
  return KeyNoremap & (RM_NONE|RM_SCRIPT);
}

/// Insert a string in position "offset" in the typeahead buffer.
///
/// If "noremap" is REMAP_YES, new string can be mapped again.
/// If "noremap" is REMAP_NONE, new string cannot be mapped again.
/// If "noremap" is REMAP_SKIP, first char of new string cannot be mapped again,
/// but abbreviations are allowed.
/// If "noremap" is REMAP_SCRIPT, new string cannot be mapped again, except for
///                               script-local mappings.
/// If "noremap" is > 0, that many characters of the new string cannot be mapped.
///
/// If "nottyped" is true, the string does not return KeyTyped (don't use when
/// "offset" is non-zero!).
///
/// If "silent" is true, cmd_silent is set when the characters are obtained.
///
/// @return  FAIL for failure, OK otherwise
int ins_typebuf(char *str, int noremap, int offset, bool nottyped, bool silent)
  FUNC_ATTR_NONNULL_ALL
{
  int val;
  int nrm;

  init_typebuf();
  if (++typebuf.tb_change_cnt == 0) {
    typebuf.tb_change_cnt = 1;
  }
  state_no_longer_safe("ins_typebuf()");

  int addlen = (int)strlen(str);

  if (offset == 0 && addlen <= typebuf.tb_off) {
    // Easy case: there is room in front of typebuf.tb_buf[typebuf.tb_off]
    typebuf.tb_off -= addlen;
    memmove(typebuf.tb_buf + typebuf.tb_off, str, (size_t)addlen);
  } else if (typebuf.tb_len == 0
             && typebuf.tb_buflen >= addlen + 3 * (MAXMAPLEN + 4)) {
    // Buffer is empty and string fits in the existing buffer.
    // Leave some space before and after, if possible.
    typebuf.tb_off = (typebuf.tb_buflen - addlen - 3 * (MAXMAPLEN + 4)) / 2;
    memmove(typebuf.tb_buf + typebuf.tb_off, str, (size_t)addlen);
  } else {
    // Need to allocate a new buffer.
    // In typebuf.tb_buf there must always be room for 3 * (MAXMAPLEN + 4)
    // characters.  We add some extra room to avoid having to allocate too
    // often.
    int newoff = MAXMAPLEN + 4;
    int extra = addlen + newoff + 4 * (MAXMAPLEN + 4);
    if (typebuf.tb_len > INT_MAX - extra) {
      // string is getting too long for 32 bit int
      emsg(_(e_command_too_complex));  // also calls flush_buffers
      setcursor();
      return FAIL;
    }
    int newlen = typebuf.tb_len + extra;
    uint8_t *s1 = xmalloc((size_t)newlen);
    uint8_t *s2 = xmalloc((size_t)newlen);
    typebuf.tb_buflen = newlen;

    // copy the old chars, before the insertion point
    memmove(s1 + newoff, typebuf.tb_buf + typebuf.tb_off, (size_t)offset);
    // copy the new chars
    memmove(s1 + newoff + offset, str, (size_t)addlen);
    // copy the old chars, after the insertion point, including the NUL at
    // the end
    int bytes = typebuf.tb_len - offset + 1;
    assert(bytes > 0);
    memmove(s1 + newoff + offset + addlen,
            typebuf.tb_buf + typebuf.tb_off + offset, (size_t)bytes);
    if (typebuf.tb_buf != typebuf_init) {
      xfree(typebuf.tb_buf);
    }
    typebuf.tb_buf = s1;

    memmove(s2 + newoff, typebuf.tb_noremap + typebuf.tb_off,
            (size_t)offset);
    memmove(s2 + newoff + offset + addlen,
            typebuf.tb_noremap + typebuf.tb_off + offset,
            (size_t)(typebuf.tb_len - offset));
    if (typebuf.tb_noremap != noremapbuf_init) {
      xfree(typebuf.tb_noremap);
    }
    typebuf.tb_noremap = s2;

    typebuf.tb_off = newoff;
  }
  typebuf.tb_len += addlen;

  // If noremap == REMAP_SCRIPT: do remap script-local mappings.
  if (noremap == REMAP_SCRIPT) {
    val = RM_SCRIPT;
  } else if (noremap == REMAP_SKIP) {
    val = RM_ABBR;
  } else {
    val = RM_NONE;
  }

  // Adjust typebuf.tb_noremap[] for the new characters:
  // If noremap == REMAP_NONE or REMAP_SCRIPT: new characters are
  //                    (sometimes) not remappable
  // If noremap == REMAP_YES: all the new characters are mappable
  // If noremap  > 0: "noremap" characters are not remappable, the rest
  //                    mappable
  if (noremap == REMAP_SKIP) {
    nrm = 1;
  } else if (noremap < 0) {
    nrm = addlen;
  } else {
    nrm = noremap;
  }
  for (int i = 0; i < addlen; i++) {
    typebuf.tb_noremap[typebuf.tb_off + i + offset] =
      (uint8_t)((--nrm >= 0) ? val : RM_YES);
  }

  // tb_maplen and tb_silent only remember the length of mapped and/or
  // silent mappings at the start of the buffer, assuming that a mapped
  // sequence doesn't result in typed characters.
  if (nottyped || typebuf.tb_maplen > offset) {
    typebuf.tb_maplen += addlen;
  }
  if (silent || typebuf.tb_silent > offset) {
    typebuf.tb_silent += addlen;
    cmd_silent = true;
  }
  if (typebuf.tb_no_abbr_cnt && offset == 0) {  // and not used for abbrev.s
    typebuf.tb_no_abbr_cnt += addlen;
  }

  return OK;
}

/// Re-queues key `c`: puts a key obtained by vgetc() back into typeahead, to be reprocessed: mapped
/// (cf. vungetc(), which bypasses mapping), recorded and reported. Calls ungetchars() to drop the
/// effects of consuming it the first time.
///
/// Uses cmd_silent, KeyTyped and KeyNoremap to restore the flags belonging to the char.
///
/// @param recorded  Pass false if the caller suppressed recording on the initial read.
/// @param extra_consumed  Extra consumed bytes to un-record beyond the key itself (vgetc()'s
///                        ALT-rewrite consumed a `K_SPECIAL KS_MODIFIER` prefix too).
void requeue_key(int c, int modifiers, int extra_consumed, bool recorded)
{
  char buf[MB_MAXBYTES * 3 + 4];
  unsigned len = special_to_buf(c, modifiers, true, buf);
  assert(len < sizeof(buf));
  buf[len] = NUL;
  ins_typebuf(buf, KeyNoremap, 0, !KeyTyped, cmd_silent);
  ungetchars((int)len + extra_consumed, recorded);
}

/// Return true if the typeahead buffer was changed (while waiting for a
/// character to arrive).  Happens when a message was received from a client or
/// from feedkeys().
/// But check in a more generic way to avoid trouble: When "typebuf.tb_buf"
/// changed it was reallocated and the old pointer can no longer be used.
/// Or "typebuf.tb_off" may have been changed and we would overwrite characters
/// that was just added.
///
/// @param tb_change_cnt  old value of typebuf.tb_change_cnt
bool typebuf_changed(int tb_change_cnt)
  FUNC_ATTR_PURE
{
  return tb_change_cnt != 0 && (typebuf.tb_change_cnt != tb_change_cnt
                                || typebuf_was_filled);
}

/// Return true if there are no characters in the typeahead buffer that have
/// not been typed (result from a mapping or come from ":normal").
int typebuf_typed(void)
  FUNC_ATTR_PURE
{
  return typebuf.tb_maplen == 0;
}

/// Get the number of characters that are mapped (or not typed).
int typebuf_maplen(void)
  FUNC_ATTR_PURE
{
  return typebuf.tb_maplen;
}

/// Remove "len" characters from typebuf.tb_buf[typebuf.tb_off + offset]
void del_typebuf(int len, int offset)
{
  if (len == 0) {
    return;             // nothing to do
  }

  typebuf.tb_len -= len;

  // Easy case: Just increase typebuf.tb_off.
  if (offset == 0 && typebuf.tb_buflen - (typebuf.tb_off + len)
      >= 3 * MAXMAPLEN + 3) {
    typebuf.tb_off += len;
  } else {
    // Have to move the characters in typebuf.tb_buf[] and typebuf.tb_noremap[]
    int i = typebuf.tb_off + offset;
    // Leave some extra room at the end to avoid reallocation.
    if (typebuf.tb_off > MAXMAPLEN) {
      memmove(typebuf.tb_buf + MAXMAPLEN,
              typebuf.tb_buf + typebuf.tb_off, (size_t)offset);
      memmove(typebuf.tb_noremap + MAXMAPLEN,
              typebuf.tb_noremap + typebuf.tb_off, (size_t)offset);
      typebuf.tb_off = MAXMAPLEN;
    }
    // adjust typebuf.tb_buf (include the NUL at the end)
    int bytes = typebuf.tb_len - offset + 1;
    assert(bytes > 0);
    memmove(typebuf.tb_buf + typebuf.tb_off + offset,
            typebuf.tb_buf + i + len, (size_t)bytes);
    // adjust typebuf.tb_noremap[]
    memmove(typebuf.tb_noremap + typebuf.tb_off + offset,
            typebuf.tb_noremap + i + len,
            (size_t)(typebuf.tb_len - offset));
  }

  if (typebuf.tb_maplen > offset) {             // adjust tb_maplen
    if (typebuf.tb_maplen < offset + len) {
      typebuf.tb_maplen = offset;
    } else {
      typebuf.tb_maplen -= len;
    }
  }
  if (typebuf.tb_silent > offset) {             // adjust tb_silent
    if (typebuf.tb_silent < offset + len) {
      typebuf.tb_silent = offset;
    } else {
      typebuf.tb_silent -= len;
    }
  }
  if (typebuf.tb_no_abbr_cnt > offset) {        // adjust tb_no_abbr_cnt
    if (typebuf.tb_no_abbr_cnt < offset + len) {
      typebuf.tb_no_abbr_cnt = offset;
    } else {
      typebuf.tb_no_abbr_cnt -= len;
    }
  }

  // Reset the flag that text received from a client or from feedkeys()
  // was inserted in the typeahead buffer.
  typebuf_was_filled = false;
  if (++typebuf.tb_change_cnt == 0) {
    typebuf.tb_change_cnt = 1;
  }
}

/// Append a single byte to a recording or 'showcmd'.
/// Return true if a full key has been received, false otherwise.
static bool gotchars_add_byte(gotchars_state_T *state, uint8_t byte)
  FUNC_ATTR_NONNULL_ALL
{
  int c = state->buf[state->buflen++] = byte;
  bool retval = false;
  const bool in_special = state->pending_special > 0;
  const bool in_mbyte = state->pending_mbyte > 0;

  if (in_special) {
    state->pending_special--;
  } else if (c == K_SPECIAL) {
    // When receiving a special key sequence, store it until we have all
    // the bytes and we can decide what to do with it.
    state->pending_special = 2;
  }

  if (state->pending_special > 0) {
    goto ret_false;
  }

  if (in_mbyte) {
    state->pending_mbyte--;
  } else {
    if (in_special) {
      if (state->prev_c == KS_MODIFIER) {
        // When receiving a modifier, wait for the modified key.
        goto ret_false;
      }
      c = TO_SPECIAL(state->prev_c, c);
      // Drop K_COMPLETE_DELAY, it's not useful in a recording.
      if (c == K_COMPLETE_DELAY) {
        state->buflen = 0;
      }
    }
    // When receiving a multibyte character, store it until we have all the bytes, so that
    // whole keys reach the recording and ungetchars() removes whole keys.
    state->pending_mbyte = MB_BYTE2LEN_CHECK(c) - 1;
  }

  if (state->pending_mbyte > 0) {
    goto ret_false;
  }

  retval = true;
ret_false:
  state->prev_c = c;
  return retval;
}

/// Write typed characters to script file.
/// If recording is on put the character in the record buffer.
static void gotchars(const uint8_t *chars, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  const uint8_t *s = chars;
  size_t todo = len;
  static gotchars_state_T state;

  while (todo-- > 0) {
    if (!gotchars_add_byte(&state, *s++)) {
      continue;
    }

    // Handle one byte at a time; no translation to be done.
    for (size_t i = 0; i < state.buflen; i++) {
      updatescript(state.buf[i]);
    }

    if (state.buflen > on_key_ignore_len) {
      kvi_concat_len(on_key_buf, (char *)state.buf + on_key_ignore_len,
                     state.buflen - on_key_ignore_len);
      on_key_ignore_len = 0;
    } else {
      on_key_ignore_len -= state.buflen;
    }

    if (reg_recording != 0) {
      kv_concat_len(recordbuff, (char *)state.buf, state.buflen);
      // remember how many chars were last recorded
      last_recorded_len += state.buflen;
    }

    // Typed keys consumed during 'operatorfunc' are the op's interactive payload.
    atom_typed_add(state.buf, state.buflen);

    state.buflen = 0;
  }

  may_sync_undo();

  // output "debug mode" message next time in debug mode
  debug_did_msg = false;

  // Since characters have been typed, consider the following to be in
  // another mapping.  Search string will be kept in history.
  maptick++;
}

/// Record an <Ignore> key.
void gotchars_ignore(void)
{
  uint8_t nop_buf[3] = { K_SPECIAL, KS_EXTRA, KE_IGNORE };
  on_key_ignore_len += 3;
  gotchars(nop_buf, 3);
}

/// Undo the last gotchars() for `len` bytes: a key that was read is being re-queued into typeahead,
/// so it will be read (+ gotchars()) again. Un-reports the bytes, and (if `recorded`) removes them
/// from the recording.
///
/// @param recorded  Pass false if recording was suppressed on the first read: the trailing
///        `recordbuff` bytes are unrelated and deleting them would corrupt it.
static void ungetchars(int len, bool recorded)
{
  if (!KeyTyped) {
    return;  // gotchars() only sees typed keys; nothing to undo.
  }
  if (recorded && reg_recording != 0 && recordbuff.size >= (size_t)len) {
    recordbuff.size -= (size_t)len;
    last_recorded_len -= (size_t)len;
  }
  atom_typed_del((size_t)len);
  size_t trim = MIN((size_t)len, on_key_buf.size);
  on_key_buf.size -= trim;
  on_key_ignore_len += (size_t)len - trim;
}

/// Sync undo.  Called when typed characters are obtained from the typeahead
/// buffer, or when a menu is used.
/// Do not sync:
/// - In Insert mode, unless cursor key has been used.
/// - While reading a script file.
/// - When no_u_sync is non-zero.
void may_sync_undo(void)
{
  if ((!(State & (MODE_INSERT | MODE_CMDLINE)) || Ins.moved != kInsNone)
      && curscript < 0) {
    u_sync(false);
  }
}

/// Make "typebuf" empty and allocate new buffers.
static void alloc_typebuf(void)
{
  typebuf.tb_buf = xmalloc(TYPELEN_INIT);
  typebuf.tb_noremap = xmalloc(TYPELEN_INIT);
  typebuf.tb_buflen = TYPELEN_INIT;
  typebuf.tb_off = MAXMAPLEN + 4;     // can insert without realloc
  typebuf.tb_len = 0;
  typebuf.tb_maplen = 0;
  typebuf.tb_silent = 0;
  typebuf.tb_no_abbr_cnt = 0;
  if (++typebuf.tb_change_cnt == 0) {
    typebuf.tb_change_cnt = 1;
  }
  typebuf_was_filled = false;
}

/// Free the buffers of "typebuf".
static void free_typebuf(void)
{
  if (typebuf.tb_buf == typebuf_init) {
    internal_error("Free typebuf 1");
  } else {
    XFREE_CLEAR(typebuf.tb_buf);
  }
  if (typebuf.tb_noremap == noremapbuf_init) {
    internal_error("Free typebuf 2");
  } else {
    XFREE_CLEAR(typebuf.tb_noremap);
  }
}

/// When doing ":so! file", the current typeahead needs to be saved, and
/// restored when "file" has been read completely.
static typebuf_T saved_typebuf[NSCRIPT];

static void save_typebuf(void)
{
  assert(curscript >= 0);
  init_typebuf();
  saved_typebuf[curscript] = typebuf;
  alloc_typebuf();
}

static bool can_get_ungot(void)
  FUNC_ATTR_PURE
{
  // If the ungotten character was not stuffed and characters have been added to
  // the stuff buffer, need to first get the stuffed characters instead.
  return ungot.c != -1 && (ungot.stuffed || stuff_empty());
}

/// Save all three kinds of typeahead, so that the user must type at a prompt.
void save_typeahead(tasave_T *tp)
  FUNC_ATTR_NONNULL_ALL
{
  tp->save_typebuf = typebuf;
  alloc_typebuf();
  tp->ungot = ungot;
  ungot.c = -1;

  tp->save_readbuf1 = readbuf1;
  readbuf1 = (StuffBuf){ 0 };
  tp->save_readbuf2 = readbuf2;
  readbuf2 = (StuffBuf){ 0 };
}

/// Restore the typeahead to what it was before calling save_typeahead().
/// The allocated memory is freed, can only be called once!
void restore_typeahead(tasave_T *tp)
  FUNC_ATTR_NONNULL_ALL
{
  free_typebuf();
  typebuf = tp->save_typebuf;
  ungot = tp->ungot;

  free_buff(&readbuf1);
  readbuf1 = tp->save_readbuf1;
  free_buff(&readbuf2);
  readbuf2 = tp->save_readbuf2;
}

/// Open a new script file for the ":source!" command.
///
/// @param directly  when true execute directly
void openscript(char *name, bool directly)
{
  if (curscript + 1 == NSCRIPT) {
    emsg(_(e_nesting));
    return;
  }

  // Disallow sourcing a file in the sandbox, the commands would be executed
  // later, possibly outside of the sandbox.
  if (check_secure()) {
    return;
  }

  if (ignore_script) {
    // Not reading from script, also don't open one.  Warning message?
    return;
  }

  curscript++;
  // use NameBuff for expanded name
  expand_env(name, NameBuff, MAXPATHL);
  int error = file_open(&scriptin[curscript], NameBuff, kFileReadOnly, 0);
  if (error) {
    semsg(_(e_notopen_2), name, os_strerror(error));
    curscript--;
    return;
  }
  save_typebuf();

  // Execute the commands from the file right now when using ":source!"
  // after ":global" or ":argdo" or in a loop.  Also when another command
  // follows.  This means the display won't be updated.  Don't do this
  // always, "make test" would fail.
  if (directly) {
    oparg_T oa;
    int save_State = State;
    int save_restart_edit = restart_edit;
    int save_finish_op = finish_op;
    int save_msg_scroll = msg_scroll;

    State = MODE_NORMAL;
    msg_scroll = false;         // no msg scrolling in Normal mode
    restart_edit = 0;           // don't go to Insert mode
    clear_oparg(&oa);
    finish_op = false;

    int oldcurscript = curscript;
    do {
      update_topline_cursor();          // update cursor position and topline
      normal_cmd(&oa, false);           // execute one command
      vpeekc();                   // check for end of file
    } while (curscript >= oldcurscript);

    State = save_State;
    msg_scroll = save_msg_scroll;
    restart_edit = save_restart_edit;
    finish_op = save_finish_op;
  }
}

/// Close the currently active input script.
static void closescript(void)
{
  assert(curscript >= 0);
  free_typebuf();
  typebuf = saved_typebuf[curscript];

  file_close(&scriptin[curscript], false);
  curscript--;
}

#ifdef EXITFREE
void close_all_scripts(void)
{
  while (curscript >= 0) {
    closescript();
  }
}

#endif

bool open_scriptin(char *scriptin_name)
  FUNC_ATTR_NONNULL_ALL
{
  assert(curscript == -1);
  curscript++;

  int error;
  if (strequal(scriptin_name, "-")) {
    error = file_open_stdin(&scriptin[0]);
  } else {
    error = file_open(&scriptin[0], scriptin_name,
                      kFileReadOnly|kFileNonBlocking, 0);
  }
  if (error) {
    fprintf(stderr, _("Cannot open for reading: \"%s\": %s\n"),
            scriptin_name, os_strerror(error));
    curscript--;
    return false;
  }
  save_typebuf();

  return true;
}

/// Return true when reading keys from a script file.
int using_script(void)
  FUNC_ATTR_PURE
{
  return curscript >= 0;
}

/// This function is called just before doing a blocking wait.  Thus after
/// waiting 'updatetime' for a character to arrive.
void before_blocking(void)
{
  updatescript(0);
  if (may_garbage_collect) {
    garbage_collect(false);
  }
}

/// updatescript() is called when a character can be written to the script
/// file or when we have waited some time for a character (c == 0).
///
/// All the changed memfiles are synced if c == 0 or when the number of typed
/// characters reaches 'updatecount' and 'updatecount' is non-zero.
static void updatescript(int c)
{
  static int count = 0;

  if (c && scriptout) {
    putc(c, scriptout);
  }
  bool idle = (c == 0);
  if (idle || (p_uc > 0 && ++count >= p_uc)) {
    ml_sync_all(idle, true,
                (!!p_fs || idle));  // Always fsync at idle (CursorHold).
    count = 0;
  }
}

/// Merge "modifiers" into "c_arg".
int merge_modifiers(int c_arg, int *modifiers)
  FUNC_ATTR_NONNULL_ALL
{
  int c = c_arg;

  if (*modifiers & MOD_MASK_CTRL) {
    if (c >= '@' && c <= 0x7f) {
      c &= 0x1f;
      if (c == NUL) {
        c = K_ZERO;
      }
    } else if (c == '6') {
      // CTRL-6 is equivalent to CTRL-^
      c = 0x1e;
    }
    if (c != c_arg) {
      *modifiers &= ~MOD_MASK_CTRL;
    }
  }
  return c;
}

/// Append a single byte to 'showcmd' for a partially matched mapping.
/// Call add_to_showcmd() if a full key has been received.
static void add_byte_to_showcmd(uint8_t byte)
{
  static gotchars_state_T state;

  if (!p_sc || msg_silent != 0) {
    return;
  }

  if (!gotchars_add_byte(&state, byte)) {
    return;
  }

  state.buf[state.buflen] = NUL;
  state.buflen = 0;

  int modifiers = 0;
  int c = NUL;

  const uint8_t *ptr = state.buf;
  if (ptr[0] == K_SPECIAL && ptr[1] == KS_MODIFIER && ptr[2] != NUL) {
    modifiers = ptr[2];
    ptr += 3;
  }

  if (*ptr != NUL) {
    const char *mb_ptr = mb_unescape((const char **)&ptr);
    c = mb_ptr != NULL ? utf_ptr2char(mb_ptr) : *ptr++;
    if (c <= 0x7f) {
      // Merge modifiers into the key to make the result more readable.
      int modifiers_after = modifiers;
      int mod_c = merge_modifiers(c, &modifiers_after);
      if (modifiers_after == 0) {
        modifiers = 0;
        c = mod_c;
      }
    }
  }

  // TODO(zeertzjq): is there a more readable and yet compact representation of
  // modifiers and special keys?
  if (modifiers != 0) {
    add_to_showcmd(K_SPECIAL);
    add_to_showcmd(KS_MODIFIER);
    add_to_showcmd(modifiers);
  }
  if (c != NUL) {
    add_to_showcmd(c);
  }
  while (*ptr != NUL) {
    add_to_showcmd(*ptr++);
  }
}

/// Get the next input character.
/// Can return a special key or a multi-byte character.
/// Can return NUL when called recursively, use safe_vgetc() if that's not
/// wanted.
/// This translates escaped K_SPECIAL bytes to a K_SPECIAL byte.
/// Collects the bytes of a multibyte character into the whole character.
/// Returns the modifiers in the global "mod_mask".
int vgetc(void)
{
  int c;
  uint8_t buf[MB_MAXBYTES + 1];

  // Do garbage collection when garbagecollect() was called previously and
  // we are now at the toplevel.
  if (may_garbage_collect && want_garbage_collect) {
    garbage_collect(false);
  }

  // If a character was put back with vungetc, it was already processed.
  // Return it directly.
  if (can_get_ungot()) {
    c = ungot.c;
    ungot.c = -1;
    mod_mask = ungot.mod_mask;
    mouse_grid = ungot.mouse_grid;
    mouse_row = ungot.mouse_row;
    mouse_col = ungot.mouse_col;
  } else {
    // number of characters recorded from the last vgetc() call
    static size_t last_vgetc_recorded_len = 0;

    mod_mask = 0;
    vgetc_mod_mask = 0;
    vgetc_char = 0;

    // last_recorded_len can be larger than last_vgetc_recorded_len
    // if peeking records more
    last_recorded_len -= last_vgetc_recorded_len;

    while (true) {              // this is done twice if there are modifiers
      bool did_inc = false;
      if (mod_mask) {           // no mapping after modifier has been read
        no_mapping++;
        allow_keys++;
        did_inc = true;         // mod_mask may change value
      }
      c = vgetorpeek(true);
      if (did_inc) {
        no_mapping--;
        allow_keys--;
      }

      // Get two extra bytes for special keys
      if (c == K_SPECIAL) {
        int save_allow_keys = allow_keys;
        no_mapping++;
        allow_keys = 0;                 // make sure BS is not found
        int c2 = vgetorpeek(true);          // no mapping for these chars
        c = vgetorpeek(true);
        no_mapping--;
        allow_keys = save_allow_keys;
        if (c2 == KS_MODIFIER) {
          mod_mask = c;
          continue;
        }
        c = TO_SPECIAL(c2, c);
      }

      // For a multi-byte character get all the bytes and return the
      // converted character.
      // Note: This will loop until enough bytes are received!
      int n;
      if ((n = MB_BYTE2LEN_CHECK(c)) > 1) {
        no_mapping++;
        buf[0] = (uint8_t)c;
        for (int i = 1; i < n; i++) {
          buf[i] = (uint8_t)vgetorpeek(true);
          if (buf[i] == K_SPECIAL) {
            // Must be a K_SPECIAL - KS_SPECIAL - KE_FILLER sequence,
            // which represents a K_SPECIAL (0x80).
            vgetorpeek(true);  // skip KS_SPECIAL
            vgetorpeek(true);  // skip KE_FILLER
          }
        }
        no_mapping--;
        c = utf_ptr2char((char *)buf);
      }

      // If mappings are enabled (i.e., not i_CTRL-V) and the user directly typed
      // something with MOD_MASK_ALT (<M-/<A- modifier) that was not mapped, interpret
      // <M-x> as <Esc>x rather than as an unbound <M-x> keypress. #8213
      // In Terminal mode, however, this is not desirable. #16202 #16220
      // Also do not do this for mouse keys, as terminals encode mouse events as
      // CSI sequences, and MOD_MASK_ALT has a meaning even for unmapped mouse keys.
      if (!no_mapping && KeyTyped && mod_mask == MOD_MASK_ALT
          && !(State & MODE_TERMINAL) && !is_mouse_key(c)) {
        mod_mask = 0;
        // Un-record/un-report the consumed <M-x> (its K_SPECIAL KS_MODIFIER MOD_MASK_ALT prefix
        // took 3 more bytes); the rewritten <Esc>x is consumed (recorded, reported) in its place.
        requeue_key(c, 0, 3, true);
        ins_typebuf(ESC_STR, KeyNoremap, 0, !KeyTyped, cmd_silent);
        continue;
      }

      if (vgetc_char == 0) {
        vgetc_mod_mask = mod_mask;
        vgetc_char = c;
      }

      // A keypad or special function key was not mapped, use it like
      // its ASCII equivalent.
      switch (c) {
      case K_KPLUS:
        c = '+'; break;
      case K_KMINUS:
        c = '-'; break;
      case K_KDIVIDE:
        c = '/'; break;
      case K_KMULTIPLY:
        c = '*'; break;
      case K_KENTER:
        c = CAR; break;
      case K_KPOINT:
        c = '.'; break;
      case K_KCOMMA:
        c = ','; break;
      case K_KEQUAL:
        c = '='; break;
      case K_K0:
        c = '0'; break;
      case K_K1:
        c = '1'; break;
      case K_K2:
        c = '2'; break;
      case K_K3:
        c = '3'; break;
      case K_K4:
        c = '4'; break;
      case K_K5:
        c = '5'; break;
      case K_K6:
        c = '6'; break;
      case K_K7:
        c = '7'; break;
      case K_K8:
        c = '8'; break;
      case K_K9:
        c = '9'; break;

      case K_XHOME:
      case K_ZHOME:
        if (mod_mask == MOD_MASK_SHIFT) {
          c = K_S_HOME;
          mod_mask = 0;
        } else if (mod_mask == MOD_MASK_CTRL) {
          c = K_C_HOME;
          mod_mask = 0;
        } else {
          c = K_HOME;
        }
        break;
      case K_XEND:
      case K_ZEND:
        if (mod_mask == MOD_MASK_SHIFT) {
          c = K_S_END;
          mod_mask = 0;
        } else if (mod_mask == MOD_MASK_CTRL) {
          c = K_C_END;
          mod_mask = 0;
        } else {
          c = K_END;
        }
        break;

      case K_KUP:
      case K_XUP:
        c = K_UP; break;
      case K_KDOWN:
      case K_XDOWN:
        c = K_DOWN; break;
      case K_KLEFT:
      case K_XLEFT:
        c = K_LEFT; break;
      case K_KRIGHT:
      case K_XRIGHT:
        c = K_RIGHT; break;
      }

      break;
    }

    last_vgetc_recorded_len = last_recorded_len;
  }

  // In the main loop "may_garbage_collect" can be set to do garbage
  // collection in the first next vgetc().  It's disabled after that to
  // avoid internally used Lists and Dicts to be freed.
  may_garbage_collect = false;

  // Execute Lua on_key callbacks.
  kvi_push(on_key_buf, NUL);
  if (nlua_exec_on_key(c, on_key_buf.items)) {
    // Keys following K_COMMAND/K_LUA/K_PASTE_START aren't normally received by
    // vim.on_key() callbacks, so discard them along with the current key.
    if (c == K_COMMAND) {
      xfree(getcmdkeycmd(NUL, NULL, 0, false));
    } else if (c == K_LUA) {
      map_execute_lua(false, true);
    } else if (c == K_PASTE_START) {
      paste_repeat(0);
    }
    // Discard the current key.
    c = K_IGNORE;
  }
  kvi_destroy(on_key_buf);
  kvi_init(on_key_buf);

  // Need to process the character before we know it's safe to do something
  // else.
  if (c != K_IGNORE) {
    state_no_longer_safe("key typed");
  }

  return c;
}

/// Like vgetc(), but never return a NUL when called recursively, get a key
/// directly from the user (ignoring typeahead).
int safe_vgetc(void)
{
  int c = vgetc();
  if (c == NUL) {
    c = get_keystroke(NULL);
  }
  return c;
}

/// Like safe_vgetc(), but loop to handle K_IGNORE.
/// Also ignore scrollbar events.
int plain_vgetc(void)
{
  int c;

  do {
    c = safe_vgetc();
  } while (c == K_IGNORE
           || c == K_VER_SCROLLBAR || c == K_HOR_SCROLLBAR
           || c == K_MOUSEMOVE);
  return c;
}

/// Check if a character is available, such that vgetc() will not block.
/// If the next character is a special character or multi-byte, the returned
/// character is not valid!.
/// Returns NUL if no character is available.
int vpeekc(void)
{
  if (can_get_ungot()) {
    return ungot.c;
  }
  return vgetorpeek(false);
}

/// Check if any character is available, also half an escape sequence.
/// Trick: when no typeahead found, but there is something in the typeahead
/// buffer, it must be an ESC that is recognized as the start of a key code.
int vpeekc_any(void)
{
  int c = vpeekc();
  if (c == NUL && typebuf.tb_len > 0) {
    c = ESC;
  }
  return c;
}

/// Call vpeekc() without causing anything to be mapped.
/// @return  true if a character is available, false otherwise.
bool char_avail(void)
{
  if (test_disable_char_avail) {
    return false;
  }
  no_mapping++;
  int retval = vpeekc();
  no_mapping--;
  return retval != NUL;
}

static int no_reduce_keys = 0;  ///< Do not apply modifiers to the key.

/// "getchar()" and "getcharstr()" functions
static void getchar_common(typval_T *argvars, typval_T *rettv, bool allow_number)
  FUNC_ATTR_NONNULL_ALL
{
  varnumber_T n = 0;
  const int called_emsg_start = called_emsg;
  bool error = false;
  bool simplify = true;
  char cursor_flag = NUL;

  if (argvars[0].v_type != VAR_UNKNOWN
      && tv_check_for_opt_dict_arg(argvars, 1) == FAIL) {
    return;
  }

  if (argvars[0].v_type != VAR_UNKNOWN && argvars[1].v_type == VAR_DICT) {
    dict_T *d = argvars[1].vval.v_dict;

    if (allow_number) {
      allow_number = tv_dict_get_bool(d, "number", true);
    } else if (tv_dict_has_key(d, "number")) {
      semsg(_(e_invarg2), "number");
    }

    simplify = tv_dict_get_bool(d, "simplify", true);

    const char *cursor_str = tv_dict_get_string(d, "cursor", false);
    if (cursor_str != NULL) {
      if (strcmp(cursor_str, "hide") != 0
          && strcmp(cursor_str, "keep") != 0
          && strcmp(cursor_str, "msg") != 0) {
        semsg(_(e_invargNval), "cursor", cursor_str);
      } else {
        cursor_flag = cursor_str[0];
      }
    }
  }

  if (called_emsg != called_emsg_start) {
    return;
  }

  if (cursor_flag == 'h') {
    ui_busy_start();
  }

  no_mapping++;
  allow_keys++;
  if (!simplify) {
    no_reduce_keys++;
  }
  while (true) {
    if (cursor_flag == 'm' || (cursor_flag == NUL && msg_col > 0)) {
      ui_cursor_goto(msg_row, msg_col);
    }

    if (argvars[0].v_type == VAR_UNKNOWN
        || (argvars[0].v_type == VAR_NUMBER && argvars[0].vval.v_number == -1)) {
      // getchar(): blocking wait.
      // TODO(bfredl): deduplicate shared logic with state_enter ?
      if (!char_avail()) {
        // Flush screen updates before blocking.
        ui_flush();
        input_get(NULL, 0, -1, typebuf.tb_change_cnt, main_loop.events);
        if (!input_available() && !multiqueue_empty(main_loop.events)) {
          state_handle_k_event();
          continue;
        }
      }
      n = safe_vgetc();
    } else if (tv_get_number_chk(&argvars[0], &error) == 1) {
      // getchar(1): only check if char avail
      n = vpeekc_any();
    } else if (error || vpeekc_any() == NUL) {
      // illegal argument or getchar(0) and no char avail: return zero
      n = 0;
    } else {
      // getchar(0) and char avail() != NUL: get a character.
      // Note that vpeekc_any() returns K_SPECIAL for K_IGNORE.
      n = safe_vgetc();
    }

    if (n == K_IGNORE
        || n == K_MOUSEMOVE
        || n == K_VER_SCROLLBAR
        || n == K_HOR_SCROLLBAR) {
      continue;
    }
    break;
  }
  no_mapping--;
  allow_keys--;
  if (!simplify) {
    no_reduce_keys--;
  }

  if (cursor_flag == 'h') {
    ui_busy_stop();
  }

  set_vim_var_nr(VV_MOUSE_WIN, 0);
  set_vim_var_nr(VV_MOUSE_WINID, 0);
  set_vim_var_nr(VV_MOUSE_LNUM, 0);
  set_vim_var_nr(VV_MOUSE_COL, 0);

  if (n != 0 && (!allow_number || IS_SPECIAL(n) || mod_mask != 0)) {
    char temp[10];                // modifier: 3, mbyte-char: 6, NUL: 1
    int i = 0;

    // Turn a special key into three bytes, plus modifier.
    if (mod_mask != 0) {
      temp[i++] = (char)K_SPECIAL;
      temp[i++] = (char)KS_MODIFIER;
      temp[i++] = (char)mod_mask;
    }
    if (IS_SPECIAL(n)) {
      temp[i++] = (char)K_SPECIAL;
      temp[i++] = (char)K_SECOND(n);
      temp[i++] = (char)K_THIRD(n);
    } else {
      i += utf_char2bytes((int)n, temp + i);
    }
    assert(i < 10);
    temp[i] = NUL;
    rettv->v_type = VAR_STRING;
    rettv->vval.v_string = xmemdupz(temp, (size_t)i);

    if (is_mouse_key((int)n)) {
      int row = mouse_row;
      int col = mouse_col;
      int grid = mouse_grid;
      linenr_T lnum;
      win_T *wp;

      if (row >= 0 && col >= 0) {
        int winnr = 1;
        // Find the window at the mouse coordinates and compute the
        // text position.
        win_T *const win = mouse_find_win_inner(&grid, &row, &col);
        if (win == NULL) {
          return;
        }
        mouse_comp_pos(win, &row, &col, &lnum);
        for (wp = firstwin; wp != win; wp = wp->w_next) {
          winnr++;
        }
        set_vim_var_nr(VV_MOUSE_WIN, winnr);
        set_vim_var_nr(VV_MOUSE_WINID, wp->handle);
        set_vim_var_nr(VV_MOUSE_LNUM, lnum);
        set_vim_var_nr(VV_MOUSE_COL, col + 1);
      }
    }
  } else if (!allow_number) {
    rettv->v_type = VAR_STRING;
  } else {
    rettv->vval.v_number = n;
  }
}

/// "getchar()" function
void f_getchar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  getchar_common(argvars, rettv, true);
}

/// "getcharstr()" function
void f_getcharstr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  getchar_common(argvars, rettv, false);
}

/// "getcharmod()" function
void f_getcharmod(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = mod_mask;
}

typedef enum {
  map_result_fail,    // failed (recursion limit, OOM), break loop
  map_result_get,     // get a character from typeahead
  map_result_retry,   // try to map again
  map_result_nomatch,  // no matching mapping, get char
} map_result_T;

/// Put "string[new_slen]" in typebuf.
/// Remove "slen" bytes.
/// @return  FAIL for error, OK otherwise.
static int put_string_in_typebuf(int offset, int slen, uint8_t *string, int new_slen)
  FUNC_ATTR_NONNULL_ALL
{
  int extra = new_slen - slen;
  string[new_slen] = NUL;
  if (extra < 0) {
    // remove matched chars, taking care of noremap
    del_typebuf(-extra, offset);
  } else if (extra > 0) {
    // insert the extra space we need
    if (ins_typebuf((char *)string + slen, REMAP_YES, offset, false, false) == FAIL) {
      return FAIL;
    }
  }
  // Careful: del_typebuf() and ins_typebuf() may have reallocated
  // typebuf.tb_buf[]!
  memmove(typebuf.tb_buf + typebuf.tb_off + offset, string, (size_t)new_slen);
  return OK;
}

/// Check if the bytes at the start of the typeahead buffer are a character used
/// in Insert mode completion.  This includes the form with a CTRL modifier.
/// During completion started by complete() keys are mapped as usual.
static bool at_ins_compl_key(void)
{
  uint8_t *p = typebuf.tb_buf + typebuf.tb_off;
  int c = *p;

  if (typebuf.tb_len > 3 && c == K_SPECIAL && p[1] == KS_MODIFIER && (p[2] & MOD_MASK_CTRL)) {
    c = p[3] & 0x1f;
  }
  return !ctrl_x_mode_eval()
         && ((ctrl_x_mode_not_default() && vim_is_ctrl_x_key(c))
             || (compl_status_local() && (c == Ctrl_N || c == Ctrl_P)));
}

/// Check if typebuf.tb_buf[] contains a modifier plus key that can be changed
/// into just a key, apply that.
/// Check from typebuf.tb_buf[typebuf.tb_off] to typebuf.tb_buf[typebuf.tb_off + "max_offset"].
/// @return  the length of the replaced bytes, 0 if nothing changed, -1 for error.
static int check_simplify_modifier(int max_offset)
{
  // We want full modifiers in Terminal mode so that the key can be correctly
  // encoded
  if ((State & MODE_TERMINAL) || no_reduce_keys > 0) {
    return 0;
  }

  for (int offset = 0; offset < max_offset; offset++) {
    if (offset + 3 >= typebuf.tb_len) {
      break;
    }
    uint8_t *tp = typebuf.tb_buf + typebuf.tb_off + offset;
    if (tp[0] == K_SPECIAL && tp[1] == KS_MODIFIER) {
      // A modifier was not used for a mapping, apply it to ASCII
      // keys.  Shift would already have been applied.
      int modifier = tp[2];
      int c = tp[3];
      int new_c = merge_modifiers(c, &modifier);

      if (new_c != c) {
        if (offset == 0) {
          // At the start: remember the character and mod_mask before
          // merging, in some cases, e.g. at the hit-return prompt,
          // they are put back in the typeahead buffer.
          vgetc_char = c;
          vgetc_mod_mask = tp[2];
        }
        uint8_t new_string[MB_MAXBYTES];
        int len;
        if (IS_SPECIAL(new_c)) {
          new_string[0] = K_SPECIAL;
          new_string[1] = (uint8_t)K_SECOND(new_c);
          new_string[2] = (uint8_t)K_THIRD(new_c);
          len = 3;
        } else {
          len = utf_char2bytes(new_c, (char *)new_string);
        }
        if (modifier == 0) {
          if (put_string_in_typebuf(offset, 4, new_string, len) == FAIL) {
            return -1;
          }
        } else {
          tp[2] = (uint8_t)modifier;
          if (put_string_in_typebuf(offset + 3, 1, new_string, len) == FAIL) {
            return -1;
          }
        }
        return len;
      }
    }
  }
  return 0;
}

/// Returns the next character from a NUL-terminated UTF-8-encoded escaped-K_SPECIAL string.
///
/// Combining characters are treated as separate code points.
///
/// @param[inout] itp   Pointer to the input string pointer. The string pointer will be advanced to
///                     the next character.
/// @param        nomap If non-zero, then multi-byte characters are not decoded and the function
///                     always returns the next byte from the string.
/// @return             Unicode code point or 0, if at the end.
///                     - Returns 0 when NUL is in the middle of a multi-byte sequence. This allows
///                       calling code to request more data.
///                     - If decoding of a multi-byte character fails, returns the first byte of
///                       the encoded character.
static int char_iter(const uint8_t **itp, int nomap)
  FUNC_ATTR_NONNULL_ALL
{
  const uint8_t *it = *itp;
  int c = *it;
  if (c == NUL) {
    return 0;
  }

  if (nomap == 0) {
    int mblen = MB_BYTE2LEN(c);
    if (mblen > 1) {
      uint8_t buf[MB_MAXBYTES + 1];
      buf[0] = (uint8_t)c;
      int i = 1;

      do {
        buf[i] = *++it;
        if (buf[i] == K_SPECIAL) {
          // Follows vgetc()'s logic: Must be a K_SPECIAL - KS_SPECIAL - KE_FILLER sequence, which
          // represents a K_SPECIAL (0x80). Skip KS_SPECIAL and KE_FILLER.
          if (*++it == NUL || *++it == NUL) {
            break;
          }
        }
      } while (buf[i] != NUL && ++i < mblen);

      if (i != mblen) {
        *itp = it;
        return 0;
      }

      c = utf_ptr2char((const char *)buf);
      if (c == buf[0]) {
        // Invalid UTF-8 sequence
        it = *itp;
      }
    }
  }

  *itp = ++it;
  return c;
}

/// Handle mappings in the typeahead buffer.
/// - When something was mapped, return map_result_retry for recursive mappings.
/// - When nothing mapped and typeahead has a character: return map_result_get.
/// - When there is no match yet, return map_result_nomatch, need to get more
///   typeahead.
/// - On failure (out of memory) return map_result_fail.
static int handle_mapping(int *keylenp, const bool *timedout, int *mapdepth)
  FUNC_ATTR_NONNULL_ARG(1)
{
  mapblock_T *mp = NULL;
  mapblock_T *mp2;
  mapblock_T *mp_match;
  int mp_match_len = 0;
  int tb_match_len = 0;
  int max_mlen = 0;
  int keylen = *keylenp;
  int local_State = get_real_state();
  bool is_plug_map = false;

  // If typeahead starts with <Plug> then remap, even for a "noremap" mapping.
  if (typebuf.tb_len >= 3
      && typebuf.tb_buf[typebuf.tb_off] == K_SPECIAL
      && typebuf.tb_buf[typebuf.tb_off + 1] == KS_EXTRA
      && typebuf.tb_buf[typebuf.tb_off + 2] == KE_PLUG) {
    is_plug_map = true;
  }

  // Check for a mappable key sequence.
  // Walk through one maphash[] list until we find an entry that matches.
  //
  // Don't look for mappings if:
  // - no_mapping set: mapping disabled (e.g. for CTRL-V)
  // - maphash_valid not set: no mappings present.
  // - typebuf.tb_buf[typebuf.tb_off] should not be remapped
  // - in insert or cmdline mode and 'paste' option set
  // - waiting for "hit return to continue" and CR or SPACE typed
  // - waiting for a char with --more--
  // - in Ctrl-X mode, and we get a valid char for that mode
  // - in Ctrl-X mode (not started by complete()), and we get a valid char for that mode
  int tb_b1 = typebuf.tb_buf[typebuf.tb_off];
  if (no_mapping == 0
      && (no_zero_mapping == 0 || tb_b1 != '0')
      && (typebuf.tb_maplen == 0 || is_plug_map
          || (!(typebuf.tb_noremap[typebuf.tb_off] & (RM_NONE|RM_ABBR))))
      && !(p_paste && (State & (MODE_INSERT | MODE_CMDLINE)))
      && !(State == MODE_HITRETURN && (tb_b1 == CAR || tb_b1 == ' '))
      && State != MODE_ASKMORE
      && !at_ins_compl_key()) {
    int nolmaplen;
    int tb_c1 = tb_b1;
    const uint8_t *tb_iter = typebuf.tb_buf + typebuf.tb_off;

    if (tb_b1 == K_SPECIAL) {
      nolmaplen = 2;
      tb_iter += 1;
    } else {
      tb_c1 = char_iter(&tb_iter, 0);
      if (tb_c1 == 0) {
        if (*timedout) {
          *keylenp = 0;
          return map_result_get;
        }
        *keylenp = KEYLEN_PART_KEY;
        return map_result_nomatch;
      }

      int orig_tb_c1 = tb_c1;
      LANGMAP_ADJUST(tb_c1, ((State & (MODE_CMDLINE | MODE_INSERT)) == 0
                             && get_real_state() != MODE_SELECT));
      if (orig_tb_c1 != tb_c1) {
        // Mapped by 'langmap', update the first byte
        char cbuf[6];
        utf_char2bytes(tb_c1, cbuf);
        tb_b1 = (uint8_t)cbuf[0];
      }
      nolmaplen = 0;
    }
    // First try buffer-local mappings.
    mp = get_buf_maphash_list(local_State, tb_b1);
    mp2 = get_maphash_list(local_State, tb_b1);
    if (mp == NULL) {
      // There are no buffer-local mappings.
      mp = mp2;
      mp2 = NULL;
    }
    // Loop until a partly matching mapping is found or all (local)
    // mappings have been checked.
    // The longest full match is remembered in "mp_match".
    // A full match is only accepted if there is no partly match, so "aa"
    // and "aaa" can both be mapped.
    mp_match = NULL;
    mp_match_len = 0;
    tb_match_len = 0;
    for (; mp != NULL; mp->m_next == NULL ? (mp = mp2, mp2 = NULL) : (mp = mp->m_next)) {
      // Only consider an entry if the first character matches and it is
      // for the current state.
      // Skip ":lmap" mappings if keys were mapped.
      const uint8_t *key_iter = (const uint8_t *)mp->m_keys;

      if (char_iter(&key_iter, 0) == tb_c1 && (mp->m_mode & local_State)
          && ((mp->m_mode & MODE_LANGMAP) == 0 || typebuf.tb_maplen == 0)) {
        int nomap = nolmaplen;
        int modifiers = 0;
        int c2;
        const uint8_t *tmp_tb_iter = tb_iter;
        // Match length in key buffer
        int mlen = (int)(key_iter - (const uint8_t *)mp->m_keys);
        // Match length in typeahead buffer
        int tb_mlen = (int)(tmp_tb_iter - typebuf.tb_buf) - typebuf.tb_off;

        // find the match length of this mapping
        while ((c2 = char_iter(&tmp_tb_iter, nomap)) != 0) {
          int tb_nomap = nomap;
          if (nomap > 0) {
            if (nomap == 2 && c2 == KS_MODIFIER) {
              modifiers = 1;
            } else if (nomap == 1 && modifiers == 1) {
              modifiers = c2;
            }
            nomap--;
          } else {
            if (c2 == K_SPECIAL) {
              nomap = 2;
            } else if (merge_modifiers(c2, &modifiers) == c2) {
              // Only apply 'langmap' if merging modifiers into
              // the key will not result in another character,
              // so that 'langmap' behaves consistently in
              // different terminals and GUIs.
              LANGMAP_ADJUST(c2, true);
            }
            modifiers = 0;
          }

          int key_char = char_iter(&key_iter, tb_nomap);
          if (key_char != c2) {
            break;
          }

          mlen = (int)(key_iter - (const uint8_t *)mp->m_keys);
          tb_mlen = (int)(tmp_tb_iter - typebuf.tb_buf) - typebuf.tb_off;
        }

        // Check an entry whether it matches.
        // - Full match: mlen == keylen
        // - Partly match: mlen == typebuf.tb_len
        keylen = mp->m_keylen;
        if (mlen == keylen || (mlen == typebuf.tb_len && typebuf.tb_len < keylen)) {
          int n;

          // If only script-local mappings are allowed, check if the
          // mapping starts with K_SNR.
          uint8_t *s = typebuf.tb_noremap + typebuf.tb_off;
          if (*s == RM_SCRIPT
              && ((uint8_t)mp->m_keys[0] != K_SPECIAL
                  || (uint8_t)mp->m_keys[1] != KS_EXTRA
                  || mp->m_keys[2] != KE_SNR)) {
            continue;
          }

          // If one of the typed keys cannot be remapped, skip the entry.
          for (n = mlen; --n >= 0;) {
            if (*s++ & (RM_NONE|RM_ABBR)) {
              break;
            }
          }
          if (!is_plug_map && n >= 0) {
            continue;
          }

          if (keylen > typebuf.tb_len) {
            if (!*timedout && !(mp_match != NULL && mp_match->m_nowait)) {
              // break at a partly match
              keylen = KEYLEN_PART_MAP;
              break;
            }
          } else if (keylen > mp_match_len
                     || (keylen == mp_match_len
                         && mp_match != NULL
                         && (mp_match->m_mode & MODE_LANGMAP) == 0
                         && (mp->m_mode & MODE_LANGMAP) != 0)) {
            // found a longer match
            mp_match = mp;
            mp_match_len = keylen;
            tb_match_len = tb_mlen;
          }
        } else {
          // No match; may have to check for termcode at next character.
          max_mlen = MAX(max_mlen, mlen);
        }
      }
    }

    // If no partly match found, use the longest full match.
    if (keylen != KEYLEN_PART_MAP && mp_match != NULL) {
      mp = mp_match;
      keylen = tb_match_len;
    }
  }

  if ((mp == NULL || max_mlen > mp_match_len) && keylen != KEYLEN_PART_MAP) {
    // When no matching mapping found or found a non-matching mapping that
    // matches at least what the matching mapping matched:
    // Try to include the modifier into the key when mapping is allowed.
    if (no_mapping == 0 || allow_keys != 0) {
      if (tb_b1 == K_SPECIAL
          && (typebuf.tb_len < 2
              || (typebuf.tb_buf[typebuf.tb_off + 1] == KS_MODIFIER && typebuf.tb_len < 4))) {
        // Incomplete modifier sequence: cannot decide whether to simplify yet.
        keylen = KEYLEN_PART_KEY;
      } else {
        // Try to include the modifier into the key.
        keylen = check_simplify_modifier(max_mlen + 1);
        if (keylen < 0) {
          // ins_typebuf() failed
          return map_result_fail;
        }
      }
    } else {
      keylen = 0;
    }
    if (keylen == 0) {  // no simplification has been done
      // If there was no mapping at all use the character from the
      // typeahead buffer right here.
      if (mp == NULL) {
        *keylenp = keylen;
        return map_result_get;  // get character from typeahead
      }
    }

    if (keylen > 0) {  // keys have been simplified
      *keylenp = keylen;
      return map_result_retry;  // try mapping again
    }

    if (keylen < 0) {
      // Incomplete key sequence: get some more characters.
      assert(keylen == KEYLEN_PART_KEY);
    } else {
      assert(mp != NULL);
      // When a matching mapping was found use that one.
      keylen = tb_match_len;
    }
  }

  // complete match
  if (keylen >= 0 && keylen <= typebuf.tb_len) {
    int i;
    char *map_str = NULL;

    // Write chars to script file(s).
    // Note: :lmap mappings are written *after* being applied. #5658
    if (keylen > typebuf.tb_maplen && (mp->m_mode & MODE_LANGMAP) == 0) {
      gotchars(typebuf.tb_buf + typebuf.tb_off + typebuf.tb_maplen,
               (size_t)(keylen - typebuf.tb_maplen));
      // A typed key sequence resolved this mapping (not a nested expansion:
      // those keys come from another mapping): open its composite.
      atom_map_start(mp->m_keys, (size_t)mp->m_keylen);
    }

    cmd_silent = (typebuf.tb_silent > 0);
    del_typebuf(keylen, 0);  // remove the mapped keys

    // Put the replacement string in front of mapstr.
    // The depth check catches ":map x y" and ":map y x".
    if (++*mapdepth >= p_mmd) {
      emsg(_(e_recursive_mapping));
      if (State & MODE_CMDLINE) {
        redrawcmdline();
      } else {
        setcursor();
      }
      flush_buffers(FLUSH_MINIMAL);
      *mapdepth = 0;  // for next one
      *keylenp = keylen;
      return map_result_fail;
    }

    // In Select mode and a Visual mode mapping is used: Switch to Visual
    // mode temporarily.  Append K_SELECT to switch back to Select mode.
    if (Visual.active && Visual.select && (mp->m_mode & MODE_VISUAL)) {
      Visual.select = false;
      ins_typebuf(K_SELECT_STRING, REMAP_NONE, 0, true, false);
    }

    // Copy the values from *mp that are used, because evaluating the
    // expression may invoke a function that redefines the mapping, thereby
    // making *mp invalid.
    const bool save_m_expr = mp->m_expr;
    const int save_m_noremap = mp->m_noremap;
    const bool save_m_silent = mp->m_silent;
    char *save_m_keys = NULL;  // only saved when needed
    char *save_alt_m_keys = NULL;  // only saved when needed
    const int save_alt_m_keylen = mp->m_alt != NULL ? mp->m_alt->m_keylen : 0;

    // Handle ":map <expr>": evaluate the {rhs} as an
    // expression.  Also save and restore the command line
    // for "normal :".
    if (mp->m_expr) {
      const int save_vgetc_busy = vgetc_busy;
      const bool save_may_garbage_collect = may_garbage_collect;
      const int prev_did_emsg = did_emsg;

      vgetc_busy = 0;
      may_garbage_collect = false;

      save_m_keys = xmemdupz(mp->m_keys, (size_t)mp->m_keylen);
      save_alt_m_keys = mp->m_alt != NULL
                        ? xmemdupz(mp->m_alt->m_keys, (size_t)save_alt_m_keylen)
                        : NULL;
      map_str = eval_map_expr(mp, NUL);

      if ((map_str == NULL || *map_str == NUL)) {
        // If an error was displayed and the expression returns an empty
        // string, generate a <Nop> to allow for a redraw.
        if (prev_did_emsg != did_emsg) {
          char buf[4];
          xfree(map_str);
          buf[0] = (char)K_SPECIAL;
          buf[1] = (char)KS_EXTRA;
          buf[2] = KE_IGNORE;
          buf[3] = NUL;
          map_str = xmemdupz(buf, 3);
          if (State & MODE_CMDLINE) {
            // redraw the command below the error
            msg_didout = true;
            msg_row = MAX(msg_row, cmdline_row);
            redrawcmd();
          }
        } else if (State & (MODE_NORMAL | MODE_INSERT)) {
          // otherwise, just put back the cursor
          setcursor();
        }
      }

      vgetc_busy = save_vgetc_busy;
      may_garbage_collect = save_may_garbage_collect;
    } else {
      map_str = mp->m_str;
    }

    // Insert the 'to' part in the typebuf.tb_buf.
    // If 'from' field is the same as the start of the 'to' field, don't
    // remap the first character (but do allow abbreviations).
    // If m_noremap is set, don't remap the whole 'to' part.
    if (map_str == NULL) {
      i = FAIL;
    } else {
      int noremap;

      // If this is a LANGMAP mapping, then we didn't record the keys
      // at the start of the function and have to record them now.
      if (keylen > typebuf.tb_maplen && (mp->m_mode & MODE_LANGMAP) != 0) {
        gotchars((uint8_t *)map_str, strlen(map_str));
      }

      if (save_m_noremap != REMAP_YES) {
        noremap = save_m_noremap;
      } else if (save_m_expr
                 ? strncmp(map_str, save_m_keys, (size_t)keylen) == 0
                 || (save_alt_m_keys != NULL
                     && strncmp(map_str, save_alt_m_keys,
                                (size_t)save_alt_m_keylen) == 0)
                 : strncmp(map_str, mp->m_keys, (size_t)keylen) == 0
                 || (mp->m_alt != NULL
                     && strncmp(map_str, mp->m_alt->m_keys,
                                (size_t)mp->m_alt->m_keylen) == 0)) {
        noremap = REMAP_SKIP;
      } else {
        noremap = REMAP_YES;
      }
      i = ins_typebuf(map_str, noremap, 0, true, cmd_silent || save_m_silent);
      if (save_m_expr) {
        xfree(map_str);
      }
    }
    xfree(save_m_keys);
    xfree(save_alt_m_keys);
    *keylenp = keylen;
    if (i == FAIL) {
      return map_result_fail;
    }
    return map_result_retry;
  }

  *keylenp = keylen;
  return map_result_nomatch;
}

/// unget one character (can only be done once!)
/// If the character was stuffed, vgetc() will get it next time it is called.
/// Otherwise vgetc() will only get it when the stuff buffer is empty.
void vungetc(int c)
{
  ungot = (UngotKey){
    .c = c,
    .mod_mask = mod_mask,
    .mouse_grid = mouse_grid,
    .mouse_row = mouse_row,
    .mouse_col = mouse_col,
    .stuffed = KeyStuffed,
  };
}

/// When peeking and not getting a character, reg_executing cannot be cleared
/// yet, so set a flag to clear it later.
void check_end_reg_executing(bool advance)
{
  if (reg_executing != 0 && (typebuf.tb_maplen == 0 || pending_end_reg_executing)) {
    if (advance) {
      reg_executing = 0;
      pending_end_reg_executing = false;
    } else {
      pending_end_reg_executing = true;
    }
  }
}

/// Gets a byte:
/// 1. from the stuffbuffer
///    This is used for abbreviated commands like "D" -> "d$".
///    Also used to redo a command for ".".
/// 2. from the typeahead buffer
///    Stores text obtained previously but not used yet.
///    Also stores the result of mappings.
///    Also used for the ":normal" command.
/// 3. from the user
///    This may do a blocking wait if "advance" is true.
///
/// if "advance" is true (vgetc()):
///    Really get the character.
///    KeyTyped is set to true in the case the user typed the key.
///    KeyStuffed is true if the character comes from the stuff buffer.
/// if "advance" is false (vpeekc()):
///    Just look whether there is a character available.
///    Return NUL if not.
///
/// When `no_mapping` (global) is zero, checks for mappings in the current mode.
/// Only returns one byte (of a multi-byte character).
/// K_SPECIAL may be escaped, need to get two more bytes then.
static int vgetorpeek(bool advance)
{
  int c;
  bool timedout = false;  // waited for more than 'timeoutlen'
                          // for mapping to complete or
                          // 'ttimeoutlen' for complete key code
  int mapdepth = 0;  // check for recursive mapping
  bool mode_deleted = false;  // set when mode has been deleted

  // This function doesn't work very well when called recursively.  This may
  // happen though, because of:
  // 1. The call to add_to_showcmd().   char_avail() is then used to check if
  // there is a character available, which calls this function.  In that
  // case we must return NUL, to indicate no character is available.
  // 2. A GUI callback function writes to the screen, causing a
  // wait_return().
  // Using ":normal" can also do this, but it saves the typeahead buffer,
  // thus it should be OK.  But don't get a key from the user then.
  if (vgetc_busy > 0 && ex_normal_busy == 0) {
    return NUL;
  }

  vgetc_busy++;

  if (advance) {
    KeyStuffed = false;
    typebuf_was_empty = false;
  }

  init_typebuf();
  start_stuff();
  check_end_reg_executing(advance);
  do {
    // get a character: 1. from the stuffbuffer
    if (typeahead_char != 0) {
      c = typeahead_char;
      if (advance) {
        typeahead_char = 0;
      }
    } else {
      c = read_readbuffers(advance);
    }
    if (c != NUL && !got_int) {
      if (advance) {
        // KeyTyped = false;  When the command that stuffed something
        // was typed, behave like the stuffed command was typed.
        // needed for CTRL-W CTRL-] to open a fold, for example.
        KeyStuffed = true;
      }
      if (typebuf.tb_no_abbr_cnt == 0) {
        typebuf.tb_no_abbr_cnt = 1;  // no abbreviations now
      }
    } else {
      // Loop until we either find a matching mapped key, or we
      // are sure that it is not a mapped key.
      // If a mapped key sequence is found we go back to the start to
      // try re-mapping.
      while (true) {
        check_end_reg_executing(advance);
        // os_breakcheck() is slow, don't use it too often when
        // inside a mapping.  But call it each time for typed
        // characters.
        if (typebuf.tb_maplen) {
          line_breakcheck();
        } else {
          // os_breakcheck() can call input_enqueue()
          if ((mapped_ctrl_c | curbuf->b_mapped_ctrl_c) & get_real_state()) {
            ctrl_c_interrupts = false;
          }
          os_breakcheck();  // check for CTRL-C
          ctrl_c_interrupts = true;
        }
        int keylen = 0;
        if (got_int) {
          // flush all input
          c = inchar(typebuf.tb_buf, typebuf.tb_buflen - 1, 0);

          // If inchar() returns true (script file was active) or we
          // are inside a mapping, get out of Insert mode.
          // Otherwise we behave like having gotten a CTRL-C.
          // As a result typing CTRL-C in insert mode will
          // really insert a CTRL-C.
          if ((c || typebuf.tb_maplen)
              && (State & (MODE_INSERT | MODE_CMDLINE))) {
            c = ESC;
          } else {
            c = Ctrl_C;
          }
          flush_buffers(FLUSH_INPUT);  // flush all typeahead

          if (advance) {
            // Also record this character, it might be needed to
            // get out of Insert mode.
            *typebuf.tb_buf = (uint8_t)c;
            gotchars(typebuf.tb_buf, 1);
          }
          cmd_silent = false;

          break;
        } else if (typebuf.tb_len > 0) {
          // Check for a mapping in "typebuf".
          map_result_T result = (map_result_T)handle_mapping(&keylen, &timedout, &mapdepth);

          if (result == map_result_retry) {
            // try mapping again
            continue;
          }

          if (result == map_result_fail) {
            atom_composite_abort();
            // failed, use the outer loop
            c = -1;
            break;
          }

          if (result == map_result_get) {
            // get a character: 2. from the typeahead buffer
            c = typebuf.tb_buf[typebuf.tb_off];
            if (advance) {  // remove chars from tb_buf
              cmd_silent = (typebuf.tb_silent > 0);
              if (typebuf.tb_maplen > 0) {
                KeyTyped = false;
              } else {
                KeyTyped = true;
                // write char to script file(s)
                gotchars(typebuf.tb_buf + typebuf.tb_off, 1);
              }
              KeyNoremap = (unsigned char)typebuf.tb_noremap[typebuf.tb_off];
              del_typebuf(1, 0);
            }
            break;  // got character, break the for loop
          }

          // not enough characters, get more
        }

        // get a character: 3. from the user - handle <Esc> in Insert mode

        // special case: if we get an <ESC> in insert mode and there
        // are no more characters at once, we pretend to go out of
        // insert mode.  This prevents the one second delay after
        // typing an <ESC>.  If we get something after all, we may
        // have to redisplay the mode. That the cursor is in the wrong
        // place does not matter.
        c = 0;
        int new_wcol = curwin->w_wcol;
        int new_wrow = curwin->w_wrow;
        if (advance
            && typebuf.tb_len == 1
            && typebuf.tb_buf[typebuf.tb_off] == ESC
            && !no_mapping
            && ex_normal_busy == 0
            && typebuf.tb_maplen == 0
            && (State & MODE_INSERT)
            && (p_timeout || (keylen == KEYLEN_PART_KEY && p_ttimeout))
            && (c = inchar(typebuf.tb_buf + typebuf.tb_off + typebuf.tb_len, 3, 25)) == 0) {
          if (mode_displayed) {
            unshowmode(true);
            mode_deleted = true;
          }
          validate_cursor(curwin);
          int old_wcol = curwin->w_wcol;
          int old_wrow = curwin->w_wrow;

          // move cursor left, if possible
          if (curwin->w_cursor.col != 0) {
            colnr_T col = 0;
            char *ptr;
            if (curwin->w_wcol > 0) {
              // After auto-indenting and no text is following,
              // we are expecting to truncate the trailing
              // white-space, so find the last non-white
              // character -- webb
              if (Ins.did_ai && *skipwhite(get_cursor_line_ptr() + curwin->w_cursor.col) == NUL) {
                curwin->w_wcol = 0;
                ptr = get_cursor_line_ptr();
                char *endptr = ptr + curwin->w_cursor.col;

                CharsizeArg csarg;
                CSType cstype = init_charsize_arg(&csarg, curwin, curwin->w_cursor.lnum, ptr);
                StrCharInfo ci = utf_ptr2StrCharInfo(ptr);
                int vcol = 0;
                while (ci.ptr < endptr) {
                  if (!ascii_iswhite(ci.chr.value)) {
                    curwin->w_wcol = vcol;
                  }
                  vcol += win_charsize(cstype, vcol, ci.ptr, ci.chr.value, &csarg).width;
                  ci = utfc_next(ci);
                }

                curwin->w_wrow = curwin->w_cline_row
                                 + curwin->w_wcol / curwin->w_view_width;
                curwin->w_wcol %= curwin->w_view_width;
                curwin->w_wcol += win_col_off(curwin);
                col = 0;  // no correction needed
              } else {
                curwin->w_wcol--;
                col = curwin->w_cursor.col - 1;
              }
            } else if (curwin->w_p_wrap && curwin->w_wrow) {
              curwin->w_wrow--;
              curwin->w_wcol = curwin->w_view_width - 1;
              col = curwin->w_cursor.col - 1;
            }
            if (col > 0 && curwin->w_wcol > 0) {
              // Correct when the cursor is on the right halve
              // of a double-wide character.
              ptr = get_cursor_line_ptr();
              col -= utf_head_off(ptr, ptr + col);
              if (utf_ptr2cells(ptr + col) > 1) {
                curwin->w_wcol--;
              }
            }
          }
          setcursor();
          ui_flush();
          new_wcol = curwin->w_wcol;
          new_wrow = curwin->w_wrow;
          curwin->w_wcol = old_wcol;
          curwin->w_wrow = old_wrow;
        }
        if (c < 0) {
          continue;  // end of input script reached
        }

        // Allow mapping for just typed characters. When we get here c
        // is the number of extra bytes and typebuf.tb_len is 1.
        for (int n = 1; n <= c; n++) {
          typebuf.tb_noremap[typebuf.tb_off + n] = RM_YES;
        }
        typebuf.tb_len += c;

        // buffer full, don't map
        if (typebuf.tb_len >= typebuf.tb_maplen + MAXMAPLEN) {
          timedout = true;
          continue;
        }

        if (ex_normal_busy > 0) {
          static int tc = 0;

          // No typeahead left and inside ":normal".  Must return
          // something to avoid getting stuck.  When an incomplete
          // mapping is present, behave like it timed out.
          if (typebuf.tb_len > 0) {
            timedout = true;
            continue;
          }

          // For the command line only CTRL-C always breaks it.
          // For the cmdline window: Alternate between ESC and
          // CTRL-C: ESC for most situations and CTRL-C to close the
          // cmdline window.
          c = ((State & MODE_CMDLINE) || (cmdwin_type > 0 && tc == ESC)) ? Ctrl_C : ESC;
          tc = c;

          // set a flag to indicate this wasn't a normal char
          if (advance) {
            typebuf_was_empty = true;
          }

          // no chars to block abbreviations for
          typebuf.tb_no_abbr_cnt = 0;

          break;
        }

        // get a character: 3. from the user - update display

        // In insert mode a screen update is skipped when characters
        // are still available.  But when those available characters
        // are part of a mapping, and we are going to do a blocking
        // wait here.  Need to update the screen to display the
        // changed text so far. Also for when 'lazyredraw' is set and
        // redrawing was postponed because there was something in the
        // input buffer (e.g., termresponse).
        if (((State & MODE_INSERT) != 0 || p_lz) && (State & MODE_CMDLINE) == 0
            && advance && must_redraw != 0 && !need_wait_return) {
          update_screen();
          setcursor();  // put cursor back where it belongs
        }

        // If we have a partial match (and are going to wait for more
        // input from the user), show the partially matched characters
        // to the user with showcmd.
        int showcmd_idx = 0;
        bool showing_partial = false;
        if (typebuf.tb_len > 0 && advance) {
          if (((State & (MODE_NORMAL | MODE_INSERT)) || State == MODE_LANGMAP)
              && State != MODE_HITRETURN) {
            // this looks nice when typing a dead character map
            if (State & MODE_INSERT
                && ptr2cells((char *)typebuf.tb_buf + typebuf.tb_off + typebuf.tb_len - 1) == 1) {
              edit_putchar(typebuf.tb_buf[typebuf.tb_off + typebuf.tb_len - 1], false);
              setcursor();  // put cursor back where it belongs
              showing_partial = true;
            }
            // need to use the col and row from above here
            int old_wcol = curwin->w_wcol;
            int old_wrow = curwin->w_wrow;
            curwin->w_wcol = new_wcol;
            curwin->w_wrow = new_wrow;
            push_showcmd();
            if (typebuf.tb_len > SHOWCMD_COLS) {
              showcmd_idx = typebuf.tb_len - SHOWCMD_COLS;
            }
            while (showcmd_idx < typebuf.tb_len) {
              add_byte_to_showcmd(typebuf.tb_buf[typebuf.tb_off + showcmd_idx++]);
            }
            curwin->w_wcol = old_wcol;
            curwin->w_wrow = old_wrow;
          }

          // This looks nice when typing a dead character map.
          // There is no actual command line for get_number().
          if ((State & MODE_CMDLINE)
              && get_cmdline_info()->cmdbuff != NULL
              && cmdline_star == 0) {
            char *p = (char *)typebuf.tb_buf + typebuf.tb_off + typebuf.tb_len - 1;
            if (ptr2cells(p) == 1 && (uint8_t)(*p) < 128) {
              putcmdline(*p, false);
              showing_partial = true;
            }
          }
        }

        // get a character: 3. from the user - get it
        if (typebuf.tb_len == 0) {
          // timedout may have been set if a mapping with empty RHS
          // fully matched while longer mappings timed out.
          timedout = false;
        }

        int wait_time = 0;

        if (advance) {
          if (typebuf.tb_len == 0 || !(p_timeout || (p_ttimeout && keylen == KEYLEN_PART_KEY))) {
            // blocking wait
            wait_time = -1;
          } else if (keylen == KEYLEN_PART_KEY && p_ttm >= 0) {
            wait_time = (int)p_ttm;
          } else {
            wait_time = (int)p_tm;
          }
        }

        int wait_tb_len = typebuf.tb_len;
        c = inchar(typebuf.tb_buf + typebuf.tb_off + typebuf.tb_len,
                   typebuf.tb_buflen - typebuf.tb_off - typebuf.tb_len - 1,
                   wait_time);

        if (showcmd_idx != 0) {
          pop_showcmd();
        }
        if (showing_partial == 1) {
          if (State & MODE_INSERT) {
            edit_unputchar();
          }
          if ((State & MODE_CMDLINE)
              && get_cmdline_info()->cmdbuff != NULL) {
            unputcmdline();
          } else {
            setcursor();  // put cursor back where it belongs
          }
        }

        if (c < 0) {
          continue;  // end of input script reached
        }
        if (c == NUL) {  // no character available
          if (!advance) {
            break;
          }
          if (wait_tb_len > 0) {  // timed out
            timedout = true;
            continue;
          }
        } else {  // allow mapping for just typed characters
          while (typebuf.tb_buf[typebuf.tb_off + typebuf.tb_len] != NUL) {
            typebuf.tb_noremap[typebuf.tb_off + typebuf.tb_len++] = RM_YES;
          }
        }
      }  // while (true)
    }  // if (!character from stuffbuf)

    // if advance is false don't loop on NULs
  } while (c < 0 || (advance && c == NUL));

  // The "INSERT" message is taken care of here:
  //     if we return an ESC to exit insert mode, the message is deleted
  //     if we don't return an ESC but deleted the message before, redisplay it
  if (advance && p_smd && msg_silent == 0 && (State & MODE_INSERT)) {
    if (c == ESC && !mode_deleted && !no_mapping && mode_displayed) {
      if (typebuf.tb_len && !KeyTyped) {
        redraw_cmdline = true;  // delete mode later
      } else {
        unshowmode(false);
      }
    } else if (c != ESC && mode_deleted) {
      if (typebuf.tb_len && !KeyTyped) {
        redraw_cmdline = true;  // show mode later
      } else {
        showmode();
      }
    }
  }

  if (timedout && c == ESC) {
    // When recording there will be no timeout.  Add an <Ignore> after the
    // ESC to avoid that it forms a key code with following characters.
    gotchars_ignore();
  }

  vgetc_busy--;

  return c;
}

/// inchar() - get one character from
///      1. a scriptfile
///      2. the keyboard
///
///  As many characters as we can get (up to 'maxlen') are put in "buf" and
///  NUL terminated (buffer length must be 'maxlen' + 1).
///  Minimum for "maxlen" is 3!!!!
///
///  "tb_change_cnt" is the value of typebuf.tb_change_cnt if "buf" points into
///  it.  When typebuf.tb_change_cnt changes (e.g., when a message is received
///  from a remote client) "buf" can no longer be used.  "tb_change_cnt" is 0
///  otherwise.
///
///  If we got an interrupt all input is read until none is available.
///
///  If wait_time == 0  there is no waiting for the char.
///  If wait_time == n  we wait for n msec for a character to arrive.
///  If wait_time == -1 we wait forever for a character to arrive.
///
///  Return the number of obtained characters.
///  Return -1 when end of input script reached.
///
/// @param wait_time  milliseconds
static int inchar(uint8_t *buf, int maxlen, long wait_time)
{
  int len = 0;  // Init for GCC.
  int retesc = false;  // Return ESC with gotint.
  const int tb_change_cnt = typebuf.tb_change_cnt;

  if (wait_time == -1 || wait_time > 100) {
    // flush output before waiting
    ui_flush();
  }

  // Don't reset these when at the hit-return prompt, otherwise an endless
  // recursive loop may result (write error in swapfile, hit-return, timeout
  // on char wait, flush swapfile, write error....).
  if (State != MODE_HITRETURN) {
    did_outofmem_msg = false;       // display out of memory message (again)
    did_swapwrite_msg = false;      // display swap file write error again
  }

  // Get a character from a script file if there is one.
  // If interrupted: Stop reading script files, close them all.
  ptrdiff_t read_size = -1;
  while (curscript >= 0 && read_size <= 0 && !ignore_script) {
    char script_char;
    if (got_int
        || (read_size = file_read(&scriptin[curscript], &script_char, 1)) != 1) {
      // Reached EOF or some error occurred.
      // Careful: closescript() frees typebuf.tb_buf[] and buf[] may
      // point inside typebuf.tb_buf[].  Don't use buf[] after this!
      closescript();
      // When reading script file is interrupted, return an ESC to get
      // back to normal mode.
      // Otherwise return -1, because typebuf.tb_buf[] has changed.
      if (got_int) {
        retesc = true;
      } else {
        return -1;
      }
    } else {
      buf[0] = (uint8_t)script_char;
      len = 1;
    }
  }

  if (read_size <= 0) {  // Did not get a character from script.
    // If we got an interrupt, skip all previously typed characters and
    // return true if quit reading script file.
    // Stop reading typeahead when a single CTRL-C was read,
    // fill_input_buf() returns this when not able to read from stdin.
    // Don't use buf[] here, closescript() may have freed typebuf.tb_buf[]
    // and buf may be pointing inside typebuf.tb_buf[].
    if (got_int) {
#define DUM_LEN (MAXMAPLEN * 3 + 3)
      uint8_t dum[DUM_LEN + 1];

      while (true) {
        len = input_get(dum, DUM_LEN, 0, 0, NULL);
        if (len == 0 || (len == 1 && dum[0] == Ctrl_C)) {
          break;
        }
      }
      return retesc;
    }

    // Always flush the output characters when getting input characters
    // from the user and not just peeking.
    if (wait_time == -1 || wait_time > 10) {
      ui_flush();
    }

    // Fill up to a third of the buffer, because each character may be
    // tripled below.
    len = input_get(buf, maxlen / 3, (int)wait_time, tb_change_cnt, NULL);
  }

  // If the typebuf was changed further down, it is like nothing was added by
  // this call.
  if (typebuf_changed(tb_change_cnt)) {
    return 0;
  }

  // Note the change in the typeahead buffer, this matters for when
  // vgetorpeek() is called recursively, e.g. using getchar(1) in a timer
  // function.
  if (len > 0 && ++typebuf.tb_change_cnt == 0) {
    typebuf.tb_change_cnt = 1;
  }

  return fix_input_buffer(buf, len);
}

/// Fix typed characters for use by vgetc().
/// "buf[]" must have room to triple the number of bytes!
/// Returns the new length.
int fix_input_buffer(uint8_t *buf, int len)
  FUNC_ATTR_NONNULL_ALL
{
  if (!using_script()) {
    // Should not escape K_SPECIAL reading input from the user because vim
    // key codes keys are processed in input.c/input_enqueue.
    buf[len] = NUL;
    return len;
  }

  // Reading from script, need to process special bytes
  uint8_t *p = buf;

  // Two characters are special: NUL and K_SPECIAL.
  // Replace       NUL by K_SPECIAL KS_ZERO    KE_FILLER
  // Replace K_SPECIAL by K_SPECIAL KS_SPECIAL KE_FILLER
  for (int i = len; --i >= 0; p++) {
    if (p[0] == NUL
        || (p[0] == K_SPECIAL
            && (i < 2 || p[1] != KS_EXTRA))) {
      memmove(p + 3, p + 1, (size_t)i);
      p[2] = (uint8_t)K_THIRD(p[0]);
      p[1] = (uint8_t)K_SECOND(p[0]);
      p[0] = K_SPECIAL;
      p += 2;
      len += 2;
    }
  }
  *p = NUL;  // add trailing NUL
  return len;
}

/// Get a key stroke directly from the user.
///
/// Ignores mouse clicks and scrollbar events, except a click for the left
/// button (used at the more prompt).
/// Doesn't use vgetc(), because it syncs undo and eats mapped characters.
/// Disadvantage: typeahead is ignored.
/// Translates the interrupt character for unix to ESC.
int get_keystroke(MultiQueue *events)
{
  uint8_t *buf = NULL;
  int buflen = 150;
  int len = 0;
  int n;
  int save_mapped_ctrl_c = mapped_ctrl_c;

  mod_mask = 0;
  mapped_ctrl_c = 0;        // mappings are not used here
  while (true) {
    // flush output before waiting
    ui_flush();
    // Leave some room for check_termcode() to insert a key code into (max
    // 5 chars plus NUL).  And fix_input_buffer() can triple the number of
    // bytes.
    int maxlen = (buflen - 6 - len) / 3;
    if (buf == NULL) {
      buf = xmalloc((size_t)buflen);
    } else if (maxlen < 10) {
      // Need some more space. This might happen when receiving a long
      // escape sequence.
      buflen += 100;
      buf = xrealloc(buf, (size_t)buflen);
      maxlen = (buflen - 6 - len) / 3;
    }

    // First time: blocking wait.  Second time: wait up to 100ms for a
    // terminal code to complete.
    n = input_get(buf + len, maxlen, len == 0 ? -1 : 100, 0, events);
    if (n > 0) {
      // Replace zero and K_SPECIAL by a special key code.
      n = fix_input_buffer(buf + len, n);
      len += n;
    }

    if (n > 0) {  // found a termcode: adjust length
      len = n;
    }
    if (len == 0) {  // nothing typed yet
      continue;
    }

    // Handle modifier and/or special key code.
    n = buf[0];
    if (n == K_SPECIAL) {
      n = TO_SPECIAL(buf[1], buf[2]);
      if (buf[1] == KS_MODIFIER
          || n == K_IGNORE
          || (is_mouse_key(n) && n != K_LEFTMOUSE)) {
        if (buf[1] == KS_MODIFIER) {
          mod_mask = buf[2];
        }
        len -= 3;
        if (len > 0) {
          memmove(buf, buf + 3, (size_t)len);
        }
        continue;
      }
      break;
    }
    if (MB_BYTE2LEN(n) > len) {
      // more bytes to get.
      continue;
    }
    buf[len >= buflen ? buflen - 1 : len] = NUL;
    n = utf_ptr2char((char *)buf);
    break;
  }
  xfree(buf);

  mapped_ctrl_c = save_mapped_ctrl_c;
  return merge_modifiers(n, &mod_mask);
}

/// Function passed to do_cmdline() to get the command after a <Cmd> key from
/// typeahead.
char *getcmdkeycmd(int promptc, void *cookie, int indent, bool do_concat)
{
  garray_T line_ga;
  int c1 = -1;
  int cmod = 0;
  bool aborted = false;

  ga_init(&line_ga, 1, 32);

  // no mapping for these characters
  no_mapping++;

  got_int = false;
  while (c1 != NUL && !aborted) {
    ga_grow(&line_ga, 32);

    if (vgetorpeek(false) == NUL) {
      // incomplete <Cmd> is an error, because there is not much the user
      // could do in this state.
      emsg(_(e_cmd_mapping_must_end_with_cr));
      aborted = true;
      break;
    }

    // Get one character at a time.
    c1 = vgetorpeek(true);

    // Get two extra bytes for special keys
    if (c1 == K_SPECIAL) {
      c1 = vgetorpeek(true);
      int c2 = vgetorpeek(true);
      if (c1 == KS_MODIFIER) {
        cmod = c2;
        continue;
      }
      c1 = TO_SPECIAL(c1, c2);
    }

    if (got_int) {
      aborted = true;
    } else if (c1 == '\r' || c1 == '\n') {
      c1 = NUL;  // end the line
    } else if (c1 == ESC) {
      aborted = true;
    } else if (c1 == K_COMMAND) {
      // give a nicer error message for this special case
      emsg(_(e_cmd_mapping_must_end_with_cr_before_second_cmd));
      aborted = true;
    } else if (c1 == K_SNR) {
      GA_CONCAT_LITERAL(&line_ga, "<SNR>");
    } else {
      if (cmod != 0) {
        ga_append(&line_ga, K_SPECIAL);
        ga_append(&line_ga, KS_MODIFIER);
        ga_append(&line_ga, (uint8_t)cmod);
      }
      if (IS_SPECIAL(c1)) {
        ga_append(&line_ga, K_SPECIAL);
        ga_append(&line_ga, (uint8_t)K_SECOND(c1));
        ga_append(&line_ga, (uint8_t)K_THIRD(c1));
      } else {
        ga_append(&line_ga, (uint8_t)c1);
      }
    }

    cmod = 0;
  }

  no_mapping--;

  if (aborted) {
    ga_clear(&line_ga);
  } else if (promptc == ':') {
    // Executing (do_cmdline()), not discarding (vim.on_key()): capture the payload.
    atom_cmdline_set(K_COMMAND, line_ga.ga_data, (size_t)line_ga.ga_len);
  }

  return line_ga.ga_data;
}

/// Handle a Lua mapping: get its LuaRef from typeahead and execute it.
///
/// @param may_repeat  save the LuaRef for redoing with "." later
/// @param discard     discard the keys instead of executing the LuaRef
///
/// @return  false if getting the LuaRef was aborted, true otherwise
bool map_execute_lua(bool may_repeat, bool discard)
{
  garray_T line_ga;
  int c1 = -1;
  bool aborted = false;

  ga_init(&line_ga, 1, 32);

  no_mapping++;

  got_int = false;
  while (c1 != NUL && !aborted) {
    ga_grow(&line_ga, 32);
    // Get one character at a time.
    c1 = vgetorpeek(true);
    if (got_int) {
      aborted = true;
    } else if (c1 == '\r' || c1 == '\n') {
      c1 = NUL;  // end the line
    } else {
      ga_append(&line_ga, (uint8_t)c1);
    }
  }

  no_mapping--;

  if (aborted || discard) {
    ga_clear(&line_ga);
    return !aborted;
  }

  LuaRef ref = (LuaRef)atoi(line_ga.ga_data);
  if (may_repeat) {
    repeat_luaref = ref;
  }

  Error err = ERROR_INIT;
  Array args = ARRAY_DICT_INIT;
  nlua_call_ref(ref, NULL, args, kRetNilBool, NULL, &err);
  if (ERROR_SET(&err)) {
    semsg_multiline("emsg", "E5108: %s", err.msg);
    api_clear_error(&err);
  }

  ga_clear(&line_ga);
  return true;
}

/// Wraps pasted text stream with K_PASTE_START and K_PASTE_END, and
/// appends to redo buffer and/or record buffer if needed.
/// Escapes all K_SPECIAL and NUL bytes in the content.
///
/// @param state  kFalse for the start of a paste
///               kTrue for the end of a paste
///               kNone for the content of a paste
/// @param str    the content of the paste (only used when state is kNone)
void paste_store(const uint64_t channel_id, const TriState state, const String str, const bool crlf)
{
  if (State & MODE_CMDLINE) {
    return;
  }

  const bool need_redo = !block_redo;
  const bool need_record = reg_recording != 0 && !is_internal_call(channel_id);

  if (!need_redo && !need_record) {
    return;
  }

  if (state != kNone) {
    const int c = state == kFalse ? K_PASTE_START : K_PASTE_END;
    if (need_redo) {
      if (state == kFalse && !(State & MODE_INSERT)) {
        redo_new((CmdSpec){ 0 });
      }
      sb_add_char(&redobuff.cur.body, c);
    }
    if (need_record) {
      sb_add_char(&recordbuff, c);
    }
    return;
  }

  const char *s = str.data;
  const char *const str_end = str.data + str.size;

  while (s < str_end) {
    const char *start = s;
    while (s < str_end && (uint8_t)(*s) != K_SPECIAL && *s != NUL
           && *s != NL && !(crlf && *s == CAR)) {
      s++;
    }

    if (s > start) {
      if (need_redo) {
        kv_concat_len(redobuff.cur.body, start, (size_t)(s - start));
      }
      if (need_record) {
        kv_concat_len(recordbuff, start, (size_t)(s - start));
      }
    }

    if (s < str_end) {
      int c = (uint8_t)(*s++);
      if (crlf && c == CAR) {
        if (s < str_end && *s == NL) {
          s++;
        }
        c = NL;
      }
      if (need_redo) {
        sb_add_byte(&redobuff.cur.body, c);
      }
      if (need_record) {
        sb_add_byte(&recordbuff, c);
      }
    }
  }
}

/// Gets a paste stored by paste_store() from typeahead and repeats it.
void paste_repeat(int count)
{
  garray_T ga = GA_INIT(1, 32);
  bool aborted = false;

  no_mapping++;

  got_int = false;
  while (!aborted) {
    ga_grow(&ga, 32);
    uint8_t c1 = (uint8_t)vgetorpeek(true);
    if (c1 == K_SPECIAL) {
      c1 = (uint8_t)vgetorpeek(true);
      uint8_t c2 = (uint8_t)vgetorpeek(true);
      int c = TO_SPECIAL(c1, c2);
      if (c == K_PASTE_END) {
        break;
      } else if (c == K_ZERO) {
        ga_append(&ga, NUL);
      } else if (c == K_SPECIAL) {
        ga_append(&ga, K_SPECIAL);
      } else {
        ga_append(&ga, K_SPECIAL);
        ga_append(&ga, c1);
        ga_append(&ga, c2);
      }
    } else {
      ga_append(&ga, c1);
    }
    aborted = got_int;
  }

  no_mapping--;

  String str = cbuf_as_string(ga.ga_data, (size_t)ga.ga_len);
  Arena arena = ARENA_EMPTY;
  Error err = ERROR_INIT;
  for (int i = 0; !aborted && i < count; i++) {
    nvim_paste(LUA_INTERNAL_CALL, str, false, -1, &arena, &err);
    aborted = ERROR_SET(&err);
  }
  api_clear_error(&err);
  arena_mem_free(arena_finish(&arena));
  ga_clear(&ga);
}
