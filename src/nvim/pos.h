#ifndef NVIM_POS_H
#define NVIM_POS_H

// for INT_MAX, LONG_MAX et al.
#include <limits.h>

typedef long linenr_T;         // line number type
/// Format used to print values which have linenr_T type
#define PRIdLINENR "ld"

/// Column number type
typedef int colnr_T;
/// Format used to print values which have colnr_T type
#define PRIdCOLNR "d"

/// Maximal (invalid) line number
enum { MAXLNUM = 0x7fffffff };
/// Maximal column number
enum { MAXCOL = INT_MAX };
// Minimum line number
enum { MINLNUM = 1 };
// minimum column number
enum { MINCOL = 1 };

/*
 * position in file or buffer
 */
typedef struct {
  linenr_T lnum;        /* line number */
  colnr_T col;          /* column number */
  colnr_T coladd;
} pos_T;


/*
 * Same, but without coladd.
 */
typedef struct {
  linenr_T lnum;        /* line number */
  colnr_T col;          /* column number */
} lpos_T;

#endif  // NVIM_POS_H
