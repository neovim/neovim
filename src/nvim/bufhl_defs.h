#ifndef NVIM_BUFHL_DEFS_H
#define NVIM_BUFHL_DEFS_H

#include "nvim/pos.h"
#include "nvim/lib/kvec.h"
#include "nvim/lib/kbtree.h"

// bufhl: buffer specific highlighting

typedef struct {
  int src_id;
  int hl_id;  // highlight group
  colnr_T start;  // first column to highlight
  colnr_T stop;  // last column to highlight
} BufhlItem;

typedef kvec_t(BufhlItem) BufhlItemVec;

typedef struct {
  linenr_T line;
  BufhlItemVec items;
} BufhlLine;
#define BUFHLLINE_INIT(l) { l, KV_INITIAL_VALUE }

typedef struct {
  BufhlItemVec entries;
  int current;
  colnr_T valid_to;
} BufhlLineInfo;

#define BUFHL_CMP(a, b) ((int)(((a)->line - (b)->line)))
KBTREE_INIT(bufhl, BufhlLine *, BUFHL_CMP, 10)  // -V512
typedef kbtree_t(bufhl) BufhlInfo;
#endif  // NVIM_BUFHL_DEFS_H
