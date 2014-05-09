#ifndef NVIM_OS_WSTREAM_H
#define NVIM_OS_WSTREAM_H

#include <stdint.h>
#include <stdbool.h>
#include <uv.h>

#include "nvim/os/wstream_defs.h"

WStream * wstream_new(size_t maxmem);

void wstream_free(WStream *wstream);

void wstream_set_stream(WStream *wstream, uv_stream_t *stream);

bool wstream_write(WStream *wstream, WBuffer *buffer);

WBuffer *wstream_new_buffer(char *data, size_t size, bool copy);

#endif  // NVIM_OS_WSTREAM_H

