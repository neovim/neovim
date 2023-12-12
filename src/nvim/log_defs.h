#pragma once

#include <stdbool.h>
#include <stdio.h>

#include "auto/config.h"
#include "nvim/macros_defs.h"

#define LOGLVL_DBG 1
#define LOGLVL_INF 2
#define LOGLVL_WRN 3
#define LOGLVL_ERR 4

#define LOG(level, ...) logmsg((level), NULL, __func__, __LINE__, true, __VA_ARGS__)

#ifdef NVIM_LOG_DEBUG
# define DLOG(...) logmsg(LOGLVL_DBG, NULL, __func__, __LINE__, true, __VA_ARGS__)
# define DLOGN(...) logmsg(LOGLVL_DBG, NULL, __func__, __LINE__, false, __VA_ARGS__)
# define ILOG(...) logmsg(LOGLVL_INF, NULL, __func__, __LINE__, true, __VA_ARGS__)
# define ILOGN(...) logmsg(LOGLVL_INF, NULL, __func__, __LINE__, false, __VA_ARGS__)
#else
# define DLOG(...)
# define DLOGN(...)
# define ILOG(...)
# define ILOGN(...)
#endif

#define WLOG(...) logmsg(LOGLVL_WRN, NULL, __func__, __LINE__, true, __VA_ARGS__)
#define WLOGN(...) logmsg(LOGLVL_WRN, NULL, __func__, __LINE__, false, __VA_ARGS__)
#define ELOG(...) logmsg(LOGLVL_ERR, NULL, __func__, __LINE__, true, __VA_ARGS__)
#define ELOGN(...) logmsg(LOGLVL_ERR, NULL, __func__, __LINE__, false, __VA_ARGS__)

#ifdef HAVE_EXECINFO_BACKTRACE
# define LOG_CALLSTACK() log_callstack(__func__, __LINE__)
# define LOG_CALLSTACK_TO_FILE(fp) log_callstack_to_file(fp, __func__, __LINE__)
#endif
