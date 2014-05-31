#ifndef NVIM_POS_H
#define NVIM_POS_H

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
