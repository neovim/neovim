" Test for :cd and chdir()

source shared.vim
source check.vim

func Test_cd_large_path()
  " This used to crash with a heap write overflow.
  call assert_fails('cd ' . repeat('x', 5000), 'E344:')
endfunc

func Test_cd_up_and_down()
  let path = getcwd()
  cd ..
  call assert_notequal(path, getcwd())
  exe 'cd ' .. fnameescape(path)
  call assert_equal(path, getcwd())
endfunc

func Test_cd_no_arg()
  if has('unix')
    " Test that cd without argument goes to $HOME directory on Unix systems.
    let path = getcwd()
    cd
    call assert_equal($HOME, getcwd())
    call assert_notequal(path, getcwd())
    exe 'cd ' .. fnameescape(path)
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

  " Test for :cd - after a failed :cd
  call assert_fails('cd /nonexistent', 'E344:')
  call assert_equal(path, getcwd())
  cd -
  call assert_equal(path_dotdot, getcwd())
  cd -

  " Test for :cd - without a previous directory
  let lines =<< trim [SCRIPT]
    call assert_fails('cd -', 'E186:')
    call assert_fails('call chdir("-")', 'E186:')
    call writefile(v:errors, 'Xresult')
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript', 'D')
  if RunVim([], [], '--clean -S Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xresult')
endfunc

" Test for chdir()
func Test_chdir_func()
  let topdir = getcwd()
  call mkdir('Xchdir/y/z', 'pR')

  " Create a few tabpages and windows with different directories
  new
  cd Xchdir
  tabnew
  tcd y
  below new
  below new
  lcd z

  tabfirst
  call assert_match('^\[global\] .*/Xchdir$', trim(execute('verbose pwd')))
  call chdir('..')
  call assert_equal('y', fnamemodify(getcwd(1, 2), ':t'))
  call assert_equal('z', fnamemodify(3->getcwd(2), ':t'))
  tabnext | wincmd t
  call assert_match('^\[tabpage\] .*/y$', trim(execute('verbose pwd')))
  eval '..'->chdir()
  call assert_equal('Xchdir', fnamemodify(getcwd(1, 2), ':t'))
  call assert_equal('Xchdir', fnamemodify(getcwd(2, 2), ':t'))
  call assert_equal('z', fnamemodify(getcwd(3, 2), ':t'))
  call assert_equal('testdir', fnamemodify(getcwd(1, 1), ':t'))
  3wincmd w
  call assert_match('^\[window\] .*/z$', trim(execute('verbose pwd')))
  call chdir('..')
  call assert_equal('Xchdir', fnamemodify(getcwd(1, 2), ':t'))
  call assert_equal('Xchdir', fnamemodify(getcwd(2, 2), ':t'))
  call assert_equal('y', fnamemodify(getcwd(3, 2), ':t'))
  call assert_equal('testdir', fnamemodify(getcwd(1, 1), ':t'))

  " Error case
  call assert_fails("call chdir('dir-abcd')", 'E344:')
  silent! let d = chdir("dir_abcd")
  call assert_equal("", d)
  " Should not crash
  call chdir(d)
  call assert_equal('', chdir([]))

  only | tabonly
  call chdir(topdir)
endfunc

" Test for changing to the previous directory '-'
func Test_prev_dir()
  let topdir = getcwd()
  call mkdir('Xprevdir/a/b/c', 'pR')

  " Create a few tabpages and windows with different directories
  new | only
  tabnew | new
  tabnew
  tabfirst
  cd Xprevdir
  tabnext | wincmd t
  tcd a
  wincmd w
  lcd b
  tabnext
  tcd a/b/c

  " Change to the previous directory twice in all the windows.
  tabfirst
  cd - | cd -
  tabnext | wincmd t
  tcd - | tcd -
  wincmd w
  lcd - | lcd -
  tabnext
  tcd - | tcd -

  " Check the directory of all the windows
  tabfirst
  call assert_equal('Xprevdir', fnamemodify(getcwd(), ':t'))
  tabnext | wincmd t
  call assert_equal('a', fnamemodify(getcwd(), ':t'))
  wincmd w
  call assert_equal('b', fnamemodify(getcwd(), ':t'))
  tabnext
  call assert_equal('c', fnamemodify(getcwd(), ':t'))

  " Change to the previous directory using chdir()
  tabfirst
  call chdir("-") | call chdir("-")
  tabnext | wincmd t
  call chdir("-") | call chdir("-")
  wincmd w
  call chdir("-") | call chdir("-")
  tabnext
  call chdir("-") | call chdir("-")

  " Check the directory of all the windows
  tabfirst
  call assert_equal('Xprevdir', fnamemodify(getcwd(), ':t'))
  tabnext | wincmd t
  call assert_equal('a', fnamemodify(getcwd(), ':t'))
  wincmd w
  call assert_equal('b', fnamemodify(getcwd(), ':t'))
  tabnext
  call assert_equal('c', fnamemodify(getcwd(), ':t'))

  only | tabonly
  call chdir(topdir)
endfunc

func Test_lcd_split()
  let curdir = getcwd()
  lcd ..
  split
  lcd -
  call assert_equal(curdir, getcwd())
  quit!
endfunc

func Test_cd_from_non_existing_dir()
  CheckNotMSWindows

  let saveddir = getcwd()
  call mkdir('Xdeleted_dir')
  cd Xdeleted_dir
  call delete(saveddir .. '/Xdeleted_dir', 'd')

  " Expect E187 as the current directory was deleted.
  call assert_fails('pwd', 'E187:')
  call assert_equal('', getcwd())
  cd -
  call assert_equal(saveddir, getcwd())
endfunc

func Test_cd_completion()
  call mkdir('XComplDir1', 'D')
  call mkdir('XComplDir2', 'D')
  call mkdir('sub/XComplDir3', 'pD')
  call writefile([], 'XComplFile', 'D')

  for cmd in ['cd', 'chdir', 'lcd', 'lchdir', 'tcd', 'tchdir']
    call feedkeys(':' .. cmd .. " XCompl\<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"' .. cmd .. ' XComplDir1/ XComplDir2/', @:)
  endfor

  set cdpath+=sub
  for cmd in ['cd', 'chdir', 'lcd', 'lchdir', 'tcd', 'tchdir']
    call feedkeys(':' .. cmd .. " XCompl\<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"' .. cmd .. ' XComplDir1/ XComplDir2/ XComplDir3/', @:)
  endfor
  set cdpath&
endfunc

func Test_cd_unknown_dir()
  call mkdir('Xa', 'R')
  cd Xa
  call writefile(['text'], 'Xb.txt')
  edit Xa/Xb.txt
  let first_buf = bufnr()
  cd ..
  edit
  call assert_equal(first_buf, bufnr())
  edit Xa/Xb.txt
  call assert_notequal(first_buf, bufnr())

  bwipe!
  exe "bwipe! " .. first_buf
endfunc

func Test_getcwd_actual_dir()
  CheckFunction test_autochdir
  CheckOption autochdir

  let startdir = getcwd()
  call mkdir('Xactual', 'R')
  call test_autochdir()
  set autochdir
  edit Xactual/file.txt
  call assert_match('testdir.Xactual$', getcwd())
  lcd ..
  call assert_match('testdir$', getcwd())
  edit
  call assert_match('testdir.Xactual$', getcwd())
  call assert_match('testdir$', getcwd(win_getid()))

  set noautochdir
  bwipe!
  call chdir(startdir)
endfunc

func Test_cd_preserve_symlinks()
  " Test new behavior: preserve symlinks when cpo-=~
  set cpoptions+=~

  let savedir = getcwd()
  call mkdir('Xsource', 'R')
  call writefile(['abc'], 'Xsource/foo.txt', 'D')

  if has("win32")
    silent !mklink /D Xdest Xsource
  else
    silent !ln -s Xsource Xdest
  endif
  if v:shell_error
    call delete('Xsource', 'rf')
    throw 'Skipped: cannot create symlinks'
  endif

  edit Xdest/foo.txt
  let path_before = expand('%')
  call assert_match('Xdest[/\\]foo\.txt$', path_before)

  cd .
  let path_after = expand('%')
  call assert_equal(path_before, path_after)
  call assert_match('Xdest[/\\]foo\.txt$', path_after)

  bwipe!
  set cpoptions&
  call delete('Xdest', 'rf')
  call delete('Xsource', 'rf')
  call chdir(savedir)
endfunc

func Test_cd_symlinks()
  CheckNotMSWindows

  let savedir = getcwd()
  call mkdir('Xsource', 'R')
  call writefile(['abc'], 'Xsource/foo.txt', 'D')

  silent !ln -s Xsource Xdest
  if v:shell_error
    call delete('Xsource', 'rf')
    throw 'Skipped: cannot create symlinks'
  endif

  edit Xdest/foo.txt
  let path_before = expand('%')
  call assert_match('Xdest[/\\]foo\.txt$', path_before)

  cd .
  let path_after = expand('%')
  call assert_match('Xsource[/\\]foo\.txt$', path_after)
  call assert_notequal(path_before, path_after)

  bwipe!
  set cpoptions&
  call delete('Xdest', 'rf')
  call delete('Xsource', 'rf')
  call chdir(savedir)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
