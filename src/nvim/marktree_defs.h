#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/decoration_defs.h"
#include "nvim/map_defs.h"

enum {
  MT_MAX_DEPTH     = 20,
  MT_BRANCH_FACTOR = 10,
  // note max branch is actually 2*MT_BRANCH_FACTOR
  // and strictly this is ceil(log2(2*MT_BRANCH_FACTOR + 1))
  // as we need a pseudo-index for "right before this node"
  MT_LOG2_BRANCH   = 5,
};

typedef struct {
  int32_t row;
  int32_t col;
} MTPos;
#define MTPos(r, c) ((MTPos){ .row = (r), .col = (c) })

typedef struct mtnode_s MTNode;

typedef struct {
  MTPos pos;
  int lvl;
  MTNode *x;
  int i;
  struct {
    int oldcol;
    int i;
  } s[MT_MAX_DEPTH];

  size_t intersect_idx;
  MTPos intersect_pos;
  MTPos intersect_pos_x;
} MarkTreeIter;

#define marktree_itr_valid(itr) ((itr)->x != NULL)
// access raw key: flags in MT_FLAG_EXTERNAL_MASK and decor_data are safe to modify.
#define mt_itr_rawkey(itr) ((itr)->x->key[(itr)->i])

// Internal storage
//
// NB: actual marks have flags > 0, so we can use (row,col,0) pseudo-key for
// "space before (row,col)"
typedef struct {
  MTPos pos;
  uint32_t ns;
  uint32_t id;
  uint16_t flags;
  DecorInlineData decor_data;  // "ext" tag in flags
} MTKey;

typedef struct {
  MTKey start;
  MTPos end_pos;
  bool end_right_gravity;
} MTPair;

typedef kvec_withinit_t(uint64_t, 4) Intersection;

struct mtnode_s {
  int32_t n;
  int16_t level;
  int16_t p_idx;  // index in parent
  Intersection intersect;
  // TODO(bfredl): we could consider having a only-sometimes-valid
  // index into parent for faster "cached" lookup.
  MTNode *parent;
  MTKey key[2 * MT_BRANCH_FACTOR - 1];
  MTNode *ptr[];
};

typedef struct {
  MTNode *root;
  size_t n_keys, n_nodes;
  PMap(uint64_t) id2node[1];
} MarkTree;
