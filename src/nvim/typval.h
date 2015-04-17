#ifndef NVIM_TYPVAL_H
#define NVIM_TYPVAL_H

#include "nvim/eval_defs.h"
#include "nvim/hashtab.h"

/// Used to avoid allocating empty strings.
EXTERN char_u * const empty_string INIT(= (char_u *)"");

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "typval.h.generated.h"
#endif
#endif  // NVIM_TYPVAL_H
