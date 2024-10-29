" Test findfile() and finddir()

source check.vim

let s:files = [ 'Xfinddir1/foo',
      \         'Xfinddir1/bar',
      \         'Xfinddir1/Xdir2/foo',
      \         'Xfinddir1/Xdir2/foobar',
      \         'Xfinddir1/Xdir2/Xdir3/bar',
      \         'Xfinddir1/Xdir2/Xdir3/barfoo' ]

func CreateFiles()
  call mkdir('Xfinddir1/Xdir2/Xdir3/Xdir2', 'p')
  for f in s:files
    call writefile([], f)
  endfor
endfunc

func CleanFiles()
  " Safer to delete each file even if it's more verbose
  " than doing a recursive delete('Xfinddir1', 'rf').
  for f in s:files
    call delete(f)
  endfor

  call delete('Xfinddir1/Xdir2/Xdir3/Xdir2', 'd')
  call delete('Xfinddir1/Xdir2/Xdir3', 'd')
  call delete('Xfinddir1/Xdir2', 'd')
  call delete('Xfinddir1', 'd')
endfunc

" Test findfile({name} [, {path} [, {count}]])
func Test_findfile()
  let save_path = &path
  let save_shellslash = &shellslash
  let save_dir = getcwd()
  set shellslash
  call CreateFiles()
  cd Xfinddir1
  e Xdir2/foo

  " With ,, in path, findfile() searches in current directory.
  set path=,,
  call assert_equal('foo', findfile('foo'))
  call assert_equal('bar', findfile('bar'))
  call assert_equal('',    findfile('foobar'))

  " Directories should not be found (finddir() finds them).
  call assert_equal('', findfile('Xdir2'))

  " With . in 'path', findfile() searches relatively to current file.
  set path=.
  call assert_equal('Xdir2/foo',    findfile('foo'))
  call assert_equal('',             findfile('bar'))
  call assert_equal('Xdir2/foobar', 'foobar'->findfile())

  " Empty {path} 2nd argument is the same as no 2nd argument.
  call assert_equal('Xdir2/foo', findfile('foo', ''))
  call assert_equal('',          findfile('bar', ''))

  " Test with *
  call assert_equal('Xdir2/foo',       findfile('foo', '*'))
  call assert_equal('',                findfile('bar', '*'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', '*/*'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', 'Xdir2/*'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', 'Xdir*/Xdir3'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', '*2/*3'))

  " Test with **
  call assert_equal('bar',             findfile('bar', '**'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', '**/Xdir3'))
  call assert_equal('Xdir2/Xdir3/bar', findfile('bar', 'Xdir2/**'))

  call assert_equal('Xdir2/Xdir3/barfoo', findfile('barfoo', '**2'))
  call assert_equal('',                   findfile('barfoo', '**1'))
  call assert_equal('Xdir2/foobar',       findfile('foobar', '**1'))

  " Test with {count} 3rd argument.
  call assert_equal('bar',                      findfile('bar', '**', 0))
  call assert_equal('bar',                      findfile('bar', '**', 1))
  call assert_equal('Xdir2/Xdir3/bar',          findfile('bar', '**', 2))
  call assert_equal('',                         findfile('bar', '**', 3))
  call assert_equal(['bar', 'Xdir2/Xdir3/bar'], findfile('bar', '**', -1))

  " Test upwards search.
  cd Xdir2/Xdir3
  call assert_equal('bar',                findfile('bar', ';'))
  call assert_match('.*/Xfinddir1/Xdir2/foo', findfile('foo', ';'))
  call assert_match('.*/Xfinddir1/Xdir2/foo', findfile('foo', ';', 1))
  call assert_match('.*/Xfinddir1/foo',       findfile('foo', ';', 2))
  call assert_match('.*/Xfinddir1/foo',       findfile('foo', ';', 2))
  call assert_match('.*/Xfinddir1/Xdir2/foo', findfile('foo', 'Xdir2;', 1))
  call assert_equal('',                   findfile('foo', 'Xdir2;', 2))

  " List l should have at least 2 values (possibly more if foo file
  " happens to be found upwards above Xfinddir1).
  let l = findfile('foo', ';', -1)
  call assert_match('.*/Xfinddir1/Xdir2/foo', l[0])
  call assert_match('.*/Xfinddir1/foo',       l[1])

  " Test upwards search with stop-directory.
  cd Xdir2
  let l = findfile('bar', ';' . save_dir . '/Xfinddir1/Xdir2/Xdir3/', -1)
  call assert_equal(1, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  let l = findfile('bar', ';' . save_dir . '/Xfinddir1/Xdir2/Xdir3', -1)
  call assert_equal(1, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  let l = findfile('bar', ';../', -1)
  call assert_equal(1, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  let l = findfile('bar', ';..', -1)
  call assert_equal(1, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])

  let l = findfile('bar', ';' . save_dir . '/Xfinddir1/Xdir2/', -1)
  call assert_equal(1, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  let l = findfile('bar', ';' . save_dir . '/Xfinddir1/Xdir2', -1)
  call assert_equal(1, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  let l = findfile('bar', ';../../', -1)
  call assert_equal(1, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  let l = findfile('bar', ';../..', -1)
  call assert_equal(1, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])

  let l = findfile('bar', ';' . save_dir . '/Xfinddir1/', -1)
  call assert_equal(2, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  call assert_match('.*/Xfinddir1/bar',             l[1])
  let l = findfile('bar', ';' . save_dir . '/Xfinddir1', -1)
  call assert_equal(2, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  call assert_match('.*/Xfinddir1/bar',             l[1])
  let l = findfile('bar', ';../../../', -1)
  call assert_equal(2, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  call assert_match('.*/Xfinddir1/bar',             l[1])
  let l = findfile('bar', ';../../..', -1)
  call assert_equal(2, len(l))
  call assert_match('.*/Xfinddir1/Xdir2/Xdir3/bar', l[0])
  call assert_match('.*/Xfinddir1/bar',             l[1])

  " Test combined downwards and upwards search from Xdir2/.
  cd ../..
  call assert_equal('Xdir3/bar',    findfile('bar', '**;', 1))
  call assert_match('.*/Xfinddir1/bar', findfile('bar', '**;', 2))

  bwipe!
  call chdir(save_dir)
  call CleanFiles()
  let &path = save_path
  let &shellslash = save_shellslash
endfunc

func Test_findfile_error()
  call assert_fails('call findfile([])', 'E730:')
  call assert_fails('call findfile("x", [])', 'E730:')
  call assert_fails('call findfile("x", "", [])', 'E745:')
  call assert_fails('call findfile("x", "**x")', 'E343:')
  call assert_fails('call findfile("x", repeat("x", 5000))', 'E854:')
endfunc

" Test finddir({name} [, {path} [, {count}]])
func Test_finddir()
  let save_path = &path
  let save_shellslash = &shellslash
  let save_dir = getcwd()
  set path=,,
  set shellslash
  call CreateFiles()
  cd Xfinddir1

  call assert_equal('Xdir2', finddir('Xdir2'))
  call assert_equal('',      'Xdir3'->finddir())

  " Files should not be found (findfile() finds them).
  call assert_equal('', finddir('foo'))

  call assert_equal('Xdir2',       finddir('Xdir2', '**'))
  call assert_equal('Xdir2/Xdir3', finddir('Xdir3', '**'))

  call assert_equal('Xdir2',               finddir('Xdir2', '**', 1))
  call assert_equal('Xdir2/Xdir3/Xdir2',   finddir('Xdir2', '**', 2))
  call assert_equal(['Xdir2',
        \            'Xdir2/Xdir3/Xdir2'], finddir('Xdir2', '**', -1))

  call assert_equal('Xdir2',       finddir('Xdir2', '**1'))
  call assert_equal('Xdir2',       finddir('Xdir2', '**0'))
  call assert_equal('Xdir2/Xdir3', finddir('Xdir3', '**1'))
  call assert_equal('',            finddir('Xdir3', '**0'))

  " Test upwards dir search.
  cd Xdir2/Xdir3
  call assert_match('.*/Xfinddir1', finddir('Xfinddir1', ';'))

  " Test upwards search with stop-directory.
  call assert_match('.*/Xfinddir1', finddir('Xfinddir1', ';' . save_dir . '/'))
  call assert_equal('',         finddir('Xfinddir1', ';' . save_dir . '/Xfinddir1/'))

  " Test combined downwards and upwards dir search from Xdir2/.
  cd ..
  call assert_match('.*/Xfinddir1',       finddir('Xfinddir1', '**;', 1))
  call assert_equal('Xdir3/Xdir2',    finddir('Xdir2', '**;', 1))
  call assert_match('.*/Xfinddir1/Xdir2', finddir('Xdir2', '**;', 2))
  call assert_equal('Xdir3',          finddir('Xdir3', '**;', 1))

  call chdir(save_dir)
  call CleanFiles()
  let &path = save_path
  let &shellslash = save_shellslash
endfunc

func Test_finddir_error()
  call assert_fails('call finddir([])', 'E730:')
  call assert_fails('call finddir("x", [])', 'E730:')
  call assert_fails('call finddir("x", "", [])', 'E745:')
  call assert_fails('call finddir("x", "**x")', 'E343:')
  call assert_fails('call finddir("x", repeat("x", 5000))', 'E854:')
endfunc

" Test for the :find, :sfind and :tabfind commands
func Test_find_cmd()
  new
  let save_path = &path
  let save_dir = getcwd()
  set path=.,./**/*
  call CreateFiles()
  cd Xfinddir1

  " Test for :find
  find foo
  call assert_equal('foo', expand('%:.'))
  2find foo
  call assert_equal('Xdir2/foo', expand('%:.'))
  call assert_fails('3find foo', 'E347:')

  " Test for :sfind
  enew
  sfind barfoo
  call assert_equal('Xdir2/Xdir3/barfoo', expand('%:.'))
  call assert_equal(3, winnr('$'))
  close
  call assert_fails('sfind baz', 'E345:')
  call assert_equal(2, winnr('$'))

  " Test for :tabfind
  enew
  tabfind foobar
  call assert_equal('Xdir2/foobar', expand('%:.'))
  call assert_equal(2, tabpagenr('$'))
  tabclose
  call assert_fails('tabfind baz', 'E345:')
  call assert_equal(1, tabpagenr('$'))

  call chdir(save_dir)
  exe 'cd ' . save_dir
  call CleanFiles()
  let &path = save_path
  close

  call assert_fails('find', 'E471:')
  call assert_fails('sfind', 'E471:')
  call assert_fails('tabfind', 'E471:')
endfunc

func Test_find_non_existing_path()
  new
  let save_path = &path
  let save_dir = getcwd()
  call mkdir('dir1/dir2', 'p')
  call writefile([], 'dir1/file.txt')
  call writefile([], 'dir1/dir2/base.txt')
  call chdir('dir1/dir2')
  e base.txt
  set path=../include

  call assert_fails(':find file.txt', 'E345:')

  call chdir(save_dir)
  bw!
  call delete('dir1/dir2/base.txt', 'rf')
  call delete('dir1/dir2', 'rf')
  call delete('dir1/file.txt', 'rf')
  call delete('dir1', 'rf')
  let &path = save_path
endfunc

" Test for 'findexpr'
func Test_findexpr()
  CheckUnix
  call assert_equal('', &findexpr)
  call writefile(['aFile'], 'Xfindexpr1.c', 'D')
  call writefile(['bFile'], 'Xfindexpr2.c', 'D')
  call writefile(['cFile'], 'Xfindexpr3.c', 'D')

  " basic tests
  func FindExpr1()
    let fnames = ['Xfindexpr1.c', 'Xfindexpr2.c', 'Xfindexpr3.c']
    return fnames->copy()->filter('v:val =~? v:fname')
  endfunc

  set findexpr=FindExpr1()
  find Xfindexpr3
  call assert_match('Xfindexpr3.c', @%)
  bw!
  2find Xfind
  call assert_match('Xfindexpr2.c', @%)
  bw!
  call assert_fails('4find Xfind', 'E347: No more file "Xfind" found in path')
  call assert_fails('find foobar', 'E345: Can''t find file "foobar" in path')

  sfind Xfindexpr2.c
  call assert_match('Xfindexpr2.c', @%)
  call assert_equal(2, winnr('$'))
  %bw!
  call assert_fails('sfind foobar', 'E345: Can''t find file "foobar" in path')

  tabfind Xfindexpr3.c
  call assert_match('Xfindexpr3.c', @%)
  call assert_equal(2, tabpagenr())
  %bw!
  call assert_fails('tabfind foobar', 'E345: Can''t find file "foobar" in path')

  " Buffer-local option
  set findexpr=['abc']
  new
  setlocal findexpr=['def']
  find xxxx
  call assert_equal('def', @%)
  wincmd w
  find xxxx
  call assert_equal('abc', @%)
  aboveleft new
  call assert_equal("['abc']", &findexpr)
  wincmd k
  aboveleft new
  call assert_equal("['abc']", &findexpr)
  %bw!

  " Empty list
  set findexpr=[]
  call assert_fails('find xxxx', 'E345: Can''t find file "xxxx" in path')

  " Error cases

  " Syntax error in the expression
  set findexpr=FindExpr1{}
  call assert_fails('find Xfindexpr1.c', 'E15: Invalid expression')

  " Find expression throws an error
  func FindExpr2()
    throw 'find error'
  endfunc
  set findexpr=FindExpr2()
  call assert_fails('find Xfindexpr1.c', 'find error')

  " Try using a null List as the expression
  set findexpr=v:_null_list
  call assert_fails('find Xfindexpr1.c', 'E345: Can''t find file "Xfindexpr1.c" in path')

  " Try to create a new window from the find expression
  func FindExpr3()
    new
    return ["foo"]
  endfunc
  set findexpr=FindExpr3()
  call assert_fails('find Xfindexpr1.c', 'E565: Not allowed to change text or change window')

  " Try to modify the current buffer from the find expression
  func FindExpr4()
    call setline(1, ['abc'])
    return ["foo"]
  endfunc
  set findexpr=FindExpr4()
  call assert_fails('find Xfindexpr1.c', 'E565: Not allowed to change text or change window')

  " Expression returning a string
  set findexpr='abc'
  call assert_fails('find Xfindexpr1.c', "E1514: 'findexpr' did not return a List type")

  set findexpr&
  delfunc! FindExpr1
  delfunc! FindExpr2
  delfunc! FindExpr3
  delfunc! FindExpr4
endfunc

" Test for using a script-local function for 'findexpr'
func Test_findexpr_scriptlocal_func()
  func! s:FindExprScript()
    let g:FindExprArg = v:fname
    return ['xxx']
  endfunc

  set findexpr=s:FindExprScript()
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &findexpr)
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &g:findexpr)
  new | only
  let g:FindExprArg = ''
  find abc
  call assert_equal('abc', g:FindExprArg)
  bw!

  set findexpr=<SID>FindExprScript()
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &findexpr)
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &g:findexpr)
  new | only
  let g:FindExprArg = ''
  find abc
  call assert_equal('abc', g:FindExprArg)
  bw!

  let &findexpr = 's:FindExprScript()'
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &g:findexpr)
  new | only
  let g:FindExprArg = ''
  find abc
  call assert_equal('abc', g:FindExprArg)
  bw!

  let &findexpr = '<SID>FindExprScript()'
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &g:findexpr)
  new | only
  let g:FindExprArg = ''
  find abc
  call assert_equal('abc', g:FindExprArg)
  bw!

  set findexpr=
  setglobal findexpr=s:FindExprScript()
  setlocal findexpr=
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &findexpr)
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &g:findexpr)
  call assert_equal('', &l:findexpr)
  new | only
  let g:FindExprArg = ''
  find abc
  call assert_equal('abc', g:FindExprArg)
  bw!

  new | only
  set findexpr=
  setglobal findexpr=
  setlocal findexpr=s:FindExprScript()
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &findexpr)
  call assert_equal(expand('<SID>') .. 'FindExprScript()', &l:findexpr)
  call assert_equal('', &g:findexpr)
  let g:FindExprArg = ''
  find abc
  call assert_equal('abc', g:FindExprArg)
  bw!

  set findexpr=
  delfunc s:FindExprScript
endfunc

" Test for expanding the argument to the :find command using 'findexpr'
func Test_findexpr_expand_arg()
  let s:fnames = ['Xfindexpr1.c', 'Xfindexpr2.c', 'Xfindexpr3.c']

  " 'findexpr' that accepts a regular expression
  func FindExprRegexp()
    return s:fnames->copy()->filter('v:val =~? v:fname')
  endfunc

  " 'findexpr' that accepts a glob
  func FindExprGlob()
    let pat = glob2regpat(v:cmdcomplete ? $'*{v:fname}*' : v:fname)
    return s:fnames->copy()->filter('v:val =~? pat')
  endfunc

  for regexp in [v:true, v:false]
    let &findexpr = regexp ? 'FindExprRegexp()' : 'FindExprGlob()'

    call feedkeys(":find \<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindexpr1.c', @:)

    call feedkeys(":find Xfind\<Tab>\<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindexpr2.c', @:)

    call assert_equal(s:fnames, getcompletion('find ', 'cmdline'))
    call assert_equal(s:fnames, getcompletion('find Xfind', 'cmdline'))

    let pat = regexp ? 'X.*1\.c' : 'X*1.c'
    call feedkeys($":find {pat}\<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindexpr1.c', @:)
    call assert_equal(['Xfindexpr1.c'], getcompletion($'find {pat}', 'cmdline'))

    call feedkeys(":find 3\<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindexpr3.c', @:)
    call assert_equal(['Xfindexpr3.c'], getcompletion($'find 3', 'cmdline'))

    call feedkeys(":find Xfind\<C-A>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindexpr1.c Xfindexpr2.c Xfindexpr3.c', @:)

    call feedkeys(":find abc\<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find abc', @:)
    call assert_equal([], getcompletion('find abc', 'cmdline'))
  endfor

  set findexpr&
  delfunc! FindExprRegexp
  delfunc! FindExprGlob
  unlet s:fnames
endfunc

" vim: shiftwidth=2 sts=2 expandtab
