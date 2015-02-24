#ifndef NVIM_OS_JOB_DEFS_H
#define NVIM_OS_JOB_DEFS_H

#include <uv.h>
#include "nvim/os/rstream_defs.h"
#include "nvim/os/wstream_defs.h"

typedef struct job Job;

/// Function called when the job reads data
///
/// @param id The job id
/// @param data Some data associated with the job by the caller
typedef void (*job_exit_cb)(Job *job, void *data);

// Job startup options
// job_exit_cb Callback that will be invoked when the job exits
// maxmem Maximum amount of memory used by the job WStream
typedef struct {
  // Argument vector for the process. The first item is the
  // executable to run.
  // [consumed]
  char **argv;
  // Caller data that will be associated with the job
  void *data;
  // If true the job stdin will be available for writing with job_write,
  // otherwise it will be redirected to /dev/null
  bool writable;
  // Callback that will be invoked when data is available on stdout. If NULL
  // stdout will be redirected to /dev/null.
  rstream_cb stdout_cb;
  // Callback that will be invoked when data is available on stderr. If NULL
  // stderr will be redirected to /dev/null.
  rstream_cb  stderr_cb;
  // Callback that will be invoked when the job has exited and will not send
  // data
  job_exit_cb exit_cb;
  // Maximum memory used by the job's WStream
  size_t maxmem;
  // Connect the job to a pseudo terminal
  bool pty;
  // Initial window dimensions if the job is connected to a pseudo terminal
  uint16_t width, height;
  // Value for the $TERM environment variable. A default value of "ansi" is
  // assumed if NULL
  char *term_name;
} JobOptions;

#define JOB_OPTIONS_INIT ((JobOptions) {                     \
    .argv = NULL,                                            \
    .data = NULL,                                            \
    .writable = true,                                        \
    .stdout_cb = NULL,                                       \
    .stderr_cb = NULL,                                       \
    .exit_cb = NULL,                                         \
    .maxmem = 0,                                             \
    .pty = false,                                            \
    .width = 80,                                             \
    .height = 24,                                            \
    .term_name = NULL                                        \
    })
#endif  // NVIM_OS_JOB_DEFS_H
