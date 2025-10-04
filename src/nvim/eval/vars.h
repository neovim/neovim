#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/eval_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/hashtab_defs.h"  // IWYU pragma: keep
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

#include "eval/vars.h.generated.h"

#define SCRIPT_SV(id) (SCRIPT_ITEM(id)->sn_vars)
#define SCRIPT_VARS(id) (SCRIPT_SV(id)->sv_dict.dv_hashtab)

/// v: hashtab
#define vimvarht  vimvardict.dv_hashtab
