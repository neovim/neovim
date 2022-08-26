#ifndef NVIM_ARABIC_H
#define NVIM_ARABIC_H

#include <stdbool.h>

#define ARABIC_CHAR(ch)            (((ch) & 0xFF00) == 0x0600)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "arabic.h.generated.h"
#endif
#endif  // NVIM_ARABIC_H
