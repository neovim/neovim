#include <stdint.h>
#include <fcntl.h> 
#include <assert.h>
#include <stdlib.h>
#include <unistd.h> 
#include <signal.h> 

#include "nvim/main.h"

extern int nvim_main(int argc, char **argv);

void thread_func(void* fifo_name){


  char *argv[] = {"/home/xwang/project/neovim/build/bin/nvim","--embed","--headless","--listen",fifo_name};
  int res = nvim_main(5, argv);

  (void)res;
}

extern int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
  char fifo_name[256]; 
  snprintf(fifo_name, sizeof(fifo_name), "/tmp/nvim_fuzz_pid%ld_tid%ld.fifo",
             (long)getpid(), (long)gettid());


  //ssize_t written = write(fd,Data,Size);

  //assert(written == (int)Size);

  pthread_t id;
  pthread_create(&id,NULL, (void *(*)(void *))&thread_func,fifo_name);




  pthread_join(id,NULL);

  //int fd = open(fifo_name, O_WRONLY);
  //assert(fd != -1);
  return 0;
}
