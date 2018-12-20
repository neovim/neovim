#ifndef NVIM_REGEXP_H
#define NVIM_REGEXP_H

#include "nvim/types.h"
#include "nvim/buffer_defs.h"
#include "nvim/regexp_defs.h"

// Second argument for vim_regcomp().
#define RE_MAGIC        1       ///< 'magic' option
#define RE_STRING       2       ///< match in string instead of buffer text
#define RE_STRICT       4       ///< don't allow [abc] without ]
#define RE_AUTO         8       ///< automatic engine selection

// values for reg_do_extmatch
#define REX_SET        1       ///< to allow \z\(...\),
#define REX_USE        2       ///< to allow \z\1 et al.
#define REX_ALL       (REX_SET | REX_USE)

// regexp.c
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "regexp.h.generated.h"
#endif

#endif  // NVIM_REGEXP_H
