#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
WStream *wstream_new(uint32_t maxmem);
void wstream_free(WStream *wstream);
void wstream_set_stream(WStream *wstream, uv_stream_t *stream);
_Bool wstream_write(WStream *wstream, char *buffer, uint32_t length, _Bool free);
#include "func_attr.h"
