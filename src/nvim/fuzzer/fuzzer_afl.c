#include <stdint.h>
#include <stdlib.h>

#include "uv.h"
#include "nvim/event/loop.h"
#include "nvim/main.h"

void get_test_base(char* buf,size_t size);
void redirect_common_path(void* test_base);
void run_prepare_script(const char* test_base);
extern int nvim_main(int argc, char **argv);

  //last argument as fuzzer input file
int main(int argc, char** argv){
  // nvim call os exit to quite, 
  // and nvim_man not reentrant
  // which conflicit with libfuzzer/ afl fast in process mode
  // so we can only work with slow executable mode, that is, run neovim as new process for every
  // fuzzer run

  char test_base[1024];

  get_test_base(test_base, sizeof(test_base));
  run_prepare_script(test_base);
  redirect_common_path(test_base);

  struct loop *data = uv_loop_get_data(&main_loop.uv);

  data->fuzzer_test_base = test_base;

  char *nvim_argv[] = {"fake_bin", LUA_SHIM_PATH,argv[argc-1]};
  nvim_main(3, nvim_argv);
}
