" Test for variable tabstops

if !has("vartabs")
  finish
endif

source view_util.vim
function! s:compare_lines(expect, actual)
  call assert_equal(join(a:expect, "\n"), join(a:actual, "\n"))
endfunction

func! Test_vartabs()
  new
  %d

  " Test normal operation of tabstops ...
  set ts=4
  call setline(1, join(split('aaaaa', '\zs'), "\t"))
  retab 8
  let expect = "a   a\<tab>a   a\<tab>a"
  call assert_equal(expect, getline(1))

  " ... and softtabstops
  set ts=8 sts=6
  exe "norm! Sb\<tab>b\<tab>b\<tab>b\<tab>b"
  let expect = "b     b\<tab>    b\<tab>  b\<tab>b"
  call assert_equal(expect, getline(1))

  " Test variable tabstops.
  set sts=0 vts=4,8,4,8
  exe "norm! Sc\<tab>c\<tab>c\<tab>c\<tab>c\<tab>c"
  retab 8
  let expect = "c   c\<tab>    c\<tab>c\<tab>c\<tab>c"
  call assert_equal(expect, getline(1))

  set et vts=4,8,4,8
  exe "norm! Sd\<tab>d\<tab>d\<tab>d\<tab>d\<tab>d"
  let expect = "d   d       d   d       d       d"
  call assert_equal(expect, getline(1))

  " Changing ts should have no effect if vts is in use.
  call cursor(1, 1)
  set ts=6
  exe "norm! Se\<tab>e\<tab>e\<tab>e\<tab>e\<tab>e"
  let expect = "e   e       e   e       e       e"
  call assert_equal(expect, getline(1))

  " Clearing vts should revert to using ts.
  set vts=
  exe "norm! Sf\<tab>f\<tab>f\<tab>f\<tab>f\<tab>f"
  let expect = "f     f     f     f     f     f"
  call assert_equal(expect, getline(1))

  " Test variable softtabstops.
  set noet ts=8 vsts=12,2,6
  exe "norm! Sg\<tab>g\<tab>g\<tab>g\<tab>g\<tab>g"
  let expect = "g\<tab>    g g\<tab>    g\<tab>  g\<tab>g"
  call assert_equal(expect, getline(1))

  " Variable tabstops and softtabstops combined.
  set vsts=6,12,8 vts=4,6,8
  exe "norm! Sh\<tab>h\<tab>h\<tab>h\<tab>h"
  let expect = "h\<tab>  h\<tab>\<tab>h\<tab>h\<tab>h"
  call assert_equal(expect, getline(1))

  " Retab with a single value, not using vts.
  set ts=8 sts=0 vts= vsts=
  exe "norm! Si\<tab>i\<tab>i\<tab>i\<tab>i"
  retab 4
  let expect = "i\<tab>\<tab>i\<tab>\<tab>i\<tab>\<tab>i\<tab>\<tab>i"
  call assert_equal(expect, getline(1))

  " Retab with a single value, using vts.
  set ts=8 sts=0 vts=6 vsts=
  exe "norm! Sj\<tab>j\<tab>j\<tab>j\<tab>j"
  retab 4
  let expect = "j\<tab>  j\<tab>\<tab>j\<tab>  j\<tab>\<tab>j"
  call assert_equal(expect, getline(1))

  " Retab with multiple values, not using vts.
  set ts=6 sts=0 vts= vsts=
  exe "norm! Sk\<tab>k\<tab>k\<tab>k\<tab>k\<tab>k"
  retab 4,8
  let expect = "k\<tab>  k\<tab>k     k\<tab>    k\<tab>  k"
  call assert_equal(expect, getline(1))

  " Retab with multiple values, using vts.
  set ts=8 sts=0 vts=6 vsts=
  exe "norm! Sl\<tab>l\<tab>l\<tab>l\<tab>l\<tab>l"
  retab 4,8
  let expect = "l\<tab>  l\<tab>l     l\<tab>    l\<tab>  l"
  call assert_equal(expect, getline(1))

  " Check that global and local values are set.
  set ts=4 vts=6 sts=8 vsts=10
  call assert_equal(&ts, 4)
  call assert_equal(&vts, '6')
  call assert_equal(&sts, 8)
  call assert_equal(&vsts, '10')
  new
  call assert_equal(&ts, 4)
  call assert_equal(&vts, '6')
  call assert_equal(&sts, 8)
  call assert_equal(&vsts, '10')
  bwipeout!

  " Check that local values only are set.
  setlocal ts=5 vts=7 sts=9 vsts=11
  call assert_equal(&ts, 5)
  call assert_equal(&vts, '7')
  call assert_equal(&sts, 9)
  call assert_equal(&vsts, '11')
  new
  call assert_equal(&ts, 4)
  call assert_equal(&vts, '6')
  call assert_equal(&sts, 8)
  call assert_equal(&vsts, '10')
  bwipeout!

  " Check that global values only are set.
  setglobal ts=6 vts=8 sts=10 vsts=12
  call assert_equal(&ts, 5)
  call assert_equal(&vts, '7')
  call assert_equal(&sts, 9)
  call assert_equal(&vsts, '11')
  new
  call assert_equal(&ts, 6)
  call assert_equal(&vts, '8')
  call assert_equal(&sts, 10)
  call assert_equal(&vsts, '12')
  bwipeout!

  set ts& vts& sts& vsts& et&
  bwipeout!
endfunc

func! Test_vartabs_breakindent()
  if !exists("+breakindent")
    return
  endif
  new
  %d

  " Test normal operation of tabstops ...
  set ts=4
  call setline(1, join(split('aaaaa', '\zs'), "\t"))
  retab 8
  let expect = "a   a\<tab>a   a\<tab>a"
  call assert_equal(expect, getline(1))

  " ... and softtabstops
  set ts=8 sts=6
  exe "norm! Sb\<tab>b\<tab>b\<tab>b\<tab>b"
  let expect = "b     b\<tab>    b\<tab>  b\<tab>b"
  call assert_equal(expect, getline(1))

  " Test variable tabstops.
  set sts=0 vts=4,8,4,8
  exe "norm! Sc\<tab>c\<tab>c\<tab>c\<tab>c\<tab>c"
  retab 8
  let expect = "c   c\<tab>    c\<tab>c\<tab>c\<tab>c"
  call assert_equal(expect, getline(1))

  set et vts=4,8,4,8
  exe "norm! Sd\<tab>d\<tab>d\<tab>d\<tab>d\<tab>d"
  let expect = "d   d       d   d       d       d"
  call assert_equal(expect, getline(1))

  " Changing ts should have no effect if vts is in use.
  call cursor(1, 1)
  set ts=6
  exe "norm! Se\<tab>e\<tab>e\<tab>e\<tab>e\<tab>e"
  let expect = "e   e       e   e       e       e"
  call assert_equal(expect, getline(1))

  " Clearing vts should revert to using ts.
  set vts=
  exe "norm! Sf\<tab>f\<tab>f\<tab>f\<tab>f\<tab>f"
  let expect = "f     f     f     f     f     f"
  call assert_equal(expect, getline(1))

  " Test variable softtabstops.
  set noet ts=8 vsts=12,2,6
  exe "norm! Sg\<tab>g\<tab>g\<tab>g\<tab>g\<tab>g"
  let expect = "g\<tab>    g g\<tab>    g\<tab>  g\<tab>g"
  call assert_equal(expect, getline(1))

  " Variable tabstops and softtabstops combined.
  set vsts=6,12,8 vts=4,6,8
  exe "norm! Sh\<tab>h\<tab>h\<tab>h\<tab>h"
  let expect = "h\<tab>  h\<tab>\<tab>h\<tab>h\<tab>h"
  call assert_equal(expect, getline(1))

  " Retab with a single value, not using vts.
  set ts=8 sts=0 vts= vsts=
  exe "norm! Si\<tab>i\<tab>i\<tab>i\<tab>i"
  retab 4
  let expect = "i\<tab>\<tab>i\<tab>\<tab>i\<tab>\<tab>i\<tab>\<tab>i"
  call assert_equal(expect, getline(1))

  " Retab with a single value, using vts.
  set ts=8 sts=0 vts=6 vsts=
  exe "norm! Sj\<tab>j\<tab>j\<tab>j\<tab>j"
  retab 4
  let expect = "j\<tab>  j\<tab>\<tab>j\<tab>  j\<tab>\<tab>j"
  call assert_equal(expect, getline(1))

  " Retab with multiple values, not using vts.
  set ts=6 sts=0 vts= vsts=
  exe "norm! Sk\<tab>k\<tab>k\<tab>k\<tab>k\<tab>k"
  retab 4,8
  let expect = "k\<tab>  k\<tab>k     k\<tab>    k\<tab>  k"
  call assert_equal(expect, getline(1))

  " Retab with multiple values, using vts.
  set ts=8 sts=0 vts=6 vsts=
  exe "norm! Sl\<tab>l\<tab>l\<tab>l\<tab>l\<tab>l"
  retab 4,8
  let expect = "l\<tab>  l\<tab>l     l\<tab>    l\<tab>  l"
  call assert_equal(expect, getline(1))

  " Check that global and local values are set.
  set ts=4 vts=6 sts=8 vsts=10
  call assert_equal(&ts, 4)
  call assert_equal(&vts, '6')
  call assert_equal(&sts, 8)
  call assert_equal(&vsts, '10')
  new
  call assert_equal(&ts, 4)
  call assert_equal(&vts, '6')
  call assert_equal(&sts, 8)
  call assert_equal(&vsts, '10')
  bwipeout!

  " Check that local values only are set.
  setlocal ts=5 vts=7 sts=9 vsts=11
  call assert_equal(&ts, 5)
  call assert_equal(&vts, '7')
  call assert_equal(&sts, 9)
  call assert_equal(&vsts, '11')
  new
  call assert_equal(&ts, 4)
  call assert_equal(&vts, '6')
  call assert_equal(&sts, 8)
  call assert_equal(&vsts, '10')
  bwipeout!

  " Check that global values only are set.
  setglobal ts=6 vts=8 sts=10 vsts=12
  call assert_equal(&ts, 5)
  call assert_equal(&vts, '7')
  call assert_equal(&sts, 9)
  call assert_equal(&vsts, '11')
  new
  call assert_equal(&ts, 6)
  call assert_equal(&vts, '8')
  call assert_equal(&sts, 10)
  call assert_equal(&vsts, '12')
  bwipeout!

  bwipeout!
endfunc

func! Test_vartabs_linebreak()
  if winwidth(0) < 40
    return
  endif
  new
  40vnew
  %d
  setl linebreak vartabstop=10,20,30,40
  call setline(1, "\tx\tx\tx\tx")

  let expect = ['          x                             ',
        \       'x                   x                   ',
        \       'x                                       ']
  let lines = ScreenLines([1, 3], winwidth(0))
  call s:compare_lines(expect, lines)
  setl list listchars=tab:>-
  let expect = ['>---------x>------------------          ',
        \       'x>------------------x>------------------',
        \       'x                                       ']
  let lines = ScreenLines([1, 3], winwidth(0))
  call s:compare_lines(expect, lines)
  setl linebreak vartabstop=40
  let expect = ['>---------------------------------------',
        \       'x>--------------------------------------',
        \       'x>--------------------------------------',
        \       'x>--------------------------------------',
        \       'x                                       ']
  let lines = ScreenLines([1, 5], winwidth(0))
  call s:compare_lines(expect, lines)

  " cleanup
  bw!
  bw!
  set nolist listchars&vim
endfunc
