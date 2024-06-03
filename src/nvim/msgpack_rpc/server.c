#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <uv.h>

#include "nvim/ascii_defs.h"
#include "nvim/channel.h"
#include "nvim/eval.h"
#include "nvim/event/defs.h"
#include "nvim/event/socket.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/server.h"
#include "nvim/os/os.h"
#include "nvim/os/stdpaths_defs.h"

#define MAX_CONNECTIONS 32
#define ENV_LISTEN "NVIM_LISTEN_ADDRESS"  // deprecated

static garray_T watchers = GA_EMPTY_INIT_VALUE;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/server.c.generated.h"
#endif

/// Initializes the module
bool server_init(const char *listen_addr)
{
  ga_init(&watchers, sizeof(SocketWatcher *), 1);

  // $NVIM_LISTEN_ADDRESS (deprecated)
  if (!listen_addr && os_env_exists(ENV_LISTEN)) {
    listen_addr = os_getenv(ENV_LISTEN);
  }

  int rv = listen_addr ? server_start(listen_addr) : 1;
  if (0 != rv) {
    listen_addr = server_address_new(NULL);
    if (!listen_addr) {
      return false;
    }
    rv = server_start(listen_addr);
    xfree((char *)listen_addr);
  }

  if (os_env_exists(ENV_LISTEN)) {
    // Unset $NVIM_LISTEN_ADDRESS, it's a liability hereafter.
    os_unsetenv(ENV_LISTEN);
  }

  // TODO(justinmk): this is for logging_spec. Can remove this after nvim_log #7062 is merged.
  if (os_env_exists("__NVIM_TEST_LOG")) {
    ELOG("test log message");
  }

  return rv == 0;
}

/// Teardown a single server
static void close_socket_watcher(SocketWatcher **watcher)
{
  socket_watcher_close(*watcher, free_server);
}

/// Sets the "primary address" (v:servername and $NVIM) to the first server in
/// the server list, or unsets if no servers are known.
static void set_vservername(garray_T *srvs)
{
  char *default_server = (srvs->ga_len > 0)
                         ? ((SocketWatcher **)srvs->ga_data)[0]->addr
                         : NULL;
  set_vim_var_string(VV_SEND_SERVER, default_server, -1);
}

/// Teardown the server module
void server_teardown(void)
{
  GA_DEEP_CLEAR(&watchers, SocketWatcher *, close_socket_watcher);
}

/// Generates unique address for local server.
///
/// Named pipe format:
/// - Windows: "\\.\pipe\<name>.<pid>.<counter>"
/// - Other: "/tmp/nvim.user/xxx/<name>.<pid>.<counter>"
char *server_address_new(const char *name)
{
  static uint32_t count = 0;
  char fmt[ADDRESS_MAX_SIZE];
  const char *appname = get_appname();
#ifdef MSWIN
  int r = snprintf(fmt, sizeof(fmt), "\\\\.\\pipe\\%s.%" PRIu64 ".%" PRIu32,
                   name ? name : appname, os_get_pid(), count++);
#else
  char *dir = stdpaths_get_xdg_var(kXDGRuntimeDir);
  int r = snprintf(fmt, sizeof(fmt), "%s/%s.%" PRIu64 ".%" PRIu32,
                   dir, name ? name : appname, os_get_pid(), count++);
  xfree(dir);
#endif
  if ((size_t)r >= sizeof(fmt)) {
    ELOG("truncated server address: %.40s...", fmt);
  }
  return xstrdup(fmt);
}

/// Check if this instance owns a pipe address.
/// The argument must already be resolved to an absolute path!
bool server_owns_pipe_address(const char *path)
{
  for (int i = 0; i < watchers.ga_len; i++) {
    if (!strcmp(path, ((SocketWatcher **)watchers.ga_data)[i]->addr)) {
      return true;
    }
  }
  return false;
}

/// Starts listening for RPC calls.
///
/// Socket type is decided by the format of `addr`:
/// - TCP socket if it looks like an IPv4/6 address ("ip:[port]").
///   - If [port] is omitted, a random one is assigned.
/// - Unix socket (or named pipe on Windows) otherwise.
///   - If the name doesn't contain slashes it is appended to a generated path. #8519
///
/// @param addr Server address: a "ip:[port]" string or arbitrary name or filepath (max 256 bytes)
///             for the Unix socket or named pipe.
/// @returns 0: success, 1: validation error, 2: already listening, -errno: failed to bind/listen.
int server_start(const char *addr)
{
  if (addr == NULL || addr[0] == NUL) {
    WLOG("Empty or NULL address");
    return 1;
  }

  bool isname = !strstr(addr, ":") && !strstr(addr, "/") && !strstr(addr, "\\");
  char *addr_gen = isname ? server_address_new(addr) : NULL;
  SocketWatcher *watcher = xmalloc(sizeof(SocketWatcher));
  int result = socket_watcher_init(&main_loop, watcher, isname ? addr_gen : addr);
  xfree(addr_gen);
  if (result < 0) {
    xfree(watcher);
    return result;
  }

  // Check if a watcher for the address already exists.
  for (int i = 0; i < watchers.ga_len; i++) {
    if (!strcmp(watcher->addr, ((SocketWatcher **)watchers.ga_data)[i]->addr)) {
      ELOG("Already listening on %s", watcher->addr);
      if (watcher->stream->type == UV_TCP) {
        uv_freeaddrinfo(watcher->uv.tcp.addrinfo);
      }
      socket_watcher_close(watcher, free_server);
      return 2;
    }
  }

  result = socket_watcher_start(watcher, MAX_CONNECTIONS, connection_cb);
  if (result < 0) {
    WLOG("Failed to start server: %s: %s", uv_strerror(result), watcher->addr);
    socket_watcher_close(watcher, free_server);
    return result;
  }

  // Add the watcher to the list.
  ga_grow(&watchers, 1);
  ((SocketWatcher **)watchers.ga_data)[watchers.ga_len++] = watcher;

  // Update v:servername, if not set.
  if (strlen(get_vim_var_str(VV_SEND_SERVER)) == 0) {
    set_vservername(&watchers);
  }

  return 0;
}

/// Stops listening on the address specified by `endpoint`.
///
/// @param endpoint Address of the server.
bool server_stop(char *endpoint)
{
  SocketWatcher *watcher;
  bool watcher_found = false;
  char addr[ADDRESS_MAX_SIZE];

  // Trim to `ADDRESS_MAX_SIZE`
  xstrlcpy(addr, endpoint, sizeof(addr));

  int i = 0;  // Index of the server whose address equals addr.
  for (; i < watchers.ga_len; i++) {
    watcher = ((SocketWatcher **)watchers.ga_data)[i];
    if (strcmp(addr, watcher->addr) == 0) {
      watcher_found = true;
      break;
    }
  }

  if (!watcher_found) {
    WLOG("Not listening on %s", addr);
    return false;
  }

  socket_watcher_close(watcher, free_server);

  // Remove this server from the list by swapping it with the last item.
  if (i != watchers.ga_len - 1) {
    ((SocketWatcher **)watchers.ga_data)[i] =
      ((SocketWatcher **)watchers.ga_data)[watchers.ga_len - 1];
  }
  watchers.ga_len--;

  // Bump v:servername to the next available server, if any.
  if (strequal(addr, get_vim_var_str(VV_SEND_SERVER))) {
    set_vservername(&watchers);
  }

  return true;
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
