#pragma once

#include <stdint.h>

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/gettext_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/marktree_defs.h"
#include "nvim/types_defs.h"

/// Values for buflist_getfile()
enum getf_values {
  GETF_SETMARK = 0x01,  ///< set pcmark before jumping
  GETF_ALT     = 0x02,  ///< jumping to alternate file (not buf num)
  GETF_SWITCH  = 0x04,  ///< respect 'switchbuf' settings when jumping
};

// Return values of getfile()
enum getf_retvalues {
  GETFILE_ERROR       = 1,   ///< normal error
  GETFILE_NOT_WRITTEN = 2,   ///< "not written" error
  GETFILE_SAME_FILE   = 0,   ///< success, same file
  GETFILE_OPEN_OTHER  = -1,  ///< success, opened another file
  GETFILE_UNUSED      = 8,
};

/// Values for buflist_new() flags
enum bln_values {
  BLN_CURBUF = 1,   ///< May re-use curbuf for new buffer
  BLN_LISTED = 2,   ///< Put new buffer in buffer list
  BLN_DUMMY  = 4,   ///< Allocating dummy buffer
  BLN_NEW    = 8,   ///< create a new buffer
  BLN_NOOPT  = 16,  ///< Don't copy options to existing buffer
  // BLN_DUMMY_OK = 32,  // also find an existing dummy buffer
  // BLN_REUSE = 64,   // may re-use number from buf_reuse
  BLN_NOCURWIN = 128,  ///< buffer is not associated with curwin
};

/// Values for action argument for do_buffer_ext() and close_buffer()
enum dobuf_action_values {
  DOBUF_GOTO   = 0,  ///< go to specified buffer
  DOBUF_SPLIT  = 1,  ///< split window and go to specified buffer
  DOBUF_UNLOAD = 2,  ///< unload specified buffer(s)
  DOBUF_DEL    = 3,  ///< delete specified buffer(s) from buflist
  DOBUF_WIPE   = 4,  ///< delete specified buffer(s) really
};

/// Values for start argument for do_buffer_ext()
enum dobuf_start_values {
  DOBUF_CURRENT = 0,  ///< "count" buffer from current buffer
  DOBUF_FIRST   = 1,  ///< "count" buffer from first buffer
  DOBUF_LAST    = 2,  ///< "count" buffer from last buffer
  DOBUF_MOD     = 3,  ///< "count" mod. buffer from current buffer
};

/// Values for flags argument of do_buffer_ext()
enum dobuf_flags_value {
  DOBUF_FORCEIT  = 1,  ///< :cmd!
  DOBUF_SKIPHELP = 4,  ///< skip or keep help buffers depending on b_help of the
                       ///< starting buffer
};

/// flags for buf_freeall()
enum bfa_values {
  BFA_DEL          = 1,  ///< buffer is going to be deleted
  BFA_WIPE         = 2,  ///< buffer is going to be wiped out
  BFA_KEEP_UNDO    = 4,  ///< do not free undo information
  BFA_IGNORE_ABORT = 8,  ///< do not abort for aborting()
};

EXTERN char *msg_loclist INIT( = N_("[Location List]"));
EXTERN char *msg_qflist INIT( = N_("[Quickfix List]"));

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "buffer.h.generated.h"
# include "buffer.h.inline.generated.h"
#endif

/// Get b:changedtick value
///
/// Faster then querying b:.
///
/// @param[in]  buf  Buffer to get b:changedtick from.
static inline varnumber_T buf_get_changedtick(const buf_T *const buf)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_PURE
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return buf->changedtick_di.di_tv.vval.v_number;
}

static inline uint32_t buf_meta_total(const buf_T *b, MetaIndex m)
{
  return b->b_marktree->meta_root[m];
}
