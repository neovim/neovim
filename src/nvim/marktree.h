#pragma once

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "klib/kvec.h"
#include "nvim/assert.h"
#include "nvim/garray.h"
#include "nvim/map.h"
#include "nvim/pos.h"
#include "nvim/types.h"
// only for debug functions:
#include "api/private/defs.h"

struct mtnode_s;

#define MT_MAX_DEPTH 20
#define MT_BRANCH_FACTOR 10
// note max branch is actually 2*MT_BRANCH_FACTOR
// and strictly this is ceil(log2(2*MT_BRANCH_FACTOR + 1))
// as we need a pseudo-index for "right before this node"
#define MT_LOG2_BRANCH 5

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

// Internal storage
//
// NB: actual marks have flags > 0, so we can use (row,col,0) pseudo-key for
// "space before (row,col)"
typedef struct {
  MTPos pos;
  uint32_t ns;
  uint32_t id;
  int32_t hl_id;
  uint16_t flags;
  uint16_t priority;
  Decoration *decor_full;
} MTKey;

typedef struct {
  MTKey start;
  MTPos end_pos;
  bool end_right_gravity;
} MTPair;

#define MT_INVALID_KEY (MTKey) { { -1, -1 }, 0, 0, 0, 0, 0, NULL }

#define MT_FLAG_REAL (((uint16_t)1) << 0)
#define MT_FLAG_END (((uint16_t)1) << 1)
#define MT_FLAG_PAIRED (((uint16_t)1) << 2)
// orphaned: the other side of this paired mark was deleted. this mark must be deleted very soon!
#define MT_FLAG_ORPHANED (((uint16_t)1) << 3)
#define MT_FLAG_HL_EOL (((uint16_t)1) << 4)
#define MT_FLAG_NO_UNDO (((uint16_t)1) << 5)
#define MT_FLAG_INVALIDATE (((uint16_t)1) << 6)
#define MT_FLAG_INVALID (((uint16_t)1) << 7)

#define DECOR_LEVELS 4
#define MT_FLAG_DECOR_OFFSET 8
#define MT_FLAG_DECOR_MASK (((uint16_t)(DECOR_LEVELS - 1)) << MT_FLAG_DECOR_OFFSET)

// These _must_ be last to preserve ordering of marks
#define MT_FLAG_RIGHT_GRAVITY (((uint16_t)1) << 14)
#define MT_FLAG_LAST (((uint16_t)1) << 15)

#define MT_FLAG_EXTERNAL_MASK (MT_FLAG_DECOR_MASK | MT_FLAG_RIGHT_GRAVITY | MT_FLAG_HL_EOL \
                               | MT_FLAG_NO_UNDO | MT_FLAG_INVALIDATE | MT_FLAG_INVALID)

// this is defined so that start and end of the same range have adjacent ids
#define MARKTREE_END_FLAG ((uint64_t)1)
static inline uint64_t mt_lookup_id(uint32_t ns, uint32_t id, bool enda)
{
  return (uint64_t)ns << 33 | (id <<1) | (enda ? MARKTREE_END_FLAG : 0);
}

static inline uint64_t mt_lookup_key_side(MTKey key, bool end)
{
  return mt_lookup_id(key.ns, key.id, end);
}

static inline uint64_t mt_lookup_key(MTKey key)
{
  return mt_lookup_id(key.ns, key.id, key.flags & MT_FLAG_END);
}

static inline bool mt_paired(MTKey key)
{
  return key.flags & MT_FLAG_PAIRED;
}

static inline bool mt_end(MTKey key)
{
  return key.flags & MT_FLAG_END;
}

static inline bool mt_start(MTKey key)
{
  return mt_paired(key) && !mt_end(key);
}

static inline bool mt_right(MTKey key)
{
  return key.flags & MT_FLAG_RIGHT_GRAVITY;
}

static inline bool mt_no_undo(MTKey key)
{
  return key.flags & MT_FLAG_NO_UNDO;
}

static inline bool mt_invalidate(MTKey key)
{
  return key.flags & MT_FLAG_INVALIDATE;
}

static inline bool mt_invalid(MTKey key)
{
  return key.flags & MT_FLAG_INVALID;
}

static inline uint8_t marktree_decor_level(MTKey key)
{
  return (uint8_t)((key.flags&MT_FLAG_DECOR_MASK) >> MT_FLAG_DECOR_OFFSET);
}

static inline uint16_t mt_flags(bool right_gravity, bool hl_eol, bool no_undo, bool invalidate,
                                uint8_t decor_level)
{
  assert(decor_level < DECOR_LEVELS);
  return (uint16_t)((right_gravity ? MT_FLAG_RIGHT_GRAVITY : 0)
                    | (hl_eol ? MT_FLAG_HL_EOL : 0)
                    | (no_undo ? MT_FLAG_NO_UNDO : 0)
                    | (invalidate ? MT_FLAG_INVALIDATE : 0)
                    | (decor_level << MT_FLAG_DECOR_OFFSET));
}

static inline MTPair mtpair_from(MTKey start, MTKey end)
{
  return (MTPair){ .start = start, .end_pos = end.pos, .end_right_gravity = mt_right(end) };
}

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

static inline uint64_t mt_dbg_id(uint64_t id)
{
  return (id>>1)&0xffffffff;
}

typedef struct {
  MTNode *root;
  size_t n_keys, n_nodes;
  // TODO(bfredl): the pointer to node could be part of the larger
  // Map(uint64_t, ExtmarkItem) essentially;
  PMap(uint64_t) id2node[1];
} MarkTree;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "marktree.h.generated.h"
#endif
