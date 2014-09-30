#ifndef NVIM_OS_WSTREAM_DEFS_H
#define NVIM_OS_WSTREAM_DEFS_H

typedef struct wbuffer WBuffer;
typedef struct wstream WStream;
typedef void (*wbuffer_data_finalizer)(void *data);

/// Type of function called when the WStream has information about a write
/// request.
///
/// @param wstream The `WStream` instance
/// @param data User-defined data
/// @param pending The number of write requests that are still pending
/// @param status 0 on success, anything else indicates failure
typedef void (*wstream_cb)(WStream *wstream,
                           void *data,
                           size_t pending,
                           int status);

#endif  // NVIM_OS_WSTREAM_DEFS_H

