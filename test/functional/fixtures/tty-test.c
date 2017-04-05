// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include <uv.h>
#ifdef _WIN32
#include <windows.h>
#endif

// -V:STRUCT_CAST:641
#define STRUCT_CAST(Type, obj) ((Type *)(obj))
#define is_terminal(stream) (uv_guess_handle(fileno(stream)) == UV_TTY)
#define BUF_SIZE 0xfff
#define CTRL_C 0x03
#ifdef _WIN32
#define CTRL_Q 0x11
#endif

#ifdef _WIN32
typedef struct screen_size {
  int width;
  int height;
} ScreenSize;
#endif

uv_tty_t tty;
#ifdef _WIN32
ScreenSize screen_rect;
#endif

#ifdef _WIN32
bool owns_tty(void)
{
  // XXX: We need to make proper detect owns tty
  // HWND consoleWnd = GetConsoleWindow();
  // DWORD dwProcessId;
  // GetWindowThreadProcessId(consoleWnd, &dwProcessId);
  // return GetCurrentProcessId() == dwProcessId;
  return true;
}
#else
#include <unistd.h>
bool owns_tty(void)
{
  return getsid(0) == getpid();
}
#endif

static void walk_cb(uv_handle_t *handle, void *arg)
{
  if (!uv_is_closing(handle)) {
    uv_close(handle, NULL);
  }
}

#ifndef WIN32
static void sig_handler(int signum)
{
  switch (signum) {
  case SIGWINCH: {
    int width, height;
    uv_tty_get_winsize(&tty, &width, &height);
    fprintf(stderr, "rows: %d, cols: %d\n", height, width);
    return;
  }
  case SIGHUP:
    exit(42);  // arbitrary exit code to test against
    return;
  default:
    return;
  }
}
#else
// static void sigwinch_cb(uv_signal_t *handle, int signum)
// {
//   int width, height;
//   uv_tty_t out;
//   uv_tty_init(uv_default_loop(), &out, fileno(stdout), 0);
//   uv_tty_get_winsize(&out, &width, &height);
//   fprintf(stderr, "rows: %d, cols: %d\n", height, width);
//   uv_close((uv_handle_t *)&out, NULL);
// }
#endif

static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  buf->len = BUF_SIZE;
  buf->base = malloc(BUF_SIZE);
}

static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf)
{
  if (cnt <= 0) {
    uv_read_stop(stream);
    return;
  }

  int *interrupted = stream->data;
#ifdef _WIN32
  bool prsz = false;
  int width;
  int height;
#endif

  for (int i = 0; i < cnt; i++) {
    if (buf->base[i] == CTRL_C) {
      (*interrupted)++;
#ifdef _WIN32
    } else if (buf->base[i] == CTRL_Q) {
      prsz = true;
#endif
    }
  }

  uv_loop_t write_loop;
  uv_loop_init(&write_loop);
  uv_tty_t out;
  uv_tty_init(&write_loop, &out, fileno(stdout), 0);

#ifdef _WIN32
  if (prsz) {
    uv_tty_get_winsize(&out, &width, &height);
    if (screen_rect.width != width || screen_rect.height != height) {
      screen_rect.width = width;
      screen_rect.height = height;
      fprintf(stderr, "rows: %d, cols: %d\n", height, width);
    }
  } else {
#endif
    uv_write_t req;
    uv_buf_t b = {.base = buf->base, .len = (size_t)cnt};
    uv_write(&req, STRUCT_CAST(uv_stream_t, &out), &b, 1, NULL);
    uv_run(&write_loop, UV_RUN_DEFAULT);
#ifdef _WIN32
  }
#endif

  uv_close(STRUCT_CAST(uv_handle_t, &out), NULL);
  uv_run(&write_loop, UV_RUN_DEFAULT);
  if (uv_loop_close(&write_loop)) {
    abort();
  }
  free(buf->base);

  if (*interrupted >= 2) {
    uv_walk(uv_default_loop(), walk_cb, NULL);
  } else if (*interrupted == 1) {
    fprintf(stderr, "interrupt received, press again to exit\n");
  }
}

static void prepare_cb(uv_prepare_t *handle)
{
  fprintf(stderr, "tty ready\n");
  uv_prepare_stop(handle);
}

int main(int argc, char **argv)
{
  if (!owns_tty()) {
    fprintf(stderr, "process does not own the terminal\n");
    exit(2);
  }

  if (!is_terminal(stdin)) {
    fprintf(stderr, "stdin is not a terminal\n");
    exit(2);
  }

  if (!is_terminal(stdout)) {
    fprintf(stderr, "stdout is not a terminal\n");
    exit(2);
  }

  if (!is_terminal(stderr)) {
    fprintf(stderr, "stderr is not a terminal\n");
    exit(2);
  }

  if (argc > 1) {
    int count = atoi(argv[1]);
    for (int i = 0; i < count; i++) {
      printf("line%d\n", i);
    }
    fflush(stdout);
    return 0;
  }

  int interrupted = 0;
  uv_prepare_t prepare;
  uv_prepare_init(uv_default_loop(), &prepare);
  uv_prepare_start(&prepare, prepare_cb);
  // uv_tty_t tty;
#ifndef WIN32
  uv_tty_init(uv_default_loop(), &tty, fileno(stderr), 1);
#else
  uv_tty_init(uv_default_loop(), &tty, fileno(stdin), 1);
  uv_tty_t out;
  uv_tty_init(uv_default_loop(), &out, fileno(stdout), 0);
  int width;
  int height;
  uv_tty_get_winsize(&out, &width, &height);
  screen_rect.width = width;
  screen_rect.height = height;
  uv_close((uv_handle_t *)&out, NULL);
#endif
  uv_tty_set_mode(&tty, UV_TTY_MODE_RAW);
  tty.data = &interrupted;
  uv_read_start(STRUCT_CAST(uv_stream_t, &tty), alloc_cb, read_cb);
#ifndef WIN32
  struct sigaction sa;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = 0;
  sa.sa_handler = sig_handler;
  sigaction(SIGHUP, &sa, NULL);
  sigaction(SIGWINCH, &sa, NULL);
#else
  // uv_signal_t sigwinch_watcher;
  // uv_signal_init(uv_default_loop(), &sigwinch_watcher);
  // uv_signal_start(&sigwinch_watcher, sigwinch_cb, SIGWINCH);
#endif
  uv_run(uv_default_loop(), UV_RUN_DEFAULT);

#ifndef WIN32
  // XXX: Without this the SIGHUP handler is skipped on some systems.
  sleep(100);
#endif

  return 0;
}
