// uncrustify:off
#include <math.h>
// uncrustify:on
#include <limits.h>
#include <stdint.h>
#include <string.h>

#ifdef HAVE_BITSCANFORWARD64
# include <intrin.h>  // Required for _BitScanForward64
#endif

#include "nvim/math.h"
#include "nvim/vim_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "math.c.generated.h"
#endif

int xfpclassify(double d)
  FUNC_ATTR_CONST
{
  uint64_t m;

  memcpy(&m, &d, sizeof(m));
  int e = 0x7ff & (m >> 52);
  m = 0xfffffffffffffULL & m;

  switch (e) {
  default:
    return FP_NORMAL;
  case 0x000:
    return m ? FP_SUBNORMAL : FP_ZERO;
  case 0x7ff:
    return m ? FP_NAN : FP_INFINITE;
  }
}

int xisinf(double d)
  FUNC_ATTR_CONST
{
  return FP_INFINITE == xfpclassify(d);
}

int xisnan(double d)
  FUNC_ATTR_CONST
{
  return FP_NAN == xfpclassify(d);
}

/// Count trailing zeroes at the end of bit field.
int xctz(uint64_t x)
{
  // If x == 0, that means all bits are zeroes.
  if (x == 0) {
    return 8 * sizeof(x);
  }

  // Use compiler builtin if possible.
#if defined(__clang__) || (defined(__GNUC__) && (__GNUC__ >= 4))
  return __builtin_ctzll(x);
#elif defined(HAVE_BITSCANFORWARD64)
  unsigned long index;
  _BitScanForward64(&index, x);
  return (int)index;
#else
  int count = 0;
  // Set x's trailing zeroes to ones and zero the rest.
  x = (x ^ (x - 1)) >> 1;

  // Increment count until there are just zero bits remaining.
  while (x) {
    count++;
    x >>= 1;
  }

  return count;
#endif
}

/// Count number of set bits in bit field.
unsigned xpopcount(uint64_t x)
{
  // Use compiler builtin if possible.
#if defined(__NetBSD__)
  return popcount64(x);
#elif defined(__clang__) || defined(__GNUC__)
  return (unsigned)__builtin_popcountll(x);
#else
  unsigned count = 0;
  for (; x != 0; x >>= 1) {
    if (x & 1) {
      count++;
    }
  }
  return count;
#endif
}

/// For overflow detection, add a digit safely to an int value.
int vim_append_digit_int(int *value, int digit)
{
  int x = *value;
  if (x > ((INT_MAX - digit) / 10)) {
    return FAIL;
  }
  *value = x * 10 + digit;
  return OK;
}

/// Return something that fits into an int.
int trim_to_int(int64_t x)
{
  return x > INT_MAX ? INT_MAX : x < INT_MIN ? INT_MIN : (int)x;
}
