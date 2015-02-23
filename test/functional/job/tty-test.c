#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <uv.h>

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
bool owns_tty(void)
{
  // TODO: Check if the process is the session leader
  return true;
}
#endif

#define is_terminal(stream) (uv_guess_handle(fileno(stream)) == UV_TTY)
#define BUF_SIZE 0xfff

static void walk_cb(uv_handle_t *handle, void *arg) {
  if (!uv_is_closing(handle)) {
    uv_close(handle, NULL);
  }
}

static void sigwinch_cb(uv_signal_t *handle, int signum)
{
  int width, height;
  uv_tty_t *tty = handle->data;
  uv_tty_get_winsize(tty, &width, &height);
  fprintf(stderr, "screen resized. rows: %d, columns: %d\n", height, width);
}

static void sigint_cb(uv_signal_t *handle, int signum)
{
  bool *interrupted = handle->data;

  if (*interrupted) {
    uv_walk(uv_default_loop(), walk_cb, NULL);
    return;
  }

  *interrupted = true;
  fprintf(stderr, "interrupt received, press again to exit\n");
}

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

  fprintf(stderr, "received data: ");
  uv_loop_t write_loop;
  uv_loop_init(&write_loop);
  uv_tty_t out;
  uv_tty_init(&write_loop, &out, 1, 0);
  uv_write_t req;
  uv_buf_t b = {.base = buf->base, .len = buf->len};
  uv_write(&req, (uv_stream_t *)&out, &b, 1, NULL);
  uv_run(&write_loop, UV_RUN_DEFAULT);
  uv_close((uv_handle_t *)&out, NULL);
  uv_run(&write_loop, UV_RUN_DEFAULT);
  if (uv_loop_close(&write_loop)) {
    abort();
  }
  free(buf->base);
}

int main(int argc, char **argv)
{
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

  bool interrupted = false;
  fprintf(stderr, "tty ready\n");
  uv_tty_t tty;
  uv_tty_init(uv_default_loop(), &tty, fileno(stderr), 1);
  uv_read_start((uv_stream_t *)&tty, alloc_cb, read_cb);
  uv_signal_t sigwinch_watcher, sigint_watcher;
  uv_signal_init(uv_default_loop(), &sigwinch_watcher);
  sigwinch_watcher.data = &tty;
  uv_signal_start(&sigwinch_watcher, sigwinch_cb, SIGWINCH);
  uv_signal_init(uv_default_loop(), &sigint_watcher);
  sigint_watcher.data = &interrupted;
  uv_signal_start(&sigint_watcher, sigint_cb, SIGINT);
  uv_run(uv_default_loop(), UV_RUN_DEFAULT);
  fprintf(stderr, "tty done\n");
}
