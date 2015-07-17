// Some of the code came from pangoterm and libuv
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include <unistd.h>
#include <termios.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/ioctl.h>

// forkpty is not in POSIX, so headers are platform-specific
#if defined(__FreeBSD__)
# include <libutil.h>
#elif defined(__OpenBSD__) || defined(__NetBSD__) || defined(__APPLE__)
# include <util.h>
#else
# include <pty.h>
#endif

#include <uv.h>

#include "nvim/func_attr.h"
#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/os/job_private.h"
#include "nvim/os/pty_process.h"
#include "nvim/memory.h"
#include "nvim/vim.h"
#include "nvim/globals.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process.c.generated.h"
#endif

static const unsigned int KILL_RETRIES = 5;
static const unsigned int KILL_TIMEOUT = 2;  // seconds

bool pty_process_spawn(Job *job) FUNC_ATTR_NONNULL_ALL
{
  PtyProcess *ptyproc = &job->process.pty;
  ptyproc->tty_fd = -1;

  if (job->opts.writable) {
    uv_pipe_init(&loop.uv, &ptyproc->proc_stdin, 0);
    ptyproc->proc_stdin.data = NULL;
  }

  if (job->opts.stdout_cb) {
    uv_pipe_init(&loop.uv, &ptyproc->proc_stdout, 0);
    ptyproc->proc_stdout.data = NULL;
  }

  if (job->opts.stderr_cb) {
    uv_pipe_init(&loop.uv, &ptyproc->proc_stderr, 0);
    ptyproc->proc_stderr.data = NULL;
  }

  job->proc_stdin = (uv_stream_t *)&ptyproc->proc_stdin;
  job->proc_stdout = (uv_stream_t *)&ptyproc->proc_stdout;
  job->proc_stderr = (uv_stream_t *)&ptyproc->proc_stderr;

  int master;
  ptyproc->winsize = (struct winsize){job->opts.height, job->opts.width, 0, 0};
  struct termios termios;
  init_termios(&termios);
  uv_disable_stdio_inheritance();

  int pid = forkpty(&master, NULL, &termios, &ptyproc->winsize);

  if (pid < 0) {
    return false;
  } else if (pid == 0) {
    init_child(job);
    abort();
  }

  // make sure the master file descriptor is non blocking
  int master_status_flags = fcntl(master, F_GETFL);
  if (master_status_flags == -1) {
    ELOG("Failed to get master descriptor status flags: %s", strerror(errno));
    goto error;
  }
  if (fcntl(master, F_SETFL, master_status_flags | O_NONBLOCK) == -1) {
    ELOG("Failed to make master descriptor non-blocking: %s", strerror(errno));
    goto error;
  }

  if (job->opts.writable
      && !set_pipe_duplicating_descriptor(master, &ptyproc->proc_stdin)) {
    goto error;
  }

  if (job->opts.stdout_cb
      && !set_pipe_duplicating_descriptor(master, &ptyproc->proc_stdout)) {
    goto error;
  }

  if (job->opts.stderr_cb
      && !set_pipe_duplicating_descriptor(master, &ptyproc->proc_stderr)) {
    goto error;
  }

  ptyproc->tty_fd = master;
  job->pid = pid;
  return true;

error:
  close(master);

  // terminate spawned process
  kill(pid, SIGTERM);
  int status, child;
  unsigned int try = 0;
  while (try++ < KILL_RETRIES && !(child = waitpid(pid, &status, WNOHANG))) {
    sleep(KILL_TIMEOUT);
  }
  if (child != pid) {
    kill(pid, SIGKILL);
  }

  return false;
}

static bool set_pipe_duplicating_descriptor(int fd, uv_pipe_t *pipe)
  FUNC_ATTR_NONNULL_ALL
{
  int fd_dup = dup(fd);
  if (fd_dup < 0) {
    ELOG("Failed to dup descriptor %d: %s", fd, strerror(errno));
    return false;
  }
  int uv_result = uv_pipe_open(pipe, fd_dup);
  if (uv_result) {
    ELOG("Failed to set pipe to descriptor %d: %s",
         fd_dup, uv_strerror(uv_result));
    close(fd_dup);
    return false;
  }
  return true;
}

void pty_process_close(Job *job) FUNC_ATTR_NONNULL_ALL
{
  pty_process_close_master(job);
  job_close_streams(job);
  job_decref(job);
}

void pty_process_close_master(Job *job) FUNC_ATTR_NONNULL_ALL
{
  PtyProcess *ptyproc = &job->process.pty;
  if (ptyproc->tty_fd >= 0) {
    close(ptyproc->tty_fd);
    ptyproc->tty_fd = -1;
  }
}

void pty_process_resize(Job *job, uint16_t width, uint16_t height)
  FUNC_ATTR_NONNULL_ALL
{
  PtyProcess *ptyproc = &job->process.pty;
  ptyproc->winsize = (struct winsize){height, width, 0, 0};
  ioctl(ptyproc->tty_fd, TIOCSWINSZ, &ptyproc->winsize);
}

static void init_child(Job *job) FUNC_ATTR_NONNULL_ALL
{
  unsetenv("COLUMNS");
  unsetenv("LINES");
  unsetenv("TERMCAP");
  unsetenv("COLORTERM");
  unsetenv("COLORFGBG");

  signal(SIGCHLD, SIG_DFL);
  signal(SIGHUP, SIG_DFL);
  signal(SIGINT, SIG_DFL);
  signal(SIGQUIT, SIG_DFL);
  signal(SIGTERM, SIG_DFL);
  signal(SIGALRM, SIG_DFL);

  setenv("TERM", job->opts.term_name ? job->opts.term_name : "ansi", 1);
  execvp(job->opts.argv[0], job->opts.argv);
  fprintf(stderr, "execvp failed: %s\n", strerror(errno));
}

static void init_termios(struct termios *termios) FUNC_ATTR_NONNULL_ALL
{
  memset(termios, 0, sizeof(struct termios));
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
