#ifndef NVIM_API_VIM_H
#define NVIM_API_VIM_H

#include "nvim/api/keysets.h"
#include "nvim/api/private/defs.h"

typedef struct {
  Object on_input;
  Object pty;
} Dict(open_term);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.h.generated.h"
#endif
#endif  // NVIM_API_VIM_H
