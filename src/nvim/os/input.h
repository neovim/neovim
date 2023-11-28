#pragma once

#include <stdbool.h>
#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/event/multiqueue.h"
#include "nvim/macros_defs.h"

EXTERN bool used_stdin INIT( = false);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/input.h.generated.h"
#endif
