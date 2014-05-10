void *job_data(Job *job);
int job_id(Job *job);
void job_exit_event(Event event);
int job_start(char **argv,
              void *data,
              rstream_cb stdout_cb,
              rstream_cb stderr_cb,
              job_exit_cb exit_cb);
void job_teardown(void);
void job_init(void);
bool job_stop(int id);
bool job_write(int id, char *data, uint32_t len);
