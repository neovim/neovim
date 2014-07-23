// FIXME!!!
#ifdef COMPILE_TEST_VERSION
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

int do_init(void **);

static void (*init_func)(void);
static char *(*parse_cmd_test)(char *arg, uint_least16_t flags, bool one,
                               bool out);
static void (*mch_exit)(int code);

int main(int argc, char **argv, char **env)
{
  if (argc <= 1) {
    return 1;
  }

  bool one = false;
  if (strcmp(argv[1], "-1") == 0) {
    argv++;
    argc--;
    one = true;
  }

  void *handle;

  int ret = do_init(&handle);
  if (ret) {
    return ret + 1;
  }

  parse_cmd_test = dlsym(handle, "parse_cmd_test");
  if (parse_cmd_test == NULL) {
    return 5;
  }

  parse_cmd_test(argv[1], (argc > 2
                           ? (uint_least16_t) atoi(argv[2])
                           : 0),
                 one, true);
  putc('\n', stdout);

  mch_exit = dlsym(handle, "mch_exit");
  if (mch_exit == NULL) {
    return 6;
  }
  mch_exit(0);
  return 0;
}
#endif  // COMPILE_TEST_VERSION
int abc2() {
  return 0;
}
