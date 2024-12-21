#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#ifdef _MSC_VER
# include <Windows.h>
# define usleep(usecs) Sleep(usecs/1000)
#else
# include <unistd.h>
#endif

static void flush_wait(void)
{
  fflush(NULL);
  usleep(10*1000);  // Wait 10 ms.
}

static void help(void)
{
  puts("Fake shell");
  puts("");
  puts("Usage:");
  puts("  shell-test --help");
  puts("    Prints this help to stdout.");
  puts("  shell-test");
  puts("  shell-test EXE");
  puts("    Prints \"ready $ \" to stderr.");
  puts("  shell-test -t {prompt text}");
  puts("    Prints \"{prompt text} $ \" to stderr.");
  puts("  shell-test EXE \"prog args...\"");
  puts("    Prints \"ready $ prog args...\\n\" to stderr.");
  puts("  shell-test -t {prompt text} EXE \"prog args...\"");
  puts("    Prints \"{prompt text} $ progs args...\" to stderr.");
  puts("  shell-test REP N {text}");
  puts("    Prints \"{lnr}: {text}\\n\" to stdout N times, taking N milliseconds.");
  puts("    Example:");
  puts("      shell-test REP 97 \"foo bar\"");
  puts("      0: foo bar");
  puts("      ...");
  puts("      96: foo bar");
  puts("  shell-test INTERACT");
  puts("    Prints \"interact $ \" to stderr, and waits for \"exit\" input.");
  puts("  shell-test EXIT {code}");
  puts("    Exits immediately with exit code \"{code}\".");
}

int main(int argc, char **argv)
{
  if (argc == 2 && strcmp(argv[1], "--help") == 0) {
    help();
  }

#ifdef _MSC_VER
  SetConsoleOutputCP(CP_UTF8);
#endif

  if (argc >= 2) {
    if (strcmp(argv[1], "-t") == 0) {
      if (argc < 3) {
        fprintf(stderr, "Missing prompt text for -t option\n");
        return 5;
      } else {
        fprintf(stderr, "%s $ ", argv[2]);
        if (argc >= 5 && (strcmp(argv[3], "EXE") == 0)) {
          fprintf(stderr, "%s\n", argv[4]);
        }
      }
    } else if (strcmp(argv[1], "EXE") == 0) {
      fprintf(stderr, "ready $ ");
      if (argc >= 3) {
        fprintf(stderr, "%s\n", argv[2]);
      }
    } else if (strcmp(argv[1], "REP") == 0) {
      if (argc != 4) {
        fprintf(stderr, "REP expects exactly 3 arguments\n");
        return 4;
      }
      int count = 0;
      if (sscanf(argv[2], "%d", &count) != 1) {
        fprintf(stderr, "Invalid count: %s\n", argv[2]);
        return 4;
      }
      for (int i = 0; i < count; i++) {
        printf("%d: %s\n", i, argv[3]);
        if (i % 100 == 0) {
          usleep(1000);  // Wait 1 ms (simulate typical output).
        }
        fflush(NULL);
      }
    } else if (strcmp(argv[1], "UTF-8") == 0) {
      // test split-up UTF-8 sequence
      printf("\xc3"); flush_wait();
      printf("\xa5\n"); flush_wait();

      // split up a 2+2 grapheme clusters all possible ways
      printf("ref: \xc3\xa5\xcc\xb2\n"); flush_wait();

      printf("1: \xc3"); flush_wait();
      printf("\xa5\xcc\xb2\n"); flush_wait();

      printf("2: \xc3\xa5"); flush_wait();
      printf("\xcc\xb2\n"); flush_wait();

      printf("3: \xc3\xa5\xcc"); flush_wait();
      printf("\xb2\n"); flush_wait();
    } else if (strcmp(argv[1], "INTERACT") == 0) {
      char input[256];
      char cmd[100];
      int arg;

      while (true) {
        fprintf(stderr, "interact $ ");

        if (fgets(input, sizeof(input), stdin) == NULL) {
          break;  // EOF
        }

        if (1 == sscanf(input, "%99s %d", cmd, &arg)) {
          arg = 0;
        }
        if (strcmp(cmd, "exit") == 0) {
          return arg;
        } else {
          fprintf(stderr, "command not found: %s\n", cmd);
        }
      }
    } else if (strcmp(argv[1], "EXIT") == 0) {
      int code = 1;
      if (argc >= 3) {
        if (sscanf(argv[2], "%d", &code) != 1) {
          fprintf(stderr, "Invalid exit code: %s\n", argv[2]);
          return 2;
        }
      }
      return code;
    } else {
      fprintf(stderr, "Unknown first argument: %s\n", argv[1]);
      return 3;
    }
    fflush(NULL);
    return 0;
  } else if (argc == 1) {
    fprintf(stderr, "ready $ ");
    return 0;
  } else {
    fprintf(stderr, "Missing first argument\n");
    return 2;
  }
}
