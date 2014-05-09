// Job is a short name we use to refer to child processes that run in parallel
// with the editor, probably executing long-running tasks and sending updates
// asynchronously. Communication happens through anonymous pipes connected to
// the job's std{in,out,err}. They are more like bash/zsh co-processes than the
// usual shell background job. The name 'Job' was chosen because it applies to
// the concept while being significantly shorter.
#ifndef NVIM_OS_JOB_H
#define NVIM_OS_JOB_H

#include <stdint.h>
#include <stdbool.h>

#include "nvim/os/event_defs.h"
#include "nvim/os/rstream_defs.h"

void job_init(void);

void job_teardown(void);

int job_start(char **argv,
              void *data,
              rstream_cb stdout_cb,
              rstream_cb stderr_cb,
              job_exit_cb exit_cb);

bool job_stop(int id);

bool job_write(int id, char *data, uint32_t len);

void job_exit_event(Event event);

int job_id(Job *job);

void *job_data(Job *job);

#endif  // NVIM_OS_JOB_H

