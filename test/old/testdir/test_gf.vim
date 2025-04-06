" Test for the gf and gF (goto file) commands

" This is a test if a URL is recognized by "gf", with the cursor before and
" after the "://".  Also test ":\\".
func Test_gf_url()
  enew!
  call append(0, [
      \ "first test for URL://machine.name/tmp/vimtest2a and other text",
      \ "second test for URL://machine.name/tmp/vimtest2b. And other text",
      \ "third test for URL:\\\\machine.name\\vimtest2c and other text",
      \ "fourth test for URL:\\\\machine.name\\tmp\\vimtest2d, and other text",
      \ "fifth test for URL://machine.name/tmp?q=vim&opt=yes and other text",
      \ "sixth test for URL://machine.name:1234?q=vim and other text",
      \ ])
  call cursor(1,1)
  call search("^first")
  call search("tmp")
  call assert_equal("URL://machine.name/tmp/vimtest2a", expand("<cfile>"))
  call search("^second")
  call search("URL")
  call assert_equal("URL://machine.name/tmp/vimtest2b", expand("<cfile>"))
  set isf=@,48-57,/,.,-,_,+,,,$,~,\
  call search("^third")
  call search("name")
  call assert_equal("URL:\\\\machine.name\\vimtest2c", expand("<cfile>"))
  call search("^fourth")
  call search("URL")
  call assert_equal("URL:\\\\machine.name\\tmp\\vimtest2d", expand("<cfile>"))

  call search("^fifth")
  call search("URL")
  call assert_equal("URL://machine.name/tmp?q=vim&opt=yes", expand("<cfile>"))

  call search("^sixth")
  call search("URL")
  call assert_equal("URL://machine.name:1234?q=vim", expand("<cfile>"))

  %d
  call setline(1, "demo://remote_file")
  wincmd f
  call assert_equal('demo://remote_file', @%)
  call assert_equal(2, winnr('$'))
  close!

  set isf&vim
  enew!
endfunc

func Test_gF()
  new
  call setline(1, ['111', '222', '333', '444'])
  w! Xfile
  close
  new
  set isfname-=:
  call setline(1, ['one', 'Xfile:3', 'three'])
  2
  call assert_fails('normal gF', 'E37:')
  call assert_equal(2, getcurpos()[1])
  w! Xfile2
  normal gF
  call assert_equal('Xfile', bufname('%'))
  call assert_equal(3, getcurpos()[1])

  enew!
  call setline(1, ['one', 'the Xfile line 2, and more', 'three'])
  w! Xfile2
  normal 2GfX
  normal gF
  call assert_equal('Xfile', bufname('%'))
  call assert_equal(2, getcurpos()[1])

  " jumping to the file/line with CTRL-W_F
  %bw!
  edit Xfile1
  call setline(1, ['one', 'Xfile:4', 'three'])
  exe "normal 2G\<C-W>F"
  call assert_equal('Xfile', bufname('%'))
  call assert_equal(4, getcurpos()[1])

  set isfname&
  call delete('Xfile')
  call delete('Xfile2')
  %bw!
endfunc

" Test for invoking 'gf' on a ${VAR} variable
func Test_gf()
  set isfname=@,48-57,/,.,-,_,+,,,$,:,~,{,}

  call writefile(["Test for gf command"], "Xtest1")
  if has("unix")
    call writefile(["    ${CDIR}/Xtest1"], "Xtestgf")
  else
    call writefile(["    $TDIR/Xtest1"], "Xtestgf")
  endif
  new Xtestgf
  if has("unix")
    let $CDIR = "."
    /CDIR
  else
    if has("amiga")
      let $TDIR = "/testdir"
    else
      let $TDIR = "."
    endif
    /TDIR
  endif

  normal gf
  call assert_equal('Xtest1', fnamemodify(bufname(''), ":t"))
  close!

  call delete('Xtest1')
  call delete('Xtestgf')
endfunc

func Test_gf_visual()
  call writefile(['one', 'two', 'three', 'four'], "Xtest_gf_visual")
  new
  call setline(1, 'XXXtest_gf_visualXXX')
  set hidden

  " Visually select Xtest_gf_visual and use gf to go to that file
  norm! ttvtXgf
  call assert_equal('Xtest_gf_visual', bufname('%'))

  " if multiple lines are selected, then gf should fail
  call setline(1, ["one", "two"])
  normal VGgf
  call assert_equal('Xtest_gf_visual', @%)

  " following line number is used for gF
  bwipe!
  new
  call setline(1, 'XXXtest_gf_visual:3XXX')
  norm! 0ttvt:gF
  call assert_equal('Xtest_gf_visual', bufname('%'))
  call assert_equal(3, getcurpos()[1])

  " do not include the NUL at the end
  call writefile(['x'], 'X')
  let save_enc = &enc
  " for enc in ['latin1', 'utf-8']
  for enc in ['utf-8']
    exe "set enc=" .. enc
    new
    call setline(1, 'X')
    set nomodified
    exe "normal \<C-V>$gf"
    call assert_equal('X', bufname())
    bwipe!
  endfor
  let &enc = save_enc
  call delete('X')

  " line number in visual area is used for file name
  if has('unix')
    bwipe!
    call writefile([], "Xtest_gf_visual:3")
    new
    call setline(1, 'XXXtest_gf_visual:3XXX')
    norm! 0ttvtXgF
    call assert_equal('Xtest_gf_visual:3', bufname('%'))
  call delete('Xtest_gf_visual:3')
  endif

  bwipe!
  call delete('Xtest_gf_visual')
  set hidden&
endfunc

func Test_gf_error()
  new
  call assert_fails('normal gf', 'E446:')
  call assert_fails('normal gF', 'E446:')
  call setline(1, '/doesnotexist')
  call assert_fails('normal gf', 'E447:')
  call assert_fails('normal gF', 'E447:')
  call assert_fails('normal [f', 'E447:')

  " gf is not allowed when text is locked
  au InsertCharPre <buffer> normal! gF<CR>
  let caught_e565 = 0
  try
    call feedkeys("ix\<esc>", 'xt')
  catch /^Vim\%((\a\+)\)\=:E565/ " catch E565
    let caught_e565 = 1
  endtry
  call assert_equal(1, caught_e565)
  au! InsertCharPre

  bwipe!

  " gf is not allowed when buffer is locked
  new
  augroup Test_gf
    au!
    au OptionSet diff norm! gf
  augroup END
  call setline(1, ['Xfile1', 'line2', 'line3', 'line4'])
  " Nvim does not support test_override()
  " call test_override('starting', 1)
  " call assert_fails('diffthis', 'E788:')
  " call test_override('starting', 0)
  augroup Test_gf
    au!
  augroup END
  bw!
endfunc

" If a file is not found by 'gf', then 'includeexpr' should be used to locate
" the file.
func Test_gf_includeexpr()
  new
  let g:Inc_fname = ''
  func IncFunc()
    let g:Inc_fname = v:fname
    return v:fname
  endfunc
  setlocal includeexpr=IncFunc()
  call setline(1, 'somefile.java')
  call assert_fails('normal gf', 'E447:')
  call assert_equal('somefile.java', g:Inc_fname)
  close!
  delfunc IncFunc
endfunc

" Test for using a script-local function for 'includeexpr'
func Test_includeexpr_scriptlocal_func()
  func! s:IncludeFunc()
    let g:IncludeFname = v:fname
    return ''
  endfunc
  set includeexpr=s:IncludeFunc()
  call assert_equal(expand('<SID>') .. 'IncludeFunc()', &includeexpr)
  call assert_equal(expand('<SID>') .. 'IncludeFunc()', &g:includeexpr)
  new | only
  call setline(1, 'TestFile1')
  let g:IncludeFname = ''
  call assert_fails('normal! gf', 'E447:')
  call assert_equal('TestFile1', g:IncludeFname)
  bw!
  set includeexpr=<SID>IncludeFunc()
  call assert_equal(expand('<SID>') .. 'IncludeFunc()', &includeexpr)
  call assert_equal(expand('<SID>') .. 'IncludeFunc()', &g:includeexpr)
  new | only
  call setline(1, 'TestFile2')
  let g:IncludeFname = ''
  call assert_fails('normal! gf', 'E447:')
  call assert_equal('TestFile2', g:IncludeFname)
  bw!
  setlocal includeexpr=
  setglobal includeexpr=s:IncludeFunc()
  call assert_equal(expand('<SID>') .. 'IncludeFunc()', &g:includeexpr)
  call assert_equal('', &includeexpr)
  new
  call assert_equal(expand('<SID>') .. 'IncludeFunc()', &includeexpr)
  call setline(1, 'TestFile3')
  let g:IncludeFname = ''
  call assert_fails('normal! gf', 'E447:')
  call assert_equal('TestFile3', g:IncludeFname)
  bw!
  setlocal includeexpr=
  setglobal includeexpr=<SID>IncludeFunc()
  call assert_equal(expand('<SID>') .. 'IncludeFunc()', &g:includeexpr)
  call assert_equal('', &includeexpr)
  new
  call assert_equal(expand('<SID>') .. 'IncludeFunc()', &includeexpr)
  call setline(1, 'TestFile4')
  let g:IncludeFname = ''
  call assert_fails('normal! gf', 'E447:')
  call assert_equal('TestFile4', g:IncludeFname)
  bw!
  set includeexpr&
  delfunc s:IncludeFunc
  bw!
endfunc

" Check that expanding directories can handle more than 255 entries.
func Test_gf_subdirs_wildcard()
  let cwd = getcwd()
  let dir = 'Xtestgf_dir'
  call mkdir(dir)
  call chdir(dir)
  for i in range(300)
    call mkdir(i)
    call writefile([], i .. '/' .. i, 'S')
  endfor
  set path=./**

  new | only
  call setline(1, '99')
  w! Xtest1
  normal gf
  call assert_equal('99', fnamemodify(bufname(''), ":t"))

  call chdir(cwd)
  call delete(dir, 'rf')
  set path&
endfunc

" Test for 'switchbuf' with gf and gF commands
func Test_gf_switchbuf()
  call writefile(repeat(["aaa"], 10), "Xtest1", 'D')
  edit Xtest1
  new
  call setline(1, ['Xtest1'])

  " Test for 'useopen'
  set switchbuf=useopen
  call cursor(1, 1)
  exe "normal \<C-W>f"
  call assert_equal([2, 2], [winnr(), winnr('$')])
  close

  " If the file is opened in another tabpage, then it should not be considered
  tabedit Xtest1
  tabfirst
  exe "normal \<C-W>f"
  call assert_equal([1, 2], [winnr(), winnr('$')])
  call assert_equal([1, 2], [tabpagenr(), tabpagenr('$')])
  close

  " Test for 'usetab'
  set switchbuf=usetab
  exe "normal \<C-W>f"
  call assert_equal([1, 1], [winnr(), winnr('$')])
  call assert_equal([2, 2], [tabpagenr(), tabpagenr('$')])
  %bw!

  " Test for CTRL-W_F with 'useopen'
  set isfname-=:
  call setline(1, ['Xtest1:5'])
  set switchbuf=useopen
  split +1 Xtest1
  wincmd b
  exe "normal \<C-W>F"
  call assert_equal([1, 2], [winnr(), winnr('$')])
  call assert_equal(5, line('.'))
  close

  " If the file is opened in another tabpage, then it should not be considered
  tabedit +1 Xtest1
  tabfirst
  exe "normal \<C-W>F"
  call assert_equal([1, 2], [winnr(), winnr('$')])
  call assert_equal(5, line('.'))
  call assert_equal([1, 2], [tabpagenr(), tabpagenr('$')])
  close

  " Test for CTRL_W_F with 'usetab'
  set switchbuf=usetab
  exe "normal \<C-W>F"
  call assert_equal([2, 2], [tabpagenr(), tabpagenr('$')])
  call assert_equal([1, 1], [winnr(), winnr('$')])
  call assert_equal(5, line('.'))

  set switchbuf=
  set isfname&
  %bw!
endfunc

func Test_gf_with_suffixesadd()
  let cwd = getcwd()
  let dir = 'Xtestgf_sua_dir'
  call mkdir(dir, 'R')
  call chdir(dir)

  call writefile([], 'foo.c', 'D')
  call writefile([], 'bar.cpp', 'D')
  call writefile([], 'baz.cc', 'D')
  call writefile([], 'foo.o', 'D')
  call writefile([], 'bar.o', 'D')
  call writefile([], 'baz.o', 'D')

  new
  setlocal path=,, suffixesadd=.c,.cpp
  call setline(1, ['./foo', './bar', './baz'])
  exe "normal! gg\<C-W>f"
  call assert_equal('foo.c', expand('%:t'))
  close
  exe "normal! 2gg\<C-W>f"
  call assert_equal('bar.cpp', expand('%:t'))
  close
  call assert_fails('exe "normal! 3gg\<C-W>f"', 'E447:')
  setlocal suffixesadd+=.cc
  exe "normal! 3gg\<C-W>f"
  call assert_equal('baz.cc', expand('%:t'))
  close

  %bwipe!
  call chdir(cwd)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
