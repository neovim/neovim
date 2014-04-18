#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "os/job.h"
#include "os/job_defs.h"
#include "os/rstream.h"
#include "os/rstream_defs.h"
#include "os/wstream.h"
#include "os/wstream_defs.h"
#include "os/event.h"
#include "os/event_defs.h"
#include "os/time.h"
#include "os/shell.h"
#include "vim.h"
#include "memory.h"
#include "term.h"

#define EXIT_TIMEOUT 25
#define MAX_RUNNING_JOBS 100
#define JOB_BUFFER_SIZE 1024
#define JOB_WRITE_MAXMEM 1024 * 1024

struct job {
  // Job id the index in the job table plus one.
  int id;
  // Number of polls after a SIGTERM that will trigger a SIGKILL
  int exit_timeout;
  // exit_cb may be called while there's still pending data from stdout/stderr.
  // We use this reference count to ensure the JobExit event is only emitted
  // when stdout/stderr are drained
  int pending_refs;
  // Same as above, but for freeing the job memory which contains
  // libuv handles. Only after all are closed the job can be safely freed.
  int pending_closes;
  // If the job was already stopped
  bool stopped;
  // Data associated with the job
  void *data;
  // Callbacks
  job_exit_cb exit_cb;
  rstream_cb stdout_cb, stderr_cb;
  // Readable streams(std{out,err})
  RStream *out, *err;
  // Writable stream(stdin)
  WStream *in;
  // Structures for process spawning/management used by libuv
  uv_process_t proc;
  uv_process_options_t proc_opts;
  uv_stdio_container_t stdio[3];
  uv_pipe_t proc_stdin, proc_stdout, proc_stderr;
};

static Job *table[MAX_RUNNING_JOBS] = {NULL};
static uint32_t job_count = 0;
static uv_prepare_t job_prepare;

// Some helpers shared in this module
static bool is_alive(Job *job);
static Job * find_job(int id);
static void free_job(Job *job);

// Callbacks for libuv
static void job_prepare_cb(uv_prepare_t *handle);
static void read_cb(RStream *rstream, void *data, bool eof);
static void exit_cb(uv_process_t *proc, int64_t status, int term_signal);
static void close_cb(uv_handle_t *handle);
static void emit_exit_event(Job *job);

void job_init()
{
  uv_disable_stdio_inheritance();
  uv_prepare_init(uv_default_loop(), &job_prepare);
}

void job_teardown()
{
  // 20 tries will give processes about 1 sec to exit cleanly
  uint32_t remaining_tries = 20;
  bool all_dead = true;
  int i;
  Job *job;

  // Politely ask each job to terminate
  for (i = 0; i < MAX_RUNNING_JOBS; i++) {
    if ((job = table[i]) != NULL) {
      all_dead = false;
      uv_process_kill(&job->proc, SIGTERM);
    }
  }

  if (all_dead) {
    return;
  }

  os_delay(10, 0);
  // Right now any exited process are zombies waiting for us to acknowledge
  // their status with `wait` or handling SIGCHLD. libuv does that
  // automatically (and then calls `exit_cb`) but we have to give it a chance
  // by running the loop one more time
  uv_run(uv_default_loop(), UV_RUN_NOWAIT);

  // Prepare to start shooting
  for (i = 0; i < MAX_RUNNING_JOBS; i++) {
    if ((job = table[i]) == NULL) {
      continue;
    }

    // Still alive
    while (is_alive(job) && remaining_tries--) {
      os_delay(50, 0);
      // Acknowledge child exits
      uv_run(uv_default_loop(), UV_RUN_NOWAIT);
    }

    if (is_alive(job)) {
      uv_process_kill(&job->proc, SIGKILL);
    }
  }
}

int job_start(char **argv,
              void *data,
              rstream_cb stdout_cb,
              rstream_cb stderr_cb,
              job_exit_cb job_exit_cb)
{
  int i;
  Job *job;

  // Search for a free slot in the table
  for (i = 0; i < MAX_RUNNING_JOBS; i++) {
    if (table[i] == NULL) {
      break;
    }
  }

  if (i == MAX_RUNNING_JOBS) {
    // No free slots
    return 0;
  }

  job = xmalloc(sizeof(Job));
  // Initialize
  job->id = i + 1;
  job->pending_refs = 3;
  job->pending_closes = 4;
  job->data = data;
  job->stdout_cb = stdout_cb;
  job->stderr_cb = stderr_cb;
  job->exit_cb = job_exit_cb;
  job->stopped = false;
  job->exit_timeout = EXIT_TIMEOUT;
  job->proc_opts.file = argv[0];
  job->proc_opts.args = argv;
  job->proc_opts.stdio = job->stdio;
  job->proc_opts.stdio_count = 3;
  job->proc_opts.flags = UV_PROCESS_WINDOWS_HIDE;
  job->proc_opts.exit_cb = exit_cb;
  job->proc_opts.cwd = NULL;
  job->proc_opts.env = NULL;

  // Initialize the job std{in,out,err}
  uv_pipe_init(uv_default_loop(), &job->proc_stdin, 0);
  job->proc_stdin.data = job;
  job->stdio[0].flags = UV_CREATE_PIPE | UV_READABLE_PIPE;
  job->stdio[0].data.stream = (uv_stream_t *)&job->proc_stdin;

  uv_pipe_init(uv_default_loop(), &job->proc_stdout, 0);
  job->stdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
  job->stdio[1].data.stream = (uv_stream_t *)&job->proc_stdout;

  uv_pipe_init(uv_default_loop(), &job->proc_stderr, 0);
  job->stdio[2].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
  job->stdio[2].data.stream = (uv_stream_t *)&job->proc_stderr;

  // Spawn the job
  if (uv_spawn(uv_default_loop(), &job->proc, &job->proc_opts) != 0) {
    free_job(job);
    return -1;
  }

  job->in = wstream_new(JOB_WRITE_MAXMEM);
  wstream_set_stream(job->in, (uv_stream_t *)&job->proc_stdin);
  // Start the readable streams
  job->out = rstream_new(read_cb, JOB_BUFFER_SIZE, job, true);
  job->err = rstream_new(read_cb, JOB_BUFFER_SIZE, job, true);
  rstream_set_stream(job->out, (uv_stream_t *)&job->proc_stdout);
  rstream_set_stream(job->err, (uv_stream_t *)&job->proc_stderr);
  rstream_start(job->out);
  rstream_start(job->err);
  // Give the callback a reference to the job
  job->proc.data = job;
  // Save the job to the table
  table[i] = job;

  // Start polling job status if this is the first
  if (job_count == 0) {
    uv_prepare_start(&job_prepare, job_prepare_cb);
  }
  job_count++;

  return job->id;
}

bool job_stop(int id)
{
  Job *job = find_job(id);

  if (job == NULL || job->stopped) {
    return false;
  }

  job->stopped = true;

  return true;
}

bool job_write(int id, char *data, uint32_t len)
{
  Job *job = find_job(id);

  if (job == NULL || job->stopped) {
    free(data);
    return false;
  }

  if (!wstream_write(job->in, data, len, true)) {
    job_stop(job->id);
    return false;
  }

  return true;
}

void job_exit_event(Event event)
{
  Job *job = event.data.job;

  // Free the slot now, 'exit_cb' may want to start another job to replace
  // this one
  table[job->id - 1] = NULL;

  // Invoke the exit callback
  job->exit_cb(job, job->data);

  // Free the job resources
  free_job(job);

  // Stop polling job status if this was the last
  job_count--;
  if (job_count == 0) {
    uv_prepare_stop(&job_prepare);
  }
}

int job_id(Job *job)
{
  return job->id;
}

void *job_data(Job *job)
{
  return job->data;
}

static bool is_alive(Job *job)
{
  return uv_process_kill(&job->proc, 0) == 0;
}

static Job * find_job(int id)
{
  if (id <= 0 || id > MAX_RUNNING_JOBS) {
    return NULL;
  }

  return table[id - 1];
}

static void free_job(Job *job)
{
  uv_close((uv_handle_t *)&job->proc_stdout, close_cb);
  uv_close((uv_handle_t *)&job->proc_stdin, close_cb);
  uv_close((uv_handle_t *)&job->proc_stderr, close_cb);
  uv_close((uv_handle_t *)&job->proc, close_cb);
}

/// Iterates the table, sending SIGTERM to stopped jobs and SIGKILL to those
/// that didn't die from SIGTERM after a while(exit_timeout is 0).
static void job_prepare_cb(uv_prepare_t *handle)
{
  Job *job;
  int i;

  for (i = 0; i < MAX_RUNNING_JOBS; i++) {
    if ((job = table[i]) == NULL || !job->stopped) {
      continue;
    }

    if ((job->exit_timeout--) == EXIT_TIMEOUT) {
      // Job was just stopped, close all stdio handles and send SIGTERM
      uv_process_kill(&job->proc, SIGTERM);
    } else if (job->exit_timeout == 0) {
      // We've waited long enough, send SIGKILL
      uv_process_kill(&job->proc, SIGKILL);
    }
  }
}

// Wraps the call to std{out,err}_cb and emits a JobExit event if necessary.
static void read_cb(RStream *rstream, void *data, bool eof)
{
  Job *job = data;

  if (rstream == job->out) {
    job->stdout_cb(rstream, data, eof);
  } else {
    job->stderr_cb(rstream, data, eof);
  }

  if (eof && --job->pending_refs == 0) {
    emit_exit_event(job);
  }
}

// Emits a JobExit event if both rstreams are closed
static void exit_cb(uv_process_t *proc, int64_t status, int term_signal)
{
  Job *job = proc->data;

  if (--job->pending_refs == 0) {
    emit_exit_event(job);
  }
}

static void emit_exit_event(Job *job)
{
  Event event;
  event.type = kEventJobExit;
  event.data.job = job;
  event_push(event);
}

static void close_cb(uv_handle_t *handle)
{
  Job *job = handle->data;

  if (--job->pending_closes == 0) {
    // Only free the job memory after all the associated handles are properly
    // closed by libuv
    rstream_free(job->out);
    rstream_free(job->err);
    wstream_free(job->in);
    shell_free_argv(job->proc_opts.args);
    free(job->data);
    free(job);
  }
}
