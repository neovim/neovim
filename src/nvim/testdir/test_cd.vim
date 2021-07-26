" Test for :cd

source shared.vim

func Test_cd_large_path()
  " This used to crash with a heap write overflow.
  call assert_fails('cd ' . repeat('x', 5000), 'E472:')
endfunc

func Test_cd_up_and_down()
  let path = getcwd()
  cd ..
  call assert_notequal(path, getcwd())
  exe 'cd ' . path
  call assert_equal(path, getcwd())
endfunc

func Test_cd_no_arg()
  if has('unix')
    " Test that cd without argument goes to $HOME directory on Unix systems.
    let path = getcwd()
    cd
    call assert_equal($HOME, getcwd())
    call assert_notequal(path, getcwd())
    exe 'cd ' . path
    call assert_equal(path, getcwd())
  else
    " Test that cd without argument echoes cwd on non-Unix systems.
    call assert_match(getcwd(), execute('cd'))
  endif
endfunc

func Test_cd_minus()
  " Test the  :cd -  goes back to the previous directory.
  let path = getcwd()
  cd ..
  let path_dotdot = getcwd()
  call assert_notequal(path, path_dotdot)
  cd -
  call assert_equal(path, getcwd())
  cd -
  call assert_equal(path_dotdot, getcwd())
  cd -
  call assert_equal(path, getcwd())

  " Test for :cd - without a previous directory
  let lines =<< trim [SCRIPT]
    call assert_fails('cd -', 'E186:')
    call assert_fails('call chdir("-")', 'E186:')
    call writefile(v:errors, 'Xresult')
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript')
  if RunVim([], [], '--clean -S Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xscript')
  call delete('Xresult')
endfunc

func Test_cd_with_cpo_chdir()
  e Xfoo
  call setline(1, 'foo')
  let path = getcwd()
  " set cpo+=.

  " :cd should fail when buffer is modified and 'cpo' contains dot.
  " call assert_fails('cd ..', 'E747:')
  call assert_equal(path, getcwd())

  " :cd with exclamation mark should succeed.
  cd! ..
  call assert_notequal(path, getcwd())

  " :cd should succeed when buffer has been written.
  w!
  exe 'cd ' . path
  call assert_equal(path, getcwd())

  call delete('Xfoo')
  set cpo&
  bw!
endfunc
