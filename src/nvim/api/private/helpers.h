#ifndef NVIM_API_PRIVATE_HELPERS_H
#define NVIM_API_PRIVATE_HELPERS_H

#include <stdbool.h>

#include "nvim/api/private/defs.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

#define set_api_error(message, err)                \
  do {                                             \
    xstrlcpy(err->msg, message, sizeof(err->msg)); \
    err->set = true;                               \
  } while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/helpers.h.generated.h"
#endif
#endif  // NVIM_API_PRIVATE_HELPERS_H
