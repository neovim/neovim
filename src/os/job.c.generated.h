static void emit_exit_event(Job *job);
static void close_cb(uv_handle_t *handle);
static void exit_cb(uv_process_t *proc, int64_t status, int term_signal);
static void job_prepare_cb(uv_prepare_t *handle);
static void free_job(Job *job);
static Job * find_job(int id);
static void read_cb(RStream *rstream, void *data, bool eof);
static bool is_alive(Job *job);
