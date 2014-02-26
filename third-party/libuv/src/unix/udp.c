/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#include "uv.h"
#include "internal.h"

#include <assert.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>


static void uv__udp_run_completed(uv_udp_t* handle);
static void uv__udp_run_pending(uv_udp_t* handle);
static void uv__udp_io(uv_loop_t* loop, uv__io_t* w, unsigned int revents);
static void uv__udp_recvmsg(uv_loop_t* loop, uv__io_t* w, unsigned int revents);
static void uv__udp_sendmsg(uv_loop_t* loop, uv__io_t* w, unsigned int revents);
static int uv__udp_maybe_deferred_bind(uv_udp_t* handle, int domain);


void uv__udp_close(uv_udp_t* handle) {
  uv__io_close(handle->loop, &handle->io_watcher);
  uv__handle_stop(handle);

  if (handle->io_watcher.fd != -1) {
    uv__close(handle->io_watcher.fd);
    handle->io_watcher.fd = -1;
  }
}


void uv__udp_finish_close(uv_udp_t* handle) {
  uv_udp_send_t* req;
  QUEUE* q;

  assert(!uv__io_active(&handle->io_watcher, UV__POLLIN | UV__POLLOUT));
  assert(handle->io_watcher.fd == -1);

  uv__udp_run_completed(handle);

  while (!QUEUE_EMPTY(&handle->write_queue)) {
    q = QUEUE_HEAD(&handle->write_queue);
    QUEUE_REMOVE(q);

    req = QUEUE_DATA(q, uv_udp_send_t, queue);
    uv__req_unregister(handle->loop, req);

    if (req->bufs != req->bufsml)
      free(req->bufs);
    req->bufs = NULL;

    if (req->send_cb != NULL)
      req->send_cb(req, -ECANCELED);
  }

  /* Now tear down the handle. */
  handle->recv_cb = NULL;
  handle->alloc_cb = NULL;
  /* but _do not_ touch close_cb */
}


static void uv__udp_run_pending(uv_udp_t* handle) {
  uv_udp_send_t* req;
  QUEUE* q;
  struct msghdr h;
  ssize_t size;

  while (!QUEUE_EMPTY(&handle->write_queue)) {
    q = QUEUE_HEAD(&handle->write_queue);
    assert(q != NULL);

    req = QUEUE_DATA(q, uv_udp_send_t, queue);
    assert(req != NULL);

    memset(&h, 0, sizeof h);
    h.msg_name = &req->addr;
    h.msg_namelen = (req->addr.sin6_family == AF_INET6 ?
      sizeof(struct sockaddr_in6) : sizeof(struct sockaddr_in));
    h.msg_iov = (struct iovec*) req->bufs;
    h.msg_iovlen = req->nbufs;

    do {
      size = sendmsg(handle->io_watcher.fd, &h, 0);
    }
    while (size == -1 && errno == EINTR);

    /* TODO try to write once or twice more in the
     * hope that the socket becomes readable again?
     */
    if (size == -1 && (errno == EAGAIN || errno == EWOULDBLOCK))
      break;

    req->status = (size == -1 ? -errno : size);

    /* Sending a datagram is an atomic operation: either all data
     * is written or nothing is (and EMSGSIZE is raised). That is
     * why we don't handle partial writes. Just pop the request
     * off the write queue and onto the completed queue, done.
     */
    QUEUE_REMOVE(&req->queue);
    QUEUE_INSERT_TAIL(&handle->write_completed_queue, &req->queue);
  }
}


static void uv__udp_run_completed(uv_udp_t* handle) {
  uv_udp_send_t* req;
  QUEUE* q;

  while (!QUEUE_EMPTY(&handle->write_completed_queue)) {
    q = QUEUE_HEAD(&handle->write_completed_queue);
    QUEUE_REMOVE(q);

    req = QUEUE_DATA(q, uv_udp_send_t, queue);
    uv__req_unregister(handle->loop, req);

    if (req->bufs != req->bufsml)
      free(req->bufs);
    req->bufs = NULL;

    if (req->send_cb == NULL)
      continue;

    /* req->status >= 0 == bytes written
     * req->status <  0 == errno
     */
    if (req->status >= 0)
      req->send_cb(req, 0);
    else
      req->send_cb(req, req->status);
  }
}


static void uv__udp_io(uv_loop_t* loop, uv__io_t* w, unsigned int revents) {
  if (revents & UV__POLLIN)
    uv__udp_recvmsg(loop, w, revents);

  if (revents & UV__POLLOUT)
    uv__udp_sendmsg(loop, w, revents);
}


static void uv__udp_recvmsg(uv_loop_t* loop,
                            uv__io_t* w,
                            unsigned int revents) {
  struct sockaddr_storage peer;
  struct msghdr h;
  uv_udp_t* handle;
  ssize_t nread;
  uv_buf_t buf;
  int flags;
  int count;

  handle = container_of(w, uv_udp_t, io_watcher);
  assert(handle->type == UV_UDP);
  assert(revents & UV__POLLIN);

  assert(handle->recv_cb != NULL);
  assert(handle->alloc_cb != NULL);

  /* Prevent loop starvation when the data comes in as fast as (or faster than)
   * we can read it. XXX Need to rearm fd if we switch to edge-triggered I/O.
   */
  count = 32;

  memset(&h, 0, sizeof(h));
  h.msg_name = &peer;

  do {
    handle->alloc_cb((uv_handle_t*) handle, 64 * 1024, &buf);
    if (buf.len == 0) {
      handle->recv_cb(handle, UV_ENOBUFS, &buf, NULL, 0);
      return;
    }
    assert(buf.base != NULL);

    h.msg_namelen = sizeof(peer);
    h.msg_iov = (void*) &buf;
    h.msg_iovlen = 1;

    do {
      nread = recvmsg(handle->io_watcher.fd, &h, 0);
    }
    while (nread == -1 && errno == EINTR);

    if (nread == -1) {
      if (errno == EAGAIN || errno == EWOULDBLOCK)
        handle->recv_cb(handle, 0, &buf, NULL, 0);
      else
        handle->recv_cb(handle, -errno, &buf, NULL, 0);
    }
    else {
      flags = 0;

      if (h.msg_flags & MSG_TRUNC)
        flags |= UV_UDP_PARTIAL;

      handle->recv_cb(handle,
                      nread,
                      &buf,
                      (const struct sockaddr*) &peer,
                      flags);
    }
  }
  /* recv_cb callback may decide to pause or close the handle */
  while (nread != -1
      && count-- > 0
      && handle->io_watcher.fd != -1
      && handle->recv_cb != NULL);
}


static void uv__udp_sendmsg(uv_loop_t* loop,
                            uv__io_t* w,
                            unsigned int revents) {
  uv_udp_t* handle;

  handle = container_of(w, uv_udp_t, io_watcher);
  assert(handle->type == UV_UDP);
  assert(revents & UV__POLLOUT);

  assert(!QUEUE_EMPTY(&handle->write_queue)
      || !QUEUE_EMPTY(&handle->write_completed_queue));

  /* Write out pending data first. */
  uv__udp_run_pending(handle);

  /* Drain 'request completed' queue. */
  uv__udp_run_completed(handle);

  if (!QUEUE_EMPTY(&handle->write_completed_queue)) {
    /* Schedule completion callbacks. */
    uv__io_feed(handle->loop, &handle->io_watcher);
  }
  else if (QUEUE_EMPTY(&handle->write_queue)) {
    /* Pending queue and completion queue empty, stop watcher. */
    uv__io_stop(loop, &handle->io_watcher, UV__POLLOUT);

    if (!uv__io_active(&handle->io_watcher, UV__POLLIN))
      uv__handle_stop(handle);
  }
}


/* On the BSDs, SO_REUSEPORT implies SO_REUSEADDR but with some additional
 * refinements for programs that use multicast.
 *
 * Linux as of 3.9 has a SO_REUSEPORT socket option but with semantics that
 * are different from the BSDs: it _shares_ the port rather than steal it
 * from the current listener.  While useful, it's not something we can emulate
 * on other platforms so we don't enable it.
 */
static int uv__set_reuse(int fd) {
  int yes;

#if defined(SO_REUSEPORT) && !defined(__linux__)
  yes = 1;
  if (setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &yes, sizeof(yes)))
    return -errno;
#else
  yes = 1;
  if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)))
    return -errno;
#endif

  return 0;
}


int uv__udp_bind(uv_udp_t* handle,
                 const struct sockaddr* addr,
                 unsigned int addrlen,
                 unsigned int flags) {
  int err;
  int yes;
  int fd;

  err = -EINVAL;
  fd = -1;

  /* Check for bad flags. */
  if (flags & ~UV_UDP_IPV6ONLY)
    return -EINVAL;

  /* Cannot set IPv6-only mode on non-IPv6 socket. */
  if ((flags & UV_UDP_IPV6ONLY) && addr->sa_family != AF_INET6)
    return -EINVAL;

  fd = handle->io_watcher.fd;
  if (fd == -1) {
    fd = uv__socket(addr->sa_family, SOCK_DGRAM, 0);
    if (fd == -1)
      return -errno;
    handle->io_watcher.fd = fd;
  }

  err = uv__set_reuse(fd);
  if (err)
    goto out;

  if (flags & UV_UDP_IPV6ONLY) {
#ifdef IPV6_V6ONLY
    yes = 1;
    if (setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &yes, sizeof yes) == -1) {
      err = -errno;
      goto out;
    }
#else
    err = -ENOTSUP;
    goto out;
#endif
  }

  if (bind(fd, addr, addrlen)) {
    err = -errno;
    goto out;
  }

  return 0;

out:
  uv__close(handle->io_watcher.fd);
  handle->io_watcher.fd = -1;
  return err;
}


static int uv__udp_maybe_deferred_bind(uv_udp_t* handle, int domain) {
  unsigned char taddr[sizeof(struct sockaddr_in6)];
  socklen_t addrlen;

  assert(domain == AF_INET || domain == AF_INET6);

  if (handle->io_watcher.fd != -1)
    return 0;

  switch (domain) {
  case AF_INET:
  {
    struct sockaddr_in* addr = (void*)&taddr;
    memset(addr, 0, sizeof *addr);
    addr->sin_family = AF_INET;
    addr->sin_addr.s_addr = INADDR_ANY;
    addrlen = sizeof *addr;
    break;
  }
  case AF_INET6:
  {
    struct sockaddr_in6* addr = (void*)&taddr;
    memset(addr, 0, sizeof *addr);
    addr->sin6_family = AF_INET6;
    addr->sin6_addr = in6addr_any;
    addrlen = sizeof *addr;
    break;
  }
  default:
    assert(0 && "unsupported address family");
    abort();
  }

  return uv__udp_bind(handle, (const struct sockaddr*) &taddr, addrlen, 0);
}


int uv__udp_send(uv_udp_send_t* req,
                 uv_udp_t* handle,
                 const uv_buf_t bufs[],
                 unsigned int nbufs,
                 const struct sockaddr* addr,
                 unsigned int addrlen,
                 uv_udp_send_cb send_cb) {
  int err;

  assert(nbufs > 0);

  err = uv__udp_maybe_deferred_bind(handle, addr->sa_family);
  if (err)
    return err;

  uv__req_init(handle->loop, req, UV_UDP_SEND);

  assert(addrlen <= sizeof(req->addr));
  memcpy(&req->addr, addr, addrlen);
  req->send_cb = send_cb;
  req->handle = handle;
  req->nbufs = nbufs;

  req->bufs = req->bufsml;
  if (nbufs > ARRAY_SIZE(req->bufsml))
    req->bufs = malloc(nbufs * sizeof(bufs[0]));

  if (req->bufs == NULL)
    return -ENOMEM;

  memcpy(req->bufs, bufs, nbufs * sizeof(bufs[0]));
  QUEUE_INSERT_TAIL(&handle->write_queue, &req->queue);
  uv__io_start(handle->loop, &handle->io_watcher, UV__POLLOUT);
  uv__handle_start(handle);

  return 0;
}


int uv_udp_init(uv_loop_t* loop, uv_udp_t* handle) {
  uv__handle_init(loop, (uv_handle_t*)handle, UV_UDP);
  handle->alloc_cb = NULL;
  handle->recv_cb = NULL;
  uv__io_init(&handle->io_watcher, uv__udp_io, -1);
  QUEUE_INIT(&handle->write_queue);
  QUEUE_INIT(&handle->write_completed_queue);
  return 0;
}


int uv_udp_open(uv_udp_t* handle, uv_os_sock_t sock) {
  int err;

  /* Check for already active socket. */
  if (handle->io_watcher.fd != -1)
    return -EALREADY;  /* FIXME(bnoordhuis) Should be -EBUSY. */

  err = uv__set_reuse(sock);
  if (err)
    return err;

  handle->io_watcher.fd = sock;
  return 0;
}


int uv_udp_set_membership(uv_udp_t* handle,
                          const char* multicast_addr,
                          const char* interface_addr,
                          uv_membership membership) {
  struct ip_mreq mreq;
  int optname;

  memset(&mreq, 0, sizeof mreq);

  if (interface_addr) {
    mreq.imr_interface.s_addr = inet_addr(interface_addr);
  } else {
    mreq.imr_interface.s_addr = htonl(INADDR_ANY);
  }

  mreq.imr_multiaddr.s_addr = inet_addr(multicast_addr);

  switch (membership) {
  case UV_JOIN_GROUP:
    optname = IP_ADD_MEMBERSHIP;
    break;
  case UV_LEAVE_GROUP:
    optname = IP_DROP_MEMBERSHIP;
    break;
  default:
    return -EINVAL;
  }

  if (setsockopt(handle->io_watcher.fd,
                 IPPROTO_IP,
                 optname,
                 &mreq,
                 sizeof(mreq))) {
    return -errno;
  }

  return 0;
}


static int uv__setsockopt_maybe_char(uv_udp_t* handle, int option, int val) {
#if defined(__sun)
  char arg = val;
#else
  int arg = val;
#endif

  if (val < 0 || val > 255)
    return -EINVAL;

  if (setsockopt(handle->io_watcher.fd, IPPROTO_IP, option, &arg, sizeof(arg)))
    return -errno;

  return 0;
}


int uv_udp_set_broadcast(uv_udp_t* handle, int on) {
  if (setsockopt(handle->io_watcher.fd,
                 SOL_SOCKET,
                 SO_BROADCAST,
                 &on,
                 sizeof(on))) {
    return -errno;
  }

  return 0;
}


int uv_udp_set_ttl(uv_udp_t* handle, int ttl) {
  if (ttl < 1 || ttl > 255)
    return -EINVAL;

  if (setsockopt(handle->io_watcher.fd, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl)))
    return -errno;

  return 0;
}


int uv_udp_set_multicast_ttl(uv_udp_t* handle, int ttl) {
  return uv__setsockopt_maybe_char(handle, IP_MULTICAST_TTL, ttl);
}


int uv_udp_set_multicast_loop(uv_udp_t* handle, int on) {
  return uv__setsockopt_maybe_char(handle, IP_MULTICAST_LOOP, on);
}


int uv_udp_getsockname(uv_udp_t* handle, struct sockaddr* name, int* namelen) {
  socklen_t socklen;

  if (handle->io_watcher.fd == -1)
    return -EINVAL;  /* FIXME(bnoordhuis) -EBADF */

  /* sizeof(socklen_t) != sizeof(int) on some systems. */
  socklen = (socklen_t) *namelen;

  if (getsockname(handle->io_watcher.fd, name, &socklen))
    return -errno;

  *namelen = (int) socklen;
  return 0;
}


int uv__udp_recv_start(uv_udp_t* handle,
                       uv_alloc_cb alloc_cb,
                       uv_udp_recv_cb recv_cb) {
  int err;

  if (alloc_cb == NULL || recv_cb == NULL)
    return -EINVAL;

  if (uv__io_active(&handle->io_watcher, UV__POLLIN))
    return -EALREADY;  /* FIXME(bnoordhuis) Should be -EBUSY. */

  err = uv__udp_maybe_deferred_bind(handle, AF_INET);
  if (err)
    return err;

  handle->alloc_cb = alloc_cb;
  handle->recv_cb = recv_cb;

  uv__io_start(handle->loop, &handle->io_watcher, UV__POLLIN);
  uv__handle_start(handle);

  return 0;
}


int uv__udp_recv_stop(uv_udp_t* handle) {
  uv__io_stop(handle->loop, &handle->io_watcher, UV__POLLIN);

  if (!uv__io_active(&handle->io_watcher, UV__POLLOUT))
    uv__handle_stop(handle);

  handle->alloc_cb = NULL;
  handle->recv_cb = NULL;

  return 0;
}
