#ifndef NVIM_POPUPMNU_H
#define NVIM_POPUPMNU_H

#include "nvim/vim.h"
#include "nvim/macros.h"
#include "nvim/grid_defs.h"
#include "nvim/types.h"

/// Used for popup menu items.
typedef struct {
  char_u *pum_text;        // main menu text
  char_u *pum_kind;        // extra kind text (may be truncated)
  char_u *pum_extra;       // extra menu text (may be truncated)
  char_u *pum_info;        // extra info
} pumitem_T;

EXTERN ScreenGrid pum_grid INIT(= SCREEN_GRID_INIT);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "popupmnu.h.generated.h"
#endif
#endif  // NVIM_POPUPMNU_H
