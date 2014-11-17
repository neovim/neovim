#ifndef NVIM_FUNDAMENTAL_H
#define NVIM_FUNDAMENTAL_H

#include "nvim/os/shell.h"

#define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fundamental.h.generated.h"
#endif

#endif  // NVIM_FUNDAMENTAL_H
