#ifndef NVIM_CORE_H
#define NVIM_CORE_H

#include "nvim/os/shell.h"

#define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "core.h.generated.h"
#endif

#endif  // NVIM_CORE_H
