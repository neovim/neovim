#ifndef NVIM_LOG_H
#define NVIM_LOG_H

#include <stdio.h>
#include <stdbool.h>

#include "auto/config.h"

#define DEBUG_LOG_LEVEL 0
#define INFO_LOG_LEVEL 1
#define WARN_LOG_LEVEL 2
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

#define LOG(level, ...) logmsg((level), NULL, __func__, __LINE__, true, \
                               __VA_ARGS__)

#if MIN_LOG_LEVEL <= DEBUG_LOG_LEVEL
# undef DLOG
# undef DLOGN
# define DLOG(...) logmsg(DEBUG_LOG_LEVEL, NULL, __func__, __LINE__, true, \
                          __VA_ARGS__)
# define DLOGN(...) logmsg(DEBUG_LOG_LEVEL, NULL, __func__, __LINE__, false, \
                           __VA_ARGS__)
#endif

#if MIN_LOG_LEVEL <= INFO_LOG_LEVEL
# undef ILOG
# undef ILOGN
# define ILOG(...) logmsg(INFO_LOG_LEVEL, NULL, __func__, __LINE__, true, \
                          __VA_ARGS__)
# define ILOGN(...) logmsg(INFO_LOG_LEVEL, NULL, __func__, __LINE__, false, \
                           __VA_ARGS__)
#endif

#if MIN_LOG_LEVEL <= WARN_LOG_LEVEL
# undef WLOG
# undef WLOGN
# define WLOG(...) logmsg(WARN_LOG_LEVEL, NULL, __func__, __LINE__, true, \
                          __VA_ARGS__)
# define WLOGN(...) logmsg(WARN_LOG_LEVEL, NULL, __func__, __LINE__, false, \
                           __VA_ARGS__)
#endif

#if MIN_LOG_LEVEL <= ERROR_LOG_LEVEL
# undef ELOG
# undef ELOGN
# define ELOG(...) logmsg(ERROR_LOG_LEVEL, NULL, __func__, __LINE__, true, \
                          __VA_ARGS__)
# define ELOGN(...) logmsg(ERROR_LOG_LEVEL, NULL, __func__, __LINE__, false, \
                           __VA_ARGS__)
#endif

#ifdef HAVE_EXECINFO_BACKTRACE
# define LOG_CALLSTACK() log_callstack(__func__, __LINE__)
# define LOG_CALLSTACK_TO_FILE(fp) log_callstack_to_file(fp, __func__, __LINE__)
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "log.h.generated.h"
#endif
#endif  // NVIM_LOG_H
