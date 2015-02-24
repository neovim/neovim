#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/os/uv_helpers.h"
#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/os/job_private.h"
#include "nvim/os/pipe_process.h"
#include "nvim/memory.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pipe_process.c.generated.h"
#endif

typedef struct {
  // Structures for process spawning/management used by libuv
  uv_process_t proc;
  uv_process_options_t proc_opts;
  uv_stdio_container_t stdio[3];
  uv_pipe_t proc_stdin, proc_stdout, proc_stderr;
} UvProcess;

void pipe_process_init(Job *job)
{
  UvProcess *pipeproc = xmalloc(sizeof(UvProcess));
  pipeproc->proc_opts.file = job->opts.argv[0];
  pipeproc->proc_opts.args = job->opts.argv;
  pipeproc->proc_opts.stdio = pipeproc->stdio;
  pipeproc->proc_opts.stdio_count = 3;
  pipeproc->proc_opts.flags = UV_PROCESS_WINDOWS_HIDE;
  pipeproc->proc_opts.exit_cb = exit_cb;
  pipeproc->proc_opts.cwd = NULL;
  pipeproc->proc_opts.env = NULL;
  pipeproc->proc.data = NULL;
  pipeproc->proc_stdin.data = NULL;
  pipeproc->proc_stdout.data = NULL;
  pipeproc->proc_stderr.data = NULL;

  // Initialize the job std{in,out,err}
  pipeproc->stdio[0].flags = UV_IGNORE;
  pipeproc->stdio[1].flags = UV_IGNORE;
  pipeproc->stdio[2].flags = UV_IGNORE;

  handle_set_job((uv_handle_t *)&pipeproc->proc, job);

  if (job->opts.writable) {
    uv_pipe_init(uv_default_loop(), &pipeproc->proc_stdin, 0);
    pipeproc->stdio[0].flags = UV_CREATE_PIPE | UV_READABLE_PIPE;
    pipeproc->stdio[0].data.stream = (uv_stream_t *)&pipeproc->proc_stdin;
  }

  if (job->opts.stdout_cb) {
    uv_pipe_init(uv_default_loop(), &pipeproc->proc_stdout, 0);
    pipeproc->stdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
    pipeproc->stdio[1].data.stream = (uv_stream_t *)&pipeproc->proc_stdout;
  }

  if (job->opts.stderr_cb) {
    uv_pipe_init(uv_default_loop(), &pipeproc->proc_stderr, 0);
    pipeproc->stdio[2].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
    pipeproc->stdio[2].data.stream = (uv_stream_t *)&pipeproc->proc_stderr;
  }

  job->proc_stdin = (uv_stream_t *)&pipeproc->proc_stdin;
  job->proc_stdout = (uv_stream_t *)&pipeproc->proc_stdout;
  job->proc_stderr = (uv_stream_t *)&pipeproc->proc_stderr;
  job->process = pipeproc;
}

void pipe_process_destroy(Job *job)
{
  UvProcess *pipeproc = job->process;
  free(pipeproc->proc.data);
  free(pipeproc);
  job->process = NULL;
}

bool pipe_process_spawn(Job *job)
{
  UvProcess *pipeproc = job->process;

  if (uv_spawn(uv_default_loop(), &pipeproc->proc, &pipeproc->proc_opts) != 0) {
    return false;
  }

  job->pid = pipeproc->proc.pid;
  return true;
}

void pipe_process_close(Job *job)
{
  UvProcess *pipeproc = job->process;
  uv_close((uv_handle_t *)&pipeproc->proc, close_cb);
}

static void exit_cb(uv_process_t *proc, int64_t status, int term_signal)
{
  Job *job = handle_get_job((uv_handle_t *)proc);
  job->status = (int)status;
  pipe_process_close(job);
}

static void close_cb(uv_handle_t *handle)
{
  Job *job = handle_get_job(handle);
  job_close_streams(job);
  job_decref(job);
}
