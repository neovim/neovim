#ifndef NEOVIM_OS_RSTREAM_DEFS_H
#define NEOVIM_OS_RSTREAM_DEFS_H

typedef struct rstream RStream;

/// Type of function called when the RStream receives data
///
/// @param rstream The RStream instance
/// @param data State associated with the RStream instance
/// @param eof If the stream reached EOF.
typedef void (*rstream_cb)(RStream *rstream, void *data, bool eof);

#endif  // NEOVIM_OS_RSTREAM_DEFS_H

