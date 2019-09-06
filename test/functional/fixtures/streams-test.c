/// Helper program to exit and keep stdout open (like "xclip -i -loops 1").
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>


int main(int argc, char **argv)
{
  pid_t pid = fork();

  if (pid) {
    fprintf(stderr, "pid: %d\n", pid);
    exit(0);
  }

  sleep(10);
}
