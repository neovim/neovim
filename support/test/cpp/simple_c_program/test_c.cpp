#include <iostream>

namespace Test
{
  struct TestStruct
  {
    bool  isInt;

    union {
      int somethingInt;
      char somethingChar;
    } something;
  };

  TestStruct _t;

  void bar( TestStruct b )
  {
    std::string s;
    s += b.isInt ? "An int" : "A char";
    std::cout << s << '\n';
  }

  void foo( TestStruct m )
  {
    TestStruct t{ true, {11} };
    bar( t );
  }
}


int main ( int argc, char ** argv )
{
  int x{ 10 };

  Test::TestStruct t{ true, {99} };
  foo( t );
}
