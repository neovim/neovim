#ifndef NVIM_POS_H
#define NVIM_POS_H

typedef long linenr_T;         // line number type
typedef int colnr_T;           // column number type

#define MAXLNUM (0x7fffffffL)  // maximum (invalid) line number
#define MAXCOL  (0x7fffffffL)  // maximum column number, 31 bits

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
