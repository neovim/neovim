#ifndef NVIM_API_VIM_H
#define NVIM_API_VIM_H

#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/map.h"

EXTERN Map(String, handle_T) *namespace_ids INIT(= NULL);
EXTERN handle_T next_namespace_id INIT(= 1);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.h.generated.h"
#endif
#endif  // NVIM_API_VIM_H
