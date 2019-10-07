/// Helper program to handle signal processing with jobs.
#include <stdio.h>
#include <unistd.h>
#include <signal.h>

static void on_sigterm(int signum)
{
  fprintf(stdout, "got_sigterm\n");
  fflush(stdout);
}

int main(int argc, char **argv)
{
  signal(SIGTERM, on_sigterm);
  fprintf(stdout, "pid: %d\n", getpid());
  fflush(stdout);
  while (1) {
    usleep(100000);
  }
}
