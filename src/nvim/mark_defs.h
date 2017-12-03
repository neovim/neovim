#ifndef NVIM_MARK_DEFS_H
#define NVIM_MARK_DEFS_H

#include "nvim/pos.h"
#include "nvim/os/time.h"
#include "nvim/eval/typval.h"

/*
 * marks: positions in a file
 * (a normal mark is a lnum/col pair, the same as a file position)
 */

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

/// Maximum number of marks in jump list
#define JUMPLISTSIZE    100

/// Maximum number of tags in tag stack
#define TAGSTACKSIZE    20

/// Structure defining single local mark
typedef struct filemark {
  pos_T mark;           ///< Cursor position.
  int fnum;             ///< File number.
  Timestamp timestamp;  ///< Time when this mark was last set.
  dict_T *additional_data;  ///< Additional data from ShaDa file.
} fmark_T;

/// Structure defining extended mark (mark with file name attached)
typedef struct xfilemark {
  fmark_T fmark;       ///< Actual mark.
  char_u      *fname;  ///< File name, used when fnum == 0.
} xfmark_T;

#endif // NVIM_MARK_DEFS_H
