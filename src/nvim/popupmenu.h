#ifndef NVIM_POPUPMENU_H
#define NVIM_POPUPMENU_H

#include "nvim/grid_defs.h"
#include "nvim/macros.h"
#include "nvim/types.h"
#include "nvim/vim.h"

/// Used for popup menu items.
typedef struct {
  char_u *pum_text;        // main menu text
  char_u *pum_kind;        // extra kind text (may be truncated)
  char_u *pum_extra;       // extra menu text (may be truncated)
  char_u *pum_info;        // extra info
} pumitem_T;

EXTERN ScreenGrid pum_grid INIT(= SCREEN_GRID_INIT);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "popupmenu.h.generated.h"
#endif
#endif  // NVIM_POPUPMENU_H
