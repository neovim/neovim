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


void test_base_path_join(char* buf,size_t buf_size, const char* test_base, const char* to_append){
  snprintf(buf, buf_size, "%s/%s", test_base, to_append);
}

void redirect_common_path(void* test_base);

void redirect_common_path(void* test_base){
  setenv("HOME",test_base,1);
  //change runtime dir
  char buf[1024];


  const char * change_vars[][2]={{"XDG_RUNTIME_DIR","XDG_RUNTIME_DIR"},{"TMPDIR","TMPDIR"},{"XDG_CONFIG_HOME",".config"},{"XDG_DATA_HOME",".local/share"},{"XDG_CACHE_HOME",".cache"},{"XDG_STATE_HOME",".local/state"},{"VIMRUNTIME",".local/share/nvim/runtime"}};

  for(int i = 0;i < 7; ++i){
    test_base_path_join(buf,sizeof(buf), test_base, change_vars[i][1]);
    setenv(change_vars[i][0],buf,1);
  }

  setenv("XDG_DATA_DIRS","",1);
  setenv("XDG_CONFIG_DIRS","",1);
}

static void thread_func(void* test_base){

  char fifo_name[1024];
  test_base_path_join(fifo_name,sizeof(fifo_name),(const char*)test_base, "socket");

  char *argv[] = {"/home/xwang/project/neovim/build/bin/nvim","--embed","--headless","--listen",fifo_name};


  


  int res = nvim_main(5, argv);

  (void)res;
}


int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size);

void run_prepare_script(const char* test_base);

void run_prepare_script(const char* test_base){

  char call_init[1024];
  snprintf(call_init, sizeof(call_init), FUZZER_INIT_SCRIPT " \"%s\"", test_base);

  int init_fuzzer_env_res = system(call_init);

  assert(init_fuzzer_env_res == 0);

}

void get_test_base(char* buf,size_t size);
void get_test_base(char* buf,size_t size){

  //get tmp dir envvar 
  const char* os_tmp_dir= "/tmp";

  snprintf(buf, size, "%s/nvim_fuzzer_%ld_%ld",
             os_tmp_dir,(long)getpid(), (long)gettid());
}

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {

  char test_base[1024]; 
  get_test_base(test_base,sizeof(test_base));

  run_prepare_script(test_base);



  {
    char fuzz_bin_path[1024];
    test_base_path_join(fuzz_bin_path, sizeof(fuzz_bin_path), test_base, "fuzzer.input");
  int fd = open(fuzz_bin_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  assert(fd != -1);
  ssize_t written = write(fd, Data, Size);
  assert (written == (ssize_t)Size);
    close(fd);
  }

  pthread_t id;
  pthread_create(&id,NULL, (void *(*)(void *))&thread_func,test_base);

  // wait socket file appear
  //
  char fifo_name[1024];
  test_base_path_join(fifo_name,sizeof(fifo_name),test_base, "socket");
  while(access(fifo_name,F_OK) != 0){
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

  //cleanup

  char cleanup[1024];

  snprintf(cleanup, sizeof(cleanup), "rm -rf %s",test_base);
  int res = system(cleanup);
  assert(res == 0);

  return 0;
}
