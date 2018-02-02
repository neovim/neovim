" Test :recover

func Test_recover_root_dir()
  " This used to access invalid memory.
  split Xtest
  set dir=/
  call assert_fails('recover', 'E305:')
  close!

  if has('win32')
    " can write in / directory on MS-Windows
    set dir=/notexist/
  endif
  call assert_fails('split Xtest', 'E303:')
  set dir&
endfunc

" TODO: move recover tests from test78.in to here.
