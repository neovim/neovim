#pragma once

#include <stdbool.h>
#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>

#define SHA256_BUFFER_SIZE 64
#define SHA256_SUM_SIZE    32

typedef struct {
  uint32_t total[2];
  uint32_t state[8];
  uint8_t buffer[SHA256_BUFFER_SIZE];
} context_sha256_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "sha256.h.generated.h"
#endif
