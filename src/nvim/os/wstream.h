#ifndef NVIM_OS_WSTREAM_H
#define NVIM_OS_WSTREAM_H

#include <stdint.h>
#include <stdbool.h>
#include <uv.h>

#include "nvim/os/wstream_defs.h"

/// Creates a new WStream instance. A WStream encapsulates all the boilerplate
/// necessary for writing to a libuv stream.
///
/// @param maxmem Maximum amount memory used by this `WStream` instance.
/// @return The newly-allocated `WStream` instance
WStream * wstream_new(size_t maxmem);

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
/// @return false if the write failed
bool wstream_write(WStream *wstream, WBuffer *buffer);

/// Creates a WBuffer object for holding output data. Instances of this
/// object can be reused across WStream instances, and the memory is freed
/// automatically when no longer needed(it tracks the number of references
/// internally)
///
/// @param data Data stored by the WBuffer
/// @param size The size of the data array
/// @param copy If true, the data will be copied into the WBuffer
/// @return The allocated WBuffer instance
WBuffer *wstream_new_buffer(char *data, size_t size, bool copy);

#endif  // NVIM_OS_WSTREAM_H

