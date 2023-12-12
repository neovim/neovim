#pragma once

#include "nvim/eval/typval_defs.h"
#include "nvim/os/time_defs.h"
#include "nvim/pos_defs.h"

// marks: positions in a file
// (a normal mark is a lnum/col pair, the same as a file position)

/// Flags for outcomes when moving to a mark.
typedef enum {
  kMarkMoveSuccess = 1,  ///< Successful move.
  kMarkMoveFailed = 2,  ///< Failed to move.
  kMarkSwitchedBuf = 4,  ///< Switched curbuf.
  kMarkChangedCol = 8,   ///< Changed the cursor col.
  kMarkChangedLine = 16,  ///< Changed the cursor line.
  kMarkChangedCursor = 32,  ///< Changed the cursor.
  kMarkChangedView = 64,  ///< Changed the view.
} MarkMoveRes;

/// Flags to configure the movement to a mark.
typedef enum {
  kMarkBeginLine = 1,  ///< Move cursor to the beginning of the line.
  kMarkContext = 2,  ///< Leave context mark when moving the cursor.
  KMarkNoContext = 4,  ///< Don't leave a context mark.
  kMarkSetView = 8,  ///< Set the mark view after moving
  kMarkJumpList = 16,  ///< Special case, don't leave context mark when switching buffer
} MarkMove;

/// Options when getting a mark
typedef enum {
  kMarkBufLocal,  ///< Only return marks that belong to the buffer.
  kMarkAll,  ///< Return all types of marks.
  kMarkAllNoResolve,  ///< Return all types of marks but don't resolve fnum (global marks).
} MarkGet;

/// Number of possible numbered global marks
#define EXTRA_MARKS     ('9' - '0' + 1)

/// Maximum possible number of letter marks
#define NMARKS          ('z' - 'a' + 1)

/// Total possible number of global marks
#define NGLOBALMARKS    (NMARKS + EXTRA_MARKS)

/// Total possible number of local marks
///
/// That are uppercase marks plus '"', '^' and '.'. There are other local marks,
/// but they are not saved in ShaDa files.
#define NLOCALMARKS     (NMARKS + 3)

/// Max value of local mark
#define NMARK_LOCAL_MAX 126  // Index of '~'

/// Maximum number of marks in jump list
#define JUMPLISTSIZE    100

/// Maximum number of tags in tag stack
#define TAGSTACKSIZE    20

/// Represents view in which the mark was created
typedef struct fmarkv {
  linenr_T topline_offset;  ///< Amount of lines from the mark lnum to the top of the window.
                            ///< Use MAXLNUM to indicate that the mark does not have a view.
} fmarkv_T;

#define INIT_FMARKV { MAXLNUM }

/// Structure defining single local mark
typedef struct filemark {
  pos_T mark;           ///< Cursor position.
  int fnum;             ///< File number.
  Timestamp timestamp;  ///< Time when this mark was last set.
  fmarkv_T view;  ///< View the mark was created on
  dict_T *additional_data;  ///< Additional data from ShaDa file.
} fmark_T;

#define INIT_FMARK { { 0, 0, 0 }, 0, 0, INIT_FMARKV, NULL }

/// Structure defining extended mark (mark with file name attached)
typedef struct xfilemark {
  fmark_T fmark;       ///< Actual mark.
  char *fname;  ///< File name, used when fnum == 0.
} xfmark_T;

#define INIT_XFMARK { INIT_FMARK, NULL }

/// Set fmark using given value
#define SET_FMARK(fmarkp_, mark_, fnum_, view_) \
  do { \
    fmark_T *const fmarkp__ = fmarkp_; \
    fmarkp__->mark = mark_; \
    fmarkp__->fnum = fnum_; \
    fmarkp__->timestamp = os_time(); \
    fmarkp__->view = view_; \
    fmarkp__->additional_data = NULL; \
  } while (0)

/// Free and set fmark using given value
#define RESET_FMARK(fmarkp_, mark_, fnum_, view_) \
  do { \
    fmark_T *const fmarkp___ = fmarkp_; \
    free_fmark(*fmarkp___); \
    SET_FMARK(fmarkp___, mark_, fnum_, view_); \
  } while (0)

/// Set given extended mark (regular mark + file name)
#define SET_XFMARK(xfmarkp_, mark_, fnum_, view_, fname_) \
  do { \
    xfmark_T *const xfmarkp__ = xfmarkp_; \
    xfmarkp__->fname = fname_; \
    SET_FMARK(&(xfmarkp__->fmark), mark_, fnum_, view_); \
  } while (0)

/// Free and set given extended mark (regular mark + file name)
#define RESET_XFMARK(xfmarkp_, mark_, fnum_, view_, fname_) \
  do { \
    xfmark_T *const xfmarkp__ = xfmarkp_; \
    free_xfmark(*xfmarkp__); \
    xfmarkp__->fname = fname_; \
    SET_FMARK(&(xfmarkp__->fmark), mark_, fnum_, view_); \
  } while (0)

static inline bool lt(pos_T a, pos_T b)
  REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;
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

static inline bool equalpos(pos_T a, pos_T b)
  REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;
/// Return true if position a and b are equal.
static inline bool equalpos(pos_T a, pos_T b)
{
  return (a.lnum == b.lnum) && (a.col == b.col) && (a.coladd == b.coladd);
}

static inline bool ltoreq(pos_T a, pos_T b)
  REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;
/// Return true if position a is less than or equal to b.
static inline bool ltoreq(pos_T a, pos_T b)
{
  return lt(a, b) || equalpos(a, b);
}

static inline void clearpos(pos_T *a)
  REAL_FATTR_ALWAYS_INLINE;
/// Clear the pos_T structure pointed to by a.
static inline void clearpos(pos_T *a)
{
  a->lnum = 0;
  a->col = 0;
  a->coladd = 0;
}
