#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "klib/kvec.h"
#include "nvim/decoration_defs.h"
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/map_defs.h"
#include "nvim/pos_defs.h"  // IWYU pragma: keep
// only for debug functions:
#include "nvim/api/private/defs.h"  // IWYU pragma: keep

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

#define MT_INVALID_KEY (MTKey) { { -1, -1 }, 0, 0, 0, { .hl = DECOR_HIGHLIGHT_INLINE_INIT } }

#define MT_FLAG_REAL (((uint16_t)1) << 0)
#define MT_FLAG_END (((uint16_t)1) << 1)
#define MT_FLAG_PAIRED (((uint16_t)1) << 2)
// orphaned: the other side of this paired mark was deleted. this mark must be deleted very soon!
#define MT_FLAG_ORPHANED (((uint16_t)1) << 3)
#define MT_FLAG_NO_UNDO (((uint16_t)1) << 4)
#define MT_FLAG_INVALIDATE (((uint16_t)1) << 5)
#define MT_FLAG_INVALID (((uint16_t)1) << 6)
// discriminant for union
#define MT_FLAG_DECOR_EXT (((uint16_t)1) << 7)

// TODO(bfredl): flags for decorations. These cover the cases where we quickly needs
// to skip over irrelevant marks internally. When we refactor this more, also make all info
// for ExtmarkType included here
#define MT_FLAG_DECOR_HL (((uint16_t)1) << 8)
#define MT_FLAG_DECOR_SIGNTEXT (((uint16_t)1) << 9)
// TODO(bfredl): for now this means specifically number_hl, line_hl, cursorline_hl
// needs to clean up the name.
#define MT_FLAG_DECOR_SIGNHL (((uint16_t)1) << 10)
#define MT_FLAG_DECOR_VIRT_LINES (((uint16_t)1) << 11)
#define MT_FLAG_DECOR_VIRT_TEXT_INLINE (((uint16_t)1) << 12)

// These _must_ be last to preserve ordering of marks
#define MT_FLAG_RIGHT_GRAVITY (((uint16_t)1) << 14)
#define MT_FLAG_LAST (((uint16_t)1) << 15)

#define MT_FLAG_DECOR_MASK  (MT_FLAG_DECOR_EXT| MT_FLAG_DECOR_HL | MT_FLAG_DECOR_SIGNTEXT \
                             | MT_FLAG_DECOR_SIGNHL | MT_FLAG_DECOR_VIRT_LINES \
                             | MT_FLAG_DECOR_VIRT_TEXT_INLINE)

#define MT_FLAG_EXTERNAL_MASK (MT_FLAG_DECOR_MASK | MT_FLAG_NO_UNDO \
                               | MT_FLAG_INVALIDATE | MT_FLAG_INVALID)

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

static inline bool mt_decor_any(MTKey key)
{
  return key.flags & MT_FLAG_DECOR_MASK;
}

static inline bool mt_decor_sign(MTKey key)
{
  return key.flags & (MT_FLAG_DECOR_SIGNTEXT | MT_FLAG_DECOR_SIGNHL);
}

static inline uint16_t mt_flags(bool right_gravity, bool no_undo, bool invalidate, bool decor_ext)
{
  return (uint16_t)((right_gravity ? MT_FLAG_RIGHT_GRAVITY : 0)
                    | (no_undo ? MT_FLAG_NO_UNDO : 0)
                    | (invalidate ? MT_FLAG_INVALIDATE : 0)
                    | (decor_ext ? MT_FLAG_DECOR_EXT : 0));
}

static inline MTPair mtpair_from(MTKey start, MTKey end)
{
  return (MTPair){ .start = start, .end_pos = end.pos, .end_right_gravity = mt_right(end) };
}

static inline DecorInline mt_decor(MTKey key)
{
  return (DecorInline){ .ext = key.flags & MT_FLAG_DECOR_EXT, .data = key.decor_data };
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
  PMap(uint64_t) id2node[1];
} MarkTree;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "marktree.h.generated.h"
#endif
