// A simple implementation of a shell for testing
// `termopen([&sh, &shcf, '{cmd'}])` and `termopen([&sh])`.
//
// If launched with no arguments, prints "ready $ ", otherwise prints
// "ready $ {cmd}\n".

#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
  fprintf(stderr, "ready $ ");

  if (argc == 3) {
    // argv should be {"terminal-test", "EXE", "prog args..."}
    if (strcmp(argv[1], "EXE") != 0) {
      fprintf(stderr, "first argument must be 'EXE'\n");
      return 2;
    }

    fprintf(stderr, "%s\n", argv[2]);
  }

  return 0;
}
