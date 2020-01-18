#ifndef TREE_SITTER_BITS_H_
#define TREE_SITTER_BITS_H_

#include <stdint.h>

static inline uint32_t bitmask_for_index(uint16_t id) {
  return (1u << (31 - id));
}

#ifdef _WIN32

#include <intrin.h>

static inline uint32_t count_leading_zeros(uint32_t x) {
  if (x == 0) return 32;
  uint32_t result;
  _BitScanReverse(&result, x);
  return 31 - result;
}

#else

static inline uint32_t count_leading_zeros(uint32_t x) {
  if (x == 0) return 32;
  return __builtin_clz(x);
}

#endif
#endif  // TREE_SITTER_BITS_H_
