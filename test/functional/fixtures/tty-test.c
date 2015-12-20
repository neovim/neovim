#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <uv.h>

uv_tty_t tty;

#ifdef _WIN32
#include <windows.h>
bool owns_tty(void)
{
  HWND consoleWnd = GetConsoleWindow();
  DWORD dwProcessId;
  GetWindowThreadProcessId(consoleWnd, &dwProcessId);
  return GetCurrentProcessId() == dwProcessId;
}
#else
#include <unistd.h>
bool owns_tty(void)
{
  return getsid(0) == getpid();
}
#endif

#define is_terminal(stream) (uv_guess_handle(fileno(stream)) == UV_TTY)
#define BUF_SIZE 0xfff

static void walk_cb(uv_handle_t *handle, void *arg) {
  if (!uv_is_closing(handle)) {
    uv_close(handle, NULL);
  }
}

#ifndef WIN32
static void sigwinch_handler(int signum)
{
  int width, height;
  uv_tty_get_winsize(&tty, &width, &height);
  fprintf(stderr, "rows: %d, cols: %d\n", height, width);
}
#endif

// static void sigwinch_cb(uv_signal_t *handle, int signum)
// {
//   int width, height;
//   uv_tty_t *tty = handle->data;
//   uv_tty_get_winsize(tty, &width, &height);
//   fprintf(stderr, "rows: %d, cols: %d\n", height, width);
// }

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

  for (int i = 0; i < cnt; i++) {
    if (buf->base[i] == 3) {
      (*interrupted)++;
    }
  }

  uv_loop_t write_loop;
  uv_loop_init(&write_loop);
  uv_tty_t out;
  uv_tty_init(&write_loop, &out, 1, 0);
  uv_write_t req;
  uv_buf_t b = {.base = buf->base, .len = (size_t)cnt};
  uv_write(&req, (uv_stream_t *)&out, &b, 1, NULL);
  uv_run(&write_loop, UV_RUN_DEFAULT);
  uv_close((uv_handle_t *)&out, NULL);
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
    for (int i = 0; i < count; ++i) {
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
  uv_tty_init(uv_default_loop(), &tty, fileno(stderr), 1);
  uv_tty_set_mode(&tty, UV_TTY_MODE_RAW);
  tty.data = &interrupted;
  uv_read_start((uv_stream_t *)&tty, alloc_cb, read_cb);
#ifndef WIN32
  struct sigaction sa;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = 0;
  sa.sa_handler = sigwinch_handler;
  sigaction(SIGWINCH, &sa, NULL);
  // uv_signal_t sigwinch_watcher;
  // uv_signal_init(uv_default_loop(), &sigwinch_watcher);
  // sigwinch_watcher.data = &tty;
  // uv_signal_start(&sigwinch_watcher, sigwinch_cb, SIGWINCH);
#endif
  uv_run(uv_default_loop(), UV_RUN_DEFAULT);

  return 0;
}
