#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/types_defs.h"

/// structure used to store one block of the stuff/redo/recording buffers
typedef struct buffblock {
  struct buffblock *b_next;  ///< pointer to next buffblock
  size_t b_strlen;      ///< length of b_str, excluding the NUL
  char b_str[1];        ///< contents (actually longer)
} buffblock_T;

/// Consumable byte queue (linked list of buffblock_T) of keys in typeahead encoding (K_SPECIAL
/// escaped). Appends (add_buff()) fill the spare space of the last block, allocating a new block
/// when full; reads consume from the front (read_readbuf()).
///
/// Note: Append-only key accumulation (RedoBuf, macro recording) uses StringBuilder instead.
typedef struct {
  buffblock_T bh_first;  ///< empty sentinel: bh_first.b_next holds the first content
  buffblock_T *bh_curr;  ///< buffblock for appending
  size_t bh_index;       ///< read position in the first block's b_str
  size_t bh_space;       ///< space in bh_curr for appending
  bool bh_create_newblock;  ///< create a new block?
} buffheader_T;

#define BUFFHEADER_INIT { { NULL, 0, { NUL } }, NULL, 0, 0, false }

/// Structured decomposition of a normal-mode command, used two ways:
/// - Capture (prep_redo()): the command appends its own bytes to the redo body; only `regname`
///   and `count` are functional (the `["x][count]` prefix), the rest is CmdAtom metadata.
/// - Reconstruction (atom_from_spec()): a command that never preps ("u", motions) has no body, so
///   atom_compose_keys() composes the whole keysequence from the spec.
typedef struct {
  long count;        ///< Effective count (0 = none)
  int regname;       ///< Register (`"x` prefix; 0 = none)
  int op;            ///< Operator char ('d'; 0 = none)
  int op_extra;      ///< Second operator char ("g~" => '~'; 0 = none)
  int motion_force;  ///< Forced motion type ('v'/'V'/CTRL-V; 0 = none)
  int cmd;           ///< Command/motion char ('J', 'p', 'f', K_LEFT, …; 0 = none)
  int cmd2;          ///< Second char of a two-char command name ("gJ" => 'J'; 0 = none)
  int arg;           ///< Operand ("fx" => 'x', "ma" => 'a'; 0 = none)
} CmdSpec;

/// The last change: structured fields plus the command body, filled as the command executes
/// (redo_append_xx()). "." (start_redo()) composes the `["x][count]` prefix around the body.
typedef struct {
  CmdSpec spec;        ///< Structured command fields.
  StringBuilder keys;  ///< Cmd body. Perf: StringBuilder (not buffheader_T) => fewer allocs/copies.
} RedoBuf;

/// RedoBuf (dot-repeat) state: the pending change atom and the previous one.
/// Also the "save" shape for preserving it across user code (save_redobuff()).
typedef struct {
  RedoBuf cur;  ///< Pending change: "." replays it (start_redo()).
  RedoBuf old;  ///< Last-but-one change: an insert session's own prep moved the previous change
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
  buffheader_T save_readbuf1;
  buffheader_T save_readbuf2;
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
