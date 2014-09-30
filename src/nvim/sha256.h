#ifndef NVIM_SHA256_H
#define NVIM_SHA256_H

typedef struct {
  uint32_t total[2];
  uint32_t state[8];
  char_u buffer[64];
} context_sha256_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "sha256.h.generated.h"
#endif
#endif  // NVIM_SHA256_H
