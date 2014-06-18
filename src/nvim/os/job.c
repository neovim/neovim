#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/os/uv_helpers.h"
#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/os/rstream.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/wstream.h"
#include "nvim/os/wstream_defs.h"
#include "nvim/os/event.h"
#include "nvim/os/event_defs.h"
#include "nvim/os/time.h"
#include "nvim/os/shell.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/term.h"

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
  bool defer;
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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/job.c.generated.h"
#endif
// Callbacks for libuv

/// Initializes job control resources
void job_init()
{
  uv_disable_stdio_inheritance();
  uv_prepare_init(uv_default_loop(), &job_prepare);
}

/// Releases job control resources and terminates running jobs
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

/// Tries to start a new job.
///
/// @param argv Argument vector for the process. The first item is the
///        executable to run.
/// @param data Caller data that will be associated with the job
/// @param stdout_cb Callback that will be invoked when data is available
///        on stdout
/// @param stderr_cb Callback that will be invoked when data is available
///        on stderr
/// @param exit_cb Callback that will be invoked when the job exits
/// @param defer If the job callbacks invocation should be deferred to vim
///         main loop
/// @param[out] The job id if the job started successfully, 0 if the job table
///             is full, -1 if the program could not be executed.
/// @return The job pointer if the job started successfully, NULL otherwise
Job *job_start(char **argv,
               void *data,
               rstream_cb stdout_cb,
               rstream_cb stderr_cb,
               job_exit_cb job_exit_cb,
               bool defer,
               int *status)
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
    *status = 0;
    return NULL;
  }

  job = xmalloc(sizeof(Job));
  // Initialize
  job->id = i + 1;
  *status = job->id;
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
  job->proc.data = NULL;
  job->proc_stdin.data = NULL;
  job->proc_stdout.data = NULL;
  job->proc_stderr.data = NULL;
  job->defer = defer;

  // Initialize the job std{in,out,err}
  uv_pipe_init(uv_default_loop(), &job->proc_stdin, 0);
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
    *status = -1;
    return NULL;
  }

  // Give all handles a reference to the job
  handle_set_job((uv_handle_t *)&job->proc, job);
  handle_set_job((uv_handle_t *)&job->proc_stdin, job);
  handle_set_job((uv_handle_t *)&job->proc_stdout, job);
  handle_set_job((uv_handle_t *)&job->proc_stderr, job);

  job->in = wstream_new(JOB_WRITE_MAXMEM);
  wstream_set_stream(job->in, (uv_stream_t *)&job->proc_stdin);
  // Start the readable streams
  job->out = rstream_new(read_cb, JOB_BUFFER_SIZE, job, defer);
  job->err = rstream_new(read_cb, JOB_BUFFER_SIZE, job, defer);
  rstream_set_stream(job->out, (uv_stream_t *)&job->proc_stdout);
  rstream_set_stream(job->err, (uv_stream_t *)&job->proc_stderr);
  rstream_start(job->out);
  rstream_start(job->err);
  // Save the job to the table
  table[i] = job;

  // Start polling job status if this is the first
  if (job_count == 0) {
    uv_prepare_start(&job_prepare, job_prepare_cb);
  }
  job_count++;

  return job;
}

/// Finds a job instance by id
///
/// @param id The job id
/// @return the Job instance
Job *job_find(int id)
{
  Job *job;

  if (id <= 0 || id > MAX_RUNNING_JOBS || !(job = table[id - 1])
      || job->stopped) {
    return NULL;
  }

  return job;
}

/// Terminates a job. This is a non-blocking operation, but if the job exists
/// it's guaranteed to succeed(SIGKILL will eventually be sent)
///
/// @param job The Job instance
void job_stop(Job *job)
{
  job->stopped = true;
}

/// Writes data to the job's stdin. This is a non-blocking operation, it
/// returns when the write request was sent.
///
/// @param job The Job instance
/// @param buffer The buffer which contains the data to be written
/// @return true if the write request was successfully sent, false if writing
///         to the job stream failed (possibly because the OS buffer is full)
bool job_write(Job *job, WBuffer *buffer)
{
  return wstream_write(job->in, buffer);
}

/// Sets the `defer` flag for a Job instance
///
/// @param rstream The Job id
/// @param defer The new value for the flag
void job_set_defer(Job *job, bool defer)
{
  job->defer = defer;
  rstream_set_defer(job->out, defer);
  rstream_set_defer(job->err, defer);
}


/// Runs the read callback associated with the job exit event
///
/// @param event Object containing data necessary to invoke the callback
void job_exit_event(Event event)
{
  job_exit_callback(event.data.job);
}

/// Get the job id
///
/// @param job A pointer to the job
/// @return The job id
int job_id(Job *job)
{
  return job->id;
}

/// Get data associated with a job
///
/// @param job A pointer to the job
/// @return The job data
void *job_data(Job *job)
{
  return job->data;
}

static void job_exit_callback(Job *job)
{
  // Free the slot now, 'exit_cb' may want to start another job to replace
  // this one
  table[job->id - 1] = NULL;

  if (job->exit_cb) {
    // Invoke the exit callback
    job->exit_cb(job, job->data);
  }

  // Free the job resources
  free_job(job);

  // Stop polling job status if this was the last
  job_count--;
  if (job_count == 0) {
    uv_prepare_stop(&job_prepare);
  }
}

static bool is_alive(Job *job)
{
  return uv_process_kill(&job->proc, 0) == 0;
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
  Job *job = handle_get_job((uv_handle_t *)proc);

  if (--job->pending_refs == 0) {
    emit_exit_event(job);
  }
}

static void emit_exit_event(Job *job)
{
  Event event;
  event.type = kEventJobExit;
  event.data.job = job;
  event_push(event, true);
}

static void close_cb(uv_handle_t *handle)
{
  Job *job = handle_get_job(handle);

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
