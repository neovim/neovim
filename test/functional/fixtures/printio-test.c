#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _MSC_VER
# include <Windows.h>
# define usleep(usecs) Sleep((usecs) / 1000)
#else
# include <unistd.h>
#endif

static void help(void)
{
  puts("Print input/output");
  puts("");
  puts("Usage:");
  puts("  printio-test --help");
  puts("    Prints this help to stdout.");
  puts("  printio-test [-a file] [-o file] [-e file] [-x code] -- {command}");
  puts("    Saves args after -- into file specified by \"-a\".");
  puts("    Prints file specified by \"-o\" to stdout.");
  puts("    Prints file specified by \"-e\" to stderr.");
  puts("    Returns exit code specified by \"-x\" (default 0).");
}

static void copy_file_to_stream(const char *path, FILE *stream) {
  FILE *f = fopen(path, "rb");
  if (!f) {
    fprintf(stderr, "Could not open file: %s\n", path);
    return;
  }

  char buffer[1024];
  size_t n;
  while ((n = fread(buffer, 1, sizeof(buffer), f)) > 0) {
    fwrite(buffer, 1, n, stream);
  }
  fclose(f);
}

int main(int argc, char **argv) {
#ifdef _MSC_VER
  SetConsoleOutputCP(CP_UTF8);
#endif

  const char *args_file = NULL;
  const char *out_file = NULL;
  const char *err_file = NULL;
  int exit_code = 0;
  int command_index = -1;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--help") == 0) {
      help();
      return 0;
    } else if (strcmp(argv[i], "-a") == 0 && i + 1 < argc) {
      args_file = argv[++i];
    } else if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
      out_file = argv[++i];
    } else if (strcmp(argv[i], "-e") == 0 && i + 1 < argc) {
      err_file = argv[++i];
    } else if (strcmp(argv[i], "-x") == 0 && i + 1 < argc) {
      exit_code = atoi(argv[++i]);
    } else if (strcmp(argv[i], "--") == 0) {
      command_index = i + 1;
      break;
    } else {
      fprintf(stderr, "Unknown or incomplete option: %s\n", argv[i]);
      return 1;
    }
  }

  if (command_index >= argc) {
    fprintf(stderr, "Missing command after \"--\"\n");
    return 1;
  }

  // Print input (command) to args_file if specified
  if (args_file) {
    FILE *f = fopen(args_file, "ab");
    if (!f) {
      fprintf(stderr, "Could not open args file for writing: %s\n", args_file);
      return 1;
    }
    for (int i = command_index; i < argc; i++) {
      fputs(argv[i], f);
      if (i + 1 < argc) fputc(' ', f);
    }
    fputc('\n', f);
    fclose(f);
  }

  // Print out_file to stdout if specified
  if (out_file) {
    copy_file_to_stream(out_file, stdout);
  }

  // Print err_file to stderr if specified
  if (err_file) {
    copy_file_to_stream(err_file, stderr);
  }

  return exit_code;
}
