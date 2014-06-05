#ifndef NVIM_MARK_DEFS_H
#define NVIM_MARK_DEFS_H

#include "nvim/pos.h"

/*
 * marks: positions in a file
 * (a normal mark is a lnum/col pair, the same as a file position)
 */

#define NMARKS          ('z' - 'a' + 1) /* max. # of named marks */
#define JUMPLISTSIZE    100             /* max. # of marks in jump list */
#define TAGSTACKSIZE    20              /* max. # of tags in tag stack */

typedef struct filemark {
  pos_T mark;                   /* cursor position */
  int fnum;                     /* file number */
} fmark_T;

/* Xtended file mark: also has a file name */
typedef struct xfilemark {
  fmark_T fmark;
  char_u      *fname;           /* file name, used when fnum == 0 */
} xfmark_T;

#endif // NVIM_MARK_DEFS_H
