#ifndef NVIM_MARK_H
#define NVIM_MARK_H

#include "nvim/buffer_defs.h"
#include "nvim/func_attr.h"
#include "nvim/mark_defs.h"
#include "nvim/pos.h"

static inline bool lt(pos_T, pos_T) REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;
static inline bool equalpos(pos_T, pos_T) REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;
static inline bool ltoreq(pos_T, pos_T) REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;
static inline void clearpos(pos_T *) REAL_FATTR_ALWAYS_INLINE;

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
