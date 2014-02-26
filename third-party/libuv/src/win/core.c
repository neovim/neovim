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

#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <crtdbg.h>

#include "uv.h"
#include "internal.h"
#include "handle-inl.h"
#include "req-inl.h"


/* The only event loop we support right now */
static uv_loop_t uv_default_loop_;

/* uv_once intialization guards */
static uv_once_t uv_init_guard_ = UV_ONCE_INIT;
static uv_once_t uv_default_loop_init_guard_ = UV_ONCE_INIT;


#ifdef _DEBUG
/* Our crt debug report handler allows us to temporarily disable asserts */
/* just for the current thread. */

__declspec( thread ) int uv__crt_assert_enabled = TRUE;

static int uv__crt_dbg_report_handler(int report_type, char *message, int *ret_val) {
  if (uv__crt_assert_enabled || report_type != _CRT_ASSERT)
    return FALSE;
  
  if (ret_val) {
    /* Set ret_val to 0 to continue with normal execution. */
    /* Set ret_val to 1 to trigger a breakpoint. */

    if(IsDebuggerPresent())     
      *ret_val = 1;  
    else
      *ret_val = 0;  
  }

  /* Don't call _CrtDbgReport. */
  return TRUE;
}
#endif


static void uv__crt_invalid_parameter_handler(const wchar_t* expression,
    const wchar_t* function, const wchar_t * file, unsigned int line,
    uintptr_t reserved) {
  /* No-op. */
}


static void uv_init(void) {
  /* Tell Windows that we will handle critical errors. */
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX |
               SEM_NOOPENFILEERRORBOX);

  /* Tell the CRT to not exit the application when an invalid parameter is */
  /* passed. The main issue is that invalid FDs will trigger this behavior. */
#if !defined(__MINGW32__) || __MSVCRT_VERSION__ >= 0x800
  _set_invalid_parameter_handler(uv__crt_invalid_parameter_handler);
#endif

  /* We also need to setup our debug report handler because some CRT */
  /* functions (eg _get_osfhandle) raise an assert when called with invalid */
  /* FDs even though they return the proper error code in the release build. */
#ifdef _DEBUG
  _CrtSetReportHook(uv__crt_dbg_report_handler);
#endif

  /* Fetch winapi function pointers. This must be done first because other */
  /* intialization code might need these function pointers to be loaded. */
  uv_winapi_init();

  /* Initialize winsock */
  uv_winsock_init();

  /* Initialize FS */
  uv_fs_init();

  /* Initialize signal stuff */
  uv_signals_init();

  /* Initialize console */
  uv_console_init();

  /* Initialize utilities */
  uv__util_init();
}


static void uv_loop_init(uv_loop_t* loop) {
  /* Create an I/O completion port */
  loop->iocp = CreateIoCompletionPort(INVALID_HANDLE_VALUE, NULL, 0, 1);
  if (loop->iocp == NULL) {
    uv_fatal_error(GetLastError(), "CreateIoCompletionPort");
  }

  /* To prevent uninitialized memory access, loop->time must be intialized */
  /* to zero before calling uv_update_time for the first time. */
  loop->time = 0;
  loop->last_tick_count = 0;
  uv_update_time(loop);

  QUEUE_INIT(&loop->handle_queue);
  QUEUE_INIT(&loop->active_reqs);
  loop->active_handles = 0;

  loop->pending_reqs_tail = NULL;

  loop->endgame_handles = NULL;

  RB_INIT(&loop->timers);

  loop->check_handles = NULL;
  loop->prepare_handles = NULL;
  loop->idle_handles = NULL;

  loop->next_prepare_handle = NULL;
  loop->next_check_handle = NULL;
  loop->next_idle_handle = NULL;

  memset(&loop->poll_peer_sockets, 0, sizeof loop->poll_peer_sockets);

  loop->active_tcp_streams = 0;
  loop->active_udp_streams = 0;

  loop->timer_counter = 0;
  loop->stop_flag = 0;
}


static void uv_default_loop_init(void) {
  /* Initialize libuv itself first */
  uv__once_init();

  /* Initialize the main loop */
  uv_loop_init(&uv_default_loop_);
}


void uv__once_init(void) {
  uv_once(&uv_init_guard_, uv_init);
}


uv_loop_t* uv_default_loop(void) {
  uv_once(&uv_default_loop_init_guard_, uv_default_loop_init);
  return &uv_default_loop_;
}


uv_loop_t* uv_loop_new(void) {
  uv_loop_t* loop;

  /* Initialize libuv itself first */
  uv__once_init();

  loop = (uv_loop_t*)malloc(sizeof(uv_loop_t));

  if (!loop) {
    uv_fatal_error(ERROR_OUTOFMEMORY, "malloc");
  }

  uv_loop_init(loop);
  return loop;
}


void uv_loop_delete(uv_loop_t* loop) {
  if (loop != &uv_default_loop_) {
    int i;
    for (i = 0; i < ARRAY_SIZE(loop->poll_peer_sockets); i++) {
      SOCKET sock = loop->poll_peer_sockets[i];
      if (sock != 0 && sock != INVALID_SOCKET) {
        closesocket(sock);
      }
    }

    free(loop);
  }
}


int uv_backend_fd(const uv_loop_t* loop) {
  return -1;
}


int uv_backend_timeout(const uv_loop_t* loop) {
  return 0;
}


static void uv_poll(uv_loop_t* loop, int block) {
  DWORD bytes, timeout;
  ULONG_PTR key;
  OVERLAPPED* overlapped;
  uv_req_t* req;

  if (block) {
    timeout = uv_get_poll_timeout(loop);
  } else {
    timeout = 0;
  }

  GetQueuedCompletionStatus(loop->iocp,
                            &bytes,
                            &key,
                            &overlapped,
                            timeout);

  if (overlapped) {
    /* Package was dequeued */
    req = uv_overlapped_to_req(overlapped);
    uv_insert_pending_req(loop, req);
  } else if (GetLastError() != WAIT_TIMEOUT) {
    /* Serious error */
    uv_fatal_error(GetLastError(), "GetQueuedCompletionStatus");
  } else {
    /* We're sure that at least `timeout` milliseconds have expired, but */
    /* this may not be reflected yet in the GetTickCount() return value. */
    /* Therefore we ensure it's taken into account here. */
    uv__time_forward(loop, timeout);
  }
}


static void uv_poll_ex(uv_loop_t* loop, int block) {
  BOOL success;
  DWORD timeout;
  uv_req_t* req;
  OVERLAPPED_ENTRY overlappeds[128];
  ULONG count;
  ULONG i;

  if (block) {
    timeout = uv_get_poll_timeout(loop);
  } else {
    timeout = 0;
  }

  success = pGetQueuedCompletionStatusEx(loop->iocp,
                                         overlappeds,
                                         ARRAY_SIZE(overlappeds),
                                         &count,
                                         timeout,
                                         FALSE);

  if (success) {
    for (i = 0; i < count; i++) {
      /* Package was dequeued */
      req = uv_overlapped_to_req(overlappeds[i].lpOverlapped);
      uv_insert_pending_req(loop, req);
    }
  } else if (GetLastError() != WAIT_TIMEOUT) {
    /* Serious error */
    uv_fatal_error(GetLastError(), "GetQueuedCompletionStatusEx");
  } else if (timeout > 0) {
    /* We're sure that at least `timeout` milliseconds have expired, but */
    /* this may not be reflected yet in the GetTickCount() return value. */
    /* Therefore we ensure it's taken into account here. */
    uv__time_forward(loop, timeout);
  }
}


static int uv__loop_alive(const uv_loop_t* loop) {
  return loop->active_handles > 0 ||
         !QUEUE_EMPTY(&loop->active_reqs) ||
         loop->endgame_handles != NULL;
}


int uv_loop_alive(const uv_loop_t* loop) {
    return uv__loop_alive(loop);
}


int uv_run(uv_loop_t *loop, uv_run_mode mode) {
  int r;
  void (*poll)(uv_loop_t* loop, int block);

  if (pGetQueuedCompletionStatusEx)
    poll = &uv_poll_ex;
  else
    poll = &uv_poll;

  r = uv__loop_alive(loop);
  if (!r)
    uv_update_time(loop);

  while (r != 0 && loop->stop_flag == 0) {
    uv_update_time(loop);
    uv_process_timers(loop);

    uv_process_reqs(loop);
    uv_idle_invoke(loop);
    uv_prepare_invoke(loop);

    (*poll)(loop, loop->idle_handles == NULL &&
                  loop->pending_reqs_tail == NULL &&
                  loop->endgame_handles == NULL &&
                  !loop->stop_flag &&
                  (loop->active_handles > 0 ||
                   !QUEUE_EMPTY(&loop->active_reqs)) &&
                  !(mode & UV_RUN_NOWAIT));

    uv_check_invoke(loop);
    uv_process_endgames(loop);

    if (mode == UV_RUN_ONCE) {
      /* UV_RUN_ONCE implies forward progess: at least one callback must have
       * been invoked when it returns. uv__io_poll() can return without doing
       * I/O (meaning: no callbacks) when its timeout expires - which means we
       * have pending timers that satisfy the forward progress constraint.
       *
       * UV_RUN_NOWAIT makes no guarantees about progress so it's omitted from
       * the check.
       */
      uv_update_time(loop);
      uv_process_timers(loop);
    }

    r = uv__loop_alive(loop);
    if (mode & (UV_RUN_ONCE | UV_RUN_NOWAIT))
      break;
  }

  /* The if statement lets the compiler compile it to a conditional store.
   * Avoids dirtying a cache line.
   */
  if (loop->stop_flag != 0)
    loop->stop_flag = 0;

  return r;
}
