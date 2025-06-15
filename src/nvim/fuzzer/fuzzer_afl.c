#include <stdint.h>
#include <stdlib.h>

#include "nvim/event/loop.h"
#include "nvim/main.h"

#include "uv.h"

void get_test_base(char* buf, size_t size);
void redirect_common_path(void* test_base);
void run_prepare_script(const char* test_base);
extern int nvim_main(int argc, char** argv);

void test_base_path_join(char* buf, size_t buf_size, const char* test_base, const char* to_append);

char last_arg_realpath[];

static void run_fuzz(const char* test_base)
{

  char fifo_name[1024];
  test_base_path_join(fifo_name, sizeof(fifo_name), test_base, "socket");

  while (access(fifo_name, F_OK) != 0) {
    usleep(100);
  }

  struct loop* data = uv_loop_get_data(&main_loop.uv);
  data->fuzzer_test_base = test_base;

  char send_script[1024];
  snprintf(send_script, sizeof(send_script), FUZZER_SEND_SCRIPT " \"%s\" \"%s\"", test_base,
           last_arg_realpath);

  int send_res = system(send_script);
  assert(send_res == 0);
}

// last argument as fuzzer input file
int main(int argc, char** argv)
{
  // nvim call os exit to quite,
  // and nvim_man not reentrant
  // which conflicit with libfuzzer/ afl fast in process mode
  // so we can only work with slow executable mode, that is, run neovim as new process for every
  // fuzzer run

  char test_base[1024];
  get_test_base(test_base, sizeof(test_base));
  run_prepare_script(test_base);
  redirect_common_path(test_base);

  char fifo_name[1024];
  test_base_path_join(fifo_name, sizeof(fifo_name), test_base, "socket");

  char* p = realpath(argv[argc-1], last_arg_realpath);
  assert (p!= NULL);
  pthread_t id;
  pthread_create(&id, NULL, (void* (*)(void*)) & run_fuzz, test_base);

  char* nvim_argv[] = { "fake_bin", "--embed", "--headless", "--listen", fifo_name };

  // drop into test_base tmp dir
  char tmp_dir[1024];
  test_base_path_join(tmp_dir,sizeof(tmp_dir), test_base, "TMPDIR");
  int res = chdir(tmp_dir);
  assert (res == 0);
  nvim_main(5, nvim_argv);

  pthread_join(id, NULL);


  if (getenv("SKIP_CLEANUP") == NULL){
    char cleanup[1024];
    snprintf(cleanup, sizeof(cleanup), "rm -rf %s", test_base);
    res = system(cleanup);
    assert(res == 0);
  }

}
