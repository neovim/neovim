// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <math.h>

#include <stdint.h>
#include <string.h>

#include "nvim/math.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "math.c.generated.h"
#endif

int xfpclassify(double d)
{
  uint64_t m;
  int e;

  memcpy(&m, &d, sizeof(m));
  e = 0x7ff & (m >> 52);
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
