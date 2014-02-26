/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
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

#include <errno.h>
#include <stddef.h> /* NULL */
#include <stdlib.h>
#include <string.h>


static void uv__getaddrinfo_work(struct uv__work* w) {
  uv_getaddrinfo_t* req;
  int err;

  req = container_of(w, uv_getaddrinfo_t, work_req);
  err = getaddrinfo(req->hostname, req->service, req->hints, &req->res);
  req->retcode = uv__getaddrinfo_translate_error(err);
}


static void uv__getaddrinfo_done(struct uv__work* w, int status) {
  uv_getaddrinfo_t* req;
  struct addrinfo *res;

  req = container_of(w, uv_getaddrinfo_t, work_req);
  uv__req_unregister(req->loop, req);

  res = req->res;
  req->res = NULL;

  /* See initialization in uv_getaddrinfo(). */
  if (req->hints)
    free(req->hints);
  else if (req->service)
    free(req->service);
  else if (req->hostname)
    free(req->hostname);
  else
    assert(0);

  req->hints = NULL;
  req->service = NULL;
  req->hostname = NULL;

  if (status == -ECANCELED) {
    assert(req->retcode == 0);
    req->retcode = UV_EAI_CANCELED;
  }

  req->cb(req, req->retcode, res);
}


int uv_getaddrinfo(uv_loop_t* loop,
                   uv_getaddrinfo_t* req,
                   uv_getaddrinfo_cb cb,
                   const char* hostname,
                   const char* service,
                   const struct addrinfo* hints) {
  size_t hostname_len;
  size_t service_len;
  size_t hints_len;
  size_t len;
  char* buf;

  if (req == NULL || cb == NULL || (hostname == NULL && service == NULL))
    return -EINVAL;

  hostname_len = hostname ? strlen(hostname) + 1 : 0;
  service_len = service ? strlen(service) + 1 : 0;
  hints_len = hints ? sizeof(*hints) : 0;
  buf = malloc(hostname_len + service_len + hints_len);

  if (buf == NULL)
    return -ENOMEM;

  uv__req_init(loop, req, UV_GETADDRINFO);
  req->loop = loop;
  req->cb = cb;
  req->res = NULL;
  req->hints = NULL;
  req->service = NULL;
  req->hostname = NULL;
  req->retcode = 0;

  /* order matters, see uv_getaddrinfo_done() */
  len = 0;

  if (hints) {
    req->hints = memcpy(buf + len, hints, sizeof(*hints));
    len += sizeof(*hints);
  }

  if (service) {
    req->service = memcpy(buf + len, service, service_len);
    len += service_len;
  }

  if (hostname) {
    req->hostname = memcpy(buf + len, hostname, hostname_len);
    len += hostname_len;
  }

  uv__work_submit(loop,
                  &req->work_req,
                  uv__getaddrinfo_work,
                  uv__getaddrinfo_done);

  return 0;
}


void uv_freeaddrinfo(struct addrinfo* ai) {
  if (ai)
    freeaddrinfo(ai);
}
