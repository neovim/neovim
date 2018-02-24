" Test whether glob()/globpath() return correct results with certain escaped
" characters.

function SetUp()
  " make sure glob() doesn't use the shell
  set shell=doesnotexist
  " consistent sorting of file names
  set nofileignorecase
endfunction

function Test_glob()
  call assert_equal("", glob('Xxx\{'))
  call assert_equal("", glob('Xxx\$'))
  w! Xxx{
  w! Xxx\$
  call assert_equal("Xxx{", glob('Xxx\{'))
  call assert_equal("Xxx$", glob('Xxx\$'))
endfunction

function Test_globpath()
  let slash = (!exists('+shellslash') || &shellslash) ? '/' : '\'
  call assert_equal('sautest'.slash.'autoload'.slash.'footest.vim',
        \ globpath('sautest/autoload', '*.vim'))
  call assert_equal(['sautest'.slash.'autoload'.slash.'footest.vim'],
        \ globpath('sautest/autoload', '*.vim', 0, 1))
endfunction
