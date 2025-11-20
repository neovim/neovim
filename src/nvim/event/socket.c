#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <uv.h>

#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/socket.h"
#include "nvim/event/stream.h"
#include "nvim/gettext_defs.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/os/fs.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/types_defs.h"

#include "event/socket.c.generated.h"

/// Helper callback for closing handles during cleanup
static void close_walk_cb(uv_handle_t *handle, void *arg)
{
  if (!uv_is_closing(handle)) {
    uv_close(handle, NULL);
  }
}

/// Test if a socket/pipe is actually being listened to.
///
/// @param addr Socket address to test
/// @param is_tcp Whether this is a TCP socket
/// @return true if connection succeeds (socket is alive), false otherwise
static bool socket_test_connection(const char *addr, bool is_tcp)
{
  uv_loop_t test_loop;
  if (uv_loop_init(&test_loop) != 0) {
    return false;
  }

  bool is_alive = false;
  int status = 1;  // 1 = pending, 0 = success, <0 = error
  uv_connect_t req;
  req.data = &status;

  if (is_tcp) {
    uv_tcp_t tcp;
    uv_tcp_init(&test_loop, &tcp);

    char *addr_copy = xstrdup(addr);
    char *host_end = strrchr(addr_copy, ':');
    if (!host_end) {
      xfree(addr_copy);
      uv_loop_close(&test_loop);
      return false;
    }
    *host_end = NUL;

    struct addrinfo hints = { .ai_family = AF_UNSPEC, .ai_socktype = SOCK_STREAM };
    struct addrinfo *ai = NULL;
    if (getaddrinfo(addr_copy, host_end + 1, &hints, &ai) == 0 && ai) {
      uv_tcp_connect(&req, &tcp, ai->ai_addr, connect_cb);
      freeaddrinfo(ai);
    }
    xfree(addr_copy);
  } else {
    uv_pipe_t pipe;
    uv_pipe_init(&test_loop, &pipe, 0);
    uv_pipe_connect(&req, &pipe, addr, connect_cb);
  }

  // Run loop with short timeout (500ms) to test connection
  uint64_t start = uv_now(&test_loop);
  while (status == 1 && (uv_now(&test_loop) - start) < 500) {
    uv_run(&test_loop, UV_RUN_NOWAIT);
    if (status == 1) {
      uv_sleep(10);  // Small sleep to avoid busy-waiting
    }
  }

  is_alive = (status == 0);

  // Clean up
  uv_walk(&test_loop, close_walk_cb, NULL);
  uv_run(&test_loop, UV_RUN_DEFAULT);
  uv_loop_close(&test_loop);

  return is_alive;
}

int socket_watcher_init(Loop *loop, SocketWatcher *watcher, const char *endpoint)
  FUNC_ATTR_NONNULL_ALL
{
  xstrlcpy(watcher->addr, endpoint, sizeof(watcher->addr));
  char *addr = watcher->addr;
  char *host_end = strrchr(addr, ':');

  if (host_end && addr != host_end) {
    // Split user specified address into two strings, addr (hostname) and port.
    // The port part in watcher->addr will be updated later.
    *host_end = NUL;
    char *port = host_end + 1;
    intmax_t iport;

    int ok = try_getdigits(&(char *){ port }, &iport);
    if (!ok || iport < 0 || iport > UINT16_MAX) {
      ELOG("Invalid port: %s", port);
      return UV_EINVAL;
    }

    if (*port == NUL) {
      // When no port is given, (uv_)getaddrinfo expects NULL otherwise the
      // implementation may attempt to lookup the service by name (and fail)
      port = NULL;
    }

    uv_getaddrinfo_t request;

    int retval = uv_getaddrinfo(&loop->uv, &request, NULL, addr, port,
                                &(struct addrinfo){ .ai_family = AF_UNSPEC,
                                                    .ai_socktype = SOCK_STREAM, });
    if (retval != 0) {
      ELOG("Host lookup failed: %s", endpoint);
      return retval;
    }
    watcher->uv.tcp.addrinfo = request.addrinfo;

    uv_tcp_init(&loop->uv, &watcher->uv.tcp.handle);
    uv_tcp_nodelay(&watcher->uv.tcp.handle, true);
    watcher->stream = (uv_stream_t *)(&watcher->uv.tcp.handle);
  } else {
    uv_pipe_init(&loop->uv, &watcher->uv.pipe.handle, 0);
    watcher->stream = (uv_stream_t *)(&watcher->uv.pipe.handle);
  }

  watcher->stream->data = watcher;
  watcher->cb = NULL;
  watcher->close_cb = NULL;
  watcher->events = NULL;
  watcher->data = NULL;

  return 0;
}

int socket_watcher_start(SocketWatcher *watcher, int backlog, socket_cb cb)
  FUNC_ATTR_NONNULL_ALL
{
  watcher-\u003ecb = cb;
  int result = UV_EINVAL;
  bool is_tcp = (watcher-\u003estream-\u003etype == UV_TCP);

  if (is_tcp) {
    struct addrinfo *ai = watcher-\u003euv.tcp.addrinfo;

    for (; ai; ai = ai-\u003eai_next) {
      result = uv_tcp_bind(\u0026watcher-\u003euv.tcp.handle, ai-\u003eai_addr, 0);
      if (result != 0) {
        continue;
      }
      result = uv_listen(watcher-\u003estream, backlog, connection_cb);
      if (result == 0) {
        struct sockaddr_storage sas;

        // When the endpoint in socket_watcher_init() didn't specify a port
        // number, a free random port number will be assigned. sin_port will
        // contain 0 in this case, unless uv_tcp_getsockname() is used first.
        uv_tcp_getsockname(\u0026watcher-\u003euv.tcp.handle, (struct sockaddr *)\u0026sas,
                           \u0026(int){ sizeof(sas) });
        uint16_t port = (sas.ss_family == AF_INET) ? ((struct sockaddr_in *)(\u0026sas))-\u003esin_port
                                                   : ((struct sockaddr_in6 *)(\u0026sas))-\u003esin6_port;
        // v:servername uses the string from watcher-\u003eaddr
        size_t len = strlen(watcher-\u003eaddr);
        snprintf(watcher-\u003eaddr + len, sizeof(watcher-\u003eaddr) - len, \":%\" PRIu16,
                 ntohs(port));
        break;
      }
    }
    uv_freeaddrinfo(watcher-\u003euv.tcp.addrinfo);
  } else {
    // Unix socket / named pipe
    result = uv_pipe_bind(\u0026watcher-\u003euv.pipe.handle, watcher-\u003eaddr);

    // If bind failed, check if it's due to an existing socket file
    if (result != 0 \u0026\u0026 os_path_exists(watcher-\u003eaddr)) {
      // Test if the existing socket is actually being listened to
      bool is_alive = socket_test_connection(watcher-\u003eaddr, false);

      if (is_alive) {
        // Socket is in use by another Nvim instance
        ILOG(\"Socket already in use by another Nvim instance: %s\", watcher-\u003eaddr);
        return result;  // Return the original error
      } else {
        // Socket file exists but no one is listening - it's stale
        ILOG(\"Removing stale socket: %s\", watcher-\u003eaddr);

        // Remove the stale socket file
        if (os_remove(watcher-\u003eaddr) != 0) {
          WLOG(\"Failed to remove stale socket: %s\", watcher-\u003eaddr);
          return result;
        }

        // Retry binding after removing stale socket
        result = uv_pipe_bind(\u0026watcher-\u003euv.pipe.handle, watcher-\u003eaddr);
      }
    }

    if (result == 0) {
      result = uv_listen(watcher-\u003estream, backlog, connection_cb);
    }
  }

  assert(result \u003c= 0);  // libuv should return negative error code or zero.
  if (result \u003c 0) {
    if (result == UV_EACCES) {
      // Libuv converts ENOENT to EACCES for Windows compatibility, but if
      // the parent directory does not exist, ENOENT would be more accurate.
      *path_tail(watcher-\u003eaddr) = NUL;
      if (!os_path_exists(watcher-\u003eaddr)) {
        result = UV_ENOENT;
      }
    }
    return result;
  }

  return 0;
}


int socket_watcher_accept(SocketWatcher *watcher, RStream *stream)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_NONNULL_ARG(2)
{
  uv_stream_t *client;

  if (watcher->stream->type == UV_TCP) {
    client = (uv_stream_t *)(&stream->s.uv.tcp);
    uv_tcp_init(watcher->uv.tcp.handle.loop, (uv_tcp_t *)client);
    uv_tcp_nodelay((uv_tcp_t *)client, true);
  } else {
    client = (uv_stream_t *)&stream->s.uv.pipe;
    uv_pipe_init(watcher->uv.pipe.handle.loop, (uv_pipe_t *)client, 0);
  }

  int result = uv_accept(watcher->stream, client);

  if (result) {
    uv_close((uv_handle_t *)client, NULL);
    return result;
  }

  stream_init(NULL, &stream->s, -1, client);
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
  CREATE_EVENT(watcher->events, connection_event, watcher, (void *)(uintptr_t)status);
}

static void close_cb(uv_handle_t *handle)
{
  SocketWatcher *watcher = handle->data;
  if (watcher->close_cb) {
    watcher->close_cb(watcher, watcher->data);
  }
}

static void connect_cb(uv_connect_t *req, int status)
{
  int *ret_status = req->data;
  *ret_status = status;
  uv_handle_t *handle = (uv_handle_t *)req->handle;
  if (status != 0 && !uv_is_closing(handle)) {
    uv_close(handle, NULL);
  }
}

bool socket_connect(Loop *loop, RStream *stream, bool is_tcp, const char *address, int timeout,
                    const char **error)
{
  bool success = false;
  int status;
  uv_connect_t req;
  req.data = &status;
  uv_stream_t *uv_stream;

  uv_tcp_t *tcp = &stream->s.uv.tcp;
  uv_getaddrinfo_t addr_req;
  addr_req.addrinfo = NULL;
  const struct addrinfo *addrinfo = NULL;
  char *addr = NULL;
  if (is_tcp) {
    addr = xstrdup(address);
    char *host_end = strrchr(addr, ':');
    if (!host_end) {
      *error = _("tcp address must be host:port");
      goto cleanup;
    }
    *host_end = NUL;

    const struct addrinfo hints = { .ai_family = AF_UNSPEC,
                                    .ai_socktype = SOCK_STREAM,
                                    .ai_flags = AI_NUMERICSERV };
    int retval = uv_getaddrinfo(&loop->uv, &addr_req, NULL,
                                addr, host_end + 1, &hints);
    if (retval != 0) {
      *error = _("failed to lookup host or port");
      goto cleanup;
    }
    addrinfo = addr_req.addrinfo;

tcp_retry:
    uv_tcp_init(&loop->uv, tcp);
    uv_tcp_nodelay(tcp, true);
    uv_tcp_connect(&req,  tcp, addrinfo->ai_addr, connect_cb);
    uv_stream = (uv_stream_t *)tcp;
  } else {
    uv_pipe_t *pipe = &stream->s.uv.pipe;
    uv_pipe_init(&loop->uv, pipe, 0);
    uv_pipe_connect(&req,  pipe, address, connect_cb);
    uv_stream = (uv_stream_t *)pipe;
  }
  status = 1;
  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, NULL, timeout, status != 1);
  if (status == 0) {
    stream_init(NULL, &stream->s, -1, uv_stream);
    success = true;
  } else {
    if (!uv_is_closing((uv_handle_t *)uv_stream)) {
      uv_close((uv_handle_t *)uv_stream, NULL);
      if (status == 1) {
        // The uv_close() above will make libuv call connect_cb() with UV_ECANCELED.
        // Make sure connect_cb() has been called here, as if it's called after this
        // function ends it will cause a stack-use-after-scope.
        LOOP_PROCESS_EVENTS_UNTIL(&main_loop, NULL, -1, status != 1);
      }
    }

    if (is_tcp && addrinfo->ai_next) {
      addrinfo = addrinfo->ai_next;
      goto tcp_retry;
    } else {
      *error = _("connection refused");
    }
  }

cleanup:
  xfree(addr);
  uv_freeaddrinfo(addr_req.addrinfo);
  return success;
}
