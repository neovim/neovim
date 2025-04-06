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

typedef enum {
  kMTMetaInline,
  kMTMetaLines,
  kMTMetaSignHL,
  kMTMetaSignText,
  kMTMetaConcealLines,
  kMTMetaCount,  // sentinel, must be last
} MetaIndex;

#define kMTFilterSelect ((uint32_t)-1)

// a filter should be set to kMTFilterSelect for the selected kinds, zero otherwise
typedef const uint32_t *MetaFilter;

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

// part of mtnode_s which is only allocated for inner nodes:
// pointer to children as well as their meta counts
struct mtnode_inner_s {
  MTNode *i_ptr[2 * MT_BRANCH_FACTOR];
  uint32_t i_meta[2 * MT_BRANCH_FACTOR][kMTMetaCount];
};

struct mtnode_s {
  int32_t n;
  int16_t level;
  int16_t p_idx;  // index in parent
  Intersection intersect;
  MTNode *parent;
  MTKey key[2 * MT_BRANCH_FACTOR - 1];
  struct mtnode_inner_s s[];
};

typedef struct {
  MTNode *root;
  uint32_t meta_root[kMTMetaCount];
  size_t n_keys, n_nodes;
  PMap(uint64_t) id2node[1];
} MarkTree;
