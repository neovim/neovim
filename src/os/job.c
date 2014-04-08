#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "os/job.h"
#include "os/job_defs.h"
#include "os/time.h"
#include "os/shell.h"
#include "vim.h"
#include "memory.h"
#include "term.h"

#define EXIT_TIMEOUT 25
#define MAX_RUNNING_JOBS 100
#define JOB_BUFFER_SIZE 1024

/// Possible lock states of the job buffer
typedef enum {
  kBufferLockNone = 0,  ///< No data was read
  kBufferLockStdout,    ///< Data read from stdout
  kBufferLockStderr     ///< Data read from stderr
} BufferLock;

struct job {
  // Job id the index in the job table plus one.
  int id;
  // Number of polls after a SIGTERM that will trigger a SIGKILL
  int exit_timeout;
  // If the job was already stopped
  bool stopped;
  // Data associated with the job
  void *data;
  // Buffer for reading from stdout or stderr
  char buffer[JOB_BUFFER_SIZE];
  // Size of the data from the last read
  uint32_t length;
  // Buffer lock state
  BufferLock lock;
  // Callback for consuming data from the buffer
  job_read_cb read_cb;
  // Structures for process spawning/management used by libuv
  uv_process_t proc;
  uv_process_options_t proc_opts;
  uv_stdio_container_t stdio[3];
  uv_pipe_t proc_stdin, proc_stdout, proc_stderr;
};

static Job *table[MAX_RUNNING_JOBS] = {NULL};
static uv_prepare_t job_prepare;

// Some helpers shared in this module
static bool is_alive(Job *job);
static Job * find_job(int id);
static void free_job(Job *job);

// Callbacks for libuv
static void job_prepare_cb(uv_prepare_t *handle, int status);
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf);
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf);
static void write_cb(uv_write_t *req, int status);
static void exit_cb(uv_process_t *proc, int64_t status, int term_signal);

void job_init()
{
  uv_disable_stdio_inheritance();
  uv_prepare_init(uv_default_loop(), &job_prepare);
  uv_prepare_start(&job_prepare, job_prepare_cb);
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

int job_start(char **argv, void *data, job_read_cb cb)
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
  job->data = data;
  job->read_cb = cb;
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
  job->proc_stdout.data = job;
  job->stdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
  job->stdio[1].data.stream = (uv_stream_t *)&job->proc_stdout;

  uv_pipe_init(uv_default_loop(), &job->proc_stderr, 0);
  job->proc_stderr.data = job;
  job->stdio[2].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
  job->stdio[2].data.stream = (uv_stream_t *)&job->proc_stderr;

  // Spawn the job
  if (uv_spawn(uv_default_loop(), &job->proc, &job->proc_opts) != 0) {
    free_job(job);
    return -1;
  }

  // Start the readable streams
  uv_read_start((uv_stream_t *)&job->proc_stdout, alloc_cb, read_cb);
  uv_read_start((uv_stream_t *)&job->proc_stderr, alloc_cb, read_cb);
  // Give the callback a reference to the job
  job->proc.data = job;
  // Save the job to the table
  table[i] = job;

  return job->id;
}

bool job_stop(int id)
{
  Job *job = find_job(id);

  if (job == NULL || job->stopped) {
    return false;
  }

  uv_read_stop((uv_stream_t *)&job->proc_stdout);
  uv_read_stop((uv_stream_t *)&job->proc_stderr);
  job->stopped = true;

  return true;
}

bool job_write(int id, char *data, uint32_t len)
{
  uv_buf_t uvbuf;
  uv_write_t *req;
  Job *job = find_job(id);

  if (job == NULL || job->stopped) {
    free(data);
    return false;
  }

  req = xmalloc(sizeof(uv_write_t));
  req->data = data;
  uvbuf.base = data;
  uvbuf.len = len;
  uv_write(req, (uv_stream_t *)&job->proc_stdin, &uvbuf, 1, write_cb);

  return true;
}

void job_handle(Event event)
{
  Job *job = event.data.job;

  // Invoke the job callback
  job->read_cb(job->id,
               job->data,
               job->buffer,
               job->length,
               job->lock == kBufferLockStdout);

  // restart reading
  job->lock = kBufferLockNone;
  uv_read_start((uv_stream_t *)&job->proc_stdout, alloc_cb, read_cb);
  uv_read_start((uv_stream_t *)&job->proc_stderr, alloc_cb, read_cb);
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
  uv_close((uv_handle_t *)&job->proc_stdout, NULL);
  uv_close((uv_handle_t *)&job->proc_stdin, NULL);
  uv_close((uv_handle_t *)&job->proc_stderr, NULL);
  uv_close((uv_handle_t *)&job->proc, NULL);
  free(job);
}

/// Iterates the table, sending SIGTERM to stopped jobs and SIGKILL to those
/// that didn't die from SIGTERM after a while(exit_timeout is 0).
static void job_prepare_cb(uv_prepare_t *handle, int status)
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

/// Puts the job into a 'reading state' which 'locks' the job buffer
/// until the data is consumed
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  Job *job = (Job *)handle->data;

  if (job->lock != kBufferLockNone) {
    // Already reserved the buffer for reading from stdout or stderr.
    buf->len = 0;
    return;
  }

  buf->base = job->buffer;
  buf->len = JOB_BUFFER_SIZE;
  // Avoid `alloc_cb`, `alloc_cb` sequences on windows and also mark which
  // stream we are reading from
  job->lock =
    (handle == (uv_handle_t *)&job->proc_stdout) ?
    kBufferLockStdout :
    kBufferLockStderr;
}

/// Pushes a event object to the event queue, which will be handled later by
/// `job_handle`
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf)
{
  Event event;
  Job *job = (Job *)stream->data;
  // pause reading on both streams
  uv_read_stop((uv_stream_t *)&job->proc_stdout);
  uv_read_stop((uv_stream_t *)&job->proc_stderr);

  if (cnt <= 0) {
    if (cnt != UV_ENOBUFS) {
      // Assume it's EOF and exit the job. Doesn't harm sending a SIGTERM
      // at this point
      uv_process_kill(&job->proc, SIGTERM);
    }
    return;
  }

  job->length = cnt;
  event.type = kEventJobActivity;
  event.data.job = job;
  event_push(event);
}

static void write_cb(uv_write_t *req, int status)
{
  free(req->data);
  free(req);
}

/// Cleanup all the resources associated with the job
static void exit_cb(uv_process_t *proc, int64_t status, int term_signal)
{
  Job *job = proc->data;

  table[job->id - 1] = NULL;
  shell_free_argv(job->proc_opts.args);
  free_job(job);
}

