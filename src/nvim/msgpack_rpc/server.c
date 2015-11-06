#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>

#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/server.h"
#include "nvim/os/os.h"
#include "nvim/event/socket.h"
#include "nvim/ascii.h"
#include "nvim/eval.h"
#include "nvim/garray.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/log.h"
#include "nvim/tempfile.h"
#include "nvim/path.h"
#include "nvim/strings.h"

#define MAX_CONNECTIONS 32
#define LISTEN_ADDRESS_ENV_VAR "NVIM_LISTEN_ADDRESS"

static garray_T watchers = GA_EMPTY_INIT_VALUE;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/server.c.generated.h"
#endif

/// Initializes the module
bool server_init(void)
{
  ga_init(&watchers, sizeof(SocketWatcher *), 1);

  bool must_free = false;
  const char *listen_address = os_getenv(LISTEN_ADDRESS_ENV_VAR);
  if (listen_address == NULL) {
    must_free = true;
    listen_address = server_address_new();
  }

  bool ok = (server_start(listen_address) == 0);
  if (must_free) {
    xfree((char *) listen_address);
  }
  return ok;
}

/// Teardown a single server
static void close_socket_watcher(SocketWatcher **watcher)
{
  socket_watcher_close(*watcher, free_server);
}

/// Set v:servername to the first server in the server list, or unset it if no
/// servers are known.
static void set_vservername(garray_T *srvs)
{
  char *default_server = (srvs->ga_len > 0)
    ? ((SocketWatcher **)srvs->ga_data)[0]->addr
    : NULL;
  set_vim_var_string(VV_SEND_SERVER, (char_u *)default_server, -1);
}

/// Teardown the server module
void server_teardown(void)
{
  GA_DEEP_CLEAR(&watchers, SocketWatcher *, close_socket_watcher);
}

/// Generates unique address for local server.
///
/// In Windows this is a named pipe in the format
///     \\.\pipe\nvim-<PID>-<COUNTER>.
///
/// For other systems it is a path returned by vim_tempname().
///
/// This function is NOT thread safe
char *server_address_new(void)
{
#ifdef WIN32
  static uint32_t count = 0;
  char template[ADDRESS_MAX_SIZE];
  snprintf(template, ADDRESS_MAX_SIZE,
    "\\\\.\\pipe\\nvim-%" PRIu64 "-%" PRIu32, os_get_pid(), count++);
  return xstrdup(template);
#else
  return (char *)vim_tempname();
#endif
}

/// Starts listening for API calls on the TCP address or pipe path `endpoint`.
/// The socket type is determined by parsing `endpoint`: If it's a valid IPv4
/// address in 'ip[:port]' format, then it will be TCP socket. The port is
/// optional and if omitted defaults to NVIM_DEFAULT_TCP_PORT. Otherwise it
/// will be a unix socket or named pipe.
///
/// @param endpoint Address of the server. Either a 'ip[:port]' string or an
///        arbitrary identifier (trimmed to 256 bytes) for the unix socket or
///        named pipe.
/// @returns 0 on success, 1 on a regular error, and negative errno
///          on failure to bind or connect.
int server_start(const char *endpoint)
{
  if (endpoint == NULL) {
    ELOG("Attempting to start server on NULL endpoint");
    return 1;
  }

  SocketWatcher *watcher = xmalloc(sizeof(SocketWatcher));
  socket_watcher_init(&loop, watcher, endpoint, NULL);

  // Check if a watcher for the endpoint already exists
  for (int i = 0; i < watchers.ga_len; i++) {
    if (!strcmp(watcher->addr, ((SocketWatcher **)watchers.ga_data)[i]->addr)) {
      ELOG("Already listening on %s", watcher->addr);
      socket_watcher_close(watcher, free_server);
      return 1;
    }
  }

  int result = socket_watcher_start(watcher, MAX_CONNECTIONS, connection_cb);
  if (result < 0) {
    ELOG("Failed to start server: %s", uv_strerror(result));
    socket_watcher_close(watcher, free_server);
    return result;
  }

  // Update $NVIM_LISTEN_ADDRESS, if not set.
  const char *listen_address = os_getenv(LISTEN_ADDRESS_ENV_VAR);
  if (listen_address == NULL) {
    os_setenv(LISTEN_ADDRESS_ENV_VAR, watcher->addr, 1);
  }

  // Add the watcher to the list.
  ga_grow(&watchers, 1);
  ((SocketWatcher **)watchers.ga_data)[watchers.ga_len++] = watcher;

  // Update v:servername, if not set.
  if (STRLEN(get_vim_var_str(VV_SEND_SERVER)) == 0) {
    set_vservername(&watchers);
  }

  return 0;
}

/// Stops listening on the address specified by `endpoint`.
///
/// @param endpoint Address of the server.
void server_stop(char *endpoint)
{
  SocketWatcher *watcher;
  char addr[ADDRESS_MAX_SIZE];

  // Trim to `ADDRESS_MAX_SIZE`
  xstrlcpy(addr, endpoint, sizeof(addr));

  int i = 0;  // Index of the server whose address equals addr.
  for (; i < watchers.ga_len; i++) {
    watcher = ((SocketWatcher **)watchers.ga_data)[i];
    if (strcmp(addr, watcher->addr) == 0) {
      break;
    }
  }

  if (i >= watchers.ga_len) {
    ELOG("Not listening on %s", addr);
    return;
  }

  // Unset $NVIM_LISTEN_ADDRESS if it is the stopped address.
  const char *listen_address = os_getenv(LISTEN_ADDRESS_ENV_VAR);
  if (listen_address && STRCMP(addr, listen_address) == 0) {
    os_unsetenv(LISTEN_ADDRESS_ENV_VAR);
  }

  socket_watcher_close(watcher, free_server);

  // Remove this server from the list by swapping it with the last item.
  if (i != watchers.ga_len - 1) {
    ((SocketWatcher **)watchers.ga_data)[i] =
      ((SocketWatcher **)watchers.ga_data)[watchers.ga_len - 1];
  }
  watchers.ga_len--;

  // If v:servername is the stopped address, re-initialize it.
  if (STRCMP(addr, get_vim_var_str(VV_SEND_SERVER)) == 0) {
    set_vservername(&watchers);
  }
}

/// Returns an allocated array of server addresses.
/// @param[out] size The size of the returned array.
char **server_address_list(size_t *size)
  FUNC_ATTR_NONNULL_ALL
{
  if ((*size = (size_t)watchers.ga_len) == 0) {
    return NULL;
  }

  char **addrs = xcalloc((size_t)watchers.ga_len, sizeof(const char *));
  for (int i = 0; i < watchers.ga_len; i++) {
    addrs[i] = xstrdup(((SocketWatcher **)watchers.ga_data)[i]->addr);
  }
  return addrs;
}

static void connection_cb(SocketWatcher *watcher, int result, void *data)
{
  if (result) {
    ELOG("Failed to accept connection: %s", uv_strerror(result));
    return;
  }

  channel_from_connection(watcher);
}

static void free_server(SocketWatcher *watcher, void *data)
{
  xfree(watcher);
}
