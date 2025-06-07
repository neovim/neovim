#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
extern int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size);

extern int nvim_main(int argc, char **argv);
int main(int argc, char** argv){


  //int res = nvim_main(argc, argv);
  LLVMFuzzerTestOneInput((const uint8_t *)"12345678",8);


  return 0;
}
