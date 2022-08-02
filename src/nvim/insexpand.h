#ifndef NVIM_INSEXPAND_H
#define NVIM_INSEXPAND_H

#include "nvim/vim.h"

/// state for pum_ext_select_item.
EXTERN struct {
  bool active;
  int item;
  bool insert;
  bool finish;
} pum_want;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "insexpand.h.generated.h"
#endif
#endif  // NVIM_INSEXPAND_H
