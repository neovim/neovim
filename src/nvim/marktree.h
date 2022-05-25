#ifndef NVIM_MARKTREE_H
#define NVIM_MARKTREE_H

#include <assert.h>
#include <stdint.h>

#include "nvim/assert.h"
#include "nvim/garray.h"
#include "nvim/map.h"
#include "nvim/pos.h"
#include "nvim/types.h"

#define MT_MAX_DEPTH 20
#define MT_BRANCH_FACTOR 10

typedef struct {
  int32_t row;
  int32_t col;
} mtpos_t;

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
// NB: actual marks have flags > 0, so we can use (row,col,0) pseudo-key for
// "space before (row,col)"
typedef struct {
  mtpos_t pos;
  uint32_t ns;
  uint32_t id;
  int32_t hl_id;
  uint16_t flags;
  uint16_t priority;
  Decoration *decor_full;
} mtkey_t;
#define MT_INVALID_KEY (mtkey_t) { { -1, -1 }, 0, 0, 0, 0, 0, NULL }

#define MT_FLAG_REAL (((uint16_t)1) << 0)
#define MT_FLAG_END (((uint16_t)1) << 1)
#define MT_FLAG_PAIRED (((uint16_t)1) << 2)
#define MT_FLAG_HL_EOL (((uint16_t)1) << 3)

#define DECOR_LEVELS 4
#define MT_FLAG_DECOR_OFFSET 4
#define MT_FLAG_DECOR_MASK (((uint16_t)(DECOR_LEVELS - 1)) << MT_FLAG_DECOR_OFFSET)

// next flag is (((uint16_t)1) << 6)

// These _must_ be last to preserve ordering of marks
#define MT_FLAG_RIGHT_GRAVITY (((uint16_t)1) << 14)
#define MT_FLAG_LAST (((uint16_t)1) << 15)

#define MT_FLAG_EXTERNAL_MASK (MT_FLAG_DECOR_MASK | MT_FLAG_RIGHT_GRAVITY | MT_FLAG_HL_EOL)

#define MARKTREE_END_FLAG (((uint64_t)1) << 63)
static inline uint64_t mt_lookup_id(uint32_t ns, uint32_t id, bool enda)
{
  return (uint64_t)ns << 32 | id | (enda?MARKTREE_END_FLAG:0);
}
#undef MARKTREE_END_FLAG

static inline uint64_t mt_lookup_key(mtkey_t key)
{
  return mt_lookup_id(key.ns, key.id, key.flags & MT_FLAG_END);
}

static inline bool mt_paired(mtkey_t key)
{
  return key.flags & MT_FLAG_PAIRED;
}

static inline bool mt_end(mtkey_t key)
{
  return key.flags & MT_FLAG_END;
}

static inline bool mt_start(mtkey_t key)
{
  return mt_paired(key) && !mt_end(key);
}

static inline bool mt_right(mtkey_t key)
{
  return key.flags & MT_FLAG_RIGHT_GRAVITY;
}

static inline uint8_t marktree_decor_level(mtkey_t key)
{
  return (uint8_t)((key.flags&MT_FLAG_DECOR_MASK) >> MT_FLAG_DECOR_OFFSET);
}

static inline uint16_t mt_flags(bool right_gravity, uint8_t decor_level)
{
  assert(decor_level < DECOR_LEVELS);
  return (uint16_t)((right_gravity ? MT_FLAG_RIGHT_GRAVITY : 0)
                    | (decor_level << MT_FLAG_DECOR_OFFSET));
}

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
  // TODO(bfredl): the pointer to node could be part of the larger
  // Map(uint64_t, ExtmarkItem) essentially;
  PMap(uint64_t) id2node[1];
} MarkTree;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "marktree.h.generated.h"
#endif

#endif  // NVIM_MARKTREE_H
