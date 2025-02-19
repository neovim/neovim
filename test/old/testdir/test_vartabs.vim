" Test for variable tabstops

source check.vim
CheckFeature vartabs

source view_util.vim

func s:compare_lines(expect, actual)
  call assert_equal(join(a:expect, "\n"), join(a:actual, "\n"))
endfunc

func Test_vartabs()
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

  " Test for 'retab' with vts
  set ts=8 sts=0 vts=5,3,6,2 vsts=
  exe "norm! S                l"
  .retab!
  call assert_equal("\t\t\t\tl", getline(1))

  " Test for 'retab' with same values as vts
  set ts=8 sts=0 vts=5,3,6,2 vsts=
  exe "norm! S                l"
  .retab! 5,3,6,2
  call assert_equal("\t\t\t\tl", getline(1))

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

func Test_retab_invalid_arg()
  new
  call setline(1, "\ttext")
  retab 0
  call assert_fails("retab -8", 'E487: Argument must be positive')
  call assert_fails("retab 10000", 'E475:')
  call assert_fails("retab 720575940379279360", 'E475:')
  bwipe!
endfunc

func Test_vartabs_breakindent()
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

func Test_vartabs_linebreak()
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

func Test_vartabs_shiftwidth()
  "return
  if winwidth(0) < 40
    return
  endif
  new
  40vnew
  %d
"  setl varsofttabstop=10,20,30,40
  setl shiftwidth=0 vartabstop=10,20,30,40
  call setline(1, "x")

  " Check without any change.
  let expect = ['x                                       ']
  let lines = ScreenLines(1, winwidth(0))
  call s:compare_lines(expect, lines)
  " Test 1:
  " shiftwidth depends on the indent, first check with cursor at the end of the
  " line (which is the same as the start of the line, since there is only one
  " character).
  norm! $>>
  let expect1 = ['          x                             ']
  let lines = ScreenLines(1, winwidth(0))
  call s:compare_lines(expect1, lines)
  call assert_equal(10, shiftwidth())
  call assert_equal(10, shiftwidth(1))
  call assert_equal(20, shiftwidth(virtcol('.')))
  norm! $>>
  let expect2 = ['                              x         ', '~                                       ']
  let lines = ScreenLines([1, 2], winwidth(0))
  call s:compare_lines(expect2, lines)
  call assert_equal(20, shiftwidth(virtcol('.')-2))
  call assert_equal(30, virtcol('.')->shiftwidth())
  norm! $>>
  let expect3 = ['                                        ', '                    x                   ', '~                                       ']
  let lines = ScreenLines([1, 3], winwidth(0))
  call s:compare_lines(expect3, lines)
  call assert_equal(30, shiftwidth(virtcol('.')-2))
  call assert_equal(40, shiftwidth(virtcol('.')))
  norm! $>>
  let expect4 = ['                                        ', '                                        ', '                    x                   ']
  let lines = ScreenLines([1, 3], winwidth(0))
  call assert_equal(40, shiftwidth(virtcol('.')))
  call s:compare_lines(expect4, lines)

  " Test 2: Put the cursor at the first column, result should be the same
  call setline(1, "x")
  norm! 0>>
  let lines = ScreenLines(1, winwidth(0))
  call s:compare_lines(expect1, lines)
  norm! 0>>
  let lines = ScreenLines([1, 2], winwidth(0))
  call s:compare_lines(expect2, lines)
  norm! 0>>
  let lines = ScreenLines([1, 3], winwidth(0))
  call s:compare_lines(expect3, lines)
  norm! 0>>
  let lines = ScreenLines([1, 3], winwidth(0))
  call s:compare_lines(expect4, lines)

  call assert_fails('call shiftwidth([])', 'E745:')

  " cleanup
  bw!
  bw!
endfunc

func Test_vartabs_failures()
  call assert_fails('set vts=8,')
  call assert_fails('set vsts=8,')
  call assert_fails('set vts=8,,8')
  call assert_fails('set vsts=8,,8')
  call assert_fails('set vts=8,,8,')
  call assert_fails('set vsts=8,,8,')
  call assert_fails('set vts=,8')
  call assert_fails('set vsts=,8')
endfunc

func Test_vartabs_reset()
  set vts=8
  set all&
  call assert_equal('', &vts)
endfunc

func s:SaveCol(l)
  call add(a:l, [col('.'), virtcol('.')])
  return ''
endfunc

" Test for 'varsofttabstop'
func Test_varsofttabstop()
  new
  inoremap <expr> <F2>  s:SaveCol(g:cols)

  set backspace=indent,eol,start
  set varsofttabstop=6,2,5,3
  let g:cols = []
  call feedkeys("a\t\<F2>\t\<F2>\t\<F2>\t\<F2> ", 'xt')
  call assert_equal("\t\t ", getline(1))
  call assert_equal([[7, 7], [2, 9], [7, 14], [3, 17]], g:cols)

  let g:cols = []
  call feedkeys("a\<bs>\<F2>\<bs>\<F2>\<bs>\<F2>\<bs>\<F2>\<bs>\<F2>", 'xt')
  call assert_equal('', getline(1))
  call assert_equal([[3, 17], [7, 14], [2, 9], [7, 7], [1, 1]], g:cols)

  set varsofttabstop&
  set backspace&
  iunmap <F2>
  close!
endfunc

" Setting 'shiftwidth' to a negative value, should set it to either the value
" of 'tabstop' (if 'vartabstop' is not set) or to the first value in
" 'vartabstop'
func Test_shiftwidth_vartabstop()
  throw 'Skipped: Nvim removed this behavior in #6377'
  setlocal tabstop=7 vartabstop=
  call assert_fails('set shiftwidth=-1', 'E487:')
  call assert_equal(7, &shiftwidth)
  setlocal tabstop=7 vartabstop=5,7,10
  call assert_fails('set shiftwidth=-1', 'E487:')
  call assert_equal(5, &shiftwidth)
  setlocal shiftwidth& vartabstop& tabstop&
endfunc

func Test_vartabstop_latin1()
  throw "Skipped: Nvim does not support 'compatible'"
  let save_encoding = &encoding
  new
  set encoding=iso8859-1
  set compatible linebreak list revins smarttab
  set vartabstop=400
  exe "norm i00\t\<C-D>"
  bwipe!
  let &encoding = save_encoding
  set nocompatible linebreak& list& revins& smarttab& vartabstop&
endfunc

" Verify that right-shifting and left-shifting adjust lines to the proper
" tabstops.
func Test_vartabstop_shift_right_left()
  new
  set expandtab
  set shiftwidth=0
  set vartabstop=17,11,7
  exe "norm! aword"
  let expect = "word"
  call assert_equal(expect, getline(1))

  " Shift to first tabstop.
  norm! >>
  let expect = "                 word"
  call assert_equal(expect, getline(1))

  " Shift to second tabstop.
  norm! >>
  let expect = "                            word"
  call assert_equal(expect, getline(1))

  " Shift to third tabstop.
  norm! >>
  let expect = "                                   word"
  call assert_equal(expect, getline(1))

  " Shift to fourth tabstop, repeating the third shift width.
  norm! >>
  let expect = "                                          word"
  call assert_equal(expect, getline(1))

  " Shift back to the third tabstop.
  norm! <<
  let expect = "                                   word"
  call assert_equal(expect, getline(1))

  " Shift back to the second tabstop.
  norm! <<
  let expect = "                            word"
  call assert_equal(expect, getline(1))

  " Shift back to the first tabstop.
  norm! <<
  let expect = "                 word"
  call assert_equal(expect, getline(1))

  " Shift back to the left margin.
  norm! <<
  let expect = "word"
  call assert_equal(expect, getline(1))

  " Shift again back to the left margin.
  norm! <<
  let expect = "word"
  call assert_equal(expect, getline(1))

  bwipeout!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
