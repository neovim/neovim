#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf);
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf);
static void fread_idle_cb(uv_idle_t *handle);
static void close_cb(uv_handle_t *handle);
static void emit_read_event(RStream *rstream, _Bool eof);
#include "func_attr.h"
