#pragma once

#include <stdbool.h>

#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/grid_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/menu_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Used for popup menu items.
typedef struct {
  char *pum_text;          // main menu text
  char *pum_kind;          // extra kind text (may be truncated)
  char *pum_extra;         // extra menu text (may be truncated)
  char *pum_info;          // extra info
} pumitem_T;

EXTERN ScreenGrid pum_grid INIT( = SCREEN_GRID_INIT);

/// state for pum_ext_select_item.
EXTERN struct {
  bool active;
  int item;
  bool insert;
  bool finish;
} pum_want;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "popupmenu.h.generated.h"
#endif
