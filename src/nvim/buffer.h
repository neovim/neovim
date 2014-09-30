#ifndef NVIM_BUFFER_H
#define NVIM_BUFFER_H

#include "nvim/pos.h"  // for linenr_T
#include "nvim/ex_cmds_defs.h"  // for exarg_T

// Values for buflist_getfile()
enum getf_values {
  GETF_SETMARK = 0x01, // set pcmark before jumping
  GETF_ALT     = 0x02, // jumping to alternate file (not buf num)
  GETF_SWITCH  = 0x04, // respect 'switchbuf' settings when jumping
};

// Values for buflist_new() flags
enum bln_values {
  BLN_CURBUF = 1, // May re-use curbuf for new buffer
  BLN_LISTED = 2, // Put new buffer in buffer list
  BLN_DUMMY  = 4, // Allocating dummy buffer
};

// Values for action argument for do_buffer()
enum dobuf_action_values {
  DOBUF_GOTO   = 0, // go to specified buffer
  DOBUF_SPLIT  = 1, // split window and go to specified buffer
  DOBUF_UNLOAD = 2, // unload specified buffer(s)
  DOBUF_DEL    = 3, // delete specified buffer(s) from buflist
  DOBUF_WIPE   = 4, // delete specified buffer(s) really
};

// Values for start argument for do_buffer()
enum dobuf_start_values {
  DOBUF_CURRENT = 0, // "count" buffer from current buffer
  DOBUF_FIRST   = 1, // "count" buffer from first buffer
  DOBUF_LAST    = 2, // "count" buffer from last buffer
  DOBUF_MOD     = 3, // "count" mod. buffer from current buffer
};

// flags for buf_freeall()
enum bfa_values {
  BFA_DEL       = 1, // buffer is going to be deleted
  BFA_WIPE      = 2, // buffer is going to be wiped out
  BFA_KEEP_UNDO = 4, // do not free undo information
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "buffer.h.generated.h"
#endif
#endif  // NVIM_BUFFER_H
