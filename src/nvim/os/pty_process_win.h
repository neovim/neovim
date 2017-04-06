#ifndef NVIM_OS_PTY_PROCESS_WIN_H
#define NVIM_OS_PTY_PROCESS_WIN_H

#include <uv.h>
#include <winpty.h>

#include "nvim/event/process.h"
#include "nvim/lib/queue.h"

typedef struct pty_process {
  Process process;
  char *term_name;
  uint16_t width, height;
  winpty_t *winpty_object;
  HANDLE finish_wait;
  HANDLE process_handle;
  uv_timer_t wait_eof_timer;
} PtyProcess;

// Structure used by build_cmd_line()
typedef struct arg_node {
  char *arg;  // pointer to argument.
  QUEUE node;  // QUEUE structure.
} ArgNode;

static inline PtyProcess pty_process_init(Loop *loop, void *data)
{
  PtyProcess rv;
  rv.process = process_init(loop, kProcessTypePty, data);
  rv.term_name = NULL;
  rv.width = 80;
  rv.height = 24;
  rv.winpty_object = NULL;
  rv.finish_wait = NULL;
  rv.process_handle = NULL;
  return rv;
}

/// Output error log with error code.
///
/// @param  emsg  error message.
/// @param  status  error code.
///
static inline void write_elog(const char *emsg, int status)
{
  ELOG("%s error code: %d", emsg, status);
}

/// Get error code from winpty error object and output error log.
///
/// @param  emsg  error message.
/// @param[out]  status  Location where saved error code that converted into
///                      libuv error.
/// @param  err  winpty error object.
///
static inline void write_winpty_elog(const char *emsg, int *status,
                                     winpty_error_ptr_t *err)
{
  assert(err != NULL && *err != NULL);

  *status = (int)winpty_error_code(*err);
  write_elog(emsg, *status);
  *status = translate_winpty_error(*status);
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process_win.h.generated.h"
#endif

#endif  // NVIM_OS_PTY_PROCESS_WIN_H
