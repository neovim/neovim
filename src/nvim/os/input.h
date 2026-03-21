#pragma once

#include <stdbool.h>
#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/event/defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"

EXTERN bool used_stdin INIT( = false);

#include "os/input.h.generated.h"
