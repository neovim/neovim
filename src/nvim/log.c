//
// Log module
//
// How Linux printk() handles recursion, buffering, etc:
// https://lwn.net/Articles/780556/
//

#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <uv.h>

#include "auto/config.h"
#include "nvim/ascii_defs.h"
#include "nvim/eval.h"
#include "nvim/globals.h"
#include "nvim/log.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/os/fs.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/stdpaths_defs.h"
#include "nvim/os/time.h"
#include "nvim/path.h"

/// Cached location of the expanded log file path decided by log_path_init().
static char log_file_path[MAXPATHL + 1] = { 0 };

static bool did_log_init = false;
static uv_mutex_t mutex;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "log.c.generated.h"
#endif

#ifdef HAVE_EXECINFO_BACKTRACE
# include <execinfo.h>
#endif

static bool log_try_create(char *fname)
{
  if (fname == NULL || fname[0] == NUL) {
    return false;
  }
  FILE *log_file = fopen(fname, "a");
  if (log_file == NULL) {
    return false;
  }
  fclose(log_file);
  return true;
}

/// Initializes the log file path and sets $NVIM_LOG_FILE if empty.
///
/// Tries $NVIM_LOG_FILE, or falls back to $XDG_STATE_HOME/nvim/log. Failed
/// initialization indicates either a bug in expand_env() or both $NVIM_LOG_FILE
/// and $HOME environment variables are undefined.
static void log_path_init(void)
{
  size_t size = sizeof(log_file_path);
  expand_env("$" ENV_LOGFILE, log_file_path, (int)size - 1);
  if (strequal("$" ENV_LOGFILE, log_file_path)
      || log_file_path[0] == NUL
      || os_isdir(log_file_path)
      || !log_try_create(log_file_path)) {
    // Make $XDG_STATE_HOME if it does not exist.
    char *loghome = get_xdg_home(kXDGStateHome);
    char *failed_dir = NULL;
    bool log_dir_failure = false;
    if (!os_isdir(loghome)) {
      log_dir_failure = (os_mkdir_recurse(loghome, 0700, &failed_dir, NULL) != 0);
    }
    XFREE_CLEAR(loghome);
    // Invalid $NVIM_LOG_FILE or failed to expand; fall back to default.
    char *defaultpath = stdpaths_user_state_subpath("log", 0, true);
    size_t len = xstrlcpy(log_file_path, defaultpath, size);
    xfree(defaultpath);
    // Fall back to .nvimlog
    if (len >= size || !log_try_create(log_file_path)) {
      len = xstrlcpy(log_file_path, ".nvimlog", size);
    }
    // Fall back to stderr
    if (len >= size || !log_try_create(log_file_path)) {
      log_file_path[0] = NUL;
      return;
    }
    os_setenv(ENV_LOGFILE, log_file_path, true);
    if (log_dir_failure) {
      WLOG("Failed to create directory %s for writing logs: %s",
           failed_dir, os_strerror(log_dir_failure));
    }
    XFREE_CLEAR(failed_dir);
  }
}

void log_init(void)
{
  uv_mutex_init_recursive(&mutex);
  // AFTER init_homedir ("~", XDG) and set_init_1 (env vars). 22b52dd462e5 #11501
  log_path_init();
  did_log_init = true;
}

void log_lock(void)
{
  uv_mutex_lock(&mutex);
}

void log_unlock(void)
{
  uv_mutex_unlock(&mutex);
}

/// Logs a message to $NVIM_LOG_FILE.
///
/// @param log_level  Log level (see log.h)
/// @param context    Description of a shared context or subsystem
/// @param func_name  Function name, or NULL
/// @param line_num   Source line number, or -1
/// @param eol        Append linefeed "\n"
/// @param fmt        printf-style format string
///
/// @return true if log was emitted normally, false if failed or recursive
bool logmsg(int log_level, const char *context, const char *func_name, int line_num, bool eol,
            const char *fmt, ...)
  FUNC_ATTR_PRINTF(6, 7)
{
  static bool recursive = false;
  static bool did_msg = false;  // Showed recursion message?
  if (!did_log_init) {
    g_stats.log_skip++;
    // set_init_1 may try logging before we are ready. 6f27f5ef91b3 #10183
    return false;
  }

#ifndef NVIM_LOG_DEBUG
  // This should rarely happen (callsites are compiled out), but to be sure.
  // TODO(bfredl): allow log levels to be configured at runtime
  if (log_level < LOGLVL_WRN) {
    return false;
  }
#endif

#ifdef EXITFREE
  // Logging after we've already started freeing all our memory will only cause
  // pain.  We need access to VV_PROGPATH, homedir, etc.
  if (entered_free_all_mem) {
    fprintf(stderr, "FATAL: error in free_all_mem\n %s %s %d: ", context, func_name, line_num);
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    if (eol) {
      fprintf(stderr, "\n");
    }
    abort();
  }
#endif

  log_lock();
  if (recursive) {
    if (!did_msg) {
      did_msg = true;
      msg_schedule_semsg("E5430: %s:%d: recursive log!", func_name ? func_name : context, line_num);
    }
    g_stats.log_skip++;
    log_unlock();
    return false;
  }
  recursive = true;
  bool ret = false;
  FILE *log_file = open_log_file();

  va_list args;
  va_start(args, fmt);
  ret = v_do_log_to_file(log_file, log_level, context, func_name, line_num,
                         eol, fmt, args);
  va_end(args);

  if (log_file != stderr && log_file != stdout) {
    fclose(log_file);
  }

  recursive = false;
  log_unlock();
  return ret;
}

void log_uv_handles(void *loop)
{
  uv_loop_t *l = loop;
  log_lock();
  FILE *log_file = open_log_file();

  uv_print_all_handles(l, log_file);

  if (log_file != stderr && log_file != stdout) {
    fclose(log_file);
  }

  log_unlock();
}

/// Open the log file for appending.
///
/// @return Log file, or stderr on failure
FILE *open_log_file(void)
{
  errno = 0;
  if (log_file_path[0]) {
    FILE *f = fopen(log_file_path, "a");
    if (f != NULL) {
      return f;
    }
  }

  // May happen if:
  //  - fopen() failed
  //  - LOG() is called before log_init()
  //  - Directory does not exist
  //  - File is not writable
  do_log_to_file(stderr, LOGLVL_ERR, NULL, __func__, __LINE__, true,
                 "failed to open $" ENV_LOGFILE " (%s): %s",
                 strerror(errno), log_file_path);
  return stderr;
}

#ifdef HAVE_EXECINFO_BACKTRACE
void log_callstack_to_file(FILE *log_file, const char *const func_name, const int line_num)
{
  void *trace[100];
  int trace_size = backtrace(trace, ARRAY_SIZE(trace));

  char exepath[MAXPATHL] = { 0 };
  size_t exepathlen = MAXPATHL;
  if (os_exepath(exepath, &exepathlen) != 0) {
    abort();
  }
  assert(24 + exepathlen < IOSIZE);  // Must fit in `cmdbuf` below.

  char cmdbuf[IOSIZE + (20 * ARRAY_SIZE(trace)) + MAXPATHL];
  snprintf(cmdbuf, sizeof(cmdbuf), "addr2line -e %s -f -p", exepath);
  for (int i = 1; i < trace_size; i++) {
    char buf[20];  // 64-bit pointer 0xNNNNNNNNNNNNNNNN with leading space.
    snprintf(buf, sizeof(buf), " %p", trace[i]);
    xstrlcat(cmdbuf, buf, sizeof(cmdbuf));
  }
  // Now we have a command string like:
  //    addr2line -e /path/to/exe -f -p 0x123 0x456 ...

  do_log_to_file(log_file, LOGLVL_DBG, NULL, func_name, line_num, true, "trace:");
  FILE *fp = popen(cmdbuf, "r");
  char linebuf[IOSIZE];
  while (fgets(linebuf, sizeof(linebuf) - 1, fp) != NULL) {
    fprintf(log_file, "  %s", linebuf);
  }
  pclose(fp);

  if (log_file != stderr && log_file != stdout) {
    fclose(log_file);
  }
}

void log_callstack(const char *const func_name, const int line_num)
{
  log_lock();
  FILE *log_file = open_log_file();
  log_callstack_to_file(log_file, func_name, line_num);
  log_unlock();
}
#endif

static bool do_log_to_file(FILE *log_file, int log_level, const char *context,
                           const char *func_name, int line_num, bool eol, const char *fmt, ...)
  FUNC_ATTR_PRINTF(7, 8)
{
  va_list args;
  va_start(args, fmt);
  bool ret = v_do_log_to_file(log_file, log_level, context, func_name,
                              line_num, eol, fmt, args);
  va_end(args);

  return ret;
}

static bool v_do_log_to_file(FILE *log_file, int log_level, const char *context,
                             const char *func_name, int line_num, bool eol, const char *fmt,
                             va_list args)
  FUNC_ATTR_PRINTF(7, 0)
{
  // Name of the Nvim instance that produced the log.
  static char name[32] = { 0 };

  static const char *log_levels[] = {
    [LOGLVL_DBG] = "DBG",
    [LOGLVL_INF] = "INF",
    [LOGLVL_WRN] = "WRN",
    [LOGLVL_ERR] = "ERR",
  };
  assert(log_level >= LOGLVL_DBG && log_level <= LOGLVL_ERR);

  // Format the timestamp.
  struct tm local_time;
  if (os_localtime(&local_time) == NULL) {
    return false;
  }
  char date_time[20];
  if (strftime(date_time, sizeof(date_time), "%Y-%m-%dT%H:%M:%S", &local_time) == 0) {
    return false;
  }

  int millis = 0;
  uv_timeval64_t curtime;
  if (uv_gettimeofday(&curtime) == 0) {
    millis = (int)curtime.tv_usec / 1000;
  }

  // Get a name for this Nvim instance.
  // TODO(justinmk): expose this as v:name ?
  if (name[0] == NUL) {
    // Parent servername.
    const char *parent = path_tail(os_getenv(ENV_NVIM));
    // Servername. Empty until starting=false.
    const char *serv = path_tail(get_vim_var_str(VV_SEND_SERVER));
    if (parent[0] != NUL) {
      snprintf(name, sizeof(name), "%s/c", parent);  // "/c" indicates child.
    } else if (serv[0] != NUL) {
      snprintf(name, sizeof(name), "%s", serv);
    } else {
      int64_t pid = os_get_pid();
      snprintf(name, sizeof(name), "?.%-5" PRId64, pid);
    }
  }

  // Print the log message.
  int rv = (line_num == -1 || func_name == NULL)
           ? fprintf(log_file, "%s %s.%03d %-10s %s",
                     log_levels[log_level], date_time, millis, name,
                     (context == NULL ? "?:" : context))
           : fprintf(log_file, "%s %s.%03d %-10s %s%s:%d: ",
                     log_levels[log_level], date_time, millis, name,
                     (context == NULL ? "" : context),
                     func_name, line_num);
  if (name[0] == '?') {
    // No v:servername yet. Clear `name` so that the next log can try again.
    name[0] = NUL;
  }

  if (rv < 0) {
    return false;
  }
  if (vfprintf(log_file, fmt, args) < 0) {
    return false;
  }
  if (eol) {
    fputc('\n', log_file);
  }
  if (fflush(log_file) == EOF) {
    return false;
  }

  return true;
}
