" Vim compiler file
" Compiler: IAR Systems C/C++ Compiler

if exists("current_compiler")
  finish
endif
let current_compiler = "iar"

let s:cpo_save = &cpo
set cpo&vim

"   abc;
"   ^
" "/tmp/test.c",3  Error[Pe077]: this
"           declaration has no storage class or type specifier

" Error[Li005]: no definition for "Foo::Foo(unsigned shor
"           t, unsigned short, unsigned int, char const *)"
"           [referenced from Bar.o(libBar.a)]

CompilerSet errorformat=
      \%A\ \ %p^,
      \%C\"%f\"\\\,%l\ \ Remark[%*[^]]]:\ %m,
      \%C\"%f\"\\\,%l\ \ %tarning[%*[^]]]:\ %m,
      \%C\"%f\"\\\,%l\ \ %trror[%*[^]]]:\ %m,
      \%C\"%f\"\\\,%l\ \ Fatal\ %trror[%*[^]]]:\ %m,
      \%EInternal\ error:\ %m,
      \%EError[%*[^]]]:\ %m,
      \%C%\\s%\\+%m,

let &cpo = s:cpo_save
unlet s:cpo_save
