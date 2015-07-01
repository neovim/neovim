#ifndef NVIM_OS_RSTREAM_DEFS_H
#define NVIM_OS_RSTREAM_DEFS_H

#include <stdbool.h>

#include "nvim/rbuffer.h"

typedef struct rstream RStream;

/// Type of function called when the RStream receives data
///
/// @param rstream The RStream instance
/// @param rbuffer The associated RBuffer instance
/// @param data State associated with the RStream instance
/// @param eof If the stream reached EOF.
typedef void (*rstream_cb)(RStream *rstream, RBuffer *buf, void *data,
    bool eof);

#endif  // NVIM_OS_RSTREAM_DEFS_H

