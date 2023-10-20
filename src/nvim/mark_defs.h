#ifndef NVIM_MARK_DEFS_H
#define NVIM_MARK_DEFS_H

#include "nvim/eval/typval_defs.h"
#include "nvim/os/time.h"
#include "nvim/pos.h"

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

/// Global marks (marks with file number or name)
EXTERN xfmark_T namedfm[NGLOBALMARKS] INIT( = { 0 });

#endif  // NVIM_MARK_DEFS_H
