// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Some of the code came from pangoterm and libuv
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include <termios.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/ioctl.h>

// forkpty is not in POSIX, so headers are platform-specific
#if defined(__FreeBSD__) || defined(__DragonFly__)
# include <libutil.h>
#elif defined(__OpenBSD__) || defined(__NetBSD__) || defined(__APPLE__)
# include <util.h>
#else
# include <pty.h>
#endif

#include <uv.h>

#include "nvim/lib/klist.h"

#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/event/process.h"
#include "nvim/os/pty_process_unix.h"
#include "nvim/log.h"
#include "nvim/os/os.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process_unix.c.generated.h"
#endif

/// termios saved at startup (for TUI) or initialized by pty_process_spawn().
static struct termios termios_default;

/// Saves the termios properties associated with `tty_fd`.
///
/// @param tty_fd   TTY file descriptor, or -1 if not in a terminal.
void pty_process_save_termios(int tty_fd)
{
  DLOG("tty_fd=%d", tty_fd);
  if (tty_fd == -1 || tcgetattr(tty_fd, &termios_default) != 0) {
    return;
  }
}

/// @returns zero on success, or negative error code
int pty_process_spawn(PtyProcess *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  if (!termios_default.c_cflag) {
    // TODO(jkeyes): We could pass NULL to forkpty() instead ...
    init_termios(&termios_default);
  }

  int status = 0;  // zero or negative error code (libuv convention)
  Process *proc = (Process *)ptyproc;
  assert(proc->err.closed);
  uv_signal_start(&proc->loop->children_watcher, chld_handler, SIGCHLD);
  ptyproc->winsize = (struct winsize){ ptyproc->height, ptyproc->width, 0, 0 };
  uv_disable_stdio_inheritance();
  int master;
  int pid = forkpty(&master, NULL, &termios_default, &ptyproc->winsize);

  if (pid < 0) {
    status = -errno;
    ELOG("forkpty failed: %s", strerror(errno));
    return status;
  } else if (pid == 0) {
    init_child(ptyproc);  // never returns
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

  if (!proc->in.closed
      && (status = set_duplicating_descriptor(master, &proc->in.uv.pipe))) {
    goto error;
  }
  if (!proc->out.closed
      && (status = set_duplicating_descriptor(master, &proc->out.uv.pipe))) {
    goto error;
  }

  ptyproc->tty_fd = master;
  proc->pid = pid;
  return 0;

error:
  close(master);
  kill(pid, SIGKILL);
  waitpid(pid, NULL, 0);
  return status;
}

const char *pty_process_tty_name(PtyProcess *ptyproc)
{
  return ptsname(ptyproc->tty_fd);
}

void pty_process_resize(PtyProcess *ptyproc, uint16_t width, uint16_t height)
  FUNC_ATTR_NONNULL_ALL
{
  ptyproc->winsize = (struct winsize){ height, width, 0, 0 };
  ioctl(ptyproc->tty_fd, TIOCSWINSZ, &ptyproc->winsize);
}

void pty_process_close(PtyProcess *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  pty_process_close_master(ptyproc);
  Process *proc = (Process *)ptyproc;
  if (proc->internal_close_cb) {
    proc->internal_close_cb(proc);
  }
}

void pty_process_close_master(PtyProcess *ptyproc) FUNC_ATTR_NONNULL_ALL
{
  if (ptyproc->tty_fd >= 0) {
    close(ptyproc->tty_fd);
    ptyproc->tty_fd = -1;
  }
}

void pty_process_teardown(Loop *loop)
{
  uv_signal_stop(&loop->children_watcher);
}

static void init_child(PtyProcess *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  // New session/process-group. #6530
  setsid();

  os_unsetenv("COLUMNS");
  os_unsetenv("LINES");
  os_unsetenv("TERMCAP");
  os_unsetenv("COLORTERM");
  os_unsetenv("COLORFGBG");

  signal(SIGCHLD, SIG_DFL);
  signal(SIGHUP, SIG_DFL);
  signal(SIGINT, SIG_DFL);
  signal(SIGQUIT, SIG_DFL);
  signal(SIGTERM, SIG_DFL);
  signal(SIGALRM, SIG_DFL);

  Process *proc = (Process *)ptyproc;
  if (proc->cwd && os_chdir(proc->cwd) != 0) {
    ELOG("chdir failed: %s", strerror(errno));
    return;
  }

  char *prog = ptyproc->process.argv[0];
  os_setenv("TERM", ptyproc->term_name ? ptyproc->term_name : "ansi", 1);
  execvp(prog, ptyproc->process.argv);
  ELOG("execvp failed: %s: %s", strerror(errno), prog);
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

  cfsetspeed(termios, 38400);

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

  termios->c_cc[VINTR]    = 0x1f & 'C';
  termios->c_cc[VQUIT]    = 0x1f & '\\';
  termios->c_cc[VERASE]   = 0x7f;
  termios->c_cc[VKILL]    = 0x1f & 'U';
  termios->c_cc[VEOF]     = 0x1f & 'D';
  termios->c_cc[VEOL]     = _POSIX_VDISABLE;
  termios->c_cc[VEOL2]    = _POSIX_VDISABLE;
  termios->c_cc[VSTART]   = 0x1f & 'Q';
  termios->c_cc[VSTOP]    = 0x1f & 'S';
  termios->c_cc[VSUSP]    = 0x1f & 'Z';
  termios->c_cc[VREPRINT] = 0x1f & 'R';
  termios->c_cc[VWERASE]  = 0x1f & 'W';
  termios->c_cc[VLNEXT]   = 0x1f & 'V';
  termios->c_cc[VMIN]     = 1;
  termios->c_cc[VTIME]    = 0;
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

  kl_iter(WatcherPtr, loop->children, current) {
    Process *proc = (*current)->data;
    do {
      pid = waitpid(proc->pid, &stat, WNOHANG);
    } while (pid < 0 && errno == EINTR);

    if (pid <= 0) {
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
