#pragma once

#include <stdbool.h>
#include <stdint.h>

/// Check if number is a power of two
static inline bool is_power_of_two(uint64_t x)
{
  return x != 0 && ((x & (x - 1)) == 0);
}

#include "math.h.generated.h"
