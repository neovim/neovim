#ifndef NVIM_MARK_H
#define NVIM_MARK_H

#include "nvim/macros.h"
#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/func_attr.h"
#include "nvim/mark_defs.h"
#include "nvim/memory.h"
#include "nvim/pos.h"
#include "nvim/os/time.h"
#include "nvim/ex_cmds_defs.h" // for exarg_T

/// Set fmark using given value
#define SET_FMARK(fmarkp_, mark_, fnum_) \
    do { \
      fmark_T *const fmarkp__ = fmarkp_; \
      fmarkp__->mark = mark_; \
      fmarkp__->fnum = fnum_; \
      fmarkp__->timestamp = os_time(); \
      fmarkp__->additional_data = NULL; \
    } while (0)

/// Free and set fmark using given value
#define RESET_FMARK(fmarkp_, mark_, fnum_) \
    do { \
      fmark_T *const fmarkp___ = fmarkp_; \
      free_fmark(*fmarkp___); \
      SET_FMARK(fmarkp___, mark_, fnum_); \
    } while (0)

/// Clear given fmark
#define CLEAR_FMARK(fmarkp_) \
    RESET_FMARK(fmarkp_, ((pos_T) { 0, 0, 0 }), 0)

/// Set given extended mark (regular mark + file name)
#define SET_XFMARK(xfmarkp_, mark_, fnum_, fname_) \
    do { \
      xfmark_T *const xfmarkp__ = xfmarkp_; \
      xfmarkp__->fname = fname_; \
      SET_FMARK(&(xfmarkp__->fmark), mark_, fnum_); \
    } while (0)

/// Free and set given extended mark (regular mark + file name)
#define RESET_XFMARK(xfmarkp_, mark_, fnum_, fname_) \
    do { \
      xfmark_T *const xfmarkp__ = xfmarkp_; \
      free_xfmark(*xfmarkp__); \
      xfmarkp__->fname = fname_; \
      SET_FMARK(&(xfmarkp__->fmark), mark_, fnum_); \
    } while (0)

/// Convert mark name to the offset
static inline int mark_global_index(const char name)
  FUNC_ATTR_CONST
{
  return (ASCII_ISUPPER(name)
          ? (name - 'A')
          : (ascii_isdigit(name)
             ? (NMARKS + (name - '0'))
             : -1));
}

/// Convert local mark name to the offset
static inline int mark_local_index(const char name)
  FUNC_ATTR_CONST
{
  return (ASCII_ISLOWER(name)
          ? (name - 'a')
          : (name == '"'
             ? NMARKS
             : (name == '^'
                ? NMARKS + 1
                : (name == '.'
                   ? NMARKS + 2
                   : -1))));
}

static inline bool lt(pos_T, pos_T) REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;
static inline bool equalpos(pos_T, pos_T)
  REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;
static inline bool ltoreq(pos_T, pos_T)
  REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;
static inline void clearpos(pos_T *)
  REAL_FATTR_ALWAYS_INLINE;

/// Return true if position a is before (less than) position b.
static inline bool lt(pos_T a, pos_T b)
{
  if (a.lnum != b.lnum) {
    return a.lnum < b.lnum;
  } else if (a.col != b.col) {
    return a.col < b.col;
  } else {
    return a.coladd < b.coladd;
  }
}

/// Return true if position a and b are equal.
static inline bool equalpos(pos_T a, pos_T b)
{
  return (a.lnum == b.lnum) && (a.col == b.col) && (a.coladd == b.coladd);
}

/// Return true if position a is less than or equal to b.
static inline bool ltoreq(pos_T a, pos_T b)
{
  return lt(a, b) || equalpos(a, b);
}

/// Clear the pos_T structure pointed to by a.
static inline void clearpos(pos_T *a)
{
  a->lnum = 0;
  a->col = 0;
  a->coladd = 0;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark.h.generated.h"
#endif
#endif  // NVIM_MARK_H
