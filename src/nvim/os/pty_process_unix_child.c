#include <stdlib.h>
#include <unistd.h>
#include "nvim/os/pty_process_unix.h"
#include "nvim/os/os.h"

void pty_process_child_init(PtyProcess *ptyproc) FUNC_ATTR_NONNULL_ALL
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

  Process *proc = (Process *)ptyproc;
  if (proc->cwd && os_chdir(proc->cwd) != 0) {
    fprintf(stderr, "chdir failed: %s\n", strerror(errno));
    return;
  }

  setenv("TERM", ptyproc->term_name ? ptyproc->term_name : "ansi", 1);
  execvp(ptyproc->process.argv[0], ptyproc->process.argv);
  fprintf(stderr, "execvp failed: %s\n", strerror(errno));
}

