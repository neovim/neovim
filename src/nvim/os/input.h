#ifndef NVIM_OS_INPUT_H
#define NVIM_OS_INPUT_H

#include <stdint.h>
#include <stdbool.h>

#include "nvim/api/private/defs.h"

#ifdef WIN32
# include "nvim/os/cygterm.h"
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/input.h.generated.h"
#endif
#endif  // NVIM_OS_INPUT_H
