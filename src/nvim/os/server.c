#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include <uv.h>

#include "nvim/os/channel.h"
#include "nvim/os/server.h"
#include "nvim/os/os.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/tempfile.h"
#include "nvim/map.h"
#include "nvim/path.h"
#include "nvim/misc2.h"

#define MAX_CONNECTIONS 32
#define ADDRESS_MAX_SIZE 256
#define NEOVIM_DEFAULT_TCP_PORT 7450
#define LISTEN_ADDRESS_ENV_VAR "NVIM_LISTEN_ADDRESS"

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
void server_init(void)
{
  servers = pmap_new(cstr_t)();

  const char *listen_address = os_getenv(LISTEN_ADDRESS_ENV_VAR);
  bool must_free = false;
  if (!listen_address) {
    must_free = true;
    listen_address = (char *)vim_tempname();
    os_setenv(LISTEN_ADDRESS_ENV_VAR, listen_address, 1);
  }

  int res = 1;  // The return value of server_start().

  char_u *p = (char_u *) listen_address;
  while (res != 0 && *p != NUL) {
    char_u path[MAXPATHL];
    copy_option_part(&p, path, MAXPATHL, ";");

    if (!path_with_url(path)) {
      // This address might refer to a temp dir. We may need to recreate it.
      char_u *tail = path_tail(path);
      char_u save = *tail;
      *tail = NUL;
      (void) os_mkdir((char *) path, 0666);  // Doesn't matter if this fails.
      *tail = save;
    }

    res = server_start((char *) path);
    if (res == -EACCES && !os_file_exists(path)) {
      // libuv converts ENOENT to EACCESS for Windows compatibility.
      // Convert it back for better error reporting.
      res = -ENOENT;
    }
  }

  if (res == -EADDRINUSE) {
    // Another nvim instance may be bound to this address.
    char *tmp = (char *)vim_tempname();

    // Try to start the server with the temp and add it to the environment if
    // successful.
    res = server_start(tmp);
    if (!res) {
      char *new_env = xmallocz(STRLEN(listen_address) + STRLEN(tmp) + 1);
      char *p = new_env;
      p = xstpcpy(p, listen_address);
      p = xstpcpy(p, ";");
      p = xstpcpy(p, tmp);
      os_setenv(LISTEN_ADDRESS_ENV_VAR, new_env, 1);
      free(new_env);
    }

    free(tmp);
  }

  if (res < 0) {
    EMSG2("Failed to start server: %s", uv_strerror(res));
  }

  if (must_free) {
    free((char *) listen_address);
  }
}

/// Teardown the server module
void server_teardown(void)
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
/// 'ip[:port]' format, then it will be tcp socket. The port is optional
/// and if omitted will default to NEOVIM_DEFAULT_TCP_PORT. Otherwise it will
/// be a unix socket or named pipe.
///
/// @param endpoint Address of the server. Either a 'ip[:port]' string or an
///        arbitrary identifier(trimmed to 256 bytes) for the unix socket or
///        named pipe.
/// @returns 0 on success, a positive number for regular errors,
///          or negative errno if bind or listen failed.
int server_start(char *endpoint)
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
    return 1;
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
    addr_len = sizeof(ip) - 1;
  }

  // Extract the address part
  xstrlcpy(ip, addr, addr_len + 1);

  int port = NEOVIM_DEFAULT_TCP_PORT;

  if (*ip_end == ':') {
    // Extract the port
    long lport = strtol(ip_end + 1, NULL, 10); // NOLINT
    if (lport <= 0 || lport > 0xffff) {
      // Invalid port, treat as named pipe or unix socket
      server_type = kServerTypePipe;
    } else {
      port = (int) lport;
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
    result = uv_tcp_bind(&server->socket.tcp.handle,
                         (const struct sockaddr *)&server->socket.tcp.addr,
                         0);
    if (result == 0) {
      result = uv_listen((uv_stream_t *)&server->socket.tcp.handle,
                         MAX_CONNECTIONS,
                         connection_cb);
    }
    if (result) {
      uv_close((uv_handle_t *)&server->socket.tcp.handle, free_server);
    }
  } else {
    // Listen on named pipe or unix socket
    xstrlcpy(server->socket.pipe.addr, addr, sizeof(server->socket.pipe.addr));
    uv_pipe_init(uv_default_loop(), &server->socket.pipe.handle, 0);
    server->socket.pipe.handle.data = server;
    result = uv_pipe_bind(&server->socket.pipe.handle,
                          server->socket.pipe.addr);
    if (result == 0) {
      result = uv_listen((uv_stream_t *)&server->socket.pipe.handle,
                         MAX_CONNECTIONS,
                         connection_cb);
    }
    if (result) {
      uv_close((uv_handle_t *)&server->socket.pipe.handle, free_server);
    }
  }

  if (result == 0) {
    server->type = server_type;

    // Add the server to the hash table
    pmap_put(cstr_t)(servers, addr, server);
  }

  return result;
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
