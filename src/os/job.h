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

#include "os/event.h"

/// Function called when the job reads data
///
/// @param id The job is
/// @param data Some data associated with the job by the caller
/// @param buffer Buffer containing the data read. It must be copied
///        immediately.
/// @param len Amount of bytes that must be read from `buffer`
/// @param from_stdout This is true if data was read from the job's stdout,
///        false if it came from stderr.
typedef void (*job_read_cb)(int id,
                            void *data,
                            char *buffer,
                            uint32_t len,
                            bool from_stdout);

/// Initializes job control resources
void job_init(void);

/// Releases job control resources and terminates running jobs
void job_teardown(void);

/// Tries to start a new job.
///
/// @param argv Argument vector for the process. The first item is the
///        executable to run.
/// @param data Caller data that will be associated with the job
/// @param cb Callback that will be invoked everytime data is available in
///        the job's stdout/stderr
/// @return The job id if the job started successfully. If the the first item /
///         of `argv`(the program) could not be executed, -1 will be returned.
//          0 will be returned if the job table is full.
int job_start(char **argv, void *data, job_read_cb cb);

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

/// Runs the read callback associated with the job/event
///
/// @param event Object containing data necessary to invoke the callback
void job_handle(Event event);

#endif  // NEOVIM_OS_JOB_H

