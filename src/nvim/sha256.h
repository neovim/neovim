#ifndef NVIM_SHA256_H
#define NVIM_SHA256_H

#include <stdint.h>      // for uint32_t
#include <stddef.h>

#include "nvim/types.h"  // for char_u

#define SHA256_BUFFER_SIZE 64
#define SHA256_SUM_SIZE    32

typedef struct {
  uint32_t total[2];
  uint32_t state[8];
  char_u buffer[SHA256_BUFFER_SIZE];
} context_sha256_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "sha256.h.generated.h"
#endif
#endif  // NVIM_SHA256_H
