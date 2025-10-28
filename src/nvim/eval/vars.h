#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/eval_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/hashtab_defs.h"  // IWYU pragma: keep
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Array mapping values from MessagePackType to corresponding list pointers
extern const list_T *eval_msgpack_type_lists[NUM_MSGPACK_TYPES];

#include "eval/vars.h.generated.h"
