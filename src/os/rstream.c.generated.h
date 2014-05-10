static void close_cb(uv_handle_t *handle);
static void fread_idle_cb(uv_idle_t *);
static void read_cb(uv_stream_t *, ssize_t, const uv_buf_t *);
static void alloc_cb(uv_handle_t *, size_t, uv_buf_t *);
static void emit_read_event(RStream *rstream, bool eof);
