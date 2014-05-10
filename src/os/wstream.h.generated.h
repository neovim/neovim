void wstream_set_stream(WStream *wstream, uv_stream_t *stream);
void wstream_free(WStream *wstream);
WStream * wstream_new(uint32_t maxmem);
bool wstream_write(WStream *wstream, char *buffer, uint32_t length, bool free);
