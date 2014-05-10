static void exit_cb(uv_process_t *proc, int64_t status, int term_signal);
static void write_cb(uv_write_t *req, int status);
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf);
static int proc_cleanup_exit(ProcessData *data,
                             uv_process_options_t *opts,
                             int shellopts);
static void write_selection(uv_write_t *req);
static int word_length(char_u *command);
static int tokenize(char_u *str, char **argv);
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf);
