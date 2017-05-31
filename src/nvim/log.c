// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
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
      || os_isdir((char_u *)log_file_path)) {
    // Invalid $NVIM_LOG_FILE or failed to expand; fall back to default.
    memset(log_file_path, 0, size);
    char *defaultpath = stdpaths_user_data_subpath("log", 0, true);
    size_t len = xstrlcpy(log_file_path, defaultpath, size);
    if (len >= size) {  // Fall back to stderr.
      memset(log_file_path, 0, size);
      return false;
    }
    os_setenv(LOG_FILE_ENV, log_file_path, true);
    xfree(defaultpath);
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

bool do_log(int log_level, const char *func_name, int line_num, bool eol,
            const char* fmt, ...) FUNC_ATTR_UNUSED
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
  ret = v_do_log_to_file(log_file, log_level, func_name, line_num, eol,
                              fmt, args);
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
    do_log_to_file(stderr, ERROR_LOG_LEVEL, __func__, __LINE__, true,
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
  do_log_to_file(stderr, ERROR_LOG_LEVEL, __func__, __LINE__, true,
                 "Logging to stderr, failed to open $" LOG_FILE_ENV ": %s",
                 log_file_path);
  return stderr;
}

static bool do_log_to_file(FILE *log_file, int log_level,
                           const char *func_name, int line_num, bool eol,
                           const char* fmt, ...)
{
  va_list args;
  va_start(args, fmt);
  bool ret = v_do_log_to_file(log_file, log_level, func_name, line_num, eol,
                              fmt, args);
  va_end(args);

  return ret;
}

static bool v_do_log_to_file(FILE *log_file, int log_level,
                             const char *func_name, int line_num, bool eol,
                             const char* fmt, va_list args)
{
  static const char *log_levels[] = {
    [DEBUG_LOG_LEVEL]   = "DEBUG",
    [INFO_LOG_LEVEL]    = "INFO ",
    [WARNING_LOG_LEVEL] = "WARN ",
    [ERROR_LOG_LEVEL]   = "ERROR",
  };
  assert(log_level >= DEBUG_LOG_LEVEL && log_level <= ERROR_LOG_LEVEL);

  // format current timestamp in local time
  struct tm local_time;
  if (os_get_localtime(&local_time) == NULL) {
    return false;
  }
  char date_time[20];
  if (strftime(date_time, sizeof(date_time), "%Y/%m/%d %H:%M:%S",
               &local_time) == 0) {
    return false;
  }

  // print the log message prefixed by the current timestamp and pid
  int64_t pid = os_get_pid();
  if (fprintf(log_file, "%s %s %" PRId64 "/%s:%d: ", date_time,
              log_levels[log_level], pid, func_name, line_num) < 0) {
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

