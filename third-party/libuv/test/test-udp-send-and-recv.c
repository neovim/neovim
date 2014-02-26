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
#include "task.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK_HANDLE(handle) \
  ASSERT((uv_udp_t*)(handle) == &server || (uv_udp_t*)(handle) == &client)

static uv_udp_t server;
static uv_udp_t client;

static int cl_send_cb_called;
static int cl_recv_cb_called;

static int sv_send_cb_called;
static int sv_recv_cb_called;

static int close_cb_called;


static void alloc_cb(uv_handle_t* handle,
                     size_t suggested_size,
                     uv_buf_t* buf) {
  static char slab[65536];
  CHECK_HANDLE(handle);
  ASSERT(suggested_size <= sizeof(slab));
  buf->base = slab;
  buf->len = sizeof(slab);
}


static void close_cb(uv_handle_t* handle) {
  CHECK_HANDLE(handle);
  ASSERT(1 == uv_is_closing(handle));
  close_cb_called++;
}


static void cl_recv_cb(uv_udp_t* handle,
                       ssize_t nread,
                       const uv_buf_t* buf,
                       const struct sockaddr* addr,
                       unsigned flags) {
  CHECK_HANDLE(handle);
  ASSERT(flags == 0);

  if (nread < 0) {
    ASSERT(0 && "unexpected error");
  }

  if (nread == 0) {
    /* Returning unused buffer */
    /* Don't count towards cl_recv_cb_called */
    ASSERT(addr == NULL);
    return;
  }

  ASSERT(addr != NULL);
  ASSERT(nread == 4);
  ASSERT(!memcmp("PONG", buf->base, nread));

  cl_recv_cb_called++;

  uv_close((uv_handle_t*) handle, close_cb);
}


static void cl_send_cb(uv_udp_send_t* req, int status) {
  int r;

  ASSERT(req != NULL);
  ASSERT(status == 0);
  CHECK_HANDLE(req->handle);

  r = uv_udp_recv_start(req->handle, alloc_cb, cl_recv_cb);
  ASSERT(r == 0);

  cl_send_cb_called++;
}


static void sv_send_cb(uv_udp_send_t* req, int status) {
  ASSERT(req != NULL);
  ASSERT(status == 0);
  CHECK_HANDLE(req->handle);

  uv_close((uv_handle_t*) req->handle, close_cb);
  free(req);

  sv_send_cb_called++;
}


static void sv_recv_cb(uv_udp_t* handle,
                       ssize_t nread,
                       const uv_buf_t* rcvbuf,
                       const struct sockaddr* addr,
                       unsigned flags) {
  uv_udp_send_t* req;
  uv_buf_t sndbuf;
  int r;

  if (nread < 0) {
    ASSERT(0 && "unexpected error");
  }

  if (nread == 0) {
    /* Returning unused buffer */
    /* Don't count towards sv_recv_cb_called */
    ASSERT(addr == NULL);
    return;
  }

  CHECK_HANDLE(handle);
  ASSERT(flags == 0);

  ASSERT(addr != NULL);
  ASSERT(nread == 4);
  ASSERT(!memcmp("PING", rcvbuf->base, nread));

  /* FIXME? `uv_udp_recv_stop` does what it says: recv_cb is not called
    * anymore. That's problematic because the read buffer won't be returned
    * either... Not sure I like that but it's consistent with `uv_read_stop`.
    */
  r = uv_udp_recv_stop(handle);
  ASSERT(r == 0);

  req = malloc(sizeof *req);
  ASSERT(req != NULL);

  sndbuf = uv_buf_init("PONG", 4);
  r = uv_udp_send(req, handle, &sndbuf, 1, addr, sv_send_cb);
  ASSERT(r == 0);

  sv_recv_cb_called++;
}


TEST_IMPL(udp_send_and_recv) {
  struct sockaddr_in addr;
  uv_udp_send_t req;
  uv_buf_t buf;
  int r;

  ASSERT(0 == uv_ip4_addr("0.0.0.0", TEST_PORT, &addr));

  r = uv_udp_init(uv_default_loop(), &server);
  ASSERT(r == 0);

  r = uv_udp_bind(&server, (const struct sockaddr*) &addr, 0);
  ASSERT(r == 0);

  r = uv_udp_recv_start(&server, alloc_cb, sv_recv_cb);
  ASSERT(r == 0);

  ASSERT(0 == uv_ip4_addr("127.0.0.1", TEST_PORT, &addr));

  r = uv_udp_init(uv_default_loop(), &client);
  ASSERT(r == 0);

  /* client sends "PING", expects "PONG" */
  buf = uv_buf_init("PING", 4);

  r = uv_udp_send(&req,
                  &client,
                  &buf,
                  1,
                  (const struct sockaddr*) &addr,
                  cl_send_cb);
  ASSERT(r == 0);

  ASSERT(close_cb_called == 0);
  ASSERT(cl_send_cb_called == 0);
  ASSERT(cl_recv_cb_called == 0);
  ASSERT(sv_send_cb_called == 0);
  ASSERT(sv_recv_cb_called == 0);

  uv_run(uv_default_loop(), UV_RUN_DEFAULT);

  ASSERT(cl_send_cb_called == 1);
  ASSERT(cl_recv_cb_called == 1);
  ASSERT(sv_send_cb_called == 1);
  ASSERT(sv_recv_cb_called == 1);
  ASSERT(close_cb_called == 2);

  MAKE_VALGRIND_HAPPY();
  return 0;
}
