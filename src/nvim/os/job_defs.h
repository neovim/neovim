#ifndef NEOVIM_OS_JOB_DEFS_H
#define NEOVIM_OS_JOB_DEFS_H

#include "os/rstream_defs.h"

typedef struct job Job;

/// Function called when the job reads data
///
/// @param id The job id
/// @param data Some data associated with the job by the caller
typedef void (*job_exit_cb)(Job *job, void *data);

#endif  // NEOVIM_OS_JOB_DEFS_H

