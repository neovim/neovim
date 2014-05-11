#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
RStream *rstream_new(rstream_cb cb, uint32_t buffer_size, void *data, _Bool async);
void rstream_free(RStream *rstream);
void rstream_set_stream(RStream *rstream, uv_stream_t *stream);
void rstream_set_file(RStream *rstream, uv_file file);
_Bool rstream_is_regular_file(RStream *rstream);
void rstream_start(RStream *rstream);
void rstream_stop(RStream *rstream);
size_t rstream_read(RStream *rstream, char *buf, uint32_t count);
size_t rstream_available(RStream *rstream);
void rstream_read_event(Event event);
#include "func_attr.h"
