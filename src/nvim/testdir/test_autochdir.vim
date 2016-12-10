" Test 'autochdir' behavior

if !exists("+autochdir")
  finish
endif

func Test_set_filename()
  call test_autochdir()
  set acd
  new
  w samples/Xtest
  call assert_equal("Xtest", expand('%'))
  call assert_equal("samples", substitute(getcwd(), '.*/\(\k*\)', '\1', ''))
  bwipe!
  set noacd
  call delete('samples/Xtest')
endfunc
