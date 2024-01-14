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
  call writefile(lines, 'Xscript')
  if RunVim([], [], '--clean -S Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xscript')
  call delete('Xresult')
endfunc

" Test for chdir()
func Test_chdir_func()
  let topdir = getcwd()
  call mkdir('Xdir/y/z', 'p')

  " Create a few tabpages and windows with different directories
  new
  cd Xdir
  tabnew
  tcd y
  below new
  below new
  lcd z

  tabfirst
  call assert_match('^\[global\] .*/Xdir$', trim(execute('verbose pwd')))
  call chdir('..')
  call assert_equal('y', fnamemodify(getcwd(1, 2), ':t'))
  call assert_equal('z', fnamemodify(3->getcwd(2), ':t'))
  tabnext | wincmd t
  call assert_match('^\[tabpage\] .*/y$', trim(execute('verbose pwd')))
  eval '..'->chdir()
  call assert_equal('Xdir', fnamemodify(getcwd(1, 2), ':t'))
  call assert_equal('Xdir', fnamemodify(getcwd(2, 2), ':t'))
  call assert_equal('z', fnamemodify(getcwd(3, 2), ':t'))
  call assert_equal('testdir', fnamemodify(getcwd(1, 1), ':t'))
  3wincmd w
  call assert_match('^\[window\] .*/z$', trim(execute('verbose pwd')))
  call chdir('..')
  call assert_equal('Xdir', fnamemodify(getcwd(1, 2), ':t'))
  call assert_equal('Xdir', fnamemodify(getcwd(2, 2), ':t'))
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
  call delete('Xdir', 'rf')
endfunc

" Test for changing to the previous directory '-'
func Test_prev_dir()
  let topdir = getcwd()
  call mkdir('Xdir/a/b/c', 'p')

  " Create a few tabpages and windows with different directories
  new | only
  tabnew | new
  tabnew
  tabfirst
  cd Xdir
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
  call assert_equal('Xdir', fnamemodify(getcwd(), ':t'))
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
  call assert_equal('Xdir', fnamemodify(getcwd(), ':t'))
  tabnext | wincmd t
  call assert_equal('a', fnamemodify(getcwd(), ':t'))
  wincmd w
  call assert_equal('b', fnamemodify(getcwd(), ':t'))
  tabnext
  call assert_equal('c', fnamemodify(getcwd(), ':t'))

  only | tabonly
  call chdir(topdir)
  call delete('Xdir', 'rf')
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
  call mkdir('XComplDir1', 'p')
  call mkdir('XComplDir2', 'p')
  call writefile([], 'XComplFile')

  for cmd in ['cd', 'chdir', 'lcd', 'lchdir', 'tcd', 'tchdir']
    call feedkeys(':' .. cmd .. " XCompl\<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"' .. cmd .. ' XComplDir1/ XComplDir2/', @:)
  endfor

  call delete('XComplDir1', 'd')
  call delete('XComplDir2', 'd')
  call delete('XComplFile')
endfunc

func Test_cd_unknown_dir()
  call mkdir('Xa')
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
  call delete('Xa', 'rf')
endfunc

func Test_getcwd_actual_dir()
  CheckFunction test_autochdir
  CheckOption autochdir

  let startdir = getcwd()
  call mkdir('Xactual')
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
  call delete('Xactual', 'rf')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
