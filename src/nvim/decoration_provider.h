#pragma once

#include <stdbool.h>

#include "nvim/decoration_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/types_defs.h"  // IWYU pragma: keep

EXTERN bool provider_active INIT( = false);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration_provider.h.generated.h"
#endif
