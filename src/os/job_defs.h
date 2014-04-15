#ifndef NEOVIM_OS_JOB_DEFS_H
#define NEOVIM_OS_JOB_DEFS_H

#include "os/rstream_defs.h"

typedef struct job Job;

/// Function called when the job reads data
///
/// @param id The job id
/// @param data Some data associated with the job by the caller
/// @param target The `RStream` instance containing data to be read
/// @param from_stdout This is true if data was read from the job's stdout,
///        false if it came from stderr.
typedef void (*job_read_cb)(int id,
                            void *data,
                            RStream *target,
                            bool from_stdout);

#endif  // NEOVIM_OS_JOB_DEFS_H

