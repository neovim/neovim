" Test 'autochdir' behavior

source check.vim
CheckOption autochdir

func Test_set_filename()
  CheckFunction test_autochdir
  let cwd = getcwd()
  call test_autochdir()
  set acd
  new
  w samples/Xtest
  call assert_equal("Xtest", expand('%'))
  call assert_equal("samples", substitute(getcwd(), '.*/\(\k*\)', '\1', ''))
  bwipe!
  set noacd
  exe 'cd ' . cwd
  call delete('samples/Xtest')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
