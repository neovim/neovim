#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static InbufPollResult inbuf_poll(int32_t ms);
static void stderr_switch();
static void read_cb(RStream *rstream, void *data, _Bool at_eof);
static int push_event_key(uint8_t *buf, int maxlen);
#include "func_attr.h"
