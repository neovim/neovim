#ifndef NVIM_OS_RSTREAM_DEFS_H
#define NVIM_OS_RSTREAM_DEFS_H

#include <stdbool.h>

typedef struct rbuffer RBuffer;
typedef struct rstream RStream;

/// Type of function called when the RStream receives data
///
/// @param rstream The RStream instance
/// @param data State associated with the RStream instance
/// @param eof If the stream reached EOF.
typedef void (*rstream_cb)(RStream *rstream, void *data, bool eof);

#endif  // NVIM_OS_RSTREAM_DEFS_H

