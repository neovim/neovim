void rstream_read_event(Event event);
void rstream_stop(RStream *rstream);
void rstream_start(RStream *rstream);
void rstream_set_file(RStream *rstream, uv_file file);
void rstream_set_stream(RStream *rstream, uv_stream_t *stream);
void rstream_free(RStream *rstream);
RStream * rstream_new(rstream_cb cb,
                      uint32_t buffer_size,
                      void *data,
                      bool async);
bool rstream_is_regular_file(RStream *rstream);
size_t rstream_read(RStream *rstream, char *buffer, uint32_t count);
size_t rstream_available(RStream *rstream);
