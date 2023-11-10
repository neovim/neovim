#pragma once

#include "nvim/buffer_defs.h"
#include "nvim/regexp_defs.h"
#include "nvim/types.h"

// Second argument for vim_regcomp().
#define RE_MAGIC        1       ///< 'magic' option
#define RE_STRING       2       ///< match in string instead of buffer text
#define RE_STRICT       4       ///< don't allow [abc] without ]
#define RE_AUTO         8       ///< automatic engine selection
#define RE_NOBREAK      16      ///< don't use breakcheck functions

// values for reg_do_extmatch
#define REX_SET        1       ///< to allow \z\(...\),
#define REX_USE        2       ///< to allow \z\1 et al.
#define REX_ALL       (REX_SET | REX_USE)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "regexp.h.generated.h"
#endif
