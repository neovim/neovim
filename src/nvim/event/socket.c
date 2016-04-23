#include <assert.h>
#include <stdint.h>

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/socket.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/os/os.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/strings.h"
#include "nvim/path.h"
#include "nvim/memory.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/socket.c.generated.h"
#endif

#define NVIM_DEFAULT_TCP_PORT 7450

void socket_watcher_init(Loop *loop, SocketWatcher *watcher,
    const char *endpoint, void *data)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_NONNULL_ARG(3)
{
  // Trim to `ADDRESS_MAX_SIZE`
  if (xstrlcpy(watcher->addr, endpoint, sizeof(watcher->addr))
      >= sizeof(watcher->addr)) {
    // TODO(aktau): since this is not what the user wanted, perhaps we
    // should return an error here
    WLOG("Address was too long, truncated to %s", watcher->addr);
  }

  bool tcp = true;
  char ip[16], *ip_end = xstrchrnul(watcher->addr, ':');

  // (ip_end - addr) is always > 0, so convert to size_t
  size_t addr_len = (size_t)(ip_end - watcher->addr);

  if (addr_len > sizeof(ip) - 1) {
    // Maximum length of an IPv4 address buffer is 15 (eg: 255.255.255.255)
    addr_len = sizeof(ip) - 1;
  }

  // Extract the address part
  xstrlcpy(ip, watcher->addr, addr_len + 1);
  int port = NVIM_DEFAULT_TCP_PORT;

  if (*ip_end == ':') {
    // Extract the port
    long lport = strtol(ip_end + 1, NULL, 10); // NOLINT
    if (lport <= 0 || lport > 0xffff) {
      // Invalid port, treat as named pipe or unix socket
      tcp = false;
    } else {
      port = (int) lport;
    }
  }

  if (tcp) {
    // Try to parse ip address
    if (uv_ip4_addr(ip, port, &watcher->uv.tcp.addr)) {
      // Invalid address, treat as named pipe or unix socket
      tcp = false;
    }
  }

  if (tcp) {
    uv_tcp_init(&loop->uv, &watcher->uv.tcp.handle);
    watcher->stream = (uv_stream_t *)&watcher->uv.tcp.handle;
  } else {
    uv_pipe_init(&loop->uv, &watcher->uv.pipe.handle, 0);
    watcher->stream = (uv_stream_t *)&watcher->uv.pipe.handle;
  }

  watcher->stream->data = watcher;
  watcher->cb = NULL;
  watcher->close_cb = NULL;
  watcher->events = NULL;
}

int socket_watcher_start(SocketWatcher *watcher, int backlog, socket_cb cb)
  FUNC_ATTR_NONNULL_ALL
{
  watcher->cb = cb;
  int result;

  if (watcher->stream->type == UV_TCP) {
    result = uv_tcp_bind(&watcher->uv.tcp.handle,
                         (const struct sockaddr *)&watcher->uv.tcp.addr, 0);
  } else {
    result = uv_pipe_bind(&watcher->uv.pipe.handle, watcher->addr);
  }

  if (result == 0) {
    result = uv_listen(watcher->stream, backlog, connection_cb);
  }

  assert(result <= 0);  // libuv should return negative error code or zero.
  if (result < 0) {
    if (result == -EACCES) {
      // Libuv converts ENOENT to EACCES for Windows compatibility, but if
      // the parent directory does not exist, ENOENT would be more accurate.
      *path_tail((char_u *)watcher->addr) = NUL;
      if (!os_file_exists((char_u *)watcher->addr)) {
        result = -ENOENT;
      }
    }
    return result;
  }

  return 0;
}

int socket_watcher_accept(SocketWatcher *watcher, Stream *stream, void *data)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_NONNULL_ARG(2)
{
  uv_stream_t *client;

  if (watcher->stream->type == UV_TCP) {
    client = (uv_stream_t *)&stream->uv.tcp;
    uv_tcp_init(watcher->uv.tcp.handle.loop, (uv_tcp_t *)client);
  } else {
    client = (uv_stream_t *)&stream->uv.pipe;
    uv_pipe_init(watcher->uv.pipe.handle.loop, (uv_pipe_t *)client, 0);
  }

  int result = uv_accept(watcher->stream, client);

  if (result) {
    uv_close((uv_handle_t *)client, NULL);
    return result;
  }

  stream_init(NULL, stream, -1, client, data);
  return 0;
}

void socket_watcher_close(SocketWatcher *watcher, socket_close_cb cb)
  FUNC_ATTR_NONNULL_ARG(1)
{
  watcher->close_cb = cb;
  uv_close((uv_handle_t *)watcher->stream, close_cb);
}

static void connection_event(void **argv)
{
  SocketWatcher *watcher = argv[0];
  int status = (int)(uintptr_t)(argv[1]);
  watcher->cb(watcher, status, watcher->data);
}

static void connection_cb(uv_stream_t *handle, int status)
{
  SocketWatcher *watcher = handle->data;
  CREATE_EVENT(watcher->events, connection_event, 2, watcher,
      (void *)(uintptr_t)status);
}

static void close_cb(uv_handle_t *handle)
{
  SocketWatcher *watcher = handle->data;
  if (watcher->close_cb) {
    watcher->close_cb(watcher, watcher->data);
  }
}
