#include <stddef.h>

#include "nvim/eval/gc.h"

#include "eval/gc.c.generated.h"  // IWYU pragma: export

/// Head of list of all dictionaries
dict_T *gc_first_dict = NULL;
/// Head of list of all lists
list_T *gc_first_list = NULL;
