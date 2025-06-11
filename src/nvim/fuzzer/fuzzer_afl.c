#include <stdint.h>
#include <stdlib.h>

#include "uv.h"
#include "nvim/event/loop.h"
#include "nvim/main.h"

void get_test_base(char* buf,size_t size);
void redirect_common_path(void* test_base);
void run_prepare_script(const char* test_base);
extern int nvim_main(int argc, char **argv);

static void set_data(void* test_base){

  while(1){
    struct loop *data = uv_loop_get_data(&main_loop.uv);
    if(!data){
      usleep(1000);
    }
    data->fuzzer_test_base = test_base;
    return;
  }
}

void test_base_path_join(char* buf,size_t buf_size, const char* test_base, const char* to_append);

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


  pthread_t id;
  pthread_create(&id,NULL, (void *(*)(void *))&set_data,test_base);

  test_base_path_join

  char *nvim_argv[] = {"fake_bin", LUA_SHIM_PATH,argv[argc-1]};

  nvim_main(3, nvim_argv);

  pthread_join(id, NULL);
}
