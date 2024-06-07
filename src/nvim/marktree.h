#pragma once

#include <stdbool.h>
#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>

#include "nvim/buffer_defs.h"
#include "nvim/decoration_defs.h"
#include "nvim/marktree_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
// only for debug functions:
#include "nvim/api/private/defs.h"  // IWYU pragma: keep

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

static inline DecorVirtText *mt_decor_virt(MTKey mark)
{
  return (mark.flags & MT_FLAG_DECOR_EXT) ? mark.decor_data.ext.vt : NULL;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "marktree.h.generated.h"
#endif
