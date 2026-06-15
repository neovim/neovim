#include <string.h>

#include "nvim/jobs.h"
#include "nvim/memory.h"
#include "jobs.c.generated.h"

PMap(uint64_t) jobs_map = MAP_INIT;

static void jobs_remove(uint64_t id)
{
  pmap_del(uint64_t)(&jobs_map, id, NULL);
}

void jobs_add(uint64_t id, int pid, const char *cwd,const char* exepath, const char *invoked_by, int64_t start_time)
{
  struct job *job = xcalloc(1, sizeof(*job));
  job->id = id;
  job->pid = pid;
  job->cwd = cwd ? xstrdup(cwd) : NULL;
  job->exepath= exepath ? xstrdup(exepath) : NULL;
  job->invoked_by = invoked_by ? xstrdup(invoked_by) : NULL;
  job->start_time = start_time;
  job->end_time = 0;
  job->exit_status = -1;
  pmap_put(uint64_t)(&jobs_map, id, job);
}

void jobs_update_exit(uint64_t id, int exit_status, int64_t end_time)
{
  struct job *job = jobs_get(id);
  if (job) {
    job->exit_status = exit_status;
    job->end_time = end_time;
  }
}

void jobs_teardown(void)
{
  struct job *job;
  map_foreach_value(&jobs_map, job, {
    xfree((char *)job->cwd);
    xfree((char *)job->exepath);
    xfree((char *)job->invoked_by);
    xfree(job);
  });
  map_clear(uint64_t, &jobs_map);
}

void jobs_free_all_mem(void)
{
  struct job *job;
  map_foreach_value(&jobs_map, job, {
    xfree((char *)job->cwd);
    xfree((char *)job->exepath);
    xfree((char *)job->invoked_by);
    xfree(job);
  });
  map_destroy(uint64_t, &jobs_map);
}
