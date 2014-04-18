#ifndef NEOVIM_OS_WSTREAM_H
#define NEOVIM_OS_WSTREAM_H

#include <stdint.h>
#include <stdbool.h>
#include <uv.h>

#include "os/wstream_defs.h"

/// Creates a new WStream instance. A WStream encapsulates all the boilerplate
/// necessary for writing to a libuv stream.
///
/// @param maxmem Maximum amount memory used by this `WStream` instance.
/// @return The newly-allocated `WStream` instance
WStream * wstream_new(uint32_t maxmem);

/// Frees all memory allocated for a WStream instance
///
/// @param wstream The `WStream` instance
void wstream_free(WStream *wstream);

/// Sets the underlying `uv_stream_t` instance
///
/// @param wstream The `WStream` instance
/// @param stream The new `uv_stream_t` instance
void wstream_set_stream(WStream *wstream, uv_stream_t *stream);

/// Queues data for writing to the backing file descriptor of a `WStream`
/// instance. This will fail if the write would cause the WStream use more
/// memory than specified by `maxmem`.
///
/// @param wstream The `WStream` instance
/// @param buffer The buffer which contains data to be written
/// @param length Number of bytes that should be written from `buffer`
/// @param free If true, `buffer` will be freed after the write is complete
/// @return true if the data was successfully queued, false otherwise.
bool wstream_write(WStream *wstream, char *buffer, uint32_t length, bool free);

#endif  // NEOVIM_OS_WSTREAM_H

