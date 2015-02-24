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

#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/os/job_private.h"
#include "nvim/os/pty_process.h"
#include "nvim/memory.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process.c.generated.h"
#endif

typedef struct {
  struct winsize winsize;
  uv_pipe_t proc_stdin, proc_stdout, proc_stderr;
  uv_signal_t schld;
  int tty_fd;
} PtyProcess;

void pty_process_init(Job *job)
{
  PtyProcess *ptyproc = xmalloc(sizeof(PtyProcess));

  if (job->opts.writable) {
    uv_pipe_init(uv_default_loop(), &ptyproc->proc_stdin, 0);
    ptyproc->proc_stdin.data = NULL;
  }

  if (job->opts.stdout_cb) {
    uv_pipe_init(uv_default_loop(), &ptyproc->proc_stdout, 0);
    ptyproc->proc_stdout.data = NULL;
  }

  if (job->opts.stderr_cb) {
    uv_pipe_init(uv_default_loop(), &ptyproc->proc_stderr, 0);
    ptyproc->proc_stderr.data = NULL;
  }

  job->proc_stdin = (uv_stream_t *)&ptyproc->proc_stdin;
  job->proc_stdout = (uv_stream_t *)&ptyproc->proc_stdout;
  job->proc_stderr = (uv_stream_t *)&ptyproc->proc_stderr;
  job->process = ptyproc;
}

void pty_process_destroy(Job *job)
{
  free(job->opts.term_name);
  free(job->process);
  job->process = NULL;
}

bool pty_process_spawn(Job *job)
{
  int master;
  PtyProcess *ptyproc = job->process;
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
  fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK);

  if (job->opts.writable) {
    uv_pipe_open(&ptyproc->proc_stdin, dup(master));
  }

  if (job->opts.stdout_cb) {
    uv_pipe_open(&ptyproc->proc_stdout, dup(master));
  }

  if (job->opts.stderr_cb) {
    uv_pipe_open(&ptyproc->proc_stderr, dup(master));
  }

  uv_signal_init(uv_default_loop(), &ptyproc->schld);
  uv_signal_start(&ptyproc->schld, chld_handler, SIGCHLD);
  ptyproc->schld.data = job;
  ptyproc->tty_fd = master;
  job->pid = pid;
  return true;
}

void pty_process_close(Job *job)
{
  PtyProcess *ptyproc = job->process;
  uv_signal_stop(&ptyproc->schld);
  uv_close((uv_handle_t *)&ptyproc->schld, NULL);
  job_close_streams(job);
  job_decref(job);
}

void pty_process_resize(Job *job, uint16_t width, uint16_t height)
{
  PtyProcess *ptyproc = job->process;
  ptyproc->winsize = (struct winsize){height, width, 0, 0};
  ioctl(ptyproc->tty_fd, TIOCSWINSZ, &ptyproc->winsize);
}

static void init_child(Job *job)
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

static void chld_handler(uv_signal_t *handle, int signum)
{
  Job *job = handle->data;
  int stat = 0;

  if (waitpid(job->pid, &stat, 0) < 0) {
    fprintf(stderr, "Waiting for pid %d failed: %s\n", job->pid,
        strerror(errno));
    return;
  }

  if (WIFSTOPPED(stat) || WIFCONTINUED(stat)) {
    // Did not exit
    return;
  }

  if (WIFEXITED(stat)) {
    job->status = WEXITSTATUS(stat);
  } else if (WIFSIGNALED(stat)) {
    job->status = WTERMSIG(stat);
  }

  pty_process_close(job);
}

static void init_termios(struct termios *termios)
{
  memset(termios, 0, sizeof(struct termios));
  // Taken from pangoterm
  termios->c_iflag = ICRNL|IXON;
  termios->c_oflag = OPOST|ONLCR|TAB0;
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
