#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"

/// structure used to store one block of the stuff/redo/recording buffers
typedef struct buffblock {
  struct buffblock *b_next;  ///< pointer to next buffblock
  size_t b_strlen;      ///< length of b_str, excluding the NUL
  char b_str[1];        ///< contents (actually longer)
} buffblock_T;

/// header used for the stuff buffer and the redo buffer
typedef struct {
  buffblock_T bh_first;  ///< first (dummy) block of list
  buffblock_T *bh_curr;  ///< buffblock for appending
  size_t bh_index;       ///< index for reading
  size_t bh_space;       ///< space in bh_curr for appending
  bool bh_create_newblock;  ///< create a new block?
} buffheader_T;

typedef struct {
  buffheader_T sr_redobuff;
  buffheader_T sr_old_redobuff;
} save_redo_T;

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

/// Struct to hold the saved typeahead for save_typeahead().
typedef struct {
  typebuf_T save_typebuf;
  bool typebuf_valid;  ///< true when save_typebuf valid
  int old_char;
  int old_mod_mask;
  buffheader_T save_readbuf1;
  buffheader_T save_readbuf2;
  String save_inputbuf;
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
