#include <stdint.h>
#include <fcntl.h> 
#include <assert.h>
#include <stdlib.h>
#include <unistd.h> 
#include <signal.h> 
#include "uv.h"

#include "nvim/main.h"
#include "nvim/types_defs.h"
#include "nvim/event/loop.h"

#include <sanitizer/lsan_interface.h>

extern int nvim_main(int argc, char **argv);


void thread_func(void* fifo_name){


  char *argv[] = {"/home/xwang/project/neovim/build/bin/nvim","--embed","--headless","--listen",fifo_name};
  int res = nvim_main(5, argv);

  (void)res;
}

extern int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {


  //get tmp dir envvar 
  const char* os_tmp_dir= "/tmp";
  assert(os_tmp_dir);

  char test_base[1024]; 
  snprintf(test_base, sizeof(test_base), "%s/nvim_fuzzer_%ld_%ld",
             os_tmp_dir,(long)getpid(), (long)gettid());

  char call_init[1024];
  snprintf(call_init, sizeof(call_init), FUZZER_INIT_SCRIPT " \"%s\"", test_base);

  int init_fuzzer_env_res = system(call_init);

  assert(init_fuzzer_env_res == 0);



  {
  char fuzz_bin_path[1024];
  snprintf(fuzz_bin_path, sizeof(fuzz_bin_path), "%s/fuzzer.input",
             test_base);
  int fd = open(fuzz_bin_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  assert(fd != -1);
  ssize_t written = write(fd, Data, Size);
  assert (written == (ssize_t)Size);
  }

  char fifo_name[1024];
  snprintf(fifo_name, sizeof(fifo_name), "%s/socket",test_base);
  pthread_t id;
  pthread_create(&id,NULL, (void *(*)(void *))&thread_func,fifo_name);

  // wait socket file appear
  while(access(fifo_name,F_OK) != 0){
    printf("%s\n",strerror(errno));
    usleep(100);
  }
  // now can we assume nvim is under normal state
  //
  struct loop *data = uv_loop_get_data(&main_loop.uv);

  data->fuzzer_test_base = test_base;


  char send_script[1024];
  snprintf(send_script, sizeof(send_script),FUZZER_SEND_SCRIPT " \"%s\"",
             test_base);

  int send_res = system(send_script);
  assert(send_res == 0);

  pthread_join(id,NULL);
  return 0;
}
