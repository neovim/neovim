#include <stdint.h>
#include <stdlib.h>

#include "nvim/main.h"

extern int nvim_main(int argc, char **argv);

extern int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
  char *argv[] = {"/home/xwang/project/neovim/build/bin/nvim","--embed","--headless","--listen","127.0.0.1:4444"};
  int res = nvim_main(5, argv);

  return 0;
}
