" Test 'autochdir' behavior

source check.vim
CheckOption autochdir

func Test_set_filename()
  CheckFunction test_autochdir
  let cwd = getcwd()
  call test_autochdir()
  set acd

  let s:li = []
  autocmd DirChanged auto call add(s:li, "autocd")
  autocmd DirChanged auto call add(s:li, expand("<afile>"))

  new
  w samples/Xtest
  call assert_equal("Xtest", expand('%'))
  call assert_equal("samples", substitute(getcwd(), '.*/\(\k*\)', '\1', ''))
  call assert_equal(["autocd", getcwd()], s:li)

  bwipe!
  au! DirChanged
  set noacd
  call chdir(cwd)
  call delete('samples/Xtest')
endfunc

func Test_verbose_pwd()
  CheckFunction test_autochdir
  let cwd = getcwd()
  call test_autochdir()

  edit global.txt
  call assert_match('\[global\].*testdir$', execute('verbose pwd'))

  call mkdir('Xautodir')
  split Xautodir/local.txt
  lcd Xautodir
  call assert_match('\[window\].*testdir[/\\]Xautodir', execute('verbose pwd'))

  set acd
  wincmd w
  call assert_match('\[autochdir\].*testdir$', execute('verbose pwd'))
  execute 'lcd' cwd
  call assert_match('\[window\].*testdir$', execute('verbose pwd'))
  execute 'tcd' cwd
  call assert_match('\[tabpage\].*testdir$', execute('verbose pwd'))
  execute 'cd' cwd
  call assert_match('\[global\].*testdir$', execute('verbose pwd'))
  edit
  call assert_match('\[autochdir\].*testdir$', execute('verbose pwd'))
  wincmd w
  call assert_match('\[autochdir\].*testdir[/\\]Xautodir', execute('verbose pwd'))
  set noacd
  call assert_match('\[autochdir\].*testdir[/\\]Xautodir', execute('verbose pwd'))
  wincmd w
  call assert_match('\[global\].*testdir', execute('verbose pwd'))
  wincmd w
  call assert_match('\[window\].*testdir[/\\]Xautodir', execute('verbose pwd'))

  bwipe!
  call chdir(cwd)
  call delete('Xautodir', 'rf')
endfunc

func Test_multibyte()
  " using an invalid character should not cause a crash
  set wic
  " Except on Windows, E472 is also thrown last, but v8.1.1183 isn't ported yet
  " call assert_fails('tc û¦*', has('win32') ? 'E480:' : 'E344:')
  call assert_fails('tc û¦*', has('win32') ? 'E480:' : 'E472:')
  set nowic
endfunc


" vim: shiftwidth=2 sts=2 expandtab
