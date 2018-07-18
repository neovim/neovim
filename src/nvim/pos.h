#ifndef NVIM_POS_H
#define NVIM_POS_H

typedef long linenr_T;         // line number type
/// Format used to print values which have linenr_T type
#define PRIdLINENR "ld"

/// Column number type
typedef int colnr_T;
/// Format used to print values which have colnr_T type
#define PRIdCOLNR "d"

/// Maximal (invalid) line number
enum { MAXLNUM = 0x7fffffff };
/// Maximal column number, 31 bits
enum { MAXCOL = 0x7fffffff };

/*
 * position in file or buffer
 */
typedef struct {
  linenr_T lnum;        /* line number */
  colnr_T col;          /* column number */
  colnr_T coladd;
} pos_T;

# define INIT_POS_T(l, c, ca) {l, c, ca}

/*
 * Same, but without coladd.
 */
typedef struct {
  linenr_T lnum;        /* line number */
  colnr_T col;          /* column number */
} lpos_T;

#endif  // NVIM_POS_H
