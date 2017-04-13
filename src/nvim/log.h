#ifndef NVIM_LOG_H
#define NVIM_LOG_H

#include <stdio.h>
#include <stdbool.h>

#define DEBUG_LOG_LEVEL 0
#define INFO_LOG_LEVEL 1
#define WARNING_LOG_LEVEL 2
#define ERROR_LOG_LEVEL 3

#define DLOG(...)
#define DLOGN(...)
#define ILOG(...)
#define ILOGN(...)
#define WLOG(...)
#define WLOGN(...)
#define ELOG(...)
#define ELOGN(...)

#ifndef MIN_LOG_LEVEL
#  define MIN_LOG_LEVEL INFO_LOG_LEVEL
#endif

#define LOG(level, ...) do_log((level), __func__, __LINE__, true, \
                               __VA_ARGS__)

#if MIN_LOG_LEVEL <= DEBUG_LOG_LEVEL
# undef DLOG
# undef DLOGN
# define DLOG(...) do_log(DEBUG_LOG_LEVEL, __func__, __LINE__, true, \
                          __VA_ARGS__)
# define DLOGN(...) do_log(DEBUG_LOG_LEVEL, __func__, __LINE__, false, \
                           __VA_ARGS__)
#endif

#if MIN_LOG_LEVEL <= INFO_LOG_LEVEL
# undef ILOG
# undef ILOGN
# define ILOG(...) do_log(INFO_LOG_LEVEL, __func__, __LINE__, true, \
                          __VA_ARGS__)
# define ILOGN(...) do_log(INFO_LOG_LEVEL, __func__, __LINE__, false, \
                           __VA_ARGS__)
#endif

#if MIN_LOG_LEVEL <= WARNING_LOG_LEVEL
# undef WLOG
# undef WLOGN
# define WLOG(...) do_log(WARNING_LOG_LEVEL, __func__, __LINE__, true, \
                          __VA_ARGS__)
# define WLOGN(...) do_log(WARNING_LOG_LEVEL, __func__, __LINE__, false, \
                           __VA_ARGS__)
#endif

#if MIN_LOG_LEVEL <= ERROR_LOG_LEVEL
# undef ELOG
# undef ELOGN
# define ELOG(...) do_log(ERROR_LOG_LEVEL, __func__, __LINE__, true, \
                          __VA_ARGS__)
# define ELOGN(...) do_log(ERROR_LOG_LEVEL, __func__, __LINE__, false, \
                           __VA_ARGS__)
#endif

#if defined(__linux__)
# include <execinfo.h>
# define LOG_CALLSTACK(prefix) \
  do { \
    void *trace[100]; \
    int trace_size = backtrace(trace, 100); \
    \
    char exe[1024]; \
    ssize_t elen = readlink("/proc/self/exe", exe, sizeof(exe) - 1); \
    exe[elen] = 0; \
    \
    for (int i = 1; i < trace_size; i++) { \
      char buf[256]; \
      snprintf(buf, sizeof(buf), "addr2line -e %s -f -p %p", exe, trace[i]); \
      FILE *fp = popen(buf, "r"); \
      while (fgets(buf, sizeof(buf) - 1, fp) != NULL) { \
        buf[strlen(buf)-1] = 0; \
        do_log(DEBUG_LOG_LEVEL, __func__, __LINE__, true, prefix "%s", buf); \
      } \
      fclose(fp); \
    } \
  } while (0)
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "log.h.generated.h"
#endif
#endif  // NVIM_LOG_H
