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

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <errno.h>

#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>

#if defined(__APPLE__) && !TARGET_OS_IPHONE
# include <crt_externs.h>
# define environ (*_NSGetEnviron())
#else
extern char **environ;
#endif


static QUEUE* uv__process_queue(uv_loop_t* loop, int pid) {
  assert(pid > 0);
  return loop->process_handles + pid % ARRAY_SIZE(loop->process_handles);
}


static void uv__chld(uv_signal_t* handle, int signum) {
  uv_process_t* process;
  uv_loop_t* loop;
  int exit_status;
  int term_signal;
  unsigned int i;
  int status;
  pid_t pid;
  QUEUE pending;
  QUEUE* h;
  QUEUE* q;

  assert(signum == SIGCHLD);

  QUEUE_INIT(&pending);
  loop = handle->loop;

  for (i = 0; i < ARRAY_SIZE(loop->process_handles); i++) {
    h = loop->process_handles + i;
    q = QUEUE_HEAD(h);

    while (q != h) {
      process = QUEUE_DATA(q, uv_process_t, queue);
      q = QUEUE_NEXT(q);

      do
        pid = waitpid(process->pid, &status, WNOHANG);
      while (pid == -1 && errno == EINTR);

      if (pid == 0)
        continue;

      if (pid == -1) {
        if (errno != ECHILD)
          abort();
        continue;
      }

      process->status = status;
      QUEUE_REMOVE(&process->queue);
      QUEUE_INSERT_TAIL(&pending, &process->queue);
    }

    while (!QUEUE_EMPTY(&pending)) {
      q = QUEUE_HEAD(&pending);
      QUEUE_REMOVE(q);
      QUEUE_INIT(q);

      process = QUEUE_DATA(q, uv_process_t, queue);
      uv__handle_stop(process);

      if (process->exit_cb == NULL)
        continue;

      exit_status = 0;
      if (WIFEXITED(process->status))
        exit_status = WEXITSTATUS(process->status);

      term_signal = 0;
      if (WIFSIGNALED(process->status))
        term_signal = WTERMSIG(process->status);

      process->exit_cb(process, exit_status, term_signal);
    }
  }
}


int uv__make_socketpair(int fds[2], int flags) {
#if defined(__linux__)
  static int no_cloexec;

  if (no_cloexec)
    goto skip;

  if (socketpair(AF_UNIX, SOCK_STREAM | UV__SOCK_CLOEXEC | flags, 0, fds) == 0)
    return 0;

  /* Retry on EINVAL, it means SOCK_CLOEXEC is not supported.
   * Anything else is a genuine error.
   */
  if (errno != EINVAL)
    return -errno;

  no_cloexec = 1;

skip:
#endif

  if (socketpair(AF_UNIX, SOCK_STREAM, 0, fds))
    return -errno;

  uv__cloexec(fds[0], 1);
  uv__cloexec(fds[1], 1);

  if (flags & UV__F_NONBLOCK) {
    uv__nonblock(fds[0], 1);
    uv__nonblock(fds[1], 1);
  }

  return 0;
}


int uv__make_pipe(int fds[2], int flags) {
#if defined(__linux__)
  static int no_pipe2;

  if (no_pipe2)
    goto skip;

  if (uv__pipe2(fds, flags | UV__O_CLOEXEC) == 0)
    return 0;

  if (errno != ENOSYS)
    return -errno;

  no_pipe2 = 1;

skip:
#endif

  if (pipe(fds))
    return -errno;

  uv__cloexec(fds[0], 1);
  uv__cloexec(fds[1], 1);

  if (flags & UV__F_NONBLOCK) {
    uv__nonblock(fds[0], 1);
    uv__nonblock(fds[1], 1);
  }

  return 0;
}


/*
 * Used for initializing stdio streams like options.stdin_stream. Returns
 * zero on success. See also the cleanup section in uv_spawn().
 */
static int uv__process_init_stdio(uv_stdio_container_t* container, int fds[2]) {
  int mask;
  int fd;

  mask = UV_IGNORE | UV_CREATE_PIPE | UV_INHERIT_FD | UV_INHERIT_STREAM;

  switch (container->flags & mask) {
  case UV_IGNORE:
    return 0;

  case UV_CREATE_PIPE:
    assert(container->data.stream != NULL);
    if (container->data.stream->type != UV_NAMED_PIPE)
      return -EINVAL;
    else
      return uv__make_socketpair(fds, 0);

  case UV_INHERIT_FD:
  case UV_INHERIT_STREAM:
    if (container->flags & UV_INHERIT_FD)
      fd = container->data.fd;
    else
      fd = uv__stream_fd(container->data.stream);

    if (fd == -1)
      return -EINVAL;

    fds[1] = fd;
    return 0;

  default:
    assert(0 && "Unexpected flags");
    return -EINVAL;
  }
}


static int uv__process_open_stream(uv_stdio_container_t* container,
                                   int pipefds[2],
                                   int writable) {
  int flags;

  if (!(container->flags & UV_CREATE_PIPE) || pipefds[0] < 0)
    return 0;

  if (uv__close(pipefds[1]))
    if (errno != EINTR && errno != EINPROGRESS)
      abort();

  pipefds[1] = -1;
  uv__nonblock(pipefds[0], 1);

  if (container->data.stream->type == UV_NAMED_PIPE &&
      ((uv_pipe_t*)container->data.stream)->ipc)
    flags = UV_STREAM_READABLE | UV_STREAM_WRITABLE;
  else if (writable)
    flags = UV_STREAM_WRITABLE;
  else
    flags = UV_STREAM_READABLE;

  return uv__stream_open(container->data.stream, pipefds[0], flags);
}


static void uv__process_close_stream(uv_stdio_container_t* container) {
  if (!(container->flags & UV_CREATE_PIPE)) return;
  uv__stream_close((uv_stream_t*)container->data.stream);
}


static void uv__write_int(int fd, int val) {
  ssize_t n;

  do
    n = write(fd, &val, sizeof(val));
  while (n == -1 && errno == EINTR);

  if (n == -1 && errno == EPIPE)
    return; /* parent process has quit */

  assert(n == sizeof(val));
}


static void uv__process_child_init(const uv_process_options_t* options,
                                   int stdio_count,
                                   int (*pipes)[2],
                                   int error_fd) {
  int close_fd;
  int use_fd;
  int fd;

  if (options->flags & UV_PROCESS_DETACHED)
    setsid();

  for (fd = 0; fd < stdio_count; fd++) {
    close_fd = pipes[fd][0];
    use_fd = pipes[fd][1];

    if (use_fd < 0) {
      if (fd >= 3)
        continue;
      else {
        /* redirect stdin, stdout and stderr to /dev/null even if UV_IGNORE is
         * set
         */
        use_fd = open("/dev/null", fd == 0 ? O_RDONLY : O_RDWR);
        close_fd = use_fd;

        if (use_fd == -1) {
        uv__write_int(error_fd, -errno);
          perror("failed to open stdio");
          _exit(127);
        }
      }
    }

    if (fd == use_fd)
      uv__cloexec(use_fd, 0);
    else
      dup2(use_fd, fd);

    if (fd <= 2)
      uv__nonblock(fd, 0);

    if (close_fd != -1)
      uv__close(close_fd);
  }

  for (fd = 0; fd < stdio_count; fd++) {
    use_fd = pipes[fd][1];

    if (use_fd >= 0 && fd != use_fd)
      close(use_fd);
  }

  if (options->cwd != NULL && chdir(options->cwd)) {
    uv__write_int(error_fd, -errno);
    perror("chdir()");
    _exit(127);
  }

  if ((options->flags & UV_PROCESS_SETGID) && setgid(options->gid)) {
    uv__write_int(error_fd, -errno);
    perror("setgid()");
    _exit(127);
  }

  if ((options->flags & UV_PROCESS_SETUID) && setuid(options->uid)) {
    uv__write_int(error_fd, -errno);
    perror("setuid()");
    _exit(127);
  }

  if (options->env != NULL) {
    environ = options->env;
  }

  execvp(options->file, options->args);
  uv__write_int(error_fd, -errno);
  perror("execvp()");
  _exit(127);
}


int uv_spawn(uv_loop_t* loop,
             uv_process_t* process,
             const uv_process_options_t* options) {
  int signal_pipe[2] = { -1, -1 };
  int (*pipes)[2];
  int stdio_count;
  QUEUE* q;
  ssize_t r;
  pid_t pid;
  int err;
  int exec_errorno;
  int i;

  assert(options->file != NULL);
  assert(!(options->flags & ~(UV_PROCESS_DETACHED |
                              UV_PROCESS_SETGID |
                              UV_PROCESS_SETUID |
                              UV_PROCESS_WINDOWS_HIDE |
                              UV_PROCESS_WINDOWS_VERBATIM_ARGUMENTS)));

  uv__handle_init(loop, (uv_handle_t*)process, UV_PROCESS);
  QUEUE_INIT(&process->queue);

  stdio_count = options->stdio_count;
  if (stdio_count < 3)
    stdio_count = 3;

  err = -ENOMEM;
  pipes = malloc(stdio_count * sizeof(*pipes));
  if (pipes == NULL)
    goto error;

  for (i = 0; i < stdio_count; i++) {
    pipes[i][0] = -1;
    pipes[i][1] = -1;
  }

  for (i = 0; i < options->stdio_count; i++) {
    err = uv__process_init_stdio(options->stdio + i, pipes[i]);
    if (err)
      goto error;
  }

  /* This pipe is used by the parent to wait until
   * the child has called `execve()`. We need this
   * to avoid the following race condition:
   *
   *    if ((pid = fork()) > 0) {
   *      kill(pid, SIGTERM);
   *    }
   *    else if (pid == 0) {
   *      execve("/bin/cat", argp, envp);
   *    }
   *
   * The parent sends a signal immediately after forking.
   * Since the child may not have called `execve()` yet,
   * there is no telling what process receives the signal,
   * our fork or /bin/cat.
   *
   * To avoid ambiguity, we create a pipe with both ends
   * marked close-on-exec. Then, after the call to `fork()`,
   * the parent polls the read end until it EOFs or errors with EPIPE.
   */
  err = uv__make_pipe(signal_pipe, 0);
  if (err)
    goto error;

  uv_signal_start(&loop->child_watcher, uv__chld, SIGCHLD);

  pid = fork();

  if (pid == -1) {
    err = -errno;
    uv__close(signal_pipe[0]);
    uv__close(signal_pipe[1]);
    goto error;
  }

  if (pid == 0) {
    uv__process_child_init(options, stdio_count, pipes, signal_pipe[1]);
    abort();
  }

  uv__close(signal_pipe[1]);

  process->status = 0;
  exec_errorno = 0;
  do
    r = read(signal_pipe[0], &exec_errorno, sizeof(exec_errorno));
  while (r == -1 && errno == EINTR);

  if (r == 0)
    ; /* okay, EOF */
  else if (r == sizeof(exec_errorno))
    ; /* okay, read errorno */
  else if (r == -1 && errno == EPIPE)
    ; /* okay, got EPIPE */
  else
    abort();

  uv__close(signal_pipe[0]);

  for (i = 0; i < options->stdio_count; i++) {
    err = uv__process_open_stream(options->stdio + i, pipes[i], i == 0);
    if (err == 0)
      continue;

    while (i--)
      uv__process_close_stream(options->stdio + i);

    goto error;
  }

  /* Only activate this handle if exec() happened successfully */
  if (exec_errorno == 0) {
    q = uv__process_queue(loop, pid);
    QUEUE_INSERT_TAIL(q, &process->queue);
    uv__handle_start(process);
  }

  process->pid = pid;
  process->exit_cb = options->exit_cb;

  free(pipes);
  return exec_errorno;

error:
  if (pipes != NULL) {
    for (i = 0; i < stdio_count; i++) {
      if (i < options->stdio_count)
        if (options->stdio[i].flags & (UV_INHERIT_FD | UV_INHERIT_STREAM))
          continue;
      if (pipes[i][0] != -1)
        close(pipes[i][0]);
      if (pipes[i][1] != -1)
        close(pipes[i][1]);
    }
    free(pipes);
  }

  return err;
}


int uv_process_kill(uv_process_t* process, int signum) {
  return uv_kill(process->pid, signum);
}


int uv_kill(int pid, int signum) {
  if (kill(pid, signum))
    return -errno;
  else
    return 0;
}


void uv__process_close(uv_process_t* handle) {
  /* TODO stop signal watcher when this is the last handle */
  QUEUE_REMOVE(&handle->queue);
  uv__handle_stop(handle);
}
