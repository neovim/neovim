#pragma once

#include "nvim/eval/typval_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/gc.h.generated.h"
#endif

DLLEXPORT extern dict_T *gc_first_dict;
DLLEXPORT extern list_T *gc_first_list;
