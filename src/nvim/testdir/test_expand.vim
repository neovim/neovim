" Test for expanding file names

source shared.vim
source check.vim

func Test_with_directories()
  call mkdir('Xdir1')
  call mkdir('Xdir2')
  call mkdir('Xdir3')
  cd Xdir3
  call mkdir('Xdir4')
  cd ..

  split Xdir1/file
  call setline(1, ['a', 'b'])
  w
  w Xdir3/Xdir4/file
  close

  next Xdir?/*/file
  call assert_equal('Xdir3/Xdir4/file', expand('%'))
  if has('unix')
    next! Xdir?/*/nofile
    call assert_equal('Xdir?/*/nofile', expand('%'))
  endif
  " Edit another file, on MS-Windows the swap file would be in use and can't
  " be deleted.
  edit foo

  call assert_equal(0, delete('Xdir1', 'rf'))
  call assert_equal(0, delete('Xdir2', 'rf'))
  call assert_equal(0, delete('Xdir3', 'rf'))
endfunc

func Test_with_tilde()
  let dir = getcwd()
  call mkdir('Xdir ~ dir')
  call assert_true(isdirectory('Xdir ~ dir'))
  cd Xdir\ ~\ dir
  call assert_true(getcwd() =~ 'Xdir \~ dir')
  call chdir(dir)
  call delete('Xdir ~ dir', 'd')
  call assert_false(isdirectory('Xdir ~ dir'))
endfunc

func Test_expand_tilde_filename()
  split ~
  call assert_equal('~', expand('%')) 
  call assert_notequal(expand('%:p'), expand('~/'))
  call assert_match('\~', expand('%:p')) 
  bwipe!
endfunc

func Test_expandcmd()
  let $FOO = 'Test'
  call assert_equal('e x/Test/y', expandcmd('e x/$FOO/y'))
  unlet $FOO

  new
  edit Xfile1
  call assert_equal('e Xfile1', expandcmd('e %'))
  edit Xfile2
  edit Xfile1
  call assert_equal('e Xfile2', 'e #'->expandcmd())
  edit Xfile2
  edit Xfile3
  edit Xfile4
  let bnum = bufnr('Xfile2')
  call assert_equal('e Xfile2', expandcmd('e #' . bnum))
  call setline('.', 'Vim!@#')
  call assert_equal('e Vim', expandcmd('e <cword>'))
  call assert_equal('e Vim!@#', expandcmd('e <cWORD>'))
  enew!
  edit Xfile.java
  call assert_equal('e Xfile.py', expandcmd('e %:r.py'))
  call assert_equal('make abc.java', expandcmd('make abc.%:e'))
  call assert_equal('make Xabc.java', expandcmd('make %:s?file?abc?'))
  edit a1a2a3.rb
  call assert_equal('make b1b2b3.rb a1a2a3 Xfile.o', expandcmd('make %:gs?a?b? %< #<.o'))

  call assert_fails('call expandcmd("make <afile>")', 'E495:')
  call assert_fails('call expandcmd("make <afile>")', 'E495:')
  enew
  call assert_fails('call expandcmd("make %")', 'E499:')
  let $FOO="blue\tsky"
  call setline(1, "$FOO")
  call assert_equal("grep pat blue\tsky", expandcmd('grep pat <cfile>'))

  " Test for expression expansion `=
  let $FOO= "blue"
  call assert_equal("blue sky", expandcmd("`=$FOO .. ' sky'`"))

  " Test for env variable with spaces
  let $FOO= "foo bar baz"
  call assert_equal("e foo bar baz", expandcmd("e $FOO"))

  unlet $FOO
  close!
endfunc

" Test for expanding <sfile>, <slnum> and <sflnum> outside of sourcing a script
func Test_source_sfile()
  let lines =<< trim [SCRIPT]
    :call assert_fails('echo expandcmd("<sfile>")', 'E498:')
    :call assert_fails('echo expandcmd("<slnum>")', 'E842:')
    :call assert_fails('echo expandcmd("<sflnum>")', 'E961:')
    :call assert_fails('call expandcmd("edit <cfile>")', 'E446:')
    :call assert_fails('call expandcmd("edit #")', 'E194:')
    :call assert_fails('call expandcmd("edit #<2")', 'E684:')
    :call assert_fails('call expandcmd("edit <cword>")', 'E348:')
    :call assert_fails('call expandcmd("edit <cexpr>")', 'E348:')
    :call assert_fails('autocmd User MyCmd echo "<sfile>"', 'E498:')
    :call writefile(v:errors, 'Xresult')
    :qall!

  [SCRIPT]
  call writefile(lines, 'Xscript')
  if RunVim([], [], '--clean -s Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xscript')
  call delete('Xresult')
endfunc

" Test for expanding filenames multiple times in a command line
func Test_expand_filename_multicmd()
  edit foo
  call setline(1, 'foo!')
  new
  call setline(1, 'foo!')
  new <cword> | new <cWORD>
  call assert_equal(4, winnr('$'))
  call assert_equal('foo!', bufname(winbufnr(1)))
  call assert_equal('foo', bufname(winbufnr(2)))
  call assert_fails('e %:s/.*//', 'E500:')
  %bwipe!
endfunc

func Test_expandcmd_shell_nonomatch()
  CheckNotMSWindows
  call assert_equal('$*', expandcmd('$*'))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
