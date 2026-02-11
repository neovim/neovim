#pragma once

#include "nvim/eval/typval_defs.h"

#include "eval/gc.h.generated.h"

DLLEXPORT extern dict_T *gc_first_dict;
DLLEXPORT extern list_T *gc_first_list;
