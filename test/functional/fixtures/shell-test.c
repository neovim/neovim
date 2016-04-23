#include <stdio.h>
#include <string.h>
#include <stdint.h>

static void help(void)
{
  puts("A simple implementation of a shell for testing termopen().");
  puts("");
  puts("Usage:");
  puts("  shell-test --help");
  puts("    Prints this help to stdout.");
  puts("  shell-test");
  puts("  shell-test EXE");
  puts("    Prints \"ready $ \" to stderr.");
  puts("  shell-test EXE \"prog args...\"");
  puts("    Prints \"ready $ prog args...\\n\" to stderr.");
  puts("  shell-test REP {byte} \"line line line\"");
  puts("    Prints \"{lnr}: line line line\\n\" to stdout {byte} times.");
  puts("    I.e. for `shell-test REP ab \"test\"'");
  puts("      0: test");
  puts("      ...");
  puts("      96: test");
  puts("    will be printed because byte `a' is equal to 97.");
}

int main(int argc, char **argv)
{
  if (argc == 2 && strcmp(argv[1], "--help") == 0) {
    help();
  }

  if (argc >= 2) {
    if (strcmp(argv[1], "EXE") == 0) {
      fprintf(stderr, "ready $ ");
      if (argc >= 3) {
        fprintf(stderr, "%s\n", argv[2]);
      }
    } else if (strcmp(argv[1], "REP") == 0) {
      if (argc < 4) {
        fprintf(stderr, "Not enough REP arguments\n");
        return 4;
      }
      uint8_t number = (uint8_t) *argv[2];
      for (uint8_t i = 0; i < number; i++) {
        printf("%d: %s\n", (int) i, argv[3]);
      }
    } else {
      fprintf(stderr, "Unknown first argument\n");
      return 3;
    }
    return 0;
  } else if (argc == 1) {
    fprintf(stderr, "ready $ ");
    return 0;
  } else {
    fprintf(stderr, "Missing first argument\n");
    return 2;
  }
}
