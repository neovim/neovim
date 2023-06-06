#ifndef NVIM_BUFFER_H
#define NVIM_BUFFER_H

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>

#include "nvim/buffer_defs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/func_attr.h"
#include "nvim/grid_defs.h"
#include "nvim/macros.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/pos.h"

// Values for buflist_getfile()
enum getf_values {
  GETF_SETMARK = 0x01,  // set pcmark before jumping
  GETF_ALT     = 0x02,  // jumping to alternate file (not buf num)
  GETF_SWITCH  = 0x04,  // respect 'switchbuf' settings when jumping
};

// Return values of getfile()
enum getf_retvalues {
  GETFILE_ERROR       = 1,    // normal error
  GETFILE_NOT_WRITTEN = 2,    // "not written" error
  GETFILE_SAME_FILE   = 0,    // success, same file
  GETFILE_OPEN_OTHER  = (-1),  // success, opened another file
  GETFILE_UNUSED      = 8,
};

// Values for buflist_new() flags
enum bln_values {
  BLN_CURBUF = 1,   // May re-use curbuf for new buffer
  BLN_LISTED = 2,   // Put new buffer in buffer list
  BLN_DUMMY  = 4,   // Allocating dummy buffer
  BLN_NEW    = 8,   // create a new buffer
  BLN_NOOPT  = 16,  // Don't copy options to existing buffer
  // BLN_DUMMY_OK = 32,  // also find an existing dummy buffer
  // BLN_REUSE = 64,   // may re-use number from buf_reuse
  BLN_NOCURWIN = 128,  // buffer is not associated with curwin
};

// Values for action argument for do_buffer()
enum dobuf_action_values {
  DOBUF_GOTO   = 0,  // go to specified buffer
  DOBUF_SPLIT  = 1,  // split window and go to specified buffer
  DOBUF_UNLOAD = 2,  // unload specified buffer(s)
  DOBUF_DEL    = 3,  // delete specified buffer(s) from buflist
  DOBUF_WIPE   = 4,  // delete specified buffer(s) really
};

// Values for start argument for do_buffer()
enum dobuf_start_values {
  DOBUF_CURRENT = 0,  // "count" buffer from current buffer
  DOBUF_FIRST   = 1,  // "count" buffer from first buffer
  DOBUF_LAST    = 2,  // "count" buffer from last buffer
  DOBUF_MOD     = 3,  // "count" mod. buffer from current buffer
};

// flags for buf_freeall()
enum bfa_values {
  BFA_DEL          = 1,  // buffer is going to be deleted
  BFA_WIPE         = 2,  // buffer is going to be wiped out
  BFA_KEEP_UNDO    = 4,  // do not free undo information
  BFA_IGNORE_ABORT = 8,  // do not abort for aborting()
};

EXTERN char *msg_loclist INIT(= N_("[Location List]"));
EXTERN char *msg_qflist INIT(= N_("[Quickfix List]"));

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "buffer.h.generated.h"
#endif

static inline void buf_set_changedtick(buf_T *buf, varnumber_T changedtick)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_ALWAYS_INLINE;

/// Set b:changedtick, also checking b: for consistency in debug build
///
/// @param[out]  buf  Buffer to set changedtick in.
/// @param[in]  changedtick  New value.
static inline void buf_set_changedtick(buf_T *const buf, const varnumber_T changedtick)
{
  typval_T old_val = buf->changedtick_di.di_tv;

#ifndef NDEBUG
  dictitem_T *const changedtick_di = tv_dict_find(buf->b_vars, S_LEN("changedtick"));
  assert(changedtick_di != NULL);
  assert(changedtick_di->di_tv.v_type == VAR_NUMBER);
  assert(changedtick_di->di_tv.v_lock == VAR_FIXED);
  // For some reason formatc does not like the below.
# ifndef UNIT_TESTING_LUA_PREPROCESSING
  assert(changedtick_di->di_flags == (DI_FLAGS_RO|DI_FLAGS_FIX));
# endif
  assert(changedtick_di == (dictitem_T *)&buf->changedtick_di);
#endif
  buf->changedtick_di.di_tv.vval.v_number = changedtick;

  if (tv_dict_is_watched(buf->b_vars)) {
    tv_dict_watcher_notify(buf->b_vars,
                           (char *)buf->changedtick_di.di_key,
                           &buf->changedtick_di.di_tv,
                           &old_val);
  }
}

static inline varnumber_T buf_get_changedtick(const buf_T *buf)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_ALWAYS_INLINE REAL_FATTR_PURE
  REAL_FATTR_WARN_UNUSED_RESULT;

/// Get b:changedtick value
///
/// Faster then querying b:.
///
/// @param[in]  buf  Buffer to get b:changedtick from.
static inline varnumber_T buf_get_changedtick(const buf_T *const buf)
{
  return buf->changedtick_di.di_tv.vval.v_number;
}

static inline void buf_inc_changedtick(buf_T *buf)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_ALWAYS_INLINE;

/// Increment b:changedtick value
///
/// Also checks b: for consistency in case of debug build.
///
/// @param[in,out]  buf  Buffer to increment value in.
static inline void buf_inc_changedtick(buf_T *const buf)
{
  buf_set_changedtick(buf, buf_get_changedtick(buf) + 1);
}

static inline bool buf_is_empty(buf_T *buf)
{
  return buf->b_ml.ml_line_count == 1
         && *ml_get_buf(buf, (linenr_T)1, false) == '\0';
}

#endif  // NVIM_BUFFER_H
