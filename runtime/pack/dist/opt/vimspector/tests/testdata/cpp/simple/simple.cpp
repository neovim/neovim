#include <iostream>

namespace
{
  void foo( int bar )
  {
    int unused;

    printf( "%d\n", bar );
  }
}

int main( int argc, char ** )
{
  printf( "this is a test %d\n", argc );
  foo( argc );
  return 0;
}
