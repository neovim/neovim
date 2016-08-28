#ifndef NVIM_BUFHL_DEFS_H
#define NVIM_BUFHL_DEFS_H

#include "nvim/pos.h"
#include "nvim/lib/kvec.h"
#include "nvim/lib/kbtree.h"
// bufhl: buffer specific highlighting

struct bufhl_hl_item
{
  int src_id;
  int hl_id;  // highlight group
  colnr_T start;  // first column to highlight
  colnr_T stop;  // last column to highlight
};
typedef struct bufhl_hl_item bufhl_hl_item_T;

typedef kvec_t(struct bufhl_hl_item) bufhl_vec_T;

typedef struct {
  linenr_T line;
  bufhl_vec_T items;
} BufhlLine;
#define BUFHLLINE_INIT(l) { l, KV_INITIAL_VALUE }

typedef struct {
  bufhl_vec_T entries;
  int current;
  colnr_T valid_to;
} bufhl_lineinfo_T;

#define BUFHL_CMP(a, b) ((int)(((a)->line - (b)->line)))
KBTREE_INIT(bufhl, BufhlLine *, BUFHL_CMP, 10)
typedef kbtree_t(bufhl) bufhl_info_T;
#endif  // NVIM_BUFHL_DEFS_H
