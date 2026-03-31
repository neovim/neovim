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

func Test_set_filename_other_window()
  CheckFunction test_autochdir
  let cwd = getcwd()
  call test_autochdir()
  call mkdir('Xa', 'R')
  call mkdir('Xb', 'R')
  call mkdir('Xc', 'R')
  try
    args Xa/aaa.txt Xb/bbb.txt
    set acd
    let winid = win_getid()
    snext
    call assert_equal('Xb', substitute(getcwd(), '.*/\([^/]*\)$', '\1', ''))
    call win_execute(winid, 'file ' .. cwd .. '/Xc/ccc.txt')
    call assert_equal('Xb', substitute(getcwd(), '.*/\([^/]*\)$', '\1', ''))
  finally
    set noacd
    call chdir(cwd)
    bwipe! aaa.txt
    bwipe! bbb.txt
    bwipe! ccc.txt
  endtry
endfunc

func Test_acd_win_execute()
  CheckFunction test_autochdir
  let cwd = getcwd()
  set acd
  call test_autochdir()

  call mkdir('XacdDir', 'R')
  let winid = win_getid()
  new XacdDir/file
  call assert_match('testdir.XacdDir$', getcwd())
  cd ..
  call assert_match('testdir$', getcwd())
  call win_execute(winid, 'echo')
  call assert_match('testdir$', getcwd())

  bwipe!
  set noacd
  call chdir(cwd)
endfunc

func Test_verbose_pwd()
  CheckFunction test_autochdir
  let cwd = getcwd()
  call test_autochdir()

  edit global.txt
  call assert_match('\[global\].*testdir$', execute('verbose pwd'))

  call mkdir('Xautodir', 'R')
  split Xautodir/local.txt
  lcd Xautodir
  call assert_match('\[window\].*testdir[/\\]Xautodir', execute('verbose pwd'))

  set acd
  wincmd w
  call assert_match('\[autochdir\].*testdir$', execute('verbose pwd'))
  execute 'tcd' cwd
  call assert_match('\[tabpage\].*testdir$', execute('verbose pwd'))
  execute 'cd' cwd
  call assert_match('\[global\].*testdir$', execute('verbose pwd'))
  execute 'lcd' cwd
  call assert_match('\[window\].*testdir$', execute('verbose pwd'))
  edit
  call assert_match('\[autochdir\].*testdir$', execute('verbose pwd'))
  enew
  wincmd w
  call assert_match('\[autochdir\].*testdir[/\\]Xautodir', execute('verbose pwd'))
  wincmd w
  call assert_match('\[window\].*testdir$', execute('verbose pwd'))
  wincmd w
  call assert_match('\[autochdir\].*testdir[/\\]Xautodir', execute('verbose pwd'))
  set noacd
  call assert_match('\[autochdir\].*testdir[/\\]Xautodir', execute('verbose pwd'))
  wincmd w
  call assert_match('\[window\].*testdir$', execute('verbose pwd'))
  execute 'cd' cwd
  call assert_match('\[global\].*testdir$', execute('verbose pwd'))
  wincmd w
  call assert_match('\[window\].*testdir[/\\]Xautodir', execute('verbose pwd'))

  bwipe!
  call chdir(cwd)
endfunc

func Test_multibyte()
  " using an invalid character should not cause a crash
  set wic
  call assert_fails('tc ˚ççç¶*', has('win32') ? 'E480:' : 'E344:')
  set nowic
endfunc


" vim: shiftwidth=2 sts=2 expandtab
