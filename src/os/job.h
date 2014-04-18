// Job is a short name we use to refer to child processes that run in parallel
// with the editor, probably executing long-running tasks and sending updates
// asynchronously. Communication happens through anonymous pipes connected to
// the job's std{in,out,err}. They are more like bash/zsh co-processes than the
// usual shell background job. The name 'Job' was chosen because it applies to
// the concept while being significantly shorter.
#ifndef NEOVIM_OS_JOB_H
#define NEOVIM_OS_JOB_H

#include <stdint.h>
#include <stdbool.h>

#include "os/event_defs.h"
#include "os/rstream_defs.h"

/// Initializes job control resources
void job_init(void);

/// Releases job control resources and terminates running jobs
void job_teardown(void);

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
/// @return The job id if the job started successfully. If the the first item /
///         of `argv`(the program) could not be executed, -1 will be returned.
//          0 will be returned if the job table is full.
int job_start(char **argv,
              void *data,
              rstream_cb stdout_cb,
              rstream_cb stderr_cb,
              job_exit_cb exit_cb);

/// Terminates a job. This is a non-blocking operation, but if the job exists
/// it's guaranteed to succeed(SIGKILL will eventually be sent)
///
/// @param id The job id
/// @return true if the stop request was successfully sent, false if the job
///              id is invalid(probably because it has already stopped)
bool job_stop(int id);

/// Writes data to the job's stdin. This is a non-blocking operation, it
/// returns when the write request was sent.
///
/// @param id The job id
/// @param data Buffer containing the data to be written
/// @param len Size of the data
/// @return true if the write request was successfully sent, false if the job
///              id is invalid(probably because it has already stopped)
bool job_write(int id, char *data, uint32_t len);

/// Runs the read callback associated with the job exit event
///
/// @param event Object containing data necessary to invoke the callback
void job_exit_event(Event event);

/// Get the job id
///
/// @param job A pointer to the job
/// @return The job id
int job_id(Job *job);

/// Get data associated with a job
///
/// @param job A pointer to the job
/// @return The job data
void *job_data(Job *job);

#endif  // NEOVIM_OS_JOB_H

