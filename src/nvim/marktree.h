#ifndef NVIM_MARKTREE_H
#define NVIM_MARKTREE_H

#include <stdint.h>
#include "nvim/pos.h"
#include "nvim/map.h"
#include "nvim/garray.h"

#define MT_MAX_DEPTH 20
#define MT_BRANCH_FACTOR 10

typedef struct {
  int32_t row;
  int32_t col;
} mtpos_t;

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
  mtnode_t *node;
  int i;
  iterstate_t s[MT_MAX_DEPTH];
} MarkTreeIter;


// Internal storage
//
// NB: actual marks have id > 0, so we can use (row,col,0) pseudo-key for
// "space before (row,col)"
typedef struct {
  mtpos_t pos;
  uint64_t id;
} mtkey_t;

struct mtnode_s {
  int32_t n;
  int32_t level;
  // TODO(bfredl): we could consider having a only-sometimes-valid
  // index into parent for faster "cached" lookup.
  mtnode_t *parent;
  mtkey_t key[2 * MT_BRANCH_FACTOR - 1];
  mtnode_t *ptr[];
};

// TODO(bfredl): the iterator is pretty much everpresent, make it part of the
// tree struct itself?
typedef struct {
  mtnode_t *root;
  size_t n_keys, n_nodes;
  uint64_t next_id;
  // TODO(bfredl): the pointer to node could be part of the larger
  // Map(uint64_t, ExtmarkItem) essentially;
  PMap(uint64_t) id2node[1];
} MarkTree;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "marktree.h.generated.h"
#endif

#define MARKTREE_PAIRED_FLAG (((uint64_t)1) << 1)
#define MARKTREE_END_FLAG (((uint64_t)1) << 0)

#endif  // NVIM_MARKTREE_H
