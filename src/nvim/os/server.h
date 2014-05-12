#ifndef NVIM_OS_SERVER_H
#define NVIM_OS_SERVER_H

#include "nvim/os/channel_defs.h"

/// Initializes the module
void server_init();

/// Teardown the server module
void server_teardown();

/// Starts listening on arbitrary tcp/unix addresses specified by
/// `endpoint` for API calls. The type of socket used(tcp or unix/pipe) will 
/// be determined by parsing `endpoint`: If it's a valid tcp address in the
/// 'ip:port' format, then it will be tcp socket, else it will be a unix
/// socket or named pipe.
///
/// @param endpoint Address of the server. Either a 'ip:port' string or an
///        arbitrary identifier(trimmed to 256 bytes) for the unix socket or
///        named pipe.
/// @param prot The rpc protocol to be used
void server_start(char *endpoint, ChannelProtocol prot);

/// Stops listening on the address specified by `endpoint`.
///
/// @param endpoint Address of the server.
void server_stop(char *endpoint);

#endif  // NVIM_OS_SERVER_H

