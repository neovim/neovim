#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
void job_init();
void job_teardown();
int job_start(char **argv, void *data, rstream_cb stdout_cb, rstream_cb stderr_cb, job_exit_cb job_exit_cb);
_Bool job_stop(int id);
_Bool job_write(int id, char *data, uint32_t len);
void job_exit_event(Event event);
int job_id(Job *job);
void *job_data(Job *job);
#include "func_attr.h"
