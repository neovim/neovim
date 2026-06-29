// Some of the code came from pangoterm and libuv

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <uv.h>

// forkpty is not in POSIX, so headers are platform-specific
#if defined(__FreeBSD__) || defined(__DragonFly__)
# include <libutil.h>
// TODO(bfredl): this is available on darwin, but there is an issue with cross-compile headers
#elif defined(__APPLE__) && !defined(HAVE_FORKPTY)
int forkpty(int *, char *, const struct termios *, const struct winsize *);
#elif defined(__OpenBSD__) || defined(__NetBSD__) || defined(__APPLE__)
# include <util.h>
#elif defined(__sun)
# include <fcntl.h>
# include <signal.h>
# include <sys/stream.h>
# include <sys/syscall.h>
# include <unistd.h>
#else
# include <pty.h>
#endif

#ifdef __APPLE__
# include <crt_externs.h>
#endif
#ifdef __linux__
# include <poll.h>
#endif

#include "auto/config.h"
#include "klib/kvec.h"
#include "nvim/eval/typval.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/proc.h"
#include "nvim/log.h"
#include "nvim/os/fs.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/pty_proc.h"
#include "nvim/os/pty_proc_unix.h"
#include "nvim/types_defs.h"

#include "os/pty_proc_unix.c.generated.h"

#if !defined(HAVE_FORKPTY) && !defined(__APPLE__)

// this header defines STR, just as nvim.h, but it is defined as ('S'<<8),
// to avoid #undef STR, #undef STR, #define STR ('S'<<8) just delay the
// inclusion of the header even though it gets include out of order.

# if !defined(__HAIKU__)
#  include <sys/stropts.h>
# else
#  define I_PUSH 0  // XXX: find the actual value
# endif

static int vim_openpty(int *amaster, int *aslave, char *name, struct termios *termp,
                       struct winsize *winp)
{
  int slave = -1;
  int master = open("/dev/ptmx", O_RDWR);
  if (master == -1) {
    goto error;
  }

  // grantpt will invoke a setuid program to change permissions
  // and might fail if SIGCHLD handler is set, temporarily reset
  // while running
  void (*sig_saved)(int) = signal(SIGCHLD, SIG_DFL);
  int res = grantpt(master);
  signal(SIGCHLD, sig_saved);

  if (res == -1 || unlockpt(master) == -1) {
    goto error;
  }

  char *slave_name = ptsname(master);
  if (slave_name == NULL) {
    goto error;
  }

  slave = open(slave_name, O_RDWR|O_NOCTTY);
  if (slave == -1) {
    goto error;
  }

  // ptem emulates a terminal when used on a pseudo terminal driver,
  // must be pushed before ldterm
  ioctl(slave, I_PUSH, "ptem");
  // ldterm provides most of the termio terminal interface
  ioctl(slave, I_PUSH, "ldterm");
  // ttcompat compatibility with older terminal ioctls
  ioctl(slave, I_PUSH, "ttcompat");

  if (termp) {
    tcsetattr(slave, TCSAFLUSH, termp);
  }
  if (winp) {
    ioctl(slave, TIOCSWINSZ, winp);
  }

  *amaster = master;
  *aslave = slave;
  // ignoring name, not passed and size is unknown in the API

  return 0;

error:
  if (slave != -1) {
    close(slave);
  }
  if (master != -1) {
    close(master);
  }
  return -1;
}

static int vim_login_tty(int fd)
{
  setsid();
  if (ioctl(fd, TIOCSCTTY, NULL) == -1) {
    return -1;
  }

  dup2(fd, STDIN_FILENO);
  dup2(fd, STDOUT_FILENO);
  dup2(fd, STDERR_FILENO);
  if (fd > STDERR_FILENO) {
    close(fd);
  }

  return 0;
}

pid_t vim_forkpty(int *amaster, char *name, struct termios *termp, struct winsize *winp)
{
  int master, slave;
  if (vim_openpty(&master, &slave, name, termp, winp) == -1) {
    return -1;
  }

  pid_t pid = fork();
  switch (pid) {
  case -1:
    close(master);
    close(slave);
    return -1;
  case 0:
    close(master);
    vim_login_tty(slave);
    return 0;
  default:
    close(slave);
    *amaster = master;
    return pid;
  }
}
# define forkpty vim_forkpty
#endif

/// Creates a pipe for a forked child's stdio: the parent's end is close-on-exec, the child's end
/// (inherited across the fork) is not. `parent_reads` picks which end each side keeps (true = parent
/// reads, e.g. capturing the child's stdout; false = parent writes, e.g. feeding the child's stdin).
///
/// @param[out] parent_fd  Parent's end (cloexec), or -1 on failure.
/// @param[out] child_fd   Child's end (inherited), or -1 on failure.
/// @return 0, or a negative error code.
static int pty_make_pipe(bool parent_reads, int *parent_fd, int *child_fd)
  FUNC_ATTR_NONNULL_ALL
{
  int fds[2];
  if (pipe(fds) != 0) {
    ELOG("pipe() failed: %s", strerror(errno));
    return -errno;
  }
  *parent_fd = fds[parent_reads ? 0 : 1];
  *child_fd = fds[parent_reads ? 1 : 0];
  if (os_set_cloexec(*parent_fd) == -1) {
    int err = errno;
    close(fds[0]);
    close(fds[1]);
    *parent_fd = -1;
    *child_fd = -1;
    return -err;
  }
  return 0;
}

/// @returns zero on success, or negative error code
int pty_proc_spawn(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  // termios initialized at first use
  static struct termios termios_default;
  if (!termios_default.c_cflag) {
    init_termios(&termios_default);
  }

  int status = 0;  // zero or negative error code (libuv convention)
  Proc *proc = (Proc *)ptyproc;
  assert(proc->err.s.closed || ptyproc->stdout_pipe);  // err carries the stdout capture in fd mode
  uv_signal_start(&proc->loop->children_watcher, chld_handler, SIGCHLD);
  ptyproc->winsize = (struct winsize){ ptyproc->height, ptyproc->width, 0, 0 };
  uv_disable_stdio_inheritance();

  // pty + "fd" (kChannelStdinFd): give the child a separate stdin pipe instead of the tty. The read
  // end is dup2()'d onto fd 0 in the child (init_child); the write end becomes proc->in. #40407
  int stdin_wfd = -1;
  int capture_rfd = -1;
  int master = -1;
  int pid = -1;
  if (ptyproc->stdin_pipe) {
    status = pty_make_pipe(false, &stdin_wfd, &ptyproc->stdin_rfd);  // parent writes, child reads
    if (status != 0) {
      goto fail_prefork;
    }
  }

  // pty + stdout="fd": capture the child's stdout (fd 1) on a separate pipe. The write end is
  // dup2()'d onto fd 1 in the child; the read end becomes proc->err (the display stays proc->out =
  // master). #40407
  if (ptyproc->stdout_pipe) {
    status = pty_make_pipe(true, &capture_rfd, &ptyproc->stdout_wfd);  // parent reads, child writes
    if (status != 0) {
      goto fail_prefork;
    }
  }

  pid = forkpty(&master, NULL, &termios_default, &ptyproc->winsize);
  if (pid < 0) {
    status = -errno;
    ELOG("forkpty failed: %s", strerror(errno));
    goto fail_prefork;
  } else if (pid == 0) {
    init_child(ptyproc);  // never returns
  }

  // Parent: close the child-side ends (the forked child has its own copies).
  if (ptyproc->stdin_rfd != -1) {
    close(ptyproc->stdin_rfd);
    ptyproc->stdin_rfd = -1;
  }
  if (ptyproc->stdout_wfd != -1) {
    close(ptyproc->stdout_wfd);
    ptyproc->stdout_wfd = -1;
  }

  // make sure the master file descriptor is non blocking
  int master_status_flags = fcntl(master, F_GETFL);
  if (master_status_flags == -1) {
    status = -errno;
    ELOG("Failed to get master descriptor status flags: %s", strerror(errno));
    goto error;
  }
  if (fcntl(master, F_SETFL, master_status_flags | O_NONBLOCK) == -1) {
    status = -errno;
    ELOG("Failed to make master descriptor non-blocking: %s", strerror(errno));
    goto error;
  }

  // Other jobs and providers should not get a copy of this file descriptor.
  if (os_set_cloexec(master) == -1) {
    status = -errno;
    ELOG("Failed to set CLOEXEC on ptmx file descriptor");
    goto error;
  }

  // For "fd" mode proc->in is the stdin pipe (fed via chansend); otherwise it is the tty master.
  if (!proc->in.closed
      && (status = set_duplicating_descriptor(ptyproc->stdin_pipe ? stdin_wfd : master,
                                              &proc->in.uv.pipe))) {
    goto error;
  }
  if (stdin_wfd != -1) {
    close(stdin_wfd);  // dup'd into proc->in above; drop the original so chanclose() can EOF fd 0
    stdin_wfd = -1;
  }
  if (!proc->out.s.closed
      && (status = set_duplicating_descriptor(master, &proc->out.s.uv.pipe))) {
    goto error;
  }
  // stdout="fd": proc->err carries the child's clean stdout (fd 1); the display stays proc->out.
  if (ptyproc->stdout_pipe && !proc->err.s.closed
      && (status = set_duplicating_descriptor(capture_rfd, &proc->err.s.uv.pipe))) {
    goto error;
  }
  if (capture_rfd != -1) {
    close(capture_rfd);  // dup'd into proc->err above
    capture_rfd = -1;
    (void)capture_rfd;
  }

  ptyproc->tty_fd = master;
  proc->pid = pid;
  return 0;

fail_prefork:
  // Pre-fork failure (pipe setup or forkpty() itself): no child exists and master is still -1, so
  // just close both ends of whichever pipe(s) we created.
  if (stdin_wfd != -1) {
    close(stdin_wfd);
  }
  if (ptyproc->stdin_rfd != -1) {
    close(ptyproc->stdin_rfd);
    ptyproc->stdin_rfd = -1;
  }
  if (capture_rfd != -1) {
    close(capture_rfd);
  }
  if (ptyproc->stdout_wfd != -1) {
    close(ptyproc->stdout_wfd);
    ptyproc->stdout_wfd = -1;
  }
  return status;

error:
  close(master);
  if (stdin_wfd != -1) {
    close(stdin_wfd);
  }
  if (capture_rfd != -1) {
    close(capture_rfd);
  }
  kill(pid, SIGKILL);
  waitpid(pid, NULL, 0);
  return status;
}

const char *pty_proc_tty_name(PtyProc *ptyproc)
{
  return ptsname(ptyproc->tty_fd);
}

void pty_proc_resize(PtyProc *ptyproc, uint16_t width, uint16_t height)
  FUNC_ATTR_NONNULL_ALL
{
  ptyproc->winsize = (struct winsize){ height, width, 0, 0 };
  ioctl(ptyproc->tty_fd, TIOCSWINSZ, &ptyproc->winsize);
}

void pty_proc_resume(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  // Send SIGCONT to the entire process group, as some shells (e.g. fish) don't
  // propagate SIGCONT to suspended child processes.
  killpg(((Proc *)ptyproc)->pid, SIGCONT);
}

/// On Linux, libuv's polling (which uses epoll) doesn't flush PTY master's pending
/// work on kernel workqueue, so use an explicit poll() before that. #37982
/// Note that poll() only flushes pending work if no data is immediately available,
/// so this function is needed before every libuv poll in flush_stream().
void pty_proc_flush_master(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
#ifdef __linux__
  struct pollfd pollfd = { .fd = ptyproc->tty_fd, .events = POLLIN };
  int n = 0;
  do {
    n = poll(&pollfd, 1, 0);
  } while (n < 0 && errno == EINTR);
#endif
}

void pty_proc_close(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  pty_proc_close_master(ptyproc);
  Proc *proc = (Proc *)ptyproc;
  if (proc->internal_close_cb) {
    proc->internal_close_cb(proc);
  }
}

void pty_proc_close_master(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  if (ptyproc->tty_fd >= 0) {
    close(ptyproc->tty_fd);
    ptyproc->tty_fd = -1;
  }
}

void pty_proc_teardown(Loop *loop)
{
  uv_signal_stop(&loop->children_watcher);
}

static void init_child(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NORETURN
{
#ifdef HAVE__NSGETENVIRON
# define environ (*_NSGetEnviron())
#else
  extern char **environ;
#endif
  // New session/process-group. #6530
  setsid();

  signal(SIGCHLD, SIG_DFL);
  signal(SIGHUP, SIG_DFL);
  signal(SIGINT, SIG_DFL);
  signal(SIGQUIT, SIG_DFL);
  signal(SIGTERM, SIG_DFL);
  signal(SIGALRM, SIG_DFL);

  Proc *proc = (Proc *)ptyproc;
  int err = 0;
  // Don't use os_chdir() as that may buffer UI events unnecessarily.
  if (proc->cwd && (err = uv_chdir(proc->cwd)) != 0) {
    ELOG("chdir(%s) failed: %s", proc->cwd, uv_strerror(err));
    _exit(122);
  }

  // "fd" mode: replace the tty on fd 0 (set by forkpty/login_tty) with the stdin pipe. fd 1/2 and
  // the controlling terminal stay the pty, so the child still has a tty for prompts. #40407
  if (ptyproc->stdin_rfd != -1) {
    dup2(ptyproc->stdin_rfd, STDIN_FILENO);
    close(ptyproc->stdin_rfd);
  }
  // stdout="fd": child's stdout (fd 1) goes to the capture pipe; fd 2 + /dev/tty stay the pty.
  if (ptyproc->stdout_wfd != -1) {
    dup2(ptyproc->stdout_wfd, STDOUT_FILENO);
    close(ptyproc->stdout_wfd);
  }

  const char *prog = proc_get_exepath(proc);

  assert(proc->env);
  environ = tv_dict_to_env(proc->env);
  execvp(prog, proc->argv);
  ELOG("execvp(%s) failed: %s", prog, strerror(errno));

  _exit(122);  // 122 is EXEC_FAILED in the Vim source.
}

static void init_termios(struct termios *termios) FUNC_ATTR_NONNULL_ALL
{
  // Taken from pangoterm
  termios->c_iflag = ICRNL|IXON;
  termios->c_oflag = OPOST|ONLCR;
#ifdef TAB0
  termios->c_oflag |= TAB0;
#endif
  termios->c_cflag = CS8|CREAD;
  termios->c_lflag = ISIG|ICANON|IEXTEN|ECHO|ECHOE|ECHOK;

  // not using cfsetspeed, not available on all platforms
  cfsetispeed(termios, 38400);
  cfsetospeed(termios, 38400);

#ifdef IUTF8
  termios->c_iflag |= IUTF8;
#endif
#ifdef NL0
  termios->c_oflag |= NL0;
#endif
#ifdef CR0
  termios->c_oflag |= CR0;
#endif
#ifdef BS0
  termios->c_oflag |= BS0;
#endif
#ifdef VT0
  termios->c_oflag |= VT0;
#endif
#ifdef FF0
  termios->c_oflag |= FF0;
#endif
#ifdef ECHOCTL
  termios->c_lflag |= ECHOCTL;
#endif
#ifdef ECHOKE
  termios->c_lflag |= ECHOKE;
#endif

  termios->c_cc[VINTR] = 0x1f & 'C';
  termios->c_cc[VQUIT] = 0x1f & '\\';
  termios->c_cc[VERASE] = 0x7f;
  termios->c_cc[VKILL] = 0x1f & 'U';
  termios->c_cc[VEOF] = 0x1f & 'D';
  termios->c_cc[VEOL] = _POSIX_VDISABLE;
  termios->c_cc[VEOL2] = _POSIX_VDISABLE;
  termios->c_cc[VSTART] = 0x1f & 'Q';
  termios->c_cc[VSTOP] = 0x1f & 'S';
  termios->c_cc[VSUSP] = 0x1f & 'Z';
#if !defined(__HAIKU__)
  termios->c_cc[VREPRINT] = 0x1f & 'R';
  termios->c_cc[VWERASE] = 0x1f & 'W';
  termios->c_cc[VLNEXT] = 0x1f & 'V';
#endif
  termios->c_cc[VMIN] = 1;
  termios->c_cc[VTIME] = 0;
}

static int set_duplicating_descriptor(int fd, uv_pipe_t *pipe)
  FUNC_ATTR_NONNULL_ALL
{
  int status = 0;  // zero or negative error code (libuv convention)
  int fd_dup = dup(fd);
  if (fd_dup < 0) {
    status = -errno;
    ELOG("Failed to dup descriptor %d: %s", fd, strerror(errno));
    return status;
  }

  if (os_set_cloexec(fd_dup) == -1) {
    status = -errno;
    ELOG("Failed to set CLOEXEC on duplicate fd");
    goto error;
  }

  status = uv_pipe_open(pipe, fd_dup);
  if (status) {
    ELOG("Failed to set pipe to descriptor %d: %s",
         fd_dup, uv_strerror(status));
    goto error;
  }
  return status;

error:
  close(fd_dup);
  return status;
}

static void chld_handler(uv_signal_t *handle, int signum)
{
  int stat = 0;
  int pid;

  Loop *loop = handle->loop->data;

  for (size_t i = 0; i < kv_size(loop->children); i++) {
    Proc *proc = kv_A(loop->children, i);
    do {
      pid = waitpid(proc->pid, &stat, WNOHANG|WUNTRACED|WCONTINUED);
    } while (pid < 0 && errno == EINTR);

    if (pid <= 0) {
      continue;
    }

    if (WIFSTOPPED(stat)) {
      proc->state_cb(proc, true, proc->data);
      continue;
    }
    if (WIFCONTINUED(stat)) {
      proc->state_cb(proc, false, proc->data);
      continue;
    }

    if (WIFEXITED(stat)) {
      proc->status = WEXITSTATUS(stat);
    } else if (WIFSIGNALED(stat)) {
      proc->status = 128 + WTERMSIG(stat);
    }
    proc->internal_exit_cb(proc);
  }
}

PtyProc pty_proc_init(Loop *loop, void *data)
{
  PtyProc rv = { 0 };
  rv.proc = proc_init(loop, kProcTypePty, data);
  rv.width = 80;
  rv.height = 24;
  rv.tty_fd = -1;
  rv.stdin_pipe = false;
  rv.stdin_rfd = -1;
  rv.stdout_pipe = false;
  rv.stdout_wfd = -1;
  return rv;
}
