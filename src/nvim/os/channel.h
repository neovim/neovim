#ifndef NVIM_OS_CHANNEL_H
#define NVIM_OS_CHANNEL_H

#include <uv.h>
#include <msgpack.h>

#include "nvim/vim.h"

#define EVENT_MAXLEN 512

void channel_init(void);

void channel_teardown(void);

void channel_from_stream(uv_stream_t *stream);

void channel_from_job(char **argv);

bool channel_send_event(uint64_t id, char *type, typval_T *data);

void channel_subscribe(uint64_t id, char *event);

void channel_unsubscribe(uint64_t id, char *event);

#endif  // NVIM_OS_CHANNEL_H
