// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/eval/typval.h"
#include "nvim/eval/gc.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/gc.c.generated.h"
#endif

/// Head of list of all dictionaries
dict_T *gc_first_dict = NULL;
/// Head of list of all lists
list_T *gc_first_list = NULL;
