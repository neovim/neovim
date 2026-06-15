#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/event/defs.h"
#include "nvim/map_defs.h"

struct job {
  uint64_t id;          ///< Channel id
  int pid;
  const char *cwd;      
  const char *exepath;      
  const char *invoked_by;
  int64_t start_time;
  int64_t end_time;     ///< Set on exit; 0 if still running
  int exit_status;      ///< -1 if still running
};

#include "jobs.h.generated.h"

EXTERN PMap(uint64_t) jobs_map INIT( = MAP_INIT);

static inline struct job *jobs_get(uint64_t id)
{
  return (struct job *)pmap_get(uint64_t)(&jobs_map, id);
}
