#ifndef NVIM_MARKTREE_H
#define NVIM_MARKTREE_H

#include <stdint.h>
#include "nvim/pos.h"
#include "nvim/map.h"
#include "nvim/garray.h"
#include "nvim/lib/kvec.h"

// only for debug functions:
#include "api/private/defs.h"

#define MT_MAX_DEPTH 20
#define MT_BRANCH_FACTOR 10

typedef struct {
  int32_t row;
  int32_t col;
} mtpos_t;
#define mtpos_t(r, c) ((mtpos_t){ .row = (r), .col = (c) })

typedef struct {
  int32_t row;
  int32_t col;
  uint64_t id;
  bool right_gravity;
} mtmark_t;

typedef struct mtnode_s mtnode_t;
typedef struct {
  int oldcol;
  int i;
} iterstate_t;

typedef struct {
  mtpos_t pos;
  int lvl;
  mtnode_t *x;
  int i;
  iterstate_t s[MT_MAX_DEPTH];

  size_t intersect_idx;
  mtpos_t intersect_pos;
} MarkTreeIter;

#define marktree_itr_valid(itr) ((itr)->x != NULL)


// Internal storage
//
// NB: actual marks have id > 0, so we can use (row,col,0) pseudo-key for
// "space before (row,col)"
typedef struct {
  mtpos_t pos;
  uint64_t id;
} mtkey_t;
#define mtkey_t(p, i) ((mtkey_t){ .pos = (p), .id = (i) })

struct mtnode_s {
  int32_t n;
  int32_t level;
  kvec_withinit_t(uint64_t, 4) intersect;
  // TODO(bfredl): we could consider having a only-sometimes-valid
  // index into parent for faster "chached" lookup.
  mtnode_t *parent;
  mtkey_t key[2 * MT_BRANCH_FACTOR - 1];
  mtnode_t *ptr[];
};

typedef struct {
  mtnode_t *root;
  size_t n_keys, n_nodes;
  uint64_t next_id;
  // TODO(bfredl): the pointer to node could be part of the larger
  // Map(uint64_t, ExtmarkItem) essentially;
  PMap(uint64_t) *id2node;
} MarkTree;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "marktree.h.generated.h"
#endif

#define MARKTREE_PAIRED_FLAG (((uint64_t)1) << 1)
#define MARKTREE_END_FLAG (((uint64_t)1) << 0)

#endif  // NVIM_MARKTREE_H
