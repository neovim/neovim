#ifndef NVIM_MISC2_H
#define NVIM_MISC2_H

#include "nvim/os/shell.h"

#define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "misc2.h.generated.h"
#endif

#endif  // NVIM_MISC2_H
