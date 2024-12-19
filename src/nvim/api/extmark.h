#pragma once

#include <stdbool.h>
#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/keysets_defs.h"  // IWYU pragma: keep
#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/buffer_defs.h"
#include "nvim/decoration_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/types_defs.h"

EXTERN Map(String, int) namespace_ids INIT( = MAP_INIT);
/// Non-global namespaces. A locally-scoped namespace may be "orphaned" if all
/// window(s) it was scoped to, are destroyed. Such orphans are tracked here to
/// avoid being mistaken as "global scope".
EXTERN Set(uint32_t) namespace_localscope INIT( = SET_INIT);
EXTERN handle_T next_namespace_id INIT( = 1);

/// Returns true if the namespace is global or scoped in the given window.
static inline bool ns_in_win(uint32_t ns_id, win_T *wp)
{
  if (!set_has(uint32_t, &namespace_localscope, ns_id)) {
    return true;
  }

  return set_has(uint32_t, &wp->w_ns_set, ns_id);
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/extmark.h.generated.h"
#endif
