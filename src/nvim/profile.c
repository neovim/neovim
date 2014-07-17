#include <stdio.h>
#include <math.h>
#include <assert.h>

#include "nvim/profile.h"
#include "nvim/os/time.h"
#include "nvim/func_attr.h"

#if defined(STARTUPTIME) || defined(PROTO)
#include <string.h>    // for strstr
#include <sys/time.h>  // for struct timeval

#include "nvim/vim.h"  // for the global `time_fd`
#endif

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

#if defined(STARTUPTIME) || defined(PROTO)

static struct timeval prev_timeval;

/// time_push - save the previous time before doing something that could nest
///
/// After calling this function, the static global `prev_timeval` will
/// contain the current time.
///
/// @param[out] tv_rel to the time elapsed so far
/// @param[out] tv_start the current time
void time_push(void *tv_rel, void *tv_start)
{
  // save the time elapsed so far into tv_rel
  *((struct timeval *)tv_rel) = prev_timeval;

  // set prev_timeval to the current time
  gettimeofday(&prev_timeval, NULL);

  // subtract the previous time from the current time, store it in tv_rel
  ((struct timeval *)tv_rel)->tv_usec = prev_timeval.tv_usec
    - ((struct timeval *)tv_rel)->tv_usec;
  ((struct timeval *)tv_rel)->tv_sec = prev_timeval.tv_sec
    - ((struct timeval *)tv_rel)->tv_sec;

  // correct usec overflow
  if (((struct timeval *)tv_rel)->tv_usec < 0) {
    ((struct timeval *)tv_rel)->tv_usec += 1000000;
    --((struct timeval *)tv_rel)->tv_sec;
  }

  // set tv_start to now
  *(struct timeval *)tv_start = prev_timeval;
}

/// time_pop - compute the prev time after doing something that could nest
///
/// Subtracts `*tp` from the static global `prev_timeval`.
///
/// Note: The arguments are (void *) to avoid trouble with systems that don't
/// have struct timeval.
///
/// @param tp actually `struct timeval *`
void time_pop(const void *tp)
{
  // subtract `tp` from `prev_timeval`
  prev_timeval.tv_usec -= ((struct timeval *)tp)->tv_usec;
  prev_timeval.tv_sec -= ((struct timeval *)tp)->tv_sec;

  // correct usec oveflow
  if (prev_timeval.tv_usec < 0) {
    prev_timeval.tv_usec += 1000000;
    --prev_timeval.tv_sec;
  }
}

/// time_diff - print the difference between `then` and `now`
///
/// the format is "msec.usec".
static void time_diff(const struct timeval *then, const struct timeval *now)
{
  // convert timeval (sec/usec) to (msec,usec)
  long usec = now->tv_usec - then->tv_usec;
  long msec = (now->tv_sec - then->tv_sec) * 1000L + usec / 1000L;
  usec %= 1000L;

  fprintf(time_fd, "%03ld.%03ld", msec, usec >= 0 ? usec : usec + 1000L);
}

/// time_msg - print out timing info
///
/// when `mesg` contains the text "STARTING", special information is
/// printed.
///
/// @param mesg the message to display next to the timing information
/// @param tv_start only for do_source: start time; actually (struct timeval *)
void time_msg(const char *mesg, const void *tv_start)
{
  static struct timeval start;
  struct timeval now;

  if (time_fd == NULL) {
    return;
  }

  // if the message contains STARTING, print some extra information and
  // initialize a few variables
  if (strstr(mesg, "STARTING") != NULL) {
    // intialize the `start` static variable
    gettimeofday(&start, NULL);
    prev_timeval = start;

    fprintf(time_fd, "\n\ntimes in msec\n");
    fprintf(time_fd, " clock   self+sourced   self:  sourced script\n");
    fprintf(time_fd, " clock   elapsed:              other lines\n\n");
  }

  // print out the difference between `start` (init earlier) and `now`
  gettimeofday(&now, NULL);
  time_diff(&start, &now);

  // if `tv_start` was supplied, print the diff between `tv_start` and `now`
  if (((struct timeval *)tv_start) != NULL) {
    fprintf(time_fd, "  ");
    time_diff(((struct timeval *)tv_start), &now);
  }

  // print the difference between the global `prev_timeval` and `now`
  fprintf(time_fd, "  ");
  time_diff(&prev_timeval, &now);

  // set the global `prev_timeval` to `now` and print the message
  prev_timeval = now;
  fprintf(time_fd, ": %s\n", mesg);
}

#endif
