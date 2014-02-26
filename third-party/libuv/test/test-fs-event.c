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

#include <string.h>
#include <fcntl.h>

#ifndef HAVE_KQUEUE
# if defined(__APPLE__) ||                                                    \
     defined(__DragonFly__) ||                                                \
     defined(__FreeBSD__) ||                                                  \
     defined(__OpenBSD__) ||                                                  \
     defined(__NetBSD__)
#  define HAVE_KQUEUE 1
# endif
#endif

static uv_fs_event_t fs_event;
static const char file_prefix[] = "fsevent-";
static uv_timer_t timer;
static int timer_cb_called;
static int close_cb_called;
static const int fs_event_file_count = 128;
static int fs_event_created;
static int fs_event_cb_called;
#if defined(PATH_MAX)
static char fs_event_filename[PATH_MAX];
#else
static char fs_event_filename[1024];
#endif  /* defined(PATH_MAX) */
static int timer_cb_touch_called;

static void fs_event_unlink_files(uv_timer_t* handle, int status);

static void create_dir(uv_loop_t* loop, const char* name) {
  int r;
  uv_fs_t req;
  r = uv_fs_mkdir(loop, &req, name, 0755, NULL);
  ASSERT(r == 0 || r == UV_EEXIST);
  uv_fs_req_cleanup(&req);
}

static void create_file(uv_loop_t* loop, const char* name) {
  int r;
  uv_file file;
  uv_fs_t req;

  r = uv_fs_open(loop, &req, name, O_WRONLY | O_CREAT,
      S_IWUSR | S_IRUSR, NULL);
  ASSERT(r >= 0);
  file = r;
  uv_fs_req_cleanup(&req);
  r = uv_fs_close(loop, &req, file, NULL);
  ASSERT(r == 0);
  uv_fs_req_cleanup(&req);
}

static void touch_file(uv_loop_t* loop, const char* name) {
  int r;
  uv_file file;
  uv_fs_t req;

  r = uv_fs_open(loop, &req, name, O_RDWR, 0, NULL);
  ASSERT(r >= 0);
  file = r;
  uv_fs_req_cleanup(&req);

  r = uv_fs_write(loop, &req, file, "foo", 4, -1, NULL);
  ASSERT(r >= 0);
  uv_fs_req_cleanup(&req);

  r = uv_fs_close(loop, &req, file, NULL);
  ASSERT(r == 0);
  uv_fs_req_cleanup(&req);
}

static void close_cb(uv_handle_t* handle) {
  ASSERT(handle != NULL);
  close_cb_called++;
}

static void fail_cb(uv_fs_event_t* handle,
                    const char* path,
                    int events,
                    int status) {
  ASSERT(0 && "fail_cb called");
}

static void fs_event_cb_dir(uv_fs_event_t* handle, const char* filename,
  int events, int status) {
  ++fs_event_cb_called;
  ASSERT(handle == &fs_event);
  ASSERT(status == 0);
  ASSERT(events == UV_RENAME);
  ASSERT(filename == NULL || strcmp(filename, "file1") == 0);
  ASSERT(0 == uv_fs_event_stop(handle));
  uv_close((uv_handle_t*)handle, close_cb);
}

static void fs_event_cb_dir_multi_file(uv_fs_event_t* handle,
                                       const char* filename,
                                       int events,
                                       int status) {
  fs_event_cb_called++;
  ASSERT(handle == &fs_event);
  ASSERT(status == 0);
  ASSERT(events == UV_RENAME);
  ASSERT(filename == NULL ||
         strncmp(filename, file_prefix, sizeof(file_prefix) - 1) == 0);

  /* Stop watching dir when received events about all files:
   * both create and close events */
  if (fs_event_cb_called == 2 * fs_event_file_count) {
    ASSERT(0 == uv_fs_event_stop(handle));
    uv_close((uv_handle_t*) handle, close_cb);
  }
}

static const char* fs_event_get_filename(int i) {
  snprintf(fs_event_filename,
           sizeof(fs_event_filename),
           "watch_dir/%s%d",
           file_prefix,
           i);
  return fs_event_filename;
}

static void fs_event_create_files(uv_timer_t* handle, int status) {
  int i;

  /* Already created all files */
  if (fs_event_created == fs_event_file_count) {
    uv_close((uv_handle_t*) &timer, close_cb);
    return;
  }

  /* Create all files */
  for (i = 0; i < 16; i++, fs_event_created++)
    create_file(handle->loop, fs_event_get_filename(i));

  /* And unlink them */
  ASSERT(0 == uv_timer_start(&timer, fs_event_unlink_files, 50, 0));
}

void fs_event_unlink_files(uv_timer_t* handle, int status) {
  int r;
  int i;

  /* NOTE: handle might be NULL if invoked not as timer callback */

  /* Unlink all files */
  for (i = 0; i < 16; i++) {
    r = remove(fs_event_get_filename(i));
    if (handle != NULL)
      ASSERT(r == 0);
  }

  /* And create them again */
  if (handle != NULL)
    ASSERT(0 == uv_timer_start(&timer, fs_event_create_files, 50, 0));
}

static void fs_event_cb_file(uv_fs_event_t* handle, const char* filename,
  int events, int status) {
  ++fs_event_cb_called;
  ASSERT(handle == &fs_event);
  ASSERT(status == 0);
  ASSERT(events == UV_CHANGE);
  ASSERT(filename == NULL || strcmp(filename, "file2") == 0);
  ASSERT(0 == uv_fs_event_stop(handle));
  uv_close((uv_handle_t*)handle, close_cb);
}

static void timer_cb_close_handle(uv_timer_t* timer, int status) {
  uv_handle_t* handle;

  ASSERT(timer != NULL);
  ASSERT(status == 0);
  handle = timer->data;

  uv_close((uv_handle_t*)timer, NULL);
  uv_close((uv_handle_t*)handle, close_cb);
}

static void fs_event_cb_file_current_dir(uv_fs_event_t* handle,
  const char* filename, int events, int status) {
  ASSERT(fs_event_cb_called == 0);
  ++fs_event_cb_called;

  ASSERT(handle == &fs_event);
  ASSERT(status == 0);
  ASSERT(events == UV_CHANGE);
  ASSERT(filename == NULL || strcmp(filename, "watch_file") == 0);

  /* Regression test for SunOS: touch should generate just one event. */
  {
    static uv_timer_t timer;
    uv_timer_init(handle->loop, &timer);
    timer.data = handle;
    uv_timer_start(&timer, timer_cb_close_handle, 250, 0);
  }
}

static void timer_cb_file(uv_timer_t* handle, int status) {
  ++timer_cb_called;

  if (timer_cb_called == 1) {
    touch_file(handle->loop, "watch_dir/file1");
  } else {
    touch_file(handle->loop, "watch_dir/file2");
    uv_close((uv_handle_t*)handle, close_cb);
  }
}

static void timer_cb_touch(uv_timer_t* timer, int status) {
  ASSERT(status == 0);
  uv_close((uv_handle_t*)timer, NULL);
  touch_file(timer->loop, "watch_file");
  timer_cb_touch_called++;
}

static void timer_cb_watch_twice(uv_timer_t* handle, int status) {
  uv_fs_event_t* handles = handle->data;
  uv_close((uv_handle_t*) (handles + 0), NULL);
  uv_close((uv_handle_t*) (handles + 1), NULL);
  uv_close((uv_handle_t*) handle, NULL);
}

TEST_IMPL(fs_event_watch_dir) {
  uv_loop_t* loop = uv_default_loop();
  int r;

  /* Setup */
  fs_event_unlink_files(NULL, 0);
  remove("watch_dir/file2");
  remove("watch_dir/file1");
  remove("watch_dir/");
  create_dir(loop, "watch_dir");

  r = uv_fs_event_init(loop, &fs_event);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event, fs_event_cb_dir_multi_file, "watch_dir", 0);
  ASSERT(r == 0);
  r = uv_timer_init(loop, &timer);
  ASSERT(r == 0);
  r = uv_timer_start(&timer, fs_event_create_files, 100, 0);
  ASSERT(r == 0);

  uv_run(loop, UV_RUN_DEFAULT);

  ASSERT(fs_event_cb_called == 2 * fs_event_file_count);
  ASSERT(fs_event_created == fs_event_file_count);
  ASSERT(close_cb_called == 2);

  /* Cleanup */
  fs_event_unlink_files(NULL, 0);
  remove("watch_dir/file2");
  remove("watch_dir/file1");
  remove("watch_dir/");

  MAKE_VALGRIND_HAPPY();
  return 0;
}

TEST_IMPL(fs_event_watch_file) {
  uv_loop_t* loop = uv_default_loop();
  int r;

  /* Setup */
  remove("watch_dir/file2");
  remove("watch_dir/file1");
  remove("watch_dir/");
  create_dir(loop, "watch_dir");
  create_file(loop, "watch_dir/file1");
  create_file(loop, "watch_dir/file2");

  r = uv_fs_event_init(loop, &fs_event);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event, fs_event_cb_file, "watch_dir/file2", 0);
  ASSERT(r == 0);
  r = uv_timer_init(loop, &timer);
  ASSERT(r == 0);
  r = uv_timer_start(&timer, timer_cb_file, 100, 100);
  ASSERT(r == 0);

  uv_run(loop, UV_RUN_DEFAULT);

  ASSERT(fs_event_cb_called == 1);
  ASSERT(timer_cb_called == 2);
  ASSERT(close_cb_called == 2);

  /* Cleanup */
  remove("watch_dir/file2");
  remove("watch_dir/file1");
  remove("watch_dir/");

  MAKE_VALGRIND_HAPPY();
  return 0;
}

TEST_IMPL(fs_event_watch_file_twice) {
  const char path[] = "test/fixtures/empty_file";
  uv_fs_event_t watchers[2];
  uv_timer_t timer;
  uv_loop_t* loop;

  loop = uv_default_loop();
  timer.data = watchers;

  ASSERT(0 == uv_fs_event_init(loop, watchers + 0));
  ASSERT(0 == uv_fs_event_start(watchers + 0, fail_cb, path, 0));
  ASSERT(0 == uv_fs_event_init(loop, watchers + 1));
  ASSERT(0 == uv_fs_event_start(watchers + 1, fail_cb, path, 0));
  ASSERT(0 == uv_timer_init(loop, &timer));
  ASSERT(0 == uv_timer_start(&timer, timer_cb_watch_twice, 10, 0));
  ASSERT(0 == uv_run(loop, UV_RUN_DEFAULT));

  MAKE_VALGRIND_HAPPY();
  return 0;
}

TEST_IMPL(fs_event_watch_file_current_dir) {
  uv_timer_t timer;
  uv_loop_t* loop;
  int r;

  loop = uv_default_loop();

  /* Setup */
  remove("watch_file");
  create_file(loop, "watch_file");

  r = uv_fs_event_init(loop, &fs_event);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event,
                        fs_event_cb_file_current_dir,
                        "watch_file",
                        0);
  ASSERT(r == 0);


  r = uv_timer_init(loop, &timer);
  ASSERT(r == 0);

  r = uv_timer_start(&timer, timer_cb_touch, 1, 0);
  ASSERT(r == 0);

  ASSERT(timer_cb_touch_called == 0);
  ASSERT(fs_event_cb_called == 0);
  ASSERT(close_cb_called == 0);

  uv_run(loop, UV_RUN_DEFAULT);

  ASSERT(timer_cb_touch_called == 1);
  ASSERT(fs_event_cb_called == 1);
  ASSERT(close_cb_called == 1);

  /* Cleanup */
  remove("watch_file");

  MAKE_VALGRIND_HAPPY();
  return 0;
}

TEST_IMPL(fs_event_no_callback_after_close) {
  uv_loop_t* loop = uv_default_loop();
  int r;

  /* Setup */
  remove("watch_dir/file1");
  remove("watch_dir/");
  create_dir(loop, "watch_dir");
  create_file(loop, "watch_dir/file1");

  r = uv_fs_event_init(loop, &fs_event);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event,
                        fs_event_cb_file,
                        "watch_dir/file1",
                        0);
  ASSERT(r == 0);


  uv_close((uv_handle_t*)&fs_event, close_cb);
  touch_file(loop, "watch_dir/file1");
  uv_run(loop, UV_RUN_DEFAULT);

  ASSERT(fs_event_cb_called == 0);
  ASSERT(close_cb_called == 1);

  /* Cleanup */
  remove("watch_dir/file1");
  remove("watch_dir/");

  MAKE_VALGRIND_HAPPY();
  return 0;
}

TEST_IMPL(fs_event_no_callback_on_close) {
  uv_loop_t* loop = uv_default_loop();
  int r;

  /* Setup */
  remove("watch_dir/file1");
  remove("watch_dir/");
  create_dir(loop, "watch_dir");
  create_file(loop, "watch_dir/file1");

  r = uv_fs_event_init(loop, &fs_event);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event,
                        fs_event_cb_file,
                        "watch_dir/file1",
                        0);
  ASSERT(r == 0);

  uv_close((uv_handle_t*)&fs_event, close_cb);

  uv_run(loop, UV_RUN_DEFAULT);

  ASSERT(fs_event_cb_called == 0);
  ASSERT(close_cb_called == 1);

  /* Cleanup */
  remove("watch_dir/file1");
  remove("watch_dir/");

  MAKE_VALGRIND_HAPPY();
  return 0;
}


static void fs_event_fail(uv_fs_event_t* handle, const char* filename,
    int events, int status) {
  ASSERT(0 && "should never be called");
}


static void timer_cb(uv_timer_t* handle, int status) {
  int r;

  ASSERT(status == 0);

  r = uv_fs_event_init(handle->loop, &fs_event);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event, fs_event_fail, ".", 0);
  ASSERT(r == 0);

  uv_close((uv_handle_t*)&fs_event, close_cb);
  uv_close((uv_handle_t*)handle, close_cb);
}


TEST_IMPL(fs_event_immediate_close) {
  uv_timer_t timer;
  uv_loop_t* loop;
  int r;

  loop = uv_default_loop();

  r = uv_timer_init(loop, &timer);
  ASSERT(r == 0);

  r = uv_timer_start(&timer, timer_cb, 1, 0);
  ASSERT(r == 0);

  uv_run(loop, UV_RUN_DEFAULT);

  ASSERT(close_cb_called == 2);

  MAKE_VALGRIND_HAPPY();
  return 0;
}


TEST_IMPL(fs_event_close_with_pending_event) {
  uv_loop_t* loop;
  int r;

  loop = uv_default_loop();

  create_dir(loop, "watch_dir");
  create_file(loop, "watch_dir/file");

  r = uv_fs_event_init(loop, &fs_event);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event, fs_event_fail, "watch_dir", 0);
  ASSERT(r == 0);

  /* Generate an fs event. */
  touch_file(loop, "watch_dir/file");

  uv_close((uv_handle_t*)&fs_event, close_cb);

  uv_run(loop, UV_RUN_DEFAULT);

  ASSERT(close_cb_called == 1);

  /* Clean up */
  remove("watch_dir/file");
  remove("watch_dir/");

  MAKE_VALGRIND_HAPPY();
  return 0;
}

#if defined(HAVE_KQUEUE)

/* kqueue doesn't register fs events if you don't have an active watcher.
 * The file descriptor needs to be part of the kqueue set of interest and
 * that's not the case until we actually enter the event loop.
 */
TEST_IMPL(fs_event_close_in_callback) {
  fprintf(stderr, "Skipping test, doesn't work with kqueue.\n");
  return 0;
}

#else /* !HAVE_KQUEUE */

static void fs_event_cb_close(uv_fs_event_t* handle, const char* filename,
    int events, int status) {
  ASSERT(status == 0);

  ASSERT(fs_event_cb_called < 3);
  ++fs_event_cb_called;

  if (fs_event_cb_called == 3) {
    uv_close((uv_handle_t*) handle, close_cb);
  }
}


TEST_IMPL(fs_event_close_in_callback) {
  uv_loop_t* loop;
  int r;

  loop = uv_default_loop();

  create_dir(loop, "watch_dir");
  create_file(loop, "watch_dir/file1");
  create_file(loop, "watch_dir/file2");
  create_file(loop, "watch_dir/file3");
  create_file(loop, "watch_dir/file4");
  create_file(loop, "watch_dir/file5");

  r = uv_fs_event_init(loop, &fs_event);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event, fs_event_cb_close, "watch_dir", 0);
  ASSERT(r == 0);

  /* Generate a couple of fs events. */
  touch_file(loop, "watch_dir/file1");
  touch_file(loop, "watch_dir/file2");
  touch_file(loop, "watch_dir/file3");
  touch_file(loop, "watch_dir/file4");
  touch_file(loop, "watch_dir/file5");

  uv_run(loop, UV_RUN_DEFAULT);

  ASSERT(close_cb_called == 1);
  ASSERT(fs_event_cb_called == 3);

  /* Clean up */
  remove("watch_dir/file1");
  remove("watch_dir/file2");
  remove("watch_dir/file3");
  remove("watch_dir/file4");
  remove("watch_dir/file5");
  remove("watch_dir/");

  MAKE_VALGRIND_HAPPY();
  return 0;
}

#endif /* HAVE_KQUEUE */

TEST_IMPL(fs_event_start_and_close) {
  uv_loop_t* loop;
  uv_fs_event_t fs_event1;
  uv_fs_event_t fs_event2;
  int r;

  loop = uv_default_loop();

  create_dir(loop, "watch_dir");

  r = uv_fs_event_init(loop, &fs_event1);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event1, fs_event_cb_dir, "watch_dir", 0);
  ASSERT(r == 0);

  r = uv_fs_event_init(loop, &fs_event2);
  ASSERT(r == 0);
  r = uv_fs_event_start(&fs_event2, fs_event_cb_dir, "watch_dir", 0);
  ASSERT(r == 0);

  uv_close((uv_handle_t*) &fs_event2, close_cb);
  uv_close((uv_handle_t*) &fs_event1, close_cb);

  uv_run(loop, UV_RUN_DEFAULT);

  ASSERT(close_cb_called == 2);

  remove("watch_dir/");
  MAKE_VALGRIND_HAPPY();
  return 0;
}

#if defined(__APPLE__)

static int fs_event_error_reported;

static void fs_event_error_report_cb(uv_fs_event_t* handle,
                                     const char* filename,
                                     int events,
                                     int status) {
  if (status != 0)
    fs_event_error_reported = status;
}

static void timer_cb_nop(uv_timer_t* handle, int status) {
  ++timer_cb_called;
  uv_close((uv_handle_t*) handle, close_cb);
}

static void fs_event_error_report_close_cb(uv_handle_t* handle) {
  ASSERT(handle != NULL);
  close_cb_called++;

  /* handle is allocated on-stack, no need to free it */
}


TEST_IMPL(fs_event_error_reporting) {
  unsigned int i;
  uv_loop_t* loops[1024];
  uv_fs_event_t events[ARRAY_SIZE(loops)];
  uv_loop_t* loop;
  uv_fs_event_t* event;

  TEST_FILE_LIMIT(ARRAY_SIZE(loops) * 3);

  remove("watch_dir/");
  create_dir(uv_default_loop(), "watch_dir");

  /* Create a lot of loops, and start FSEventStream in each of them.
   * Eventually, this should create enough streams to make FSEventStreamStart()
   * fail.
   */
  for (i = 0; i < ARRAY_SIZE(loops); i++) {
    loop = uv_loop_new();
    event = &events[i];
    ASSERT(loop != NULL);

    loops[i] = loop;
    timer_cb_called = 0;
    close_cb_called = 0;
    ASSERT(0 == uv_fs_event_init(loop, event));
    ASSERT(0 == uv_fs_event_start(event,
                                  fs_event_error_report_cb,
                                  "watch_dir",
                                  0));
    uv_unref((uv_handle_t*) event);

    /* Let loop run for some time */
    ASSERT(0 == uv_timer_init(loop, &timer));
    ASSERT(0 == uv_timer_start(&timer, timer_cb_nop, 2, 0));
    uv_run(loop, UV_RUN_DEFAULT);
    ASSERT(1 == timer_cb_called);
    ASSERT(1 == close_cb_called);
    if (fs_event_error_reported != 0)
      break;
  }

  /* At least one loop should fail */
  ASSERT(fs_event_error_reported == UV_EMFILE);

  /* Stop and close all events, and destroy loops */
  do {
    loop = loops[i];
    event = &events[i];

    ASSERT(0 == uv_fs_event_stop(event));
    uv_ref((uv_handle_t*) event);
    uv_close((uv_handle_t*) event, fs_event_error_report_close_cb);

    close_cb_called = 0;
    uv_run(loop, UV_RUN_DEFAULT);
    ASSERT(close_cb_called == 1);

    uv_loop_delete(loop);

    loops[i] = NULL;
  } while (i-- != 0);

  remove("watch_dir/");
  MAKE_VALGRIND_HAPPY();
  return 0;
}

#else  /* !defined(__APPLE__) */

TEST_IMPL(fs_event_error_reporting) {
  /* No-op, needed only for FSEvents backend */

  MAKE_VALGRIND_HAPPY();
  return 0;
}

#endif  /* defined(__APPLE__) */
