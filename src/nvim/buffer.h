#ifndef NVIM_BUFFER_H
#define NVIM_BUFFER_H

#include "nvim/vim.h"
#include "nvim/window.h"
#include "nvim/pos.h"  // for linenr_T
#include "nvim/ex_cmds_defs.h"  // for exarg_T
#include "nvim/screen.h"  // for StlClickRecord
#include "nvim/func_attr.h"
#include "nvim/eval.h"
#include "nvim/macros.h"

// Values for buflist_getfile()
enum getf_values {
  GETF_SETMARK = 0x01, // set pcmark before jumping
  GETF_ALT     = 0x02, // jumping to alternate file (not buf num)
  GETF_SWITCH  = 0x04, // respect 'switchbuf' settings when jumping
};

// Return values of getfile()
enum getf_retvalues {
  GETFILE_ERROR       = 1,    // normal error
  GETFILE_NOT_WRITTEN = 2,    // "not written" error
  GETFILE_SAME_FILE   = 0,    // success, same file
  GETFILE_OPEN_OTHER  = -1,   // success, opened another file
  GETFILE_UNUSED      = 8
};

// Values for buflist_new() flags
enum bln_values {
  BLN_CURBUF = 1,   // May re-use curbuf for new buffer
  BLN_LISTED = 2,   // Put new buffer in buffer list
  BLN_DUMMY  = 4,   // Allocating dummy buffer
  BLN_NEW    = 8,   // create a new buffer
  BLN_NOOPT  = 16,  // Don't copy options to existing buffer
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

// Find a window that contains "buf" and switch to it.
// If there is no such window, use the current window and change "curbuf".
// Caller must initialize save_curbuf to NULL.
// restore_win_for_buf() MUST be called later!
static inline void switch_to_win_for_buf(buf_T *buf,
                                         win_T **save_curwinp,
                                         tabpage_T **save_curtabp,
                                         bufref_T *save_curbuf)
{
  win_T *wp;
  tabpage_T *tp;

  if (!find_win_for_buf(buf, &wp, &tp)
      || switch_win(save_curwinp, save_curtabp, wp, tp, true) == FAIL) {
    switch_buffer(save_curbuf, buf);
  }
}

static inline void restore_win_for_buf(win_T *save_curwin,
                                       tabpage_T *save_curtab,
                                       bufref_T *save_curbuf)
{
  if (save_curbuf->br_buf == NULL) {
    restore_win(save_curwin, save_curtab, true);
  } else {
    restore_buffer(save_curbuf);
  }
}

static inline void buf_set_changedtick(buf_T *const buf,
                                       const varnumber_T changedtick)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_ALWAYS_INLINE;

/// Set b:changedtick, also checking b: for consistency in debug build
///
/// @param[out]  buf  Buffer to set changedtick in.
/// @param[in]  changedtick  New value.
static inline void buf_set_changedtick(buf_T *const buf,
                                       const varnumber_T changedtick)
{
#ifndef NDEBUG
  dictitem_T *const changedtick_di = tv_dict_find(
      buf->b_vars, S_LEN("changedtick"));
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
}

static inline varnumber_T buf_get_changedtick(const buf_T *const buf)
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

static inline void buf_inc_changedtick(buf_T *const buf)
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

#define WITH_BUFFER(b, code) \
  do { \
    win_T *save_curwin = NULL; \
    tabpage_T *save_curtab = NULL; \
    bufref_T save_curbuf = { NULL, 0, 0 }; \
    switch_to_win_for_buf(b, &save_curwin, &save_curtab, &save_curbuf); \
    code; \
    restore_win_for_buf(save_curwin, save_curtab, &save_curbuf); \
  } while (0)


#endif  // NVIM_BUFFER_H
