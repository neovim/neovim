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

#include "nvim/os/rstream_defs.h"
#include "nvim/os/event_defs.h"
#include "nvim/os/wstream.h"
#include "nvim/os/wstream_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/job.h.generated.h"
#endif
#endif  // NVIM_OS_JOB_H
