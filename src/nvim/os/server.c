#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/os/channel.h"
#include "nvim/os/server.h"
#include "nvim/os/os.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/fileio.h"
#include "nvim/map.h"

#define MAX_CONNECTIONS 32
#define ADDRESS_MAX_SIZE 256
#define NEOVIM_DEFAULT_TCP_PORT 7450

typedef enum {
  kServerTypeTcp,
  kServerTypePipe
} ServerType;

typedef struct {
  // Type of the union below
  ServerType type;

  // This is either a tcp server or unix socket(named pipe on windows)
  union {
    struct {
      uv_tcp_t handle;
      struct sockaddr_in addr;
    } tcp;
    struct {
      uv_pipe_t handle;
      char addr[ADDRESS_MAX_SIZE];
    } pipe;
  } socket;
} Server;

static PMap(cstr_t) *servers = NULL;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/server.c.generated.h"
#endif

/// Initializes the module
void server_init()
{
  servers = pmap_new(cstr_t)();

  if (!os_getenv("NEOVIM_LISTEN_ADDRESS")) {
    char *listen_address = (char *)vim_tempname('s');
    os_setenv("NEOVIM_LISTEN_ADDRESS", listen_address, 1);
    free(listen_address);
  }

  server_start((char *)os_getenv("NEOVIM_LISTEN_ADDRESS"));
}

/// Teardown the server module
void server_teardown()
{
  if (!servers) {
    return;
  }

  Server *server;

  map_foreach_value(servers, server, {
    if (server->type == kServerTypeTcp) {
      uv_close((uv_handle_t *)&server->socket.tcp.handle, free_server);
    } else {
      uv_close((uv_handle_t *)&server->socket.pipe.handle, free_server);
    }
  });
}

/// Starts listening on arbitrary tcp/unix addresses specified by
/// `endpoint` for API calls. The type of socket used(tcp or unix/pipe) will
/// be determined by parsing `endpoint`: If it's a valid tcp address in the
/// 'ip:port' format, then it will be tcp socket, else it will be a unix
/// socket or named pipe.
///
/// @param endpoint Address of the server. Either a 'ip:port' string or an
///        arbitrary identifier(trimmed to 256 bytes) for the unix socket or
///        named pipe.
void server_start(char *endpoint)
{
  char addr[ADDRESS_MAX_SIZE];

  // Trim to `ADDRESS_MAX_SIZE`
  if (xstrlcpy(addr, endpoint, sizeof(addr)) >= sizeof(addr)) {
      // TODO(aktau): since this is not what the user wanted, perhaps we
      // should return an error here
      EMSG2("Address was too long, truncated to %s", addr);
  }

  // Check if the server already exists
  if (pmap_has(cstr_t)(servers, addr)) {
    EMSG2("Already listening on %s", addr);
    return;
  }

  ServerType server_type = kServerTypeTcp;
  Server *server = xmalloc(sizeof(Server));
  char ip[16], *ip_end = strrchr(addr, ':');

  if (!ip_end) {
    ip_end = strchr(addr, NUL);
  }

  uint32_t addr_len = ip_end - addr;

  if (addr_len > sizeof(ip) - 1) {
    // Maximum length of an IP address buffer is 15(eg: 255.255.255.255)
    addr_len = sizeof(ip);
  }

  // Extract the address part
  xstrlcpy(ip, addr, addr_len);

  int port = NEOVIM_DEFAULT_TCP_PORT;

  if (*ip_end == ':') {
    char *port_end;
    // Extract the port
    port = strtol(ip_end + 1, &port_end, 10);
    errno = 0;

    if (errno != 0 || port == 0 || port > 0xffff) {
      // Invalid port, treat as named pipe or unix socket
      server_type = kServerTypePipe;
    }
  }

  if (server_type == kServerTypeTcp) {
    // Try to parse ip address
    if (uv_ip4_addr(ip, port, &server->socket.tcp.addr)) {
      // Invalid address, treat as named pipe or unix socket
      server_type = kServerTypePipe;
    }
  }

  int result;

  if (server_type == kServerTypeTcp) {
    // Listen on tcp address/port
    uv_tcp_init(uv_default_loop(), &server->socket.tcp.handle);
    server->socket.tcp.handle.data = server;
    uv_tcp_bind(&server->socket.tcp.handle,
                         (const struct sockaddr *)&server->socket.tcp.addr,
                         0);
    result = uv_listen((uv_stream_t *)&server->socket.tcp.handle,
               MAX_CONNECTIONS,
               connection_cb);
    if (result) {
      uv_close((uv_handle_t *)&server->socket.tcp.handle, free_server);
    }
  } else {
    // Listen on named pipe or unix socket
    xstrlcpy(server->socket.pipe.addr, addr, sizeof(server->socket.pipe.addr));
    uv_pipe_init(uv_default_loop(), &server->socket.pipe.handle, 0);
    server->socket.pipe.handle.data = server;
    uv_pipe_bind(&server->socket.pipe.handle, server->socket.pipe.addr);
    result = uv_listen((uv_stream_t *)&server->socket.pipe.handle,
               MAX_CONNECTIONS,
               connection_cb);

    if (result) {
      uv_close((uv_handle_t *)&server->socket.pipe.handle, free_server);
    }
  }

  if (result) {
    EMSG2("Failed to start server: %s", uv_strerror(result));
    return;
  }


  server->type = server_type;

  // Add the server to the hash table
  pmap_put(cstr_t)(servers, addr, server);
}

/// Stops listening on the address specified by `endpoint`.
///
/// @param endpoint Address of the server.
void server_stop(char *endpoint)
{
  Server *server;
  char addr[ADDRESS_MAX_SIZE];

  // Trim to `ADDRESS_MAX_SIZE`
  xstrlcpy(addr, endpoint, sizeof(addr));

  if ((server = pmap_get(cstr_t)(servers, addr)) == NULL) {
    EMSG2("Not listening on %s", addr);
    return;
  }

  if (server->type == kServerTypeTcp) {
    uv_close((uv_handle_t *)&server->socket.tcp.handle, free_server);
  } else {
    uv_close((uv_handle_t *)&server->socket.pipe.handle, free_server);
  }

  pmap_del(cstr_t)(servers, addr);
}

static void connection_cb(uv_stream_t *server, int status)
{
  int result;
  uv_stream_t *client;
  Server *srv = server->data;

  if (status < 0) {
    abort();
  }

  if (srv->type == kServerTypeTcp) {
    client = xmalloc(sizeof(uv_tcp_t));
    uv_tcp_init(uv_default_loop(), (uv_tcp_t *)client);
  } else {
    client = xmalloc(sizeof(uv_pipe_t));
    uv_pipe_init(uv_default_loop(), (uv_pipe_t *)client, 0);
  }

  result = uv_accept(server, client);

  if (result) {
    EMSG2("Failed to accept connection: %s", uv_strerror(result));
    uv_close((uv_handle_t *)client, free_client);
    return;
  }

  channel_from_stream(client);
}

static void free_client(uv_handle_t *handle)
{
  free(handle);
}

static void free_server(uv_handle_t *handle)
{
  free(handle->data);
}
