" Test whether glob()/globpath() return correct results with certain escaped
" characters.

function SetUp()
  " consistent sorting of file names
  set nofileignorecase
endfunction

function Test_glob()
  if !has('unix')
    " This test fails on Windows because of the special characters in the
    " filenames. Disable the test on non-Unix systems for now.
    return
  endif

  " Execute these commands in the sandbox, so that using the shell fails.
  " Setting 'shell' to an invalid name causes a memory leak.
  sandbox call assert_equal("", glob('Xxx\{'))
  sandbox call assert_equal("", glob('Xxx\$'))
  w! Xxx{
  " } to fix highlighting
  w! Xxx\$
  sandbox call assert_equal("Xxx{", glob('Xxx\{'))
  sandbox call assert_equal("Xxx$", glob('Xxx\$'))
  call delete('Xxx{')
  call delete('Xxx$')
endfunction

function Test_globpath()
  sandbox call assert_equal(expand("sautest/autoload/globone.vim\nsautest/autoload/globtwo.vim"),
  \ globpath('sautest/autoload', 'glob*.vim'))
  sandbox call assert_equal([expand('sautest/autoload/globone.vim'), expand('sautest/autoload/globtwo.vim')],
  \ globpath('sautest/autoload', 'glob*.vim', 0, 1))
endfunction
