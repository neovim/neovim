#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/os/uv_helpers.h"
#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/os/job_private.h"
#include "nvim/os/pty_process.h"
#include "nvim/os/rstream.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/wstream.h"
#include "nvim/os/wstream_defs.h"
#include "nvim/os/event.h"
#include "nvim/os/event_defs.h"
#include "nvim/os/time.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

// {SIGNAL}_TIMEOUT is the time (in nanoseconds) that a job has to cleanly exit
// before we send SIGNAL to it
#define TERM_TIMEOUT 1000000000
#define KILL_TIMEOUT (TERM_TIMEOUT * 2)
#define MAX_RUNNING_JOBS 100
#define JOB_BUFFER_SIZE 0xFFFF

#define close_job_stream(job, stream, type)                                \
  do {                                                                     \
    if (job->stream) {                                                     \
      type##stream_free(job->stream);                                      \
      job->stream = NULL;                                                  \
      if (!uv_is_closing((uv_handle_t *)job->proc_std##stream)) {          \
        uv_close((uv_handle_t *)job->proc_std##stream, close_cb);          \
      }                                                                    \
    }                                                                      \
  } while (0)

#define close_job_in(job) close_job_stream(job, in, w)
#define close_job_out(job) close_job_stream(job, out, r)
#define close_job_err(job) close_job_stream(job, err, r)

Job *table[MAX_RUNNING_JOBS] = {NULL};
size_t stop_requests = 0;
uv_timer_t job_stop_timer;

// Some helpers shared in this module

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/job.c.generated.h"
#endif
// Callbacks for libuv

/// Initializes job control resources
void job_init(void)
{
  uv_disable_stdio_inheritance();
  uv_timer_init(uv_default_loop(), &job_stop_timer);
}

/// Releases job control resources and terminates running jobs
void job_teardown(void)
{
  // Stop all jobs
  for (int i = 0; i < MAX_RUNNING_JOBS; i++) {
    Job *job;
    if ((job = table[i]) != NULL) {
      uv_kill(job->pid, SIGTERM);
      job->term_sent = true;
      job_stop(job);
    }
  }

  // Wait until all jobs are closed
  event_poll_until(-1, !stop_requests);
  // Close the timer
  uv_close((uv_handle_t *)&job_stop_timer, NULL);
}

/// Tries to start a new job.
///
/// @param[out] status The job id if the job started successfully, 0 if the job
///             table is full, -1 if the program could not be executed.
/// @return The job pointer if the job started successfully, NULL otherwise
Job *job_start(JobOptions opts, int *status)
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
    shell_free_argv(opts.argv);
    *status = 0;
    return NULL;
  }

  job = xmalloc(sizeof(Job));
  // Initialize
  job->id = i + 1;
  *status = job->id;
  job->status = -1;
  job->refcount = 1;
  job->stopped_time = 0;
  job->term_sent = false;
  job->in = NULL;
  job->out = NULL;
  job->err = NULL;
  job->opts = opts;
  job->closed = false;

  process_init(job);

  if (opts.writable) {
    handle_set_job((uv_handle_t *)job->proc_stdin, job);
    job->refcount++;
  }

  if (opts.stdout_cb) {
    handle_set_job((uv_handle_t *)job->proc_stdout, job);
    job->refcount++;
  }

  if (opts.stderr_cb) {
    handle_set_job((uv_handle_t *)job->proc_stderr, job);
    job->refcount++;
  }

  // Spawn the job
  if (!process_spawn(job)) {
    if (opts.writable) {
      uv_close((uv_handle_t *)&job->proc_stdin, close_cb);
    }
    if (opts.stdout_cb) {
      uv_close((uv_handle_t *)&job->proc_stdout, close_cb);
    }
    if (opts.stderr_cb) {
      uv_close((uv_handle_t *)&job->proc_stderr, close_cb);
    }
    process_close(job);
    event_poll(0);
    // Manually invoke the close_cb to free the job resources
    *status = -1;
    return NULL;
  }

  if (opts.writable) {
    job->in = wstream_new(opts.maxmem);
    wstream_set_stream(job->in, job->proc_stdin);
  }

  // Start the readable streams
  if (opts.stdout_cb) {
    job->out = rstream_new(read_cb, rbuffer_new(JOB_BUFFER_SIZE), job);
    rstream_set_stream(job->out, job->proc_stdout);
    rstream_start(job->out);
  }

  if (opts.stderr_cb) {
    job->err = rstream_new(read_cb, rbuffer_new(JOB_BUFFER_SIZE), job);
    rstream_set_stream(job->err, job->proc_stderr);
    rstream_start(job->err);
  }
  // Save the job to the table
  table[i] = job;

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
      || job->stopped_time) {
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
  if (job->stopped_time) {
    return;
  }

  job->stopped_time = os_hrtime();
  // Close the job's stdin. If the job doesn't close it's own stdout/stderr,
  // they will be closed when the job exits(possibly due to being terminated
  // after a timeout)
  close_job_in(job);

  if (!stop_requests++) {
    // When there's at least one stop request pending, start a timer that
    // will periodically check if a signal should be send to a to the job
    DLOG("Starting job kill timer");
    uv_timer_start(&job_stop_timer, job_stop_timer_cb, 100, 100);
  }
}

/// job_wait - synchronously wait for a job to finish
///
/// @param job The job instance
/// @param ms Number of milliseconds to wait, 0 for not waiting, -1 for
///        waiting until the job quits.
/// @return returns the status code of the exited job. -1 if the job is
///         still running and the `timeout` has expired. Note that this is
///         indistinguishable from the process returning -1 by itself. Which
///         is possible on some OS.
int job_wait(Job *job, int ms) FUNC_ATTR_NONNULL_ALL
{
  // The default status is -1, which represents a timeout
  int status = -1;

  // Increase refcount to stop the job from being freed before we have a
  // chance to get the status.
  job->refcount++;
  event_poll_until(ms,
      // Until...
      got_int ||                // interrupted by the user
      job->refcount == 1);  // job exited

  // we'll assume that a user frantically hitting interrupt doesn't like
  // the current job. Signal that it has to be killed.
  if (got_int) {
    got_int = false;
    job_stop(job);
    if (ms == -1) {
      // We can only return, if all streams/handles are closed and the job
      // exited.
      event_poll_until(-1, job->refcount == 1);
    } else {
      event_poll(0);
    }
  }

  if (job->refcount == 1) {
    // Job exited, collect status and manually invoke close_cb to free the job
    // resources
    status = job->status;
    job_close_streams(job);
    job_decref(job);
  } else {
    job->refcount--;
  }

  return status;
}

/// Close the pipe used to write to the job.
///
/// This can be used for example to indicate to the job process that no more
/// input is coming, and that it should shut down cleanly.
///
/// It has no effect when the input pipe doesn't exist or was already
/// closed.
///
/// @param job The job instance
void job_close_in(Job *job) FUNC_ATTR_NONNULL_ALL
{
  close_job_in(job);
}

/// All writes that complete after calling this function will be reported
/// to `cb`.
///
/// Use this function to be notified about the status of an in-flight write.
///
/// @see {wstream_set_write_cb}
///
/// @param job The job instance
/// @param cb The function that will be called on write completion or
///        failure. It will be called with the job as the `data` argument.
void job_write_cb(Job *job, wstream_cb cb) FUNC_ATTR_NONNULL_ALL
{
  wstream_set_write_cb(job->in, cb, job);
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
  return job->opts.data;
}

/// Resize the window for a pty job
bool job_resize(Job *job, uint16_t width, uint16_t height)
{
  if (!job->opts.pty) {
    return false;
  }
  pty_process_resize(job, width, height);
  return true;
}

/// Iterates the table, sending SIGTERM to stopped jobs and SIGKILL to those
/// that didn't die from SIGTERM after a while(exit_timeout is 0).
static void job_stop_timer_cb(uv_timer_t *handle)
{
  Job *job;
  uint64_t now = os_hrtime();

  for (size_t i = 0; i < MAX_RUNNING_JOBS; i++) {
    if ((job = table[i]) == NULL || !job->stopped_time) {
      continue;
    }

    uint64_t elapsed = now - job->stopped_time;

    if (!job->term_sent && elapsed >= TERM_TIMEOUT) {
      ILOG("Sending SIGTERM to job(id: %d)", job->id);
      uv_kill(job->pid, SIGTERM);
      job->term_sent = true;
    } else if (elapsed >= KILL_TIMEOUT) {
      ILOG("Sending SIGKILL to job(id: %d)", job->id);
      uv_kill(job->pid, SIGKILL);
      process_close(job);
    }
  }
}

// Wraps the call to std{out,err}_cb and emits a JobExit event if necessary.
static void read_cb(RStream *rstream, void *data, bool eof)
{
  Job *job = data;

  if (rstream == job->out) {
    job->opts.stdout_cb(rstream, data, eof);
    if (eof) {
      close_job_out(job);
    }
  } else {
    job->opts.stderr_cb(rstream, data, eof);
    if (eof) {
      close_job_err(job);
    }
  }
}

void job_close_streams(Job *job)
{
  close_job_in(job);
  close_job_out(job);
  close_job_err(job);
}

static void close_cb(uv_handle_t *handle)
{
  job_decref(handle_get_job(handle));
}
