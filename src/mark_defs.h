#ifndef NEOVIM_MARK_DEFS_H
#define NEOVIM_MARK_DEFS_H

#include "pos.h"

/*
 * marks: positions in a file
 * (a normal mark is a lnum/col pair, the same as a file position)
 */

/* (Note: for EBCDIC there are more than 26, because there are gaps in the
 * alphabet coding.  To minimize changes to the code, I decided to just
 * increase the number of possible marks. */
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

#endif // NEOVIM_MARK_DEFS_H
