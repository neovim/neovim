#pragma once

#include <stdbool.h>
#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/event/defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"

EXTERN bool used_stdin INIT( = false);
/// Last channel that invoked 'nvim_input`.
/// TODO(justinmk): race condition if multiple UIs/scripts send input?
EXTERN uint64_t input_chan_id INIT( = 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/input.h.generated.h"
#endif
