#ifndef NVIM_ARABIC_H
#define NVIM_ARABIC_H

#include <stdbool.h>

/// Whether c belongs to the range of Arabic characters that might be shaped.
static inline bool arabic_char(int c)
{
    // return c >= a_HAMZA && c <= a_MINI_ALEF;
    return c >= 0x0621 && c <= 0x0670;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "arabic.h.generated.h"
#endif
#endif  // NVIM_ARABIC_H
