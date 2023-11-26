#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/event/multiqueue.h"
#include "nvim/macros.h"

EXTERN bool used_stdin INIT( = false);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/input.h.generated.h"
#endif
