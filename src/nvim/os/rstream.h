#ifndef NVIM_OS_RSTREAM_H
#define NVIM_OS_RSTREAM_H

#include <stdbool.h>
#include <stdint.h>
#include <uv.h>

#include "nvim/os/event_defs.h"
#include "nvim/os/rstream_defs.h"

RStream * rstream_new(rstream_cb cb,
                      size_t buffer_size,
                      void *data,
                      bool async);

void rstream_free(RStream *rstream);

void rstream_set_stream(RStream *rstream, uv_stream_t *stream);

void rstream_set_file(RStream *rstream, uv_file file);

bool rstream_is_regular_file(RStream *rstream);

void rstream_start(RStream *rstream);

void rstream_stop(RStream *rstream);

size_t rstream_read(RStream *rstream, char *buffer, size_t count);

size_t rstream_available(RStream *rstream);

void rstream_read_event(Event event);

#endif  // NVIM_OS_RSTREAM_H

