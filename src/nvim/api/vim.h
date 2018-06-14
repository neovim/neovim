#ifndef NVIM_API_VIM_H
#define NVIM_API_VIM_H

#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/lib/kvec.h"
#include "nvim/globals.h"

EXTERN kvec_t(String) namespaces INIT(= KVEC_INIT);
EXTERN uint64_t current_namespace_id INIT(= STARTING_NAMESPACE);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.h.generated.h"
#endif
#endif  // NVIM_API_VIM_H
