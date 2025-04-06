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

func Test_expand_env_pathsep()
  let $FOO = './foo'
  call assert_equal('./foo/bar', expand('$FOO/bar'))
  let $FOO = './foo/'
  call assert_equal('./foo/bar', expand('$FOO/bar'))
  let $FOO = 'C:'
  call assert_equal('C:/bar', expand('$FOO/bar'))
  let $FOO = 'C:/'
  call assert_equal('C:/bar', expand('$FOO/bar'))

  unlet $FOO
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

  call assert_equal('make <afile>', expandcmd("make <afile>"))
  call assert_equal('make <amatch>', expandcmd("make <amatch>"))
  call assert_equal('make <abuf>', expandcmd("make <abuf>"))
  enew
  call assert_equal('make %', expandcmd("make %"))
  let $FOO="blue\tsky"
  call setline(1, "$FOO")
  call assert_equal("grep pat blue\tsky", expandcmd('grep pat <cfile>'))

  " Test for expression expansion `=
  let $FOO= "blue"
  call assert_equal("blue sky", expandcmd("`=$FOO .. ' sky'`"))
  let x = expandcmd("`=axbycz`")
  call assert_equal('`=axbycz`', x)
  call assert_fails('let x = expandcmd("`=axbycz`", #{errmsg: 1})', 'E121:')
  let x = expandcmd("`=axbycz`", #{abc: []})
  call assert_equal('`=axbycz`', x)

  " Test for env variable with spaces
  let $FOO= "foo bar baz"
  call assert_equal("e foo bar baz", expandcmd("e $FOO"))

  if has('unix') && executable('bash')
    " test for using the shell to expand a command argument.
    " only bash supports the {..} syntax
    set shell=bash
    let x = expandcmd('{1..4}')
    call assert_equal('{1..4}', x)
    call assert_fails("let x = expandcmd('{1..4}', #{errmsg: v:true})", 'E77:')
    let x = expandcmd('{1..4}', #{error: v:true})
    call assert_equal('{1..4}', x)
    set shell&
  endif

  unlet $FOO
  close!
endfunc

" Test for expanding <sfile>, <slnum> and <sflnum> outside of sourcing a script
func Test_source_sfile()
  let lines =<< trim [SCRIPT]
    :call assert_equal('<sfile>', expandcmd("<sfile>"))
    :call assert_equal('<slnum>', expandcmd("<slnum>"))
    :call assert_equal('<sflnum>', expandcmd("<sflnum>"))
    :call assert_equal('edit <cfile>', expandcmd("edit <cfile>"))
    :call assert_equal('edit #', expandcmd("edit #"))
    :call assert_equal('edit #<2', expandcmd("edit #<2"))
    :call assert_equal('edit <cword>', expandcmd("edit <cword>"))
    :call assert_equal('edit <cexpr>', expandcmd("edit <cexpr>"))
    :call assert_fails('autocmd User MyCmd echo "<sfile>"', 'E498:')
    :
    :call assert_equal('', expand('<script>'))
    :verbose echo expand('<script>')
    :call add(v:errors, v:errmsg)
    :verbose echo expand('<sfile>')
    :call add(v:errors, v:errmsg)
    :call writefile(v:errors, 'Xresult')
    :qall!
  [SCRIPT]
  call writefile(lines, 'Xscript')
  if RunVim([], [], '--clean -s Xscript')
    call assert_equal([
          \ 'E1274: No script file name to substitute for "<script>"',
          \ 'E498: No :source file name to substitute for "<sfile>"'],
          \ readfile('Xresult'))
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

func Test_expand_script_source()
  let lines0 =<< trim [SCRIPT]
    call extend(g:script_level, [expand('<script>:t')])
    so Xscript1
    func F0()
      call extend(g:func_level, [expand('<script>:t')])
    endfunc

    au User * call extend(g:au_level, [expand('<script>:t')])
  [SCRIPT]

  let lines1 =<< trim [SCRIPT]
    call extend(g:script_level, [expand('<script>:t')])
    so Xscript2
    func F1()
      call extend(g:func_level, [expand('<script>:t')])
    endfunc

    au User * call extend(g:au_level, [expand('<script>:t')])
  [SCRIPT]

  let lines2 =<< trim [SCRIPT]
    call extend(g:script_level, [expand('<script>:t')])
    func F2()
      call extend(g:func_level, [expand('<script>:t')])
    endfunc

    au User * call extend(g:au_level, [expand('<script>:t')])
  [SCRIPT]

  call writefile(lines0, 'Xscript0')
  call writefile(lines1, 'Xscript1')
  call writefile(lines2, 'Xscript2')

  " Check the expansion of <script> at different levels.
  let g:script_level = []
  let g:func_level = []
  let g:au_level = []

  so Xscript0
  call F0()
  call F1()
  call F2()
  doautocmd User

  call assert_equal(['Xscript0', 'Xscript1', 'Xscript2'], g:script_level)
  call assert_equal(['Xscript0', 'Xscript1', 'Xscript2'], g:func_level)
  call assert_equal(['Xscript2', 'Xscript1', 'Xscript0'], g:au_level)

  unlet g:script_level g:func_level
  delfunc F0
  delfunc F1
  delfunc F2

  call delete('Xscript0')
  call delete('Xscript1')
  call delete('Xscript2')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
