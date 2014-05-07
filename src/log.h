#ifndef NEOVIM_LOG_H
#define NEOVIM_LOG_H

#include <stdbool.h>

#include "func_attr.h"

#define DEBUG_LOG_LEVEL 0
#define INFO_LOG_LEVEL 1
#define WARNING_LOG_LEVEL 2
#define ERROR_LOG_LEVEL 3

bool do_log(int log_level, const char *func_name, int line_num,
            const char* fmt, ...) FUNC_ATTR_UNUSED;

#define DLOG(...)
#define ILOG(...)
#define WLOG(...)
#define ELOG(...)

// Logging is disabled if NDEBUG or DISABLE_LOG is defined.
#ifdef NDEBUG
#  define DISABLE_LOG
#endif

// MIN_LOG_LEVEL can be defined during compilation to adjust the desired level
// of logging. DEBUG_LOG_LEVEL is used by default.
#ifndef MIN_LOG_LEVEL
#  define MIN_LOG_LEVEL DEBUG_LOG_LEVEL
#endif

#ifndef DISABLE_LOG

#  if MIN_LOG_LEVEL <= DEBUG_LOG_LEVEL
#    undef DLOG
#    define DLOG(...) do_log(DEBUG_LOG_LEVEL, __func__, __LINE__, __VA_ARGS__)
#  endif

#  if MIN_LOG_LEVEL <= INFO_LOG_LEVEL
#    undef ILOG
#    define ILOG(...) do_log(INFO_LOG_LEVEL, __func__, __LINE__, __VA_ARGS__)
#  endif

#  if MIN_LOG_LEVEL <= WARNING_LOG_LEVEL
#    undef WLOG
#    define WLOG(...) do_log(WARNING_LOG_LEVEL, __func__, __LINE__, __VA_ARGS__)
#  endif

#  if MIN_LOG_LEVEL <= ERROR_LOG_LEVEL
#    undef ELOG
#    define ELOG(...) do_log(ERROR_LOG_LEVEL, __func__, __LINE__, __VA_ARGS__)
#  endif

#endif

#endif  // NEOVIM_LOG_H

