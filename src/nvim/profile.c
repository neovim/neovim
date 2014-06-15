#include <stdio.h>
#include <math.h>
#include <assert.h>

#include "nvim/profile.h"
#include "nvim/os/time.h"
#include "nvim/func_attr.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "profile.c.generated.h"
#endif

/// functions for profiling

static proftime_T prof_wait_time;

/// profile_start - return the current time
///
/// @return the current time
proftime_T profile_start(void) FUNC_ATTR_WARN_UNUSED_RESULT
{
  return os_hrtime();
}

/// profile_end - compute the time elapsed
///
/// @return the elapsed time from `tm` until now.
proftime_T profile_end(proftime_T tm) FUNC_ATTR_WARN_UNUSED_RESULT
{
  return os_hrtime() - tm;
}

/// profile_msg - return a string that represents the time in `tm`
///
/// @warning Do not modify or free this string, not multithread-safe.
///
/// @param tm The time to be represented
/// @return a static string representing `tm` in the
///         form "seconds.microseconds".
const char *profile_msg(proftime_T tm) FUNC_ATTR_WARN_UNUSED_RESULT
{
  static char buf[50];

  snprintf(buf, sizeof(buf), "%10.6lf", (double)tm / 1000000000.0);

  return buf;
}

/// profile_setlimit - return the time `msec` into the future
///
/// @param msec milliseconds, the maximum number of milliseconds is
///             (2^63 / 10^6) - 1 = 9.223372e+12.
/// @return if msec > 0, returns the time msec past now. Otherwise returns
///         the zero time.
proftime_T profile_setlimit(int64_t msec) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (msec <= 0) {
    // no limit
    return profile_zero();
  }

  assert(msec <= (INT64_MAX / 1000000LL) - 1);

  proftime_T nsec = (proftime_T) msec * 1000000ULL;
  return os_hrtime() + nsec;
}

/// profile_passed_limit - check if current time has passed `tm`
///
/// @return true if the current time is past `tm`, false if not or if the
///         timer was not set.
bool profile_passed_limit(proftime_T tm) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (tm == 0) {
    // timer was not set
    return false;
  }

  return profile_cmp(os_hrtime(), tm) < 0;
}

/// profile_zero - obtain the zero time
///
/// @return the zero time
proftime_T profile_zero(void) FUNC_ATTR_CONST
{
  return 0;
}

/// profile_divide - divide the time `tm` by `count`.
///
/// @return 0 if count <= 0, otherwise tm / count
proftime_T profile_divide(proftime_T tm, int count) FUNC_ATTR_CONST
{
  if (count <= 0) {
    return profile_zero();
  }

  return (proftime_T) round((double) tm / (double) count);
}

/// profile_add - add the time `tm2` to `tm1`
///
/// @return `tm1` + `tm2`
proftime_T profile_add(proftime_T tm1, proftime_T tm2) FUNC_ATTR_CONST
{
  return tm1 + tm2;
}

/// profile_sub - subtract `tm2` from `tm1`
///
/// @return `tm1` - `tm2`
proftime_T profile_sub(proftime_T tm1, proftime_T tm2) FUNC_ATTR_CONST
{
  return tm1 - tm2;
}

/// profile_self - add the `self` time from the total time and the
///                children's time
///
/// @return if `total` <= `children`, then self, otherwise `self` + `total` -
///         `children`
proftime_T profile_self(proftime_T self, proftime_T total, proftime_T children)
  FUNC_ATTR_CONST
{
  // check that the result won't be negative, which can happen with
  // recursive calls.
  if (total <= children) {
    return self;
  }

  // add the total time to self and subtract the children's time from self
  return profile_sub(profile_add(self, total), children);
}

/// profile_get_wait - get the current waittime
///
/// @return the current waittime
proftime_T profile_get_wait(void) FUNC_ATTR_PURE
{
  return prof_wait_time;
}

/// profile_set_wait - set the current waittime
void profile_set_wait(proftime_T wait)
{
  prof_wait_time = wait;
}

/// profile_sub_wait - subtract the passed waittime since `tm`
///
/// @return `tma` - (waittime - `tm`)
proftime_T profile_sub_wait(proftime_T tm, proftime_T tma) FUNC_ATTR_PURE
{
  proftime_T tm3 = profile_sub(profile_get_wait(), tm);
  return profile_sub(tma, tm3);
}

/// profile_equal - check if `tm1` is equal to `tm2`
///
/// @return true if `tm1` == `tm2`
bool profile_equal(proftime_T tm1, proftime_T tm2) FUNC_ATTR_CONST
{
  return tm1 == tm2;
}

/// sgn64 - calculates the sign of a 64-bit integer
///
/// @return -1, 0, or +1
static inline int sgn64(int64_t x) FUNC_ATTR_CONST
{
  return (int) ((x > 0) - (x < 0));
}

/// profile_cmp - compare profiling times
///
/// Only guarantees correct results if both input times are not more than
/// 150 years apart.
///
/// @return <0, 0 or >0 if `tm2` < `tm1`, `tm2` == `tm1` or `tm2` > `tm1`
int profile_cmp(proftime_T tm1, proftime_T tm2) FUNC_ATTR_CONST
{
  return sgn64((int64_t)(tm2 - tm1));
}
