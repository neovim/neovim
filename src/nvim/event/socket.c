// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/macros.h"
#include "nvim/charset.h"
#include "nvim/log.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/socket.c.generated.h"
#endif

int socket_watcher_init(Loop *loop, SocketWatcher *watcher,
                        const char *endpoint)
  FUNC_ATTR_NONNULL_ALL
{
  xstrlcpy(watcher->addr, endpoint, sizeof(watcher->addr));
  char *addr = watcher->addr;
  char *host_end = strrchr(addr, ':');

  if (host_end && addr != host_end) {
    // Split user specified address into two strings, addr(hostname) and port.
    // The port part in watcher->addr will be updated later.
    *host_end = '\0';
    char *port = host_end + 1;
    intmax_t iport;

    int ret = getdigits_safe(&(char_u *){ (char_u *)port }, &iport);
    if (ret == FAIL || iport < 0 || iport > UINT16_MAX) {
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
                                &(struct addrinfo){
                                  .ai_family = AF_UNSPEC,
                                  .ai_socktype = SOCK_STREAM,
                                });
    if (retval != 0) {
      ELOG("Host lookup failed: %s", endpoint);
      return retval;
    }
    watcher->uv.tcp.addrinfo = request.addrinfo;

    uv_tcp_init(&loop->uv, &watcher->uv.tcp.handle);
    uv_tcp_nodelay(&watcher->uv.tcp.handle, true);
    watcher->stream = STRUCT_CAST(uv_stream_t, &watcher->uv.tcp.handle);
  } else {
    uv_pipe_init(&loop->uv, &watcher->uv.pipe.handle, 0);
    watcher->stream = STRUCT_CAST(uv_stream_t, &watcher->uv.pipe.handle);
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
  watcher->cb = cb;
  int result = UV_EINVAL;

  if (watcher->stream->type == UV_TCP) {
    struct addrinfo *ai = watcher->uv.tcp.addrinfo;

    for (; ai; ai = ai->ai_next) {
      result = uv_tcp_bind(&watcher->uv.tcp.handle, ai->ai_addr, 0);
      if (result != 0) {
        continue;
      }
      result = uv_listen(watcher->stream, backlog, connection_cb);
      if (result == 0) {
        struct sockaddr_storage sas;

        // When the endpoint in socket_watcher_init() didn't specify a port
        // number, a free random port number will be assigned. sin_port will
        // contain 0 in this case, unless uv_tcp_getsockname() is used first.
        uv_tcp_getsockname(&watcher->uv.tcp.handle, (struct sockaddr *)&sas,
                           &(int){ sizeof(sas) });
        uint16_t port = (uint16_t)(
            (sas.ss_family == AF_INET)
            ? (STRUCT_CAST(struct sockaddr_in, &sas))->sin_port
            : (STRUCT_CAST(struct sockaddr_in6, &sas))->sin6_port);
        // v:servername uses the string from watcher->addr
        size_t len = strlen(watcher->addr);
        snprintf(watcher->addr+len, sizeof(watcher->addr)-len, ":%" PRIu16,
                 ntohs(port));
        break;
      }
    }
    uv_freeaddrinfo(watcher->uv.tcp.addrinfo);
  } else {
    result = uv_pipe_bind(&watcher->uv.pipe.handle, watcher->addr);
    if (result == 0) {
      result = uv_listen(watcher->stream, backlog, connection_cb);
    }
  }

  assert(result <= 0);  // libuv should return negative error code or zero.
  if (result < 0) {
    if (result == UV_EACCES) {
      // Libuv converts ENOENT to EACCES for Windows compatibility, but if
      // the parent directory does not exist, ENOENT would be more accurate.
      *path_tail((char_u *)watcher->addr) = NUL;
      if (!os_path_exists((char_u *)watcher->addr)) {
        result = UV_ENOENT;
      }
    }
    return result;
  }

  return 0;
}

int socket_watcher_accept(SocketWatcher *watcher, Stream *stream)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_NONNULL_ARG(2)
{
  uv_stream_t *client;

  if (watcher->stream->type == UV_TCP) {
    client = STRUCT_CAST(uv_stream_t, &stream->uv.tcp);
    uv_tcp_init(watcher->uv.tcp.handle.loop, (uv_tcp_t *)client);
    uv_tcp_nodelay((uv_tcp_t *)client, true);
  } else {
    client = STRUCT_CAST(uv_stream_t, &stream->uv.pipe);
    uv_pipe_init(watcher->uv.pipe.handle.loop, (uv_pipe_t *)client, 0);
  }

  int result = uv_accept(watcher->stream, client);

  if (result) {
    uv_close((uv_handle_t *)client, NULL);
    return result;
  }

  stream_init(NULL, stream, -1, client);
  return 0;
}

void socket_watcher_close(SocketWatcher *watcher, socket_close_cb cb)
  FUNC_ATTR_NONNULL_ARG(1)
{
  watcher->close_cb = cb;
  uv_close(STRUCT_CAST(uv_handle_t, watcher->stream), close_cb);
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

static void connect_cb(uv_connect_t *req, int status)
{
  int *ret_status = req->data;
  *ret_status = status;
  if (status != 0) {
    uv_close((uv_handle_t *)req->handle, NULL);
  }
}

bool socket_connect(Loop *loop, Stream *stream,
                    bool is_tcp, const char *address,
                    int timeout, const char **error)
{
  bool success = false;
  int status;
  uv_connect_t req;
  req.data = &status;
  uv_stream_t *uv_stream;

  uv_tcp_t *tcp = &stream->uv.tcp;
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
                                    .ai_flags  = AI_NUMERICSERV };
    int retval = uv_getaddrinfo(&loop->uv, &addr_req, NULL,
                                addr, host_end+1, &hints);
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
    uv_pipe_t *pipe = &stream->uv.pipe;
    uv_pipe_init(&loop->uv, pipe, 0);
    uv_pipe_connect(&req,  pipe, address, connect_cb);
    uv_stream = STRUCT_CAST(uv_stream_t, pipe);
  }
  status = 1;
  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, NULL, timeout, status != 1);
  if (status == 0) {  // -V547
    stream_init(NULL, stream, -1, uv_stream);
    success = true;
  } else if (is_tcp && addrinfo->ai_next) {
    addrinfo = addrinfo->ai_next;
    goto tcp_retry;
  } else {
    *error = _("connection refused");
  }

cleanup:
  xfree(addr);
  uv_freeaddrinfo(addr_req.addrinfo);
  return success;
}
