#ifndef NVIM_API_PRIVATE_REDRAW_H
#define NVIM_API_PRIVATE_REDRAW_H

#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/vim.h"
#include "nvim/buffer_defs.h"

typedef struct {
  size_t colon, fold, sign, number, deleted, linebreak;
} UpdateLineWidths;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/redraw.h.generated.h"
#endif

#endif  // NVIM_API_PRIVATE_REDRAW_H
