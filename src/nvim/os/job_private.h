#ifndef NVIM_OS_JOB_PRIVATE_H
#define NVIM_OS_JOB_PRIVATE_H

#include <stdlib.h>

#include <uv.h>

#include "nvim/os/rstream_defs.h"
#include "nvim/os/wstream_defs.h"
#include "nvim/os/pipe_process.h"
#include "nvim/os/pty_process.h"
#include "nvim/os/shell.h"
#include "nvim/log.h"

struct job {
  // Job id the index in the job table plus one.
  int id;
  // Process id
  int pid;
  // Exit status code of the job process
  int status;
  // Number of references to the job. The job resources will only be freed by
  // close_cb when this is 0
  int refcount;
  // Time when job_stop was called for the job.
  uint64_t stopped_time;
  // If SIGTERM was already sent to the job(only send one before SIGKILL)
  bool term_sent;
  // Readable streams(std{out,err})
  RStream *out, *err;
  // Writable stream(stdin)
  WStream *in;
  // Libuv streams representing stdin/stdout/stderr
  uv_stream_t *proc_stdin, *proc_stdout, *proc_stderr;
  // Extra data set by the process spawner
  void *process;
  // If process_close has been called on this job
  bool closed;
  // Startup options
  JobOptions opts;
};

extern Job *table[];
extern size_t stop_requests;
extern uv_timer_t job_stop_timer;

static inline bool process_spawn(Job *job)
{
  return job->opts.pty ? pty_process_spawn(job) : pipe_process_spawn(job);
}

static inline void process_init(Job *job)
{
  if (job->opts.pty) {
    pty_process_init(job);
  } else {
    pipe_process_init(job);
  }
}

static inline void process_close(Job *job)
{
  if (job->closed) {
    return;
  }
  job->closed = true;
  if (job->opts.pty) {
    pty_process_close(job);
  } else {
    pipe_process_close(job);
  }
}

static inline void process_destroy(Job *job)
{
  if (job->opts.pty) {
    pty_process_destroy(job);
  } else {
    pipe_process_destroy(job);
  }
}

static inline void job_exit_callback(Job *job)
{
  // Free the slot now, 'exit_cb' may want to start another job to replace
  // this one
  table[job->id - 1] = NULL;

  if (job->opts.exit_cb) {
    // Invoke the exit callback
    job->opts.exit_cb(job, job->opts.data);
  }

  if (stop_requests && !--stop_requests) {
    // Stop the timer if no more stop requests are pending
    DLOG("Stopping job kill timer");
    uv_timer_stop(&job_stop_timer);
  }
}

static inline void job_decref(Job *job)
{
  if (--job->refcount == 0) {
    // Invoke the exit_cb
    job_exit_callback(job);
    // Free all memory allocated for the job
    free(job->proc_stdin->data);
    free(job->proc_stdout->data);
    free(job->proc_stderr->data);
    shell_free_argv(job->opts.argv);
    process_destroy(job);
    free(job);
  }
}


#endif  // NVIM_OS_JOB_PRIVATE_H
