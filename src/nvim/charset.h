#ifndef NVIM_CHARSET_H
#define NVIM_CHARSET_H

#include "nvim/types.h"
#include "nvim/pos.h"
#include "nvim/buffer_defs.h"

/// Return the folded-case equivalent of the given character
///
/// @param[in]  c  Character to transform.
///
/// @return Folded variant.
#define CH_FOLD(c) \
    utf_fold((sizeof(c) == sizeof(char)) \
             ?((int)(uint8_t)(c)) \
             :((int)(c)))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "charset.h.generated.h"
#endif
#endif  // NVIM_CHARSET_H
