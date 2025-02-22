" Test findfile() and finddir()

source check.vim
source vim9.vim

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

func Test_findfile_with_suffixesadd()
  let save_path = &path
  let save_dir = getcwd()
  set path=,,
  call mkdir('Xfinddir1', 'pR')
  cd Xfinddir1

  call writefile([], 'foo.c', 'D')
  call writefile([], 'bar.cpp', 'D')
  call writefile([], 'baz.cc', 'D')
  call writefile([], 'foo.o', 'D')
  call writefile([], 'bar.o', 'D')
  call writefile([], 'baz.o', 'D')

  set suffixesadd=.c,.cpp
  call assert_equal('foo.c', findfile('foo'))
  call assert_equal('./foo.c', findfile('./foo'))
  call assert_equal('bar.cpp', findfile('bar'))
  call assert_equal('./bar.cpp', findfile('./bar'))
  call assert_equal('', findfile('baz'))
  call assert_equal('', findfile('./baz'))
  set suffixesadd+=.cc
  call assert_equal('baz.cc', findfile('baz'))
  call assert_equal('./baz.cc', findfile('./baz'))

  set suffixesadd&
  call chdir(save_dir)
  let &path = save_path
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

" Test for 'findfunc'
func Test_findfunc()
  CheckUnix
  call assert_equal('', &findfunc)
  call writefile(['aFile'], 'Xfindfunc1.c', 'D')
  call writefile(['bFile'], 'Xfindfunc2.c', 'D')
  call writefile(['cFile'], 'Xfindfunc3.c', 'D')

  " basic tests
  func FindFuncBasic(pat, cmdcomplete)
    let fnames = ['Xfindfunc1.c', 'Xfindfunc2.c', 'Xfindfunc3.c']
    return fnames->copy()->filter('v:val =~? a:pat')
  endfunc

  set findfunc=FindFuncBasic
  find Xfindfunc3
  call assert_match('Xfindfunc3.c', @%)
  bw!
  2find Xfind
  call assert_match('Xfindfunc2.c', @%)
  bw!
  call assert_fails('4find Xfind', 'E347: No more file "Xfind" found in path')
  call assert_fails('find foobar', 'E345: Can''t find file "foobar" in path')

  sfind Xfindfunc2.c
  call assert_match('Xfindfunc2.c', @%)
  call assert_equal(2, winnr('$'))
  %bw!
  call assert_fails('sfind foobar', 'E345: Can''t find file "foobar" in path')

  tabfind Xfindfunc3.c
  call assert_match('Xfindfunc3.c', @%)
  call assert_equal(2, tabpagenr())
  %bw!
  call assert_fails('tabfind foobar', 'E345: Can''t find file "foobar" in path')

  " Test garbage collection
  call test_garbagecollect_now()
  find Xfindfunc2
  call assert_match('Xfindfunc2.c', @%)
  bw!
  delfunc FindFuncBasic
  call test_garbagecollect_now()
  call assert_fails('find Xfindfunc2', 'E117: Unknown function: FindFuncBasic')

  " Buffer-local option
  func GlobalFindFunc(pat, cmdcomplete)
    return ['global']
  endfunc
  func LocalFindFunc(pat, cmdcomplete)
    return ['local']
  endfunc
  set findfunc=GlobalFindFunc
  new
  setlocal findfunc=LocalFindFunc
  find xxxx
  call assert_equal('local', @%)
  wincmd w
  find xxxx
  call assert_equal('global', @%)
  aboveleft new
  call assert_equal("GlobalFindFunc", &findfunc)
  wincmd k
  aboveleft new
  call assert_equal("GlobalFindFunc", &findfunc)
  %bw!
  delfunc GlobalFindFunc
  delfunc LocalFindFunc

  " Assign an expression
  set findfunc=[]
  call assert_fails('find xxxx', 'E117: Unknown function: []')

  " Error cases

  " Function that doesn't take any arguments
  func FindFuncNoArg()
  endfunc
  set findfunc=FindFuncNoArg
  call assert_fails('find Xfindfunc1.c', 'E118: Too many arguments for function: FindFuncNoArg')
  delfunc FindFuncNoArg

  " Syntax error in the function
  func FindFuncSyntaxError(pat, cmdcomplete)
    return l
  endfunc
  set findfunc=FindFuncSyntaxError
  call assert_fails('find Xfindfunc1.c', 'E121: Undefined variable: l')
  delfunc FindFuncSyntaxError

  " Find function throws an error
  func FindFuncWithThrow(pat, cmdcomplete)
    throw 'find error'
  endfunc
  set findfunc=FindFuncWithThrow
  call assert_fails('find Xfindfunc1.c', 'find error')
  delfunc FindFuncWithThrow

  " Try using a null function
  "call assert_fails('let &findfunc = test_null_function()', 'E129: Function name required')

  " Try to create a new window from the find function
  func FindFuncNewWindow(pat, cmdexpand)
    new
    return ["foo"]
  endfunc
  set findfunc=FindFuncNewWindow
  call assert_fails('find Xfindfunc1.c', 'E565: Not allowed to change text or change window')
  delfunc FindFuncNewWindow

  " Try to modify the current buffer from the find function
  func FindFuncModifyBuf(pat, cmdexpand)
    call setline(1, ['abc'])
    return ["foo"]
  endfunc
  set findfunc=FindFuncModifyBuf
  call assert_fails('find Xfindfunc1.c', 'E565: Not allowed to change text or change window')
  delfunc FindFuncModifyBuf

  " Return the wrong type from the function
  func FindFuncWrongRet(pat, cmdexpand)
    return 'foo'
  endfunc
  set findfunc=FindFuncWrongRet
  call assert_fails('find Xfindfunc1.c', "E1514: 'findfunc' did not return a List type")
  delfunc FindFuncWrongRet

  set findfunc&
endfunc

" Test for using a script-local function for 'findfunc'
func Test_findfunc_scriptlocal_func()
  func! s:FindFuncScript(pat, cmdexpand)
    let g:FindFuncArg = a:pat
    return ['xxx']
  endfunc

  set findfunc=s:FindFuncScript
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &findfunc)
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &g:findfunc)
  new | only
  let g:FindFuncArg = ''
  find abc
  call assert_equal('abc', g:FindFuncArg)
  bw!

  set findfunc=<SID>FindFuncScript
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &findfunc)
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &g:findfunc)
  new | only
  let g:FindFuncArg = ''
  find abc
  call assert_equal('abc', g:FindFuncArg)
  bw!

  let &findfunc = 's:FindFuncScript'
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &g:findfunc)
  new | only
  let g:FindFuncArg = ''
  find abc
  call assert_equal('abc', g:FindFuncArg)
  bw!

  let &findfunc = '<SID>FindFuncScript'
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &g:findfunc)
  new | only
  let g:FindFuncArg = ''
  find abc
  call assert_equal('abc', g:FindFuncArg)
  bw!

  set findfunc=
  setglobal findfunc=s:FindFuncScript
  setlocal findfunc=
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &findfunc)
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &g:findfunc)
  call assert_equal('', &l:findfunc)
  new | only
  let g:FindFuncArg = ''
  find abc
  call assert_equal('abc', g:FindFuncArg)
  bw!

  new | only
  set findfunc=
  setglobal findfunc=
  setlocal findfunc=s:FindFuncScript
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &findfunc)
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &l:findfunc)
  call assert_equal('', &g:findfunc)
  let g:FindFuncArg = ''
  find abc
  call assert_equal('abc', g:FindFuncArg)
  bw!

  new | only
  set findfunc=
  setlocal findfunc=NoSuchFunc
  setglobal findfunc=s:FindFuncScript
  call assert_equal('NoSuchFunc', &findfunc)
  call assert_equal('NoSuchFunc', &l:findfunc)
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &g:findfunc)
  new | only
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &findfunc)
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &g:findfunc)
  call assert_equal('', &l:findfunc)
  let g:FindFuncArg = ''
  find abc
  call assert_equal('abc', g:FindFuncArg)
  bw!

  new | only
  set findfunc=
  setlocal findfunc=NoSuchFunc
  set findfunc=s:FindFuncScript
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &findfunc)
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &g:findfunc)
  call assert_equal('', &l:findfunc)
  let g:FindFuncArg = ''
  find abc
  call assert_equal('abc', g:FindFuncArg)
  new | only
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &findfunc)
  call assert_equal(expand('<SID>') .. 'FindFuncScript', &g:findfunc)
  call assert_equal('', &l:findfunc)
  let g:FindFuncArg = ''
  find abc
  call assert_equal('abc', g:FindFuncArg)
  bw!

  set findfunc=
  delfunc s:FindFuncScript
endfunc

" Test for expanding the argument to the :find command using 'findfunc'
func Test_findfunc_expand_arg()
  let s:fnames = ['Xfindfunc1.c', 'Xfindfunc2.c', 'Xfindfunc3.c']

  " 'findfunc' that accepts a regular expression
  func FindFuncRegexp(pat, cmdcomplete)
    return s:fnames->copy()->filter('v:val =~? a:pat')
  endfunc

  " 'findfunc' that accepts a glob
  func FindFuncGlob(pat_arg, cmdcomplete)
    let pat = glob2regpat(a:cmdcomplete ? $'*{a:pat_arg}*' : a:pat_arg)
    return s:fnames->copy()->filter('v:val =~? pat')
  endfunc

  for regexp in [v:true, v:false]
    let &findfunc = regexp ? 'FindFuncRegexp' : 'FindFuncGlob'

    call feedkeys(":find \<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindfunc1.c', @:)

    call feedkeys(":find Xfind\<Tab>\<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindfunc2.c', @:)

    call assert_equal(s:fnames, getcompletion('find ', 'cmdline'))
    call assert_equal(s:fnames, getcompletion('find Xfind', 'cmdline'))

    let pat = regexp ? 'X.*1\.c' : 'X*1.c'
    call feedkeys($":find {pat}\<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindfunc1.c', @:)
    call assert_equal(['Xfindfunc1.c'], getcompletion($'find {pat}', 'cmdline'))

    call feedkeys(":find 3\<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindfunc3.c', @:)
    call assert_equal(['Xfindfunc3.c'], getcompletion($'find 3', 'cmdline'))

    call feedkeys(":find Xfind\<C-A>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find Xfindfunc1.c Xfindfunc2.c Xfindfunc3.c', @:)

    call feedkeys(":find abc\<Tab>\<C-B>\"\<CR>", "xt")
    call assert_equal('"find abc', @:)
    call assert_equal([], getcompletion('find abc', 'cmdline'))
  endfor

  set findfunc&
  delfunc! FindFuncRegexp
  delfunc! FindFuncGlob
  unlet s:fnames
endfunc

" Test for different ways of setting the 'findfunc' option
func Test_findfunc_callback()
  new
  func FindFunc1(pat, cmdexpand)
    let g:FindFunc1Args = [a:pat, a:cmdexpand]
    return ['findfunc1']
  endfunc

  let lines =<< trim END
    #" Test for using a function name
    LET &findfunc = 'g:FindFunc1'
    LET g:FindFunc1Args = []
    find abc1
    call assert_equal(['abc1', v:false], g:FindFunc1Args)

    #" Test for using a function()
    set findfunc=function('g:FindFunc1')
    LET g:FindFunc1Args = []
    find abc2
    call assert_equal(['abc2', v:false], g:FindFunc1Args)

    #" Using a funcref variable to set 'findfunc'
    VAR Fn = function('g:FindFunc1')
    LET &findfunc = Fn
    LET g:FindFunc1Args = []
    find abc3
    call assert_equal(['abc3', v:false], g:FindFunc1Args)

    #" Using a string(funcref_variable) to set 'findfunc'
    LET Fn = function('g:FindFunc1')
    LET &findfunc = string(Fn)
    LET g:FindFunc1Args = []
    find abc4
    call assert_equal(['abc4', v:false], g:FindFunc1Args)

    #" Test for using a funcref()
    set findfunc=funcref('g:FindFunc1')
    LET g:FindFunc1Args = []
    find abc5
    call assert_equal(['abc5', v:false], g:FindFunc1Args)

    #" Using a funcref variable to set 'findfunc'
    LET Fn = funcref('g:FindFunc1')
    LET &findfunc = Fn
    LET g:FindFunc1Args = []
    find abc6
    call assert_equal(['abc6', v:false], g:FindFunc1Args)

    #" Using a string(funcref_variable) to set 'findfunc'
    LET Fn = funcref('g:FindFunc1')
    LET &findfunc = string(Fn)
    LET g:FindFunc1Args = []
    find abc7
    call assert_equal(['abc7', v:false], g:FindFunc1Args)

    #" Test for using a lambda function using set
    VAR optval = "LSTART pat, cmdexpand LMIDDLE FindFunc1(pat, cmdexpand) LEND"
    LET optval = substitute(optval, ' ', '\\ ', 'g')
    exe "set findfunc=" .. optval
    LET g:FindFunc1Args = []
    find abc8
    call assert_equal(['abc8', v:false], g:FindFunc1Args)

    #" Test for using a lambda function using LET
    LET &findfunc = LSTART pat, _ LMIDDLE FindFunc1(pat, v:false) LEND
    LET g:FindFunc1Args = []
    find abc9
    call assert_equal(['abc9', v:false], g:FindFunc1Args)

    #" Set 'findfunc' to a string(lambda expression)
    LET &findfunc = 'LSTART pat, _ LMIDDLE FindFunc1(pat, v:false) LEND'
    LET g:FindFunc1Args = []
    find abc10
    call assert_equal(['abc10', v:false], g:FindFunc1Args)

    #" Set 'findfunc' to a variable with a lambda expression
    VAR Lambda = LSTART pat, _ LMIDDLE FindFunc1(pat, v:false) LEND
    LET &findfunc = Lambda
    LET g:FindFunc1Args = []
    find abc11
    call assert_equal(['abc11', v:false], g:FindFunc1Args)

    #" Set 'findfunc' to a string(variable with a lambda expression)
    LET Lambda = LSTART pat, _ LMIDDLE FindFunc1(pat, v:false) LEND
    LET &findfunc = string(Lambda)
    LET g:FindFunc1Args = []
    find abc12
    call assert_equal(['abc12', v:false], g:FindFunc1Args)

    #" Try to use 'findfunc' after the function is deleted
    func g:TmpFindFunc(pat, cmdexpand)
      let g:TmpFindFunc1Args = [a:pat, a:cmdexpand]
    endfunc
    LET &findfunc = function('g:TmpFindFunc')
    delfunc g:TmpFindFunc
    call test_garbagecollect_now()
    LET g:TmpFindFunc1Args = []
    call assert_fails('find abc13', 'E117:')
    call assert_equal([], g:TmpFindFunc1Args)

    #" Try to use a function with three arguments for 'findfunc'
    func g:TmpFindFunc2(x, y, z)
      let g:TmpFindFunc2Args = [a:x, a:y, a:z]
    endfunc
    set findfunc=TmpFindFunc2
    LET g:TmpFindFunc2Args = []
    call assert_fails('find abc14', 'E119:')
    call assert_equal([], g:TmpFindFunc2Args)
    delfunc TmpFindFunc2

    #" Try to use a function with zero arguments for 'findfunc'
    func g:TmpFindFunc3()
      let g:TmpFindFunc3Called = v:true
    endfunc
    set findfunc=TmpFindFunc3
    LET g:TmpFindFunc3Called = v:false
    call assert_fails('find abc15', 'E118:')
    call assert_equal(v:false, g:TmpFindFunc3Called)
    delfunc TmpFindFunc3

    #" Try to use a lambda function with three arguments for 'findfunc'
    LET &findfunc = LSTART a, b, c LMIDDLE FindFunc1(a, v:false) LEND
    LET g:FindFunc1Args = []
    call assert_fails('find abc16', 'E119:')
    call assert_equal([], g:FindFunc1Args)

    #" Test for clearing the 'findfunc' option
    set findfunc=''
    set findfunc&
    call assert_fails("set findfunc=function('abc')", "E700:")
    call assert_fails("set findfunc=funcref('abc')", "E700:")

    #" set 'findfunc' to a non-existing function
    LET &findfunc = function('g:FindFunc1')
    call assert_fails("set findfunc=function('NonExistingFunc')", 'E700:')
    call assert_fails("LET &findfunc = function('NonExistingFunc')", 'E700:')
    LET g:FindFunc1Args = []
    find abc17
    call assert_equal(['abc17', v:false], g:FindFunc1Args)
  END
  call CheckTransLegacySuccess(lines)

  " Test for using a script-local function name
  func s:FindFunc2(pat, cmdexpand)
    let g:FindFunc2Args = [a:pat, a:cmdexpand]
    return ['findfunc2']
  endfunc
  set findfunc=s:FindFunc2
  let g:FindFunc2Args = []
  find abc18
  call assert_equal(['abc18', v:false], g:FindFunc2Args)

  let &findfunc = 's:FindFunc2'
  let g:FindFunc2Args = []
  find abc19
  call assert_equal(['abc19', v:false], g:FindFunc2Args)
  delfunc s:FindFunc2

  " Using Vim9 lambda expression in legacy context should fail
  set findfunc=(pat,\ cmdexpand)\ =>\ FindFunc1(pat,\ v:false)
  let g:FindFunc1Args = []
  call assert_fails('find abc20', 'E117:')
  call assert_equal([], g:FindFunc1Args)

  " set 'findfunc' to a partial with dict.
  func SetFindFunc()
    let operator = {'execute': function('FindFuncExecute')}
    let &findfunc = operator.execute
  endfunc
  func FindFuncExecute(pat, cmdexpand) dict
    return ['findfuncexecute']
  endfunc
  call SetFindFunc()
  call test_garbagecollect_now()
  set findfunc=
  delfunc SetFindFunc
  delfunc FindFuncExecute

  func FindFunc2(pat, cmdexpand)
    let g:FindFunc2Args = [a:pat, a:cmdexpand]
    return ['findfunc2']
  endfunc

  " Vim9 tests
  let lines =<< trim END
    vim9script

    def g:Vim9findFunc(pat: string, cmdexpand: bool): list<string>
      g:FindFunc1Args = [pat, cmdexpand]
      return ['vim9findfunc']
    enddef

    # Test for using a def function with findfunc
    set findfunc=function('g:Vim9findFunc')
    g:FindFunc1Args = []
    find abc21
    assert_equal(['abc21', false], g:FindFunc1Args)

    # Test for using a global function name
    &findfunc = g:FindFunc2
    g:FindFunc2Args = []
    find abc22
    assert_equal(['abc22', false], g:FindFunc2Args)
    bw!

    # Test for using a script-local function name
    def LocalFindFunc(pat: string, cmdexpand: bool): list<string>
      g:LocalFindFuncArgs = [pat, cmdexpand]
      return ['localfindfunc']
    enddef
    &findfunc = LocalFindFunc
    g:LocalFindFuncArgs = []
    find abc23
    assert_equal(['abc23', false], g:LocalFindFuncArgs)
    bw!
  END
  call CheckScriptSuccess(lines)

  " setting 'findfunc' to a script local function outside of a script context
  " should fail
  let cleanup =<< trim END
    call writefile([execute('messages')], 'Xtest.out')
    qall
  END
  call writefile(cleanup, 'Xverify.vim', 'D')
  call RunVim([], [], "-c \"set findfunc=s:abc\" -S Xverify.vim")
  call assert_match('E81: Using <SID> not in a', readfile('Xtest.out')[0])
  call delete('Xtest.out')

  " cleanup
  set findfunc&
  delfunc FindFunc1
  delfunc FindFunc2
  unlet g:FindFunc1Args g:FindFunc2Args
  %bw!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
