#ifndef NVIM_LOG_H
#define NVIM_LOG_H

#include <stdbool.h>
#include <stdio.h>

#include "auto/config.h"
#include "nvim/macros.h"

// USDT probes. Example invocation:
//     NVIM_PROBE(nvim_foo_bar, 1, string.data);
#if defined(HAVE_SYS_SDT_H)
# include <sys/sdt.h>  // NOLINT
# define NVIM_PROBE(name, n, ...) STAP_PROBE##n(neovim, name, __VA_ARGS__)
#else
# define NVIM_PROBE(name, n, ...)
#endif

#define LOGLVL_TRC 0
#define LOGLVL_DBG 1
#define LOGLVL_INF 2
#define LOGLVL_WRN 3
#define LOGLVL_ERR 4

#define DLOG(...)
#define DLOGN(...)
#define ILOG(...)
#define ILOGN(...)
#define WLOG(...)
#define WLOGN(...)
#define ELOG(...)
#define ELOGN(...)

#ifndef MIN_LOG_LEVEL
# define MIN_LOG_LEVEL LOGLVL_INF
#endif

#define LOG(level, ...) logmsg((level), NULL, __func__, __LINE__, true, __VA_ARGS__)

#if MIN_LOG_LEVEL <= LOGLVL_DBG
# undef DLOG
# undef DLOGN
# define DLOG(...) logmsg(LOGLVL_DBG, NULL, __func__, __LINE__, true, __VA_ARGS__)
# define DLOGN(...) logmsg(LOGLVL_DBG, NULL, __func__, __LINE__, false, __VA_ARGS__)
#endif

#if MIN_LOG_LEVEL <= LOGLVL_INF
# undef ILOG
# undef ILOGN
# define ILOG(...) logmsg(LOGLVL_INF, NULL, __func__, __LINE__, true, __VA_ARGS__)
# define ILOGN(...) logmsg(LOGLVL_INF, NULL, __func__, __LINE__, false, __VA_ARGS__)
#endif

#if MIN_LOG_LEVEL <= LOGLVL_WRN
# undef WLOG
# undef WLOGN
# define WLOG(...) logmsg(LOGLVL_WRN, NULL, __func__, __LINE__, true, __VA_ARGS__)
# define WLOGN(...) logmsg(LOGLVL_WRN, NULL, __func__, __LINE__, false, __VA_ARGS__)
#endif

#if MIN_LOG_LEVEL <= LOGLVL_ERR
# undef ELOG
# undef ELOGN
# define ELOG(...) logmsg(LOGLVL_ERR, NULL, __func__, __LINE__, true, __VA_ARGS__)
# define ELOGN(...) logmsg(LOGLVL_ERR, NULL, __func__, __LINE__, false, __VA_ARGS__)
#endif

#ifdef HAVE_EXECINFO_BACKTRACE
# define LOG_CALLSTACK() log_callstack(__func__, __LINE__)
# define LOG_CALLSTACK_TO_FILE(fp) log_callstack_to_file(fp, __func__, __LINE__)
#endif

#if NVIM_HAS_INCLUDE("sanitizer/asan_interface.h")
# include "sanitizer/asan_interface.h"
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "log.h.generated.h"
#endif
#endif  // NVIM_LOG_H
