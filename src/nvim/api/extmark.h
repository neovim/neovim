#pragma once

#include "nvim/api/keysets.h"
#include "nvim/api/private/defs.h"
#include "nvim/decoration.h"
#include "nvim/macros.h"
#include "nvim/map.h"
#include "nvim/types.h"

EXTERN Map(String, int) namespace_ids INIT( = MAP_INIT);
EXTERN handle_T next_namespace_id INIT( = 1);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/extmark.h.generated.h"
#endif
