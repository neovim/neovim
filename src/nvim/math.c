// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <math.h>

#include "nvim/math.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "math.c.generated.h"
#endif

#if defined(__clang__) && __clang__ == 1 && __clang_major__ >= 6
// Workaround glibc + Clang 6+ bug. #8274
// https://bugzilla.redhat.com/show_bug.cgi?id=1472437
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Wconversion"
#endif
int xfpclassify(double d)
{
#if defined(__MINGW32__)
  // Workaround mingw warning. #7863
  return __fpclassify(d);
#else
  return fpclassify(d);
#endif
}
int xisinf(double d)
{
  return isinf(d);
}
int xisnan(double d)
{
#if defined(__MINGW32__)
  // Workaround mingw warning. #7863
  return _isnan(d);
#else
  return isnan(d);
#endif
}
#if defined(__clang__) && __clang__ == 1 && __clang_major__ >= 6
# pragma clang diagnostic pop
#endif
