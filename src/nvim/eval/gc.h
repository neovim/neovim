#ifndef NVIM_EVAL_GC_H
#define NVIM_EVAL_GC_H

#include "nvim/eval/typval.h"

extern dict_T *gc_first_dict;
extern list_T *gc_first_list;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/gc.h.generated.h"
#endif
#endif  // NVIM_EVAL_GC_H
