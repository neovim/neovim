// uncrustify:off
#include <math.h>
// uncrustify:on
#include <stdint.h>
#include <string.h>

#include "nvim/math.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "math.c.generated.h"  // IWYU pragma: export
#endif

int xfpclassify(double d)
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
{
  return FP_INFINITE == xfpclassify(d);
}

int xisnan(double d)
{
  return FP_NAN == xfpclassify(d);
}
