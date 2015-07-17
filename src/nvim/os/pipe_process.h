#ifndef NVIM_OS_PIPE_PROCESS_H
#define NVIM_OS_PIPE_PROCESS_H

#include <uv.h>

typedef struct {
  // Structures for process spawning/management used by libuv
  uv_process_t proc;
  uv_process_options_t proc_opts;
  uv_stdio_container_t stdio[3];
  uv_pipe_t proc_stdin, proc_stdout, proc_stderr;
} UvProcess;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pipe_process.h.generated.h"
#endif
#endif  // NVIM_OS_PIPE_PROCESS_H
