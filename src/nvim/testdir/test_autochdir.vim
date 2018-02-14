" Test 'autochdir' behavior

if !exists("+autochdir")
  finish
endif

func Test_set_filename()
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
