// FIXME!!!
#ifdef COMPILE_TEST_VERSION
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <inttypes.h>

typedef int cmdidx_T;

#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/api/private/defs.h"
#include "nvim/viml/dumpers/dumpers.h"

int do_init(void **);

static Object (*eval_lua)(String, Error *);
static void (*msgpack_rpc_free_object)(Object);
static Object (*execute_viml)(const char *const);
static int (*dump_object)(const Object, Writer, void *);
static char *(*execute_viml_test)(const char *const);

int main(int argc, char **argv, char **env)
{
  Object result;
  if (argc <= 1) {
    return 1;
  }

  void *handle;

  int ret = do_init(&handle);
  if (ret) {
    return ret + 1;
  }

  dump_object = dlsym(handle, "dump_object");
  if (dump_object == NULL) {
    return 5;
  }

  if (argc == 3 && argv[1][0] == '-' && argv[1][1] == 'v') {
    execute_viml = dlsym(handle, "execute_viml");
    if (execute_viml == NULL) {
      return 6;
    }

    result = execute_viml(argv[2]);
  } else if (argc == 3 && argv[1][0] == '-' && argv[1][1] == 't') {
    execute_viml_test = dlsym(handle, "execute_viml_test");
    if (execute_viml_test == NULL) {
      return 7;
    }

    char *r = execute_viml_test(argv[2]);
    if (r == NULL) {
      return 8;
    }

    puts(r);
    xfree(r);

    return 0;
  } else {
    eval_lua = dlsym(handle, "eval_lua");
    if (eval_lua == NULL) {
      return 9;
    }

    String arg = {
      .data = argv[1],
      .size = strlen(argv[1]),
    };
    Error err = {
      .set = false,
    };
    result = eval_lua(arg, &err);

    if (err.set) {
      puts("Error was set:");
      puts(err.msg);
    }
  }

  if (dump_object(result, (Writer) &fwrite, (void *) stdout) == FAIL) {
    return 10;
  }

  return 0;
}
#endif  // COMPILE_TEST_VERSION
int abc3() {
  return 0;
}
