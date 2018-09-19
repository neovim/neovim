// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#if !defined(WIN32)
# include <sys/time.h>  // for gettimeofday()
#endif
#include <uv.h>

#include "nvim/log.h"
#include "nvim/types.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"

#define LOG_FILE_ENV "NVIM_LOG_FILE"

/// Cached location of the expanded log file path decided by log_path_init().
static char log_file_path[MAXPATHL + 1] = { 0 };

static uv_mutex_t mutex;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "log.c.generated.h"
#endif

#ifdef HAVE_EXECINFO_BACKTRACE
# include <execinfo.h>
#endif

static bool log_try_create(char *fname)
{
  if (fname == NULL || fname[0] == '\0') {
    return false;
  }
  FILE *log_file = fopen(fname, "a");
  if (log_file == NULL) {
    return false;
  }
  fclose(log_file);
  return true;
}

/// Initializes path to log file. Sets $NVIM_LOG_FILE if empty.
///
/// Tries $NVIM_LOG_FILE, or falls back to $XDG_DATA_HOME/nvim/log. Path to log
/// file is cached, so only the first call has effect, unless first call was not
/// successful. Failed initialization indicates either a bug in expand_env()
/// or both $NVIM_LOG_FILE and $HOME environment variables are undefined.
///
/// @return true if path was initialized, false otherwise.
static bool log_path_init(void)
{
  if (log_file_path[0]) {
    return true;
  }
  size_t size = sizeof(log_file_path);
  expand_env((char_u *)"$" LOG_FILE_ENV, (char_u *)log_file_path,
             (int)size - 1);
  if (strequal("$" LOG_FILE_ENV, log_file_path)
      || log_file_path[0] == '\0'
      || os_isdir((char_u *)log_file_path)
      || !log_try_create(log_file_path)) {
    // Invalid $NVIM_LOG_FILE or failed to expand; fall back to default.
    char *defaultpath = stdpaths_user_data_subpath("log", 0, true);
    size_t len = xstrlcpy(log_file_path, defaultpath, size);
    xfree(defaultpath);
    // Fall back to .nvimlog
    if (len >= size || !log_try_create(log_file_path)) {
      len = xstrlcpy(log_file_path, ".nvimlog", size);
    }
    // Fall back to stderr
    if (len >= size || !log_try_create(log_file_path)) {
      log_file_path[0] = '\0';
      return false;
    }
    os_setenv(LOG_FILE_ENV, log_file_path, true);
  }
  return true;
}

void log_init(void)
{
  uv_mutex_init(&mutex);
}

void log_lock(void)
{
  uv_mutex_lock(&mutex);
}

void log_unlock(void)
{
  uv_mutex_unlock(&mutex);
}

/// @param context    description of a shared context or subsystem
/// @param func_name  function name, or NULL
/// @param line_num   source line number, or -1
bool logmsg(int log_level, const char *context, const char *func_name,
            int line_num, bool eol, const char *fmt, ...)
  FUNC_ATTR_UNUSED
{
  if (log_level < MIN_LOG_LEVEL) {
    return false;
  }

  log_lock();
  bool ret = false;
  FILE *log_file = open_log_file();

  if (log_file == NULL) {
    goto end;
  }

  va_list args;
  va_start(args, fmt);
  ret = v_do_log_to_file(log_file, log_level, context, func_name, line_num,
                         eol, fmt, args);
  va_end(args);

  if (log_file != stderr && log_file != stdout) {
    fclose(log_file);
  }
end:
  log_unlock();
  return ret;
}

void log_uv_handles(void *loop)
{
  uv_loop_t *l = loop;
  log_lock();
  FILE *log_file = open_log_file();

  if (log_file == NULL) {
    goto end;
  }

  uv_print_all_handles(l, log_file);

  if (log_file != stderr && log_file != stdout) {
    fclose(log_file);
  }
end:
  log_unlock();
}

/// Open the log file for appending.
///
/// @return FILE* decided by log_path_init() or stderr in case of error
FILE *open_log_file(void)
{
  static bool opening_log_file = false;
  // check if it's a recursive call
  if (opening_log_file) {
    do_log_to_file(stderr, ERROR_LOG_LEVEL, NULL, __func__, __LINE__, true,
                   "Cannot LOG() recursively.");
    return stderr;
  }

  FILE *log_file = NULL;
  opening_log_file = true;
  if (log_path_init()) {
    log_file = fopen(log_file_path, "a");
  }
  opening_log_file = false;

  if (log_file != NULL) {
    return log_file;
  }

  // May happen if:
  //  - LOG() is called before early_init()
  //  - Directory does not exist
  //  - File is not writable
  do_log_to_file(stderr, ERROR_LOG_LEVEL, NULL, __func__, __LINE__, true,
                 "Logging to stderr, failed to open $" LOG_FILE_ENV ": %s",
                 log_file_path);
  return stderr;
}

#ifdef HAVE_EXECINFO_BACKTRACE
void log_callstack_to_file(FILE *log_file, const char *const func_name,
                           const int line_num)
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

  do_log_to_file(log_file, DEBUG_LOG_LEVEL, NULL, func_name, line_num, true,
                 "trace:");
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
  if (log_file == NULL) {
    goto end;
  }

  log_callstack_to_file(log_file, func_name, line_num);

end:
  log_unlock();
}
#endif

static bool do_log_to_file(FILE *log_file, int log_level, const char *context,
                           const char *func_name, int line_num, bool eol,
                           const char* fmt, ...)
{
  va_list args;
  va_start(args, fmt);
  bool ret = v_do_log_to_file(log_file, log_level, context, func_name,
                              line_num, eol, fmt, args);
  va_end(args);

  return ret;
}

static bool v_do_log_to_file(FILE *log_file, int log_level,
                             const char *context, const char *func_name,
                             int line_num, bool eol, const char *fmt,
                             va_list args)
{
  static const char *log_levels[] = {
    [DEBUG_LOG_LEVEL]   = "DEBUG",
    [INFO_LOG_LEVEL]    = "INFO ",
    [WARN_LOG_LEVEL]    = "WARN ",
    [ERROR_LOG_LEVEL]   = "ERROR",
  };
  assert(log_level >= DEBUG_LOG_LEVEL && log_level <= ERROR_LOG_LEVEL);

  // Format the timestamp.
  struct tm local_time;
  if (os_localtime(&local_time) == NULL) {
    return false;
  }
  char date_time[20];
  if (strftime(date_time, sizeof(date_time), "%Y-%m-%dT%H:%M:%S",
               &local_time) == 0) {
    return false;
  }

  int millis = 0;
#if !defined(WIN32)
  struct timeval curtime;
  if (gettimeofday(&curtime, NULL) == 0) {
    millis = (int)curtime.tv_usec / 1000;
  }
#endif

  // Print the log message.
  int64_t pid = os_get_pid();
  int rv = (line_num == -1 || func_name == NULL)
    ? fprintf(log_file, "%s %s.%03d %-5" PRId64 " %s",
              log_levels[log_level], date_time, millis, pid,
              (context == NULL ? "?:" : context))
    : fprintf(log_file, "%s %s.%03d %-5" PRId64 " %s%s:%d: ",
              log_levels[log_level], date_time, millis, pid,
              (context == NULL ? "" : context),
              func_name, line_num);
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

