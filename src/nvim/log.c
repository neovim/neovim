#include <assert.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "nvim/log.h"
#include "nvim/types.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"

#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif

#define USR_LOG_FILE "$HOME/.nvimlog"

static uv_mutex_t mutex;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "log.c.generated.h"
#endif

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

/// Open the log file for appending.
///
/// @return The FILE* specified by the USR_LOG_FILE path or stderr in case of
///         error
FILE *open_log_file(void)
{
  static bool opening_log_file = false;

  // check if it's a recursive call
  if (opening_log_file) {
    do_log_to_file(stderr, ERROR_LOG_LEVEL, __func__, __LINE__, true,
                   "Trying to LOG() recursively! Please fix it.");
    return stderr;
  }

  // expand USR_LOG_FILE and open the file
  FILE *log_file;
  opening_log_file = true;
  {
    static char expanded_log_file_path[MAXPATHL + 1];

    expand_env((char_u *)USR_LOG_FILE, (char_u *)expanded_log_file_path,
               MAXPATHL);
    // if the log file path expansion failed then fall back to stderr
    if (strcmp(USR_LOG_FILE, expanded_log_file_path) == 0) {
      goto open_log_file_error;
    }

    log_file = fopen(expanded_log_file_path, "a");
    if (log_file == NULL) {
      goto open_log_file_error;
    }
  }
  opening_log_file = false;

  return log_file;

open_log_file_error:
  opening_log_file = false;

  do_log_to_file(stderr, ERROR_LOG_LEVEL, __func__, __LINE__, true,
                 "Couldn't open USR_LOG_FILE, logging to stderr! This may be "
                 "caused by attempting to LOG() before initialization "
                 "functions are called (e.g. init_homedir()).");
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
    [DEBUG_LOG_LEVEL] = "debug",
    [INFO_LOG_LEVEL] = "info",
    [WARNING_LOG_LEVEL] = "warning",
    [ERROR_LOG_LEVEL] = "error"
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
  if (fprintf(log_file, "%s [%s @ %s:%d] %" PRId64 " - ", date_time,
              log_levels[log_level], func_name, line_num, pid) < 0) {
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

