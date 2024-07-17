#pragma once

#include <stdbool.h>
#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>

#include "klib/kvec.h"
#include "nvim/decoration_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/marktree_defs.h"
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/sign_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"

// actual Decor* data is in decoration_defs.h

/// Keep in sync with VirtTextPos in decoration_defs.h
EXTERN const char *const virt_text_pos_str[]
INIT( = { "eol", "overlay", "win_col", "right_align", "inline" });

/// Keep in sync with HlMode in decoration_defs.h
EXTERN const char *const hl_mode_str[] INIT( = { "", "replace", "combine", "blend" });

typedef enum {
  kDecorKindHighlight,
  kDecorKindSign,
  kDecorKindVirtText,
  kDecorKindVirtLines,
  kDecorKindUIWatched,
} DecorRangeKind;

typedef struct {
  int start_row;
  int start_col;
  int end_row;
  int end_col;
  // next pointers MUST NOT be used, these are separate ranges
  // vt->next could be pointing to freelist memory at this point
  union {
    DecorSignHighlight sh;
    DecorVirtText *vt;
    struct {
      uint32_t ns_id;
      uint32_t mark_id;
      VirtTextPos pos;
    } ui;
  } data;
  int attr_id;  ///< cached lookup of inl.hl_id if it was a highlight
  bool owned;   ///< ephemeral decoration, free memory immediately
  DecorPriority priority;
  DecorRangeKind kind;
  /// Screen column to draw the virtual text.
  /// When -1, it should be drawn on the current screen line after deciding where.
  /// When -3, it may be drawn at a position yet to be assigned.
  /// When -10, it has just been added.
  /// When INT_MIN, it should no longer be drawn.
  int draw_col;
} DecorRange;

typedef struct {
  MarkTreeIter itr[1];
  kvec_t(DecorRange) active;
  win_T *win;
  int top_row;
  int row;
  int col_until;
  int current;
  int eol_col;

  int conceal;
  schar_T conceal_char;
  int conceal_attr;

  TriState spell;

  bool running_decor_provider;
} DecorState;

EXTERN DecorState decor_state INIT( = { 0 });
// TODO(bfredl): These should maybe be per-buffer, so that all resources
// associated with a buffer can be freed when the buffer is unloaded.
EXTERN kvec_t(DecorSignHighlight) decor_items INIT( = KV_INITIAL_VALUE);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration.h.generated.h"
#endif
