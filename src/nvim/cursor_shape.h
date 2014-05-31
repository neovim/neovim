#ifndef NVIM_CURSOR_SHAPE_H
#define NVIM_CURSOR_SHAPE_H

/*
 * struct to store values from 'guicursor' and 'mouseshape'
 */
/* Indexes in shape_table[] */
#define SHAPE_IDX_N     0       /* Normal mode */
#define SHAPE_IDX_V     1       /* Visual mode */
#define SHAPE_IDX_I     2       /* Insert mode */
#define SHAPE_IDX_R     3       /* Replace mode */
#define SHAPE_IDX_C     4       /* Command line Normal mode */
#define SHAPE_IDX_CI    5       /* Command line Insert mode */
#define SHAPE_IDX_CR    6       /* Command line Replace mode */
#define SHAPE_IDX_O     7       /* Operator-pending mode */
#define SHAPE_IDX_VE    8       /* Visual mode with 'selection' exclusive */
#define SHAPE_IDX_CLINE 9       /* On command line */
#define SHAPE_IDX_STATUS 10     /* A status line */
#define SHAPE_IDX_SDRAG 11      /* dragging a status line */
#define SHAPE_IDX_VSEP  12      /* A vertical separator line */
#define SHAPE_IDX_VDRAG 13      /* dragging a vertical separator line */
#define SHAPE_IDX_MORE  14      /* Hit-return or More */
#define SHAPE_IDX_MOREL 15      /* Hit-return or More in last line */
#define SHAPE_IDX_SM    16      /* showing matching paren */
#define SHAPE_IDX_COUNT 17

#define SHAPE_BLOCK     0       /* block cursor */
#define SHAPE_HOR       1       /* horizontal bar cursor */
#define SHAPE_VER       2       /* vertical bar cursor */

#define MSHAPE_NUMBERED 1000    /* offset for shapes identified by number */
#define MSHAPE_HIDE     1       /* hide mouse pointer */

#define SHAPE_MOUSE     1       /* used for mouse pointer shape */
#define SHAPE_CURSOR    2       /* used for text cursor shape */

typedef struct cursor_entry {
  int shape;                    /* one of the SHAPE_ defines */
  int mshape;                   /* one of the MSHAPE defines */
  int percentage;               /* percentage of cell for bar */
  long blinkwait;               /* blinking, wait time before blinking starts */
  long blinkon;                 /* blinking, on time */
  long blinkoff;                /* blinking, off time */
  int id;                       /* highlight group ID */
  int id_lm;                    /* highlight group ID for :lmap mode */
  char        *name;            /* mode name (fixed) */
  char used_for;                /* SHAPE_MOUSE and/or SHAPE_CURSOR */
} cursorentry_T;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "cursor_shape.h.generated.h"
#endif
#endif  // NVIM_CURSOR_SHAPE_H
