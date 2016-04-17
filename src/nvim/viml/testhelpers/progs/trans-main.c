#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <inttypes.h>

typedef int cmdidx_T;

#include "nvim/vim.h"

int do_init(void **handle);

int (*translate_script_std)(void);

int main(int argc, char **argv, char **env)
{
  void *handle;

  int ret = do_init(&handle);
  if (ret) {
    return ret;
  }

  translate_script_std = dlsym(handle, "translate_script_std");
  if (translate_script_std == NULL) {
    return 4;
  }

  if (translate_script_std() == FAIL) {
    return 5;
  }

  return 0;
}
