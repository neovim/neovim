#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/types_defs.h"

/// Readahead ("stuff") buffer: consumable queue of keys in typeahead encoding (K_SPECIAL
/// escaped). add_buff() writes at `insert`, read_readbuf() consumes from `read`.
typedef struct {
  StringBuilder keys;  ///< Bytes; `[read, keys.size)` is unread.
  size_t read;         ///< Read position: consumed up to here. Reset (keeping capacity) on drain.
  size_t insert;       ///< Write position: `keys.size`, or the read position as of start_stuff()
                       ///< (newly stuffed keys drain before older readahead).
} StuffBuf;

/// Represents any command. Projection of (`cmdarg_T`, `oparg_T`), which are stack-transient.
///
/// Used two ways:
/// - Capture (prep_redo()): the command appends its own bytes to the redo body; only `regname`
///   and `count` are functional (the `["x][count]` prefix), the rest is CmdAtom metadata.
/// - Reconstruction (atom_from_spec()): a "non-prepped" command ("u", motions) has no body, so
///   atom_redo_keys() composes the keysequence fully from the spec.
typedef struct {
  long count;        ///< Effective count (0 = none)
  int regname;       ///< Register (`"x` prefix; 0 = none)
  int op;            ///< Operator char ('d'; 0 = none)
  int op_extra;      ///< Second operator char ("g~" => '~'; 0 = none)
  int motion_force;  ///< Forced motion type ('v'/'V'/CTRL-V; 0 = none)
  int cmd;           ///< Command/motion char ('J', 'p', 'f', K_LEFT, …; 0 = none)
  int cmd2;          ///< Command char 2 (for two-char cmds: "gJ" => 'J'; 0 = none)
  int cmdarg;        ///< Command operand ("fx" => 'x', "ma" => 'a'; 0 = none)
  StringBuilder body;  ///< Captured cmd "body": keys without the `["x][count]` "prefix", updated
                       ///< as the cmd executes (redo_append_xx); redo_keys() prepends the prefix.
                       ///< Empty in spec-only contexts (i.e. not a "redo" buf).
} CmdSpec;

/// Dot-repeat state: the pending change and the previous one.
/// Also the "save" shape for preserving it across user code (save_redobuff()).
typedef struct {
  CmdSpec cur;  ///< Pending change: "." replays it (start_redo()).
  CmdSpec old;  ///< Last-but-one change: an insert session's own prep moved the previous change
                ///< here (redo_new()); "i_CTRL-O ." replays it.
} RedoState;

/// Used for the typeahead buffer: typebuf.
typedef struct {
  uint8_t *tb_buf;      ///< buffer for typed characters
  uint8_t *tb_noremap;  ///< mapping flags for characters in tb_buf[]
  int tb_buflen;        ///< size of tb_buf[]
  int tb_off;           ///< current position in tb_buf[]
  int tb_len;           ///< number of valid bytes in tb_buf[]
  int tb_maplen;        ///< nr of mapped bytes in tb_buf[]
  int tb_silent;        ///< nr of silently mapped bytes in tb_buf[]
  int tb_no_abbr_cnt;   ///< nr of bytes without abbrev. in tb_buf[]
  int tb_change_cnt;    ///< nr of time tb_buf was changed; never zero
} typebuf_T;

/// Char put back by vungetc() (`c == -1`: none), with the read state restored when it is re-read:
/// a later input event must not leak its mod_mask/mouse coords into the ungot key.
typedef struct {
  int c;  ///< -1: none
  int mod_mask;
  int mouse_grid;
  int mouse_row;
  int mouse_col;
  bool stuffed;  ///< `KeyStuffed` when ungotten.
} UngotKey;

/// Struct to hold the saved typeahead for save_typeahead().
typedef struct {
  typebuf_T save_typebuf;
  UngotKey ungot;
  StuffBuf save_readbuf1;
  StuffBuf save_readbuf2;
} tasave_T;

/// Values for "noremap" argument of ins_typebuf()
///
/// Also used for map->m_noremap and menu->noremap[].
enum RemapValues {
  REMAP_YES = 0,      ///< Allow remapping.
  REMAP_NONE = -1,    ///< No remapping.
  REMAP_SCRIPT = -2,  ///< Remap script-local mappings only.
  REMAP_SKIP = -3,    ///< No remapping for first char.
};
