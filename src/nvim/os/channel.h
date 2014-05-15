#ifndef NVIM_OS_CHANNEL_H
#define NVIM_OS_CHANNEL_H

#include <uv.h>

#include "nvim/os/channel_defs.h"

/// Initializes the module
void channel_init(void);

/// Teardown the module
void channel_teardown(void);

/// Creates an API channel from a libuv stream representing a tcp or
/// pipe/socket client connection
///
/// @param stream The established connection
/// @param prot The rpc protocol used
void channel_from_stream(uv_stream_t *stream, ChannelProtocol prot);

/// Creates an API channel by starting a job and connecting to its
/// stdin/stdout. stderr is forwarded to the editor error stream.
///
/// @param argv The argument vector for the process
/// @param prot The rpc protocol used
void channel_from_job(char **argv, ChannelProtocol prot);

#endif  // NVIM_OS_CHANNEL_H

