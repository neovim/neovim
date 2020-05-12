// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdio.h>

int main(int argc, char **argv)
{
  for (int i=1; i<argc; i++) {
    printf("arg%d=%s;", i, argv[i]);
  }
  return 0;
}
