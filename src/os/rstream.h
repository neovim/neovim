#ifndef NEOVIM_OS_RSTREAM_H
#define NEOVIM_OS_RSTREAM_H

#include <stdbool.h>
#include <stdint.h>
#include <uv.h>

#include "os/rstream_defs.h"

/// Creates a new RStream instance. A RStream encapsulates all the boilerplate
/// necessary for reading from a libuv stream.
///
/// @param cb A function that will be called whenever some data is available
///        for reading with `rstream_read`
/// @param buffer_size Size in bytes of the internal buffer.
/// @param data Some state to associate with the `RStream` instance
/// @return The newly-allocated `RStream` instance
RStream * rstream_new(rstream_cb cb, uint32_t buffer_size, void *data);

/// Frees all memory allocated for a RStream instance
///
/// @param rstream The `RStream` instance
void rstream_free(RStream *rstream);

/// Sets the underlying `uv_stream_t` instance
///
/// @param rstream The `RStream` instance
/// @param stream The new `uv_stream_t` instance
void rstream_set_stream(RStream *rstream, uv_stream_t *stream);

/// Sets the underlying `uv_file_t` instance
///
/// @param rstream The `RStream` instance
/// @param stream The new `uv_stream_t` instance
void rstream_set_stream(RStream *rstream, uv_stream_t *stream);

/// Sets the underlying file descriptor that will be read from. Only pipes
/// and regular files are supported for now.
///
/// @param rstream The `RStream` instance
/// @param file The file descriptor
void rstream_set_file(RStream *rstream, uv_file file);

/// Tests if the stream is backed by a regular file
///
/// @param rstream The `RStream` instance
/// @return True if the underlying file descriptor represents a regular file
bool rstream_is_regular_file(RStream *rstream);

/// Starts watching for events from a `RStream` instance.
///
/// @param rstream The `RStream` instance
void rstream_start(RStream *rstream);

/// Stops watching for events from a `RStream` instance.
///
/// @param rstream The `RStream` instance
void rstream_stop(RStream *rstream);

/// Reads data from a `RStream` instance into a buffer.
///
/// @param rstream The `RStream` instance
/// @param buffer The buffer which will receive the data
/// @param count Number of bytes that `buffer` can accept
/// @return The number of bytes copied into `buffer`
uint32_t rstream_read(RStream *rstream, char *buffer, uint32_t count);

/// Returns the number of bytes available for reading from `rstream`
///
/// @param rstream The `RStream` instance
/// @return The number of bytes available
uint32_t rstream_available(RStream *rstream);

#endif  // NEOVIM_OS_RSTREAM_H

