" Test for various Normal mode commands

func! Setup_NewWindow()
  10new
  call setline(1, range(1,100))
endfunc

func! MyFormatExpr()
  " Adds '->$' at lines having numbers followed by trailing whitespace
  for ln in range(v:lnum, v:lnum+v:count-1)
    let line = getline(ln)
    if getline(ln) =~# '\d\s\+$'
      call setline(ln, substitute(line, '\s\+$', '', '') . '->$')
    endif
  endfor
endfunc

func! CountSpaces(type, ...)
  " for testing operatorfunc
  " will count the number of spaces
  " and return the result in g:a
  let sel_save = &selection
  let &selection = "inclusive"
  let reg_save = @@

  if a:0  " Invoked from Visual mode, use gv command.
    silent exe "normal! gvy"
  elseif a:type == 'line'
    silent exe "normal! '[V']y"
  else
    silent exe "normal! `[v`]y"
  endif
  let g:a=strlen(substitute(@@, '[^ ]', '', 'g'))
  let &selection = sel_save
  let @@ = reg_save
endfunc

func! OpfuncDummy(type, ...)
  " for testing operatorfunc
  let g:opt=&linebreak

  if a:0  " Invoked from Visual mode, use gv command.
    silent exe "normal! gvy"
  elseif a:type == 'line'
    silent exe "normal! '[V']y"
  else
    silent exe "normal! `[v`]y"
  endif
  " Create a new dummy window
  new
  let g:bufnr=bufnr('%')
endfunc

fun! Test_normal00_optrans()
  new
  call append(0, ['1 This is a simple test: abcd', '2 This is the second line', '3 this is the third line'])
  1
  exe "norm! Sfoobar\<esc>"
  call assert_equal(['foobar', '2 This is the second line', '3 this is the third line', ''], getline(1,'$'))
  2
  exe "norm! $vbsone"
  call assert_equal(['foobar', '2 This is the second one', '3 this is the third line', ''], getline(1,'$'))
  norm! VS Second line here
  call assert_equal(['foobar', ' Second line here', '3 this is the third line', ''], getline(1, '$'))
  %d
  call append(0, ['4 This is a simple test: abcd', '5 This is the second line', '6 this is the third line'])
  call append(0, ['1 This is a simple test: abcd', '2 This is the second line', '3 this is the third line'])

  1
  norm! 2D
  call assert_equal(['3 this is the third line', '4 This is a simple test: abcd', '5 This is the second line', '6 this is the third line', ''], getline(1,'$'))
  set cpo+=#
  norm! 4D
  call assert_equal(['', '4 This is a simple test: abcd', '5 This is the second line', '6 this is the third line', ''], getline(1,'$'))

  " clean up
  set cpo-=#
  bw!
endfunc

func! Test_normal01_keymodel()
  call Setup_NewWindow()
  " Test 1: depending on 'keymodel' <s-down> does something different
  50
  call feedkeys("V\<S-Up>y", 'tx')
  call assert_equal(['47', '48', '49', '50'], getline("'<", "'>"))
  set keymodel=startsel
  50
  call feedkeys("V\<S-Up>y", 'tx')
  call assert_equal(['49', '50'], getline("'<", "'>"))
  " Start visual mode when keymodel = startsel
  50
  call feedkeys("\<S-Up>y", 'tx')
  call assert_equal(['49', '5'], getreg(0, 0, 1))
  " Do not start visual mode when keymodel=
  set keymodel=
  50
  call feedkeys("\<S-Up>y$", 'tx')
  call assert_equal(['42'], getreg(0, 0, 1))
  " Stop visual mode when keymodel=stopsel
  set keymodel=stopsel
  50
  call feedkeys("Vkk\<Up>yy", 'tx')
  call assert_equal(['47'], getreg(0, 0, 1))

  set keymodel=
  50
  call feedkeys("Vkk\<Up>yy", 'tx')
  call assert_equal(['47', '48', '49', '50'], getreg(0, 0, 1))

  " clean up
  bw!
endfunc

func! Test_normal02_selectmode()
  " some basic select mode tests
  call Setup_NewWindow()
  50
  norm! gHy
  call assert_equal('y51', getline('.'))
  call setline(1, range(1,100))
  50
  exe ":norm! V9jo\<c-g>y"
  call assert_equal('y60', getline('.'))
  " clean up
  bw!
endfunc

func! Test_normal02_selectmode2()
  " some basic select mode tests
  call Setup_NewWindow()
  50
  call feedkeys(":set im\n\<c-o>gHc\<c-o>:set noim\n", 'tx')
  call assert_equal('c51', getline('.'))
  " clean up
  bw!
endfunc

func! Test_normal03_join()
  " basic join test
  call Setup_NewWindow()
  50
  norm! VJ
  call assert_equal('50 51', getline('.'))
  $
  norm! J
  call assert_equal('100', getline('.'))
  $
  norm! V9-gJ
  call assert_equal('919293949596979899100', getline('.'))
  call setline(1, range(1,100))
  $
  :j 10
  call assert_equal('100', getline('.'))
  " clean up
  bw!
endfunc

func! Test_normal04_filter()
  " basic filter test
  " only test on non windows platform
  if has('win32')
    return
  endif
  call Setup_NewWindow()
  1
  call feedkeys("!!sed -e 's/^/|    /'\n", 'tx')
  call assert_equal('|    1', getline('.'))
  90
  :sil :!echo one
  call feedkeys('.', 'tx')
  call assert_equal('|    90', getline('.'))
  95
  set cpo+=!
  " 2 <CR>, 1: for executing the command,
  "         2: clear hit-enter-prompt
  call feedkeys("!!\n", 'tx')
  call feedkeys(":!echo one\n\n", 'tx')
  call feedkeys(".", 'tx')
  call assert_equal('one', getline('.'))
  set cpo-=!
  bw!
endfunc

func! Test_normal05_formatexpr()
  " basic formatexpr test
  call Setup_NewWindow()
  %d_
  call setline(1, ['here: 1   ', '2', 'here: 3   ', '4', 'not here:   '])
  1
  set formatexpr=MyFormatExpr()
  norm! gqG
  call assert_equal(['here: 1->$', '2', 'here: 3->$', '4', 'not here:   '], getline(1,'$'))
  set formatexpr=
  bw!
endfunc

func Test_normal05_formatexpr_newbuf()
  " Edit another buffer in the 'formatexpr' function
  new
  func! Format()
    edit another
  endfunc
  set formatexpr=Format()
  norm gqG
  bw!
  set formatexpr=
endfunc

func Test_normal05_formatexpr_setopt()
  " Change the 'formatexpr' value in the function
  new
  func! Format()
    set formatexpr=
  endfunc
  set formatexpr=Format()
  norm gqG
  bw!
  set formatexpr=
endfunc

func! Test_normal06_formatprg()
  " basic test for formatprg
  " only test on non windows platform
  if has('win32')
    return
  else
    " uses sed to number non-empty lines
    call writefile(['#!/bin/sh', 'sed ''/./=''|sed ''/./{', 'N', 's/\n/    /', '}'''], 'Xsed_format.sh')
    call system('chmod +x ./Xsed_format.sh')
  endif
  call Setup_NewWindow()
  %d
  call setline(1, ['a', '', 'c', '', ' ', 'd', 'e'])
  set formatprg=./Xsed_format.sh
  norm! gggqG
  call assert_equal(['1    a', '', '3    c', '', '5     ', '6    d', '7    e'], getline(1, '$'))
  " clean up
  set formatprg=
  call delete('Xsed_format.sh')
  bw!
endfunc

func! Test_normal07_internalfmt()
  " basic test for internal formmatter to textwidth of 12
  let list=range(1,11)
  call map(list, 'v:val."    "')
  10new
  call setline(1, list)
  set tw=12
  norm! gggqG
  call assert_equal(['1    2    3', '4    5    6', '7    8    9', '10    11    '], getline(1, '$'))
  " clean up
  set formatprg= tw=0
  bw!
endfunc

func! Test_normal08_fold()
  " basic tests for foldopen/folddelete
  if !has("folding")
    return
  endif
  call Setup_NewWindow()
  50
  setl foldenable fdm=marker
  " First fold
  norm! V4jzf
  " check that folds have been created
  call assert_equal(['50/*{{{*/', '51', '52', '53', '54/*}}}*/'], getline(50,54))
  " Second fold
  46
  norm! V10jzf
  " check that folds have been created
  call assert_equal('46/*{{{*/', getline(46))
  call assert_equal('60/*}}}*/', getline(60))
  norm! k
  call assert_equal('45', getline('.'))
  norm! j
  call assert_equal('46/*{{{*/', getline('.'))
  norm! j
  call assert_equal('61', getline('.'))
  norm! k
  " open a fold
  norm! Vzo
  norm! k
  call assert_equal('45', getline('.'))
  norm! j
  call assert_equal('46/*{{{*/', getline('.'))
  norm! j
  call assert_equal('47', getline('.'))
  norm! k
  norm! zcVzO
  call assert_equal('46/*{{{*/', getline('.'))
  norm! j
  call assert_equal('47', getline('.'))
  norm! j
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('51', getline('.'))
  " delete folds
  :46
  " collapse fold
  norm! V14jzC
  " delete all folds recursively
  norm! VzD
  call assert_equal(['46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '60'], getline(46,60))

  " clean up
  setl nofoldenable fdm=marker
  bw!
endfunc

func! Test_normal09_operatorfunc()
  " Test operatorfunc
  call Setup_NewWindow()
  " Add some spaces for counting
  50,60s/$/  /
  unlet! g:a
  let g:a=0
  nmap <buffer><silent> ,, :set opfunc=CountSpaces<CR>g@
  vmap <buffer><silent> ,, :<C-U>call CountSpaces(visualmode(), 1)<CR>
  50
  norm V2j,,
  call assert_equal(6, g:a)
  norm V,,
  call assert_equal(2, g:a)
  norm ,,l
  call assert_equal(0, g:a)
  50
  exe "norm 0\<c-v>10j2l,,"
  call assert_equal(11, g:a)
  50
  norm V10j,,
  call assert_equal(22, g:a)

  " clean up
  unmap <buffer> ,,
  set opfunc=
  unlet! g:a
  bw!
endfunc

func! Test_normal09a_operatorfunc()
  " Test operatorfunc
  call Setup_NewWindow()
  " Add some spaces for counting
  50,60s/$/  /
  unlet! g:opt
  set linebreak
  nmap <buffer><silent> ,, :set opfunc=OpfuncDummy<CR>g@
  50
  norm ,,j
  exe "bd!" g:bufnr
  call assert_true(&linebreak)
  call assert_equal(g:opt, &linebreak)
  set nolinebreak
  norm ,,j
  exe "bd!" g:bufnr
  call assert_false(&linebreak)
  call assert_equal(g:opt, &linebreak)

  " clean up
  unmap <buffer> ,,
  set opfunc=
  bw!
  unlet! g:opt
endfunc

func! Test_normal10_expand()
  " Test for expand()
  10new
  call setline(1, ['1', 'ifooar,,cbar'])
  2
  norm! $
  let a=expand('<cword>')
  let b=expand('<cWORD>')
  call assert_equal('cbar', a)
  call assert_equal('ifooar,,cbar', b)
  " clean up
  bw!
endfunc

func! Test_normal11_showcmd()
  " test for 'showcmd'
  10new
  exe "norm! ofoobar\<esc>"
  call assert_equal(2, line('$'))
  set showcmd
  exe "norm! ofoobar2\<esc>"
  call assert_equal(3, line('$'))
  exe "norm! VAfoobar3\<esc>"
  call assert_equal(3, line('$'))
  exe "norm! 0d3\<del>2l"
  call assert_equal('obar2foobar3', getline('.'))
  bw!
endfunc

func! Test_normal12_nv_error()
  " Test for nv_error
  10new
  call setline(1, range(1,5))
  " should not do anything, just beep
  exe "norm! <c-k>"
  call assert_equal(map(range(1,5), 'string(v:val)'), getline(1,'$'))
  bw!
endfunc

func! Test_normal13_help()
  " Test for F1
  call assert_equal(1, winnr())
  call feedkeys("\<f1>", 'txi')
  call assert_match('help\.txt', bufname('%'))
  call assert_equal(2, winnr('$'))
  bw!
endfunc

func! Test_normal14_page()
  " basic test for Ctrl-F and Ctrl-B
  call Setup_NewWindow()
  exe "norm! \<c-f>"
  call assert_equal('9', getline('.'))
  exe "norm! 2\<c-f>"
  call assert_equal('25', getline('.'))
  exe "norm! 2\<c-b>"
  call assert_equal('18', getline('.'))
  1
  set scrolloff=5
  exe "norm! 2\<c-f>"
  call assert_equal('21', getline('.'))
  exe "norm! \<c-b>"
  call assert_equal('13', getline('.'))
  1
  set scrolloff=99
  exe "norm! \<c-f>"
  call assert_equal('13', getline('.'))
  set scrolloff=0
  100
  exe "norm! $\<c-b>"
  call assert_equal('92', getline('.'))
  call assert_equal([0, 92, 1, 0, 1], getcurpos())
  100
  set nostartofline
  exe "norm! $\<c-b>"
  call assert_equal('92', getline('.'))
  call assert_equal([0, 92, 2, 0, 2147483647], getcurpos())
  " cleanup
  set startofline
  bw!
endfunc

func! Test_normal14_page_eol()
  10new
  norm oxxxxxxx
  exe "norm 2\<c-f>"
  " check with valgrind that cursor is put back in column 1
  exe "norm 2\<c-b>"
  bw!
endfunc

func! Test_normal15_z_scroll_vert()
  " basic test for z commands that scroll the window
  call Setup_NewWindow()
  100
  norm! >>
  " Test for z<cr>
  exe "norm! z\<cr>"
  call assert_equal('	100', getline('.'))
  call assert_equal(100, winsaveview()['topline'])
  call assert_equal([0, 100, 2, 0, 9], getcurpos())

  " Test for zt
  21
  norm! >>0zt
  call assert_equal('	21', getline('.'))
  call assert_equal(21, winsaveview()['topline'])
  call assert_equal([0, 21, 1, 0, 8], getcurpos())

  " Test for zb
  30
  norm! >>$ztzb
  call assert_equal('	30', getline('.'))
  call assert_equal(30, winsaveview()['topline']+winheight(0)-1)
  call assert_equal([0, 30, 3, 0, 2147483647], getcurpos())

  " Test for z-
  1
  30
  norm! 0z-
  call assert_equal('	30', getline('.'))
  call assert_equal(30, winsaveview()['topline']+winheight(0)-1)
  call assert_equal([0, 30, 2, 0, 9], getcurpos())

  " Test for z{height}<cr>
  call assert_equal(10, winheight(0))
  exe "norm! z12\<cr>"
  call assert_equal(12, winheight(0))
  exe "norm! z10\<cr>"
  call assert_equal(10, winheight(0))

  " Test for z.
  1
  21
  norm! 0z.
  call assert_equal('	21', getline('.'))
  call assert_equal(17, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " Test for zz
  1
  21
  norm! 0zz
  call assert_equal('	21', getline('.'))
  call assert_equal(17, winsaveview()['topline'])
  call assert_equal([0, 21, 1, 0, 8], getcurpos())

  " Test for z+
  11
  norm! zt
  norm! z+
  call assert_equal('	21', getline('.'))
  call assert_equal(21, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " Test for [count]z+
  1
  norm! 21z+
  call assert_equal('	21', getline('.'))
  call assert_equal(21, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " Test for z^
  norm! 22z+0
  norm! z^
  call assert_equal('	21', getline('.'))
  call assert_equal(12, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " Test for [count]z^
  1
  norm! 30z^
  call assert_equal('	21', getline('.'))
  call assert_equal(12, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " cleanup
  bw!
endfunc

func! Test_normal16_z_scroll_hor()
  " basic test for z commands that scroll the window
  10new
  15vsp
  set nowrap listchars=
  let lineA='abcdefghijklmnopqrstuvwxyz'
  let lineB='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  $put =lineA
  $put =lineB
  1d

  " Test for zl
  1
  norm! 5zl
  call assert_equal(lineA, getline('.'))
  call assert_equal(6, col('.'))
  call assert_equal(5, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('f', @0)

  " Test for zh
  norm! 2zh
  call assert_equal(lineA, getline('.'))
  call assert_equal(6, col('.'))
  norm! yl
  call assert_equal('f', @0)
  call assert_equal(3, winsaveview()['leftcol'])

  " Test for zL
  norm! zL
  call assert_equal(11, col('.'))
  norm! yl
  call assert_equal('k', @0)
  call assert_equal(10, winsaveview()['leftcol'])
  norm! 2zL
  call assert_equal(25, col('.'))
  norm! yl
  call assert_equal('y', @0)
  call assert_equal(24, winsaveview()['leftcol'])

  " Test for zH
  norm! 2zH
  call assert_equal(25, col('.'))
  call assert_equal(10, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('y', @0)

  " Test for zs
  norm! $zs
  call assert_equal(26, col('.'))
  call assert_equal(25, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)

  " Test for ze
  norm! ze
  call assert_equal(26, col('.'))
  call assert_equal(11, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)

  " cleanup
  set wrap listchars=eol:$
  bw!
endfunc

func! Test_normal17_z_scroll_hor2()
  " basic test for z commands that scroll the window
  " using 'sidescrolloff' setting
  10new
  20vsp
  set nowrap listchars= sidescrolloff=5
  let lineA='abcdefghijklmnopqrstuvwxyz'
  let lineB='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  $put =lineA
  $put =lineB
  1d

  " Test for zl
  1
  norm! 5zl
  call assert_equal(lineA, getline('.'))
  call assert_equal(11, col('.'))
  call assert_equal(5, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('k', @0)

  " Test for zh
  norm! 2zh
  call assert_equal(lineA, getline('.'))
  call assert_equal(11, col('.'))
  norm! yl
  call assert_equal('k', @0)
  call assert_equal(3, winsaveview()['leftcol'])

  " Test for zL
  norm! 0zL
  call assert_equal(16, col('.'))
  norm! yl
  call assert_equal('p', @0)
  call assert_equal(10, winsaveview()['leftcol'])
  norm! 2zL
  call assert_equal(26, col('.'))
  norm! yl
  call assert_equal('z', @0)
  call assert_equal(15, winsaveview()['leftcol'])

  " Test for zH
  norm! 2zH
  call assert_equal(15, col('.'))
  call assert_equal(0, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('o', @0)

  " Test for zs
  norm! $zs
  call assert_equal(26, col('.'))
  call assert_equal(20, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)

  " Test for ze
  norm! ze
  call assert_equal(26, col('.'))
  call assert_equal(11, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)

  " cleanup
  set wrap listchars=eol:$ sidescrolloff=0
  bw!
endfunc

func! Test_normal18_z_fold()
  " basic tests for foldopen/folddelete
  if !has("folding")
    return
  endif
  call Setup_NewWindow()
  50
  setl foldenable fdm=marker foldlevel=5

  " Test for zF
  " First fold
  norm! 4zF
  " check that folds have been created
  call assert_equal(['50/*{{{*/', '51', '52', '53/*}}}*/'], getline(50,53))

  " Test for zd
  51
  norm! 2zF
  call assert_equal(2, foldlevel('.'))
  norm! kzd
  call assert_equal(['50', '51/*{{{*/', '52/*}}}*/', '53'], getline(50,53))
  norm! j
  call assert_equal(1, foldlevel('.'))

  " Test for zD
  " also deletes partially selected folds recursively
  51
  norm! zF
  call assert_equal(2, foldlevel('.'))
  norm! kV2jzD
  call assert_equal(['50', '51', '52', '53'], getline(50,53))

  " Test for zE
  85
  norm! 4zF
  86
  norm! 2zF
  90
  norm! 4zF
  call assert_equal(['85/*{{{*/', '86/*{{{*/', '87/*}}}*/', '88/*}}}*/', '89', '90/*{{{*/', '91', '92', '93/*}}}*/'], getline(85,93))
  norm! zE
  call assert_equal(['85', '86', '87', '88', '89', '90', '91', '92', '93'], getline(85,93))

  " Test for zn
  50
  set foldlevel=0
  norm! 2zF
  norm! zn
  norm! k
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('51/*}}}*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  call assert_equal(0, &foldenable)

  " Test for zN
  49
  norm! zN
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  call assert_equal(1, &foldenable)

  " Test for zi
  norm! zi
  call assert_equal(0, &foldenable)
  norm! zi
  call assert_equal(1, &foldenable)
  norm! zi
  call assert_equal(0, &foldenable)
  norm! zi
  call assert_equal(1, &foldenable)

  " Test for za
  50
  norm! za
  norm! k
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('51/*}}}*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  50
  norm! za
  norm! k
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  49
  norm! 5zF
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))
  49
  norm! za
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  set nofoldenable
  " close fold and set foldenable
  norm! za
  call assert_equal(1, &foldenable)

  50
  " have to use {count}za to open all folds and make the cursor visible
  norm! 2za
  norm! 2k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('51/*}}}*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  " Test for zA
  49
  set foldlevel=0
  50
  norm! zA
  norm! 2k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('51/*}}}*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  " zA on a opened fold when foldenale is not set
  50
  set nofoldenable
  norm! zA
  call assert_equal(1, &foldenable)
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zc
  norm! zE
  50
  norm! 2zF
  49
  norm! 5zF
  set nofoldenable
  50
  " There most likely is a bug somewhere:
  " https://groups.google.com/d/msg/vim_dev/v2EkfJ_KQjI/u-Cvv94uCAAJ
  " TODO: Should this only close the inner most fold or both folds?
  norm! zc
  call assert_equal(1, &foldenable)
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))
  set nofoldenable
  50
  norm! Vjzc
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zC
  set nofoldenable
  50
  norm! zCk
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zx
  " 1) close folds at line 49-54
  set nofoldenable
  48
  norm! zx
  call assert_equal(1, &foldenable)
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " 2) do not close fold under curser
  51
  set nofoldenable
  norm! zx
  call assert_equal(1, &foldenable)
  norm! 3k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('51/*}}}*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  norm! j
  call assert_equal('53', getline('.'))
  norm! j
  call assert_equal('54/*}}}*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " 3) close one level of folds
  48
  set nofoldenable
  set foldlevel=1
  norm! zx
  call assert_equal(1, &foldenable)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  norm! j
  call assert_equal('53', getline('.'))
  norm! j
  call assert_equal('54/*}}}*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zX
  " Close all folds
  set foldlevel=0 nofoldenable
  50
  norm! zX
  call assert_equal(1, &foldenable)
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zm
  50
  set nofoldenable foldlevel=2
  norm! zm
  call assert_equal(1, &foldenable)
  call assert_equal(1, &foldlevel)
  norm! zm
  call assert_equal(0, &foldlevel)
  norm! zm
  call assert_equal(0, &foldlevel)
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zM
  48
  set nofoldenable foldlevel=99
  norm! zM
  call assert_equal(1, &foldenable)
  call assert_equal(0, &foldlevel)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zr
  48
  set nofoldenable foldlevel=0
  norm! zr
  call assert_equal(0, &foldenable)
  call assert_equal(1, &foldlevel)
  set foldlevel=0 foldenable
  norm! zr
  call assert_equal(1, &foldenable)
  call assert_equal(1, &foldlevel)
  norm! zr
  call assert_equal(2, &foldlevel)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('51/*}}}*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  " Test for zR
  48
  set nofoldenable foldlevel=0
  norm! zR
  call assert_equal(0, &foldenable)
  call assert_equal(2, &foldlevel)
  set foldenable foldlevel=0
  norm! zR
  call assert_equal(1, &foldenable)
  call assert_equal(2, &foldlevel)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('51/*}}}*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  call append(50, ['a /*{{{*/', 'b /*}}}*/'])
  48
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('a /*{{{*/', getline('.'))
  norm! j
  call assert_equal('51/*}}}*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  48
  norm! zR
  call assert_equal(1, &foldenable)
  call assert_equal(3, &foldlevel)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/*{{{*/', getline('.'))
  norm! j
  call assert_equal('50/*{{{*/', getline('.'))
  norm! j
  call assert_equal('a /*{{{*/', getline('.'))
  norm! j
  call assert_equal('b /*}}}*/', getline('.'))
  norm! j
  call assert_equal('51/*}}}*/', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  " clean up
  setl nofoldenable fdm=marker foldlevel=0
  bw!
endfunc

func! Test_normal19_z_spell()
  if !has("spell") || !has('syntax')
    return
  endif
  new
  call append(0, ['1 good', '2 goood', '3 goood'])
  set spell spellfile=./Xspellfile.add spelllang=en
  let oldlang=v:lang
  lang C

  " Test for zg
  1
  norm! ]s
  call assert_equal('2 goood', getline('.'))
  norm! zg
  1
  let a=execute('unsilent :norm! ]s')
  call assert_equal('1 good', getline('.'))
  call assert_equal('search hit BOTTOM, continuing at TOP', a[1:])
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('goood', cnt[0])

  " Test for zw
  2
  norm! $zw
  1
  norm! ]s
  call assert_equal('2 goood', getline('.'))
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('#oood', cnt[0])
  call assert_equal('goood/!', cnt[1])

  " Test for zg in visual mode
  let a=execute('unsilent :norm! V$zg')
  call assert_equal("Word '2 goood' added to ./Xspellfile.add", a[1:])
  1
  norm! ]s
  call assert_equal('3 goood', getline('.'))
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('2 goood', cnt[2])
  " Remove "2 good" from spellfile
  2
  let a=execute('unsilent norm! V$zw')
  call assert_equal("Word '2 goood' added to ./Xspellfile.add", a[1:])
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('2 goood/!', cnt[3])

  " Test for zG
  let a=execute('unsilent norm! V$zG')
  call assert_match("Word '2 goood' added to .*", a)
  let fname=matchstr(a, 'to\s\+\zs\f\+$')
  let cnt=readfile(fname)
  call assert_equal('2 goood', cnt[0])

  " Test for zW
  let a=execute('unsilent norm! V$zW')
  call assert_match("Word '2 goood' added to .*", a)
  let cnt=readfile(fname)
  call assert_equal('# goood', cnt[0])
  call assert_equal('2 goood/!', cnt[1])

  " Test for zuW
  let a=execute('unsilent norm! V$zuW')
  call assert_match("Word '2 goood' removed from .*", a)
  let cnt=readfile(fname)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])

  " Test for zuG
  let a=execute('unsilent norm! $zG')
  call assert_match("Word 'goood' added to .*", a)
  let cnt=readfile(fname)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])
  call assert_equal('goood', cnt[2])
  let a=execute('unsilent norm! $zuG')
  let cnt=readfile(fname)
  call assert_match("Word 'goood' removed from .*", a)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])
  call assert_equal('#oood', cnt[2])
  " word not found in wordlist
  let a=execute('unsilent norm! V$zuG')
  let cnt=readfile(fname)
  call assert_match("", a)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])
  call assert_equal('#oood', cnt[2])

  " Test for zug
  call delete('./Xspellfile.add')
  2
  let a=execute('unsilent norm! $zg')
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('goood', cnt[0])
  let a=execute('unsilent norm! $zug')
  call assert_match("Word 'goood' removed from \./Xspellfile.add", a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('#oood', cnt[0])
  " word not in wordlist
  let a=execute('unsilent norm! V$zug')
  call assert_match('', a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('#oood', cnt[0])

  " Test for zuw
  call delete('./Xspellfile.add')
  2
  let a=execute('unsilent norm! Vzw')
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('2 goood/!', cnt[0])
  let a=execute('unsilent norm! Vzuw')
  call assert_match("Word '2 goood' removed from \./Xspellfile.add", a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('# goood/!', cnt[0])
  " word not in wordlist
  let a=execute('unsilent norm! $zug')
  call assert_match('', a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('# goood/!', cnt[0])

  " add second entry to spellfile setting
  set spellfile=./Xspellfile.add,./Xspellfile2.add
  call delete('./Xspellfile.add')
  2
  let a=execute('unsilent norm! $2zg')
  let cnt=readfile('./Xspellfile2.add')
  call assert_match("Word 'goood' added to ./Xspellfile2.add", a)
  call assert_equal('goood', cnt[0])

  " clean up
  exe "lang" oldlang
  call delete("./Xspellfile.add")
  call delete("./Xspellfile2.add")
  call delete("./Xspellfile.add.spl")
  call delete("./Xspellfile2.add.spl")

  " zux -> no-op
  2
  norm! $zux
  call assert_equal([], glob('Xspellfile.add',0,1))
  call assert_equal([], glob('Xspellfile2.add',0,1))

  set spellfile=
  bw!
endfunc

func! Test_normal20_exmode()
  if !has("unix")
    " Reading from redirected file doesn't work on MS-Windows
    return
  endif
  call writefile(['1a', 'foo', 'bar', '.', 'w! Xfile2', 'q!'], 'Xscript')
  call writefile(['1', '2'], 'Xfile')
  call system(v:progpath .' -e -s < Xscript Xfile')
  let a=readfile('Xfile2')
  call assert_equal(['1', 'foo', 'bar', '2'], a)

  " clean up
  for file in ['Xfile', 'Xfile2', 'Xscript']
    call delete(file)
  endfor
  bw!
endfunc

func! Test_normal21_nv_hat()
  set hidden
  new
  " to many buffers opened already, will not work
  "call assert_fails(":b#", 'E23')
  "call assert_equal('', @#)
  e Xfoobar
  e Xfile2
  call feedkeys("\<c-^>", 't')
  call assert_equal("Xfile2", fnamemodify(bufname('%'), ':t'))
  call feedkeys("f\<c-^>", 't')
  call assert_equal("Xfile2", fnamemodify(bufname('%'), ':t'))
  " clean up
  set nohidden
  bw!
endfunc

func! Test_normal22_zet()
  " Test for ZZ
  " let shell = &shell
  " let &shell = 'sh'
  call writefile(['1', '2'], 'Xfile')
  let args = ' -u NONE -N -U NONE -i NONE --noplugins -X --not-a-term'
  call system(v:progpath . args . ' -c "%d" -c ":norm! ZZ" Xfile')
  let a = readfile('Xfile')
  call assert_equal([], a)
  " Test for ZQ
  call writefile(['1', '2'], 'Xfile')
  call system(v:progpath . args . ' -c "%d" -c ":norm! ZQ" Xfile')
  let a = readfile('Xfile')
  call assert_equal(['1', '2'], a)

  " clean up
  for file in ['Xfile']
    call delete(file)
  endfor
  " let &shell = shell
endfunc

func! Test_normal23_K()
  " Test for K command
  new
  call append(0, ['version8.txt', 'man', 'aa%bb', 'cc|dd'])
  let k = &keywordprg
  set keywordprg=:help
  1
  norm! VK
  call assert_equal('version8.txt', fnamemodify(bufname('%'), ':t'))
  call assert_equal('help', &ft)
  call assert_match('\*version8.txt\*', getline('.'))
  helpclose
  norm! 0K
  call assert_equal('version8.txt', fnamemodify(bufname('%'), ':t'))
  call assert_equal('help', &ft)
  call assert_match('\*version8\.0\*', getline('.'))
  helpclose

  set keywordprg=:new
  set iskeyword+=%
  set iskeyword+=\|
  2
  norm! K
  call assert_equal('man', fnamemodify(bufname('%'), ':t'))
  bwipe!
  3
  norm! K
  call assert_equal('aa%bb', fnamemodify(bufname('%'), ':t'))
  bwipe!
  if !has('win32')
    4
    norm! K
    call assert_equal('cc|dd', fnamemodify(bufname('%'), ':t'))
    bwipe!
  endif
  set iskeyword-=%
  set iskeyword-=\|

  " Only expect "man" to work on Unix
  if !has("unix")
    let &keywordprg = k
    bw!
    return
  endif
  set keywordprg=man\ --pager=cat
  " Test for using man
  2
  let a = execute('unsilent norm! K')
  call assert_match("man --pager=cat 'man'", a)

  " clean up
  let &keywordprg = k
  bw!
endfunc

func! Test_normal24_rot13()
  " This test uses multi byte characters
  if !has("multi_byte")
    return
  endif
  " Testing for g?? g?g?
  new
  call append(0, 'abcdefghijklmnopqrstuvwxyzäüö')
  1
  norm! g??
  call assert_equal('nopqrstuvwxyzabcdefghijklmäüö', getline('.'))
  norm! g?g?
  call assert_equal('abcdefghijklmnopqrstuvwxyzäüö', getline('.'))

  " clean up
  bw!
endfunc

func! Test_normal25_tag()
  " Testing for CTRL-] g CTRL-] g]
  " CTRL-W g] CTRL-W CTRL-] CTRL-W g CTRL-]
  h
  " Test for CTRL-]
  call search('\<x\>$')
  exe "norm! \<c-]>"
  call assert_equal("change.txt", fnamemodify(bufname('%'), ':t'))
  norm! yiW
  call assert_equal("*x*", @0)
  exe ":norm \<c-o>"

  " Test for g_CTRL-]
  call search('\<v_u\>$')
  exe "norm! g\<c-]>"
  call assert_equal("change.txt", fnamemodify(bufname('%'), ':t'))
  norm! yiW
  call assert_equal("*v_u*", @0)
  exe ":norm \<c-o>"

  " Test for g]
  call search('\<i_<Esc>$')
  let a = execute(":norm! g]")
  call assert_match('i_<Esc>.*insert.txt', a)

  if !empty(exepath('cscope')) && has('cscope')
    " setting cscopetag changes how g] works
    set cst
    exe "norm! g]"
    call assert_equal("insert.txt", fnamemodify(bufname('%'), ':t'))
    norm! yiW
    call assert_equal("*i_<Esc>*", @0)
    exe ":norm \<c-o>"
    " Test for CTRL-W g]
    exe "norm! \<C-W>g]"
    call assert_equal("insert.txt", fnamemodify(bufname('%'), ':t'))
    norm! yiW
    call assert_equal("*i_<Esc>*", @0)
    call assert_equal(3, winnr('$'))
    helpclose
    set nocst
  endif

  " Test for CTRL-W g]
  let a = execute("norm! \<C-W>g]")
  call assert_match('i_<Esc>.*insert.txt', a)

  " Test for CTRL-W CTRL-]
  exe "norm! \<C-W>\<C-]>"
  call assert_equal("insert.txt", fnamemodify(bufname('%'), ':t'))
  norm! yiW
  call assert_equal("*i_<Esc>*", @0)
  call assert_equal(3, winnr('$'))
  helpclose

  " Test for CTRL-W g CTRL-]
  exe "norm! \<C-W>g\<C-]>"
  call assert_equal("insert.txt", fnamemodify(bufname('%'), ':t'))
  norm! yiW
  call assert_equal("*i_<Esc>*", @0)
  call assert_equal(3, winnr('$'))
  helpclose

  " clean up
  helpclose
endfunc

func! Test_normal26_put()
  " Test for ]p ]P [p and [P
  new
  call append(0, ['while read LINE', 'do', '  ((count++))', '  if [ $? -ne 0 ]; then', "    echo 'Error writing file'", '  fi', 'done'])
  1
  /Error/y a
  2
  norm! "a]pj"a[p
  call assert_equal(['do', "echo 'Error writing file'", "  echo 'Error writing file'", '  ((count++))'], getline(2,5))
  1
  /^\s\{4}/
  exe "norm!  \"a]P3Eldt'"
  exe "norm! j\"a[P2Eldt'"
  call assert_equal(['  if [ $? -ne 0 ]; then', "    echo 'Error writing'", "    echo 'Error'", "    echo 'Error writing file'", '  fi'], getline(6,10))

  " clean up
  bw!
endfunc

func! Test_normal27_bracket()
  " Test for [' [` ]' ]`
  call Setup_NewWindow()
  1,21s/.\+/  &   b/
  1
  norm! $ma
  5
  norm! $mb
  10
  norm! $mc
  15
  norm! $md
  20
  norm! $me

  " Test for ['
  9
  norm! 2['
  call assert_equal('  1   b', getline('.'))
  call assert_equal(1, line('.'))
  call assert_equal(3, col('.'))

  " Test for ]'
  norm! ]'
  call assert_equal('  5   b', getline('.'))
  call assert_equal(5, line('.'))
  call assert_equal(3, col('.'))

  " No mark after line 21, cursor moves to first non blank on current line
  21
  norm! $]'
  call assert_equal('  21   b', getline('.'))
  call assert_equal(21, line('.'))
  call assert_equal(3, col('.'))

  " Test for [`
  norm! 2[`
  call assert_equal('  15   b', getline('.'))
  call assert_equal(15, line('.'))
  call assert_equal(8, col('.'))

  " Test for ]`
  norm! ]`
  call assert_equal('  20   b', getline('.'))
  call assert_equal(20, line('.'))
  call assert_equal(8, col('.'))

  " clean up
  bw!
endfunc

func! Test_normal28_parenthesis()
  " basic testing for ( and )
  new
  call append(0, ['This is a test. With some sentences!', '', 'Even with a question? And one more. And no sentence here'])

  $
  norm! d(
  call assert_equal(['This is a test. With some sentences!', '', 'Even with a question? And one more. ', ''], getline(1, '$'))
  norm! 2d(
  call assert_equal(['This is a test. With some sentences!', '', ' ', ''], getline(1, '$'))
  1
  norm! 0d)
  call assert_equal(['With some sentences!', '', ' ', ''], getline(1, '$'))

  call append('$', ['This is a long sentence', '', 'spanning', 'over several lines. '])
  $
  norm! $d(
  call assert_equal(['With some sentences!', '', ' ', '', 'This is a long sentence', ''], getline(1, '$'))

  " clean up
  bw!
endfunc

fun! Test_normal29_brace()
  " basic test for { and } movements
  let text= ['A paragraph begins after each empty line, and also at each of a set of',
  \ 'paragraph macros, specified by the pairs of characters in the ''paragraphs''',
  \ 'option.  The default is "IPLPPPQPP TPHPLIPpLpItpplpipbp", which corresponds to',
  \ 'the macros ".IP", ".LP", etc.  (These are nroff macros, so the dot must be in',
  \ 'the first column).  A section boundary is also a paragraph boundary.',
  \ 'Note that a blank line (only containing white space) is NOT a paragraph',
  \ 'boundary.',
  \ '',
  \ '',
  \ 'Also note that this does not include a ''{'' or ''}'' in the first column.  When',
  \ 'the ''{'' flag is in ''cpoptions'' then ''{'' in the first column is used as a',
  \ 'paragraph boundary |posix|.',
  \ '{',
  \ 'This is no paragaraph',
  \ 'unless the ''{'' is set',
  \ 'in ''cpoptions''',
  \ '}',
  \ '.IP',
  \ 'The nroff macros IP seperates a paragraph',
  \ 'That means, it must be a ''.''',
  \ 'followed by IP',
  \ '.LPIt does not matter, if afterwards some',
  \ 'more characters follow.',
  \ '.SHAlso section boundaries from the nroff',
  \ 'macros terminate a paragraph. That means',
  \ 'a character like this:',
  \ '.NH',
  \ 'End of text here']
  new
  call append(0, text)
  1
  norm! 0d2}
  call assert_equal(['.IP',
    \  'The nroff macros IP seperates a paragraph', 'That means, it must be a ''.''', 'followed by IP',
    \ '.LPIt does not matter, if afterwards some', 'more characters follow.', '.SHAlso section boundaries from the nroff',
    \  'macros terminate a paragraph. That means', 'a character like this:', '.NH', 'End of text here', ''], getline(1,'$'))
  norm! 0d}
  call assert_equal(['.LPIt does not matter, if afterwards some', 'more characters follow.',
    \ '.SHAlso section boundaries from the nroff', 'macros terminate a paragraph. That means',
    \ 'a character like this:', '.NH', 'End of text here', ''], getline(1, '$'))
  $
  norm! d{
  call assert_equal(['.LPIt does not matter, if afterwards some', 'more characters follow.',
	\ '.SHAlso section boundaries from the nroff', 'macros terminate a paragraph. That means', 'a character like this:', ''], getline(1, '$'))
  norm! d{
  call assert_equal(['.LPIt does not matter, if afterwards some', 'more characters follow.', ''], getline(1,'$'))
  " Test with { in cpooptions
  %d
  call append(0, text)
  set cpo+={
  1
  norm! 0d2}
  call assert_equal(['{', 'This is no paragaraph', 'unless the ''{'' is set', 'in ''cpoptions''', '}',
    \ '.IP', 'The nroff macros IP seperates a paragraph', 'That means, it must be a ''.''',
    \ 'followed by IP', '.LPIt does not matter, if afterwards some', 'more characters follow.',
    \ '.SHAlso section boundaries from the nroff', 'macros terminate a paragraph. That means',
    \ 'a character like this:', '.NH', 'End of text here', ''], getline(1,'$'))
  $
  norm! d}
  call assert_equal(['{', 'This is no paragaraph', 'unless the ''{'' is set', 'in ''cpoptions''', '}',
    \ '.IP', 'The nroff macros IP seperates a paragraph', 'That means, it must be a ''.''',
    \ 'followed by IP', '.LPIt does not matter, if afterwards some', 'more characters follow.',
    \ '.SHAlso section boundaries from the nroff', 'macros terminate a paragraph. That means',
    \ 'a character like this:', '.NH', 'End of text here', ''], getline(1,'$'))
  norm! gg}
  norm! d5}
  call assert_equal(['{', 'This is no paragaraph', 'unless the ''{'' is set', 'in ''cpoptions''', '}', ''], getline(1,'$'))

  " clean up
  set cpo-={
  bw!
endfunc

fun! Test_normal30_changecase()
  " This test uses multi byte characters
  if !has("multi_byte")
    return
  endif
  new
  call append(0, 'This is a simple test: äüöß')
  norm! 1ggVu
  call assert_equal('this is a simple test: äüöß', getline('.'))
  norm! VU
  call assert_equal('THIS IS A SIMPLE TEST: ÄÜÖSS', getline('.'))
  norm! guu
  call assert_equal('this is a simple test: äüöss', getline('.'))
  norm! gUgU
  call assert_equal('THIS IS A SIMPLE TEST: ÄÜÖSS', getline('.'))
  norm! gugu
  call assert_equal('this is a simple test: äüöss', getline('.'))
  norm! gUU
  call assert_equal('THIS IS A SIMPLE TEST: ÄÜÖSS', getline('.'))
  norm! 010~
  call assert_equal('this is a SIMPLE TEST: ÄÜÖSS', getline('.'))
  norm! V~
  call assert_equal('THIS IS A simple test: äüöss', getline('.'))

  " clean up
  bw!
endfunc

fun! Test_normal31_r_cmd()
  " Test for r command
  new
  call append(0, 'This is a simple test: abcd')
  exe "norm! 1gg$r\<cr>"
  call assert_equal(['This is a simple test: abc', '', ''], getline(1,'$'))
  exe "norm! 1gg2wlr\<cr>"
  call assert_equal(['This is a', 'simple test: abc', '', ''], getline(1,'$'))
  exe "norm! 2gg0W5r\<cr>"
  call assert_equal(['This is a', 'simple ', ' abc', '', ''], getline('1', '$'))
  set autoindent
  call setline(2, ['simple test: abc', ''])
  exe "norm! 2gg0W5r\<cr>"
  call assert_equal(['This is a', 'simple ', 'abc', '', '', ''], getline('1', '$'))
  exe "norm! 1ggVr\<cr>"
  call assert_equal('^M^M^M^M^M^M^M^M^M', strtrans(getline(1)))
  call setline(1, 'This is a')
  exe "norm! 1gg05rf"
  call assert_equal('fffffis a', getline(1))

  " clean up
  set noautoindent
  bw!
endfunc

func! Test_normal32_g_cmd1()
  " Test for g*, g#
  new
  call append(0, ['abc.x_foo', 'x_foobar.abc'])
  1
  norm! $g*
  call assert_equal('x_foo', @/)
  call assert_equal('x_foobar.abc', getline('.'))
  norm! $g#
  call assert_equal('abc', @/)
  call assert_equal('abc.x_foo', getline('.'))

  " clean up
  bw!
endfunc

fun! Test_normal33_g_cmd2()
  if !has("jumplist")
    return
  endif
  " Tests for g cmds
  call Setup_NewWindow()
  " Test for g`
  clearjumps
  norm! ma10j
  let a=execute(':jumps')
  " empty jumplist
  call assert_equal('>', a[-1:])
  norm! g`a
  call assert_equal('>', a[-1:])
  call assert_equal(1, line('.'))
  call assert_equal('1', getline('.'))

  " Test for g; and g,
  norm! g;
  " there is only one change in the changelist
  " currently, when we setup the window
  call assert_equal(2, line('.'))
  call assert_fails(':norm! g;', 'E662')
  call assert_fails(':norm! g,', 'E663')
  let &ul=&ul
  call append('$', ['a', 'b', 'c', 'd'])
  let &ul=&ul
  call append('$', ['Z', 'Y', 'X', 'W'])
  let a = execute(':changes')
  call assert_match('2\s\+0\s\+2', a)
  call assert_match('101\s\+0\s\+a', a)
  call assert_match('105\s\+0\s\+Z', a)
  norm! 3g;
  call assert_equal(2, line('.'))
  norm! 2g,
  call assert_equal(105, line('.'))

  " Test for g& - global substitute
  %d
  call setline(1, range(1,10))
  call append('$', ['a', 'b', 'c', 'd'])
  $s/\w/&&/g
  exe "norm! /[1-8]\<cr>"
  norm! g&
  call assert_equal(['11', '22', '33', '44', '55', '66', '77', '88', '9', '110', 'a', 'b', 'c', 'dd'], getline(1, '$'))

  " Test for gv
  %d
  call append('$', repeat(['abcdefgh'], 8))
  exe "norm! 2gg02l\<c-v>2j2ly"
  call assert_equal(['cde', 'cde', 'cde'], getreg(0, 1, 1))
  " in visual mode, gv swaps current and last selected region
  exe "norm! G0\<c-v>4k4lgvd"
  call assert_equal(['', 'abfgh', 'abfgh', 'abfgh', 'abcdefgh', 'abcdefgh', 'abcdefgh', 'abcdefgh', 'abcdefgh'], getline(1,'$'))
  exe "norm! G0\<c-v>4k4ly"
  exe "norm! gvood"
  call assert_equal(['', 'abfgh', 'abfgh', 'abfgh', 'fgh', 'fgh', 'fgh', 'fgh', 'fgh'], getline(1,'$'))

  " Test for gk/gj
  %d
  15vsp
  set wrap listchars= sbr=
  let lineA='abcdefghijklmnopqrstuvwxyz'
  let lineB='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  $put =lineA
  $put =lineB

  norm! 3gg0dgk
  call assert_equal(['', 'abcdefghijklmno', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'], getline(1, '$'))
  set nu
  norm! 3gg0gjdgj
  call assert_equal(['', 'abcdefghijklmno', '0123456789AMNOPQRSTUVWXYZ'], getline(1,'$'))

  " Test for gJ
  norm! 2gggJ
  call assert_equal(['', 'abcdefghijklmno0123456789AMNOPQRSTUVWXYZ'], getline(1,'$'))
  call assert_equal(16, col('.'))
  " shouldn't do anything
  norm! 10gJ
  call assert_equal(1, col('.'))

  " Test for g0 g^ gm g$
  exe "norm! 2gg0gji   "
  call assert_equal(['', 'abcdefghijk   lmno0123456789AMNOPQRSTUVWXYZ'], getline(1,'$'))
  norm! g0yl
  call assert_equal(12, col('.'))
  call assert_equal(' ', getreg(0))
  norm! g$yl
  call assert_equal(22, col('.'))
  call assert_equal('3', getreg(0))
  norm! gmyl
  call assert_equal(17, col('.'))
  call assert_equal('n', getreg(0))
  norm! g^yl
  call assert_equal(15, col('.'))
  call assert_equal('l', getreg(0))

  " Test for g Ctrl-G
  set ff=unix
  let a=execute(":norm! g\<c-g>")
  call assert_match('Col 15 of 43; Line 2 of 2; Word 2 of 2; Byte 16 of 45', a)

  " Test for gI
  norm! gIfoo
  call assert_equal(['', 'fooabcdefghijk   lmno0123456789AMNOPQRSTUVWXYZ'], getline(1,'$'))

  " Test for gi
  wincmd c
  %d
  set tw=0
  call setline(1, ['foobar', 'new line'])
  norm! A next word
  $put ='third line'
  norm! gi another word
  call assert_equal(['foobar next word another word', 'new line', 'third line'], getline(1,'$'))

  " clean up
  bw!
endfunc

fun! Test_normal34_g_cmd3()
  if !has("multi_byte")
    return
  endif
  " Test for g8
  new
  call append(0, 'abcdefghijklmnopqrstuvwxyzäüö')
  let a=execute(':norm! 1gg$g8')
  call assert_equal('c3 b6 ', a[1:])

  " Test for gp gP
  call append(1, range(1,10))
  " clean up
  bw!
endfunc

fun! Test_normal35_g_cmd4()
  " Test for g<
  " Cannot capture its output,
  " probably a bug, therefore, test disabled:
  throw "Skipped: output of g< can't be tested currently"
  echo "a\nb\nc\nd"
  let b=execute(':norm! g<')
  call assert_true(!empty(b), 'failed `execute(g<)`')
endfunc

fun! Test_normal36_g_cmd5()
  new
  call append(0, 'abcdefghijklmnopqrstuvwxyz')
  set ff=unix
  " Test for gp gP
  call append(1, range(1,10))
  1
  norm! 1yy
  3
  norm! gp
  call assert_equal([0, 5, 1, 0, 1], getcurpos())
  $
  norm! gP
  call assert_equal([0, 14, 1, 0, 1], getcurpos())

  " Test for go
  norm! 26go
  call assert_equal([0, 1, 26, 0, 26], getcurpos())
  norm! 27go
  call assert_equal([0, 1, 26, 0, 26], getcurpos())
  norm! 28go
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  set ff=dos
  norm! 29go
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  set ff=unix
  norm! gg0
  norm! 101go
  call assert_equal([0, 13, 26, 0, 26], getcurpos())
  norm! 103go
  call assert_equal([0, 14, 1, 0, 1], getcurpos())
  " count > buffer content
  norm! 120go
  call assert_equal([0, 14, 1, 0, 2147483647], getcurpos())
  " clean up
  bw!
endfunc

fun! Test_normal37_g_cmd6()
  " basic test for gt and gT
  tabnew 1.txt
  tabnew 2.txt
  tabnew 3.txt
  norm! 1gt
  call assert_equal(1, tabpagenr())
  norm! 3gt
  call assert_equal(3, tabpagenr())
  norm! 1gT
  " count gT goes not to the absolute tabpagenumber
  " but, but goes to the count previous tabpagenumber
  call assert_equal(2, tabpagenr())
  " wrap around
  norm! 3gT
  call assert_equal(3, tabpagenr())
  " gt does not wrap around
  norm! 5gt
  call assert_equal(3, tabpagenr())

  for i in range(3)
    tabclose
  endfor
  " clean up
  call assert_fails(':tabclose', 'E784')
endfunc

fun! Test_normal38_nvhome()
  " Test for <Home> and <C-Home> key
  new
  call setline(1, range(10))
  $
  setl et sw=2
  norm! V10>$
  " count is ignored
  exe "norm! 10\<home>"
  call assert_equal(1, col('.'))
  exe "norm! \<home>"
  call assert_equal([0, 10, 1, 0, 1], getcurpos())
  exe "norm! 5\<c-home>"
  call assert_equal([0, 5, 1, 0, 1], getcurpos())
  exe "norm! \<c-home>"
  call assert_equal([0, 1, 1, 0, 1], getcurpos())

  " clean up
  bw!
endfunc

fun! Test_normal39_cw()
  " Test for cw and cW on whitespace
  " and cpo+=w setting
  new
  set tw=0
  call append(0, 'here      are   some words')
  norm! 1gg0elcwZZZ
  call assert_equal('hereZZZare   some words', getline('.'))
  norm! 1gg0elcWYYY
  call assert_equal('hereZZZareYYYsome words', getline('.'))
  set cpo+=w
  call setline(1, 'here      are   some words')
  norm! 1gg0elcwZZZ
  call assert_equal('hereZZZ     are   some words', getline('.'))
  norm! 1gg2elcWYYY
  call assert_equal('hereZZZ     areYYY  some words', getline('.'))
  set cpo-=w
  norm! 2gg0cwfoo
  call assert_equal('foo', getline('.'))

  " clean up
  bw!
endfunc

fun! Test_normal40_ctrl_bsl()
  " Basic test for CTRL-\ commands
  new
  call append(0, 'here      are   some words')
  exe "norm! 1gg0a\<C-\>\<C-N>"
  call assert_equal('n', mode())
  call assert_equal(1, col('.'))
  call assert_equal('', visualmode())
  exe "norm! 1gg0viw\<C-\>\<C-N>"
  call assert_equal('n', mode())
  call assert_equal(4, col('.'))
  exe "norm! 1gg0a\<C-\>\<C-G>"
  call assert_equal('n', mode())
  call assert_equal(1, col('.'))
  "imap <buffer> , <c-\><c-n>
  set im
  exe ":norm! \<c-\>\<c-n>dw"
  set noim
  call assert_equal('are   some words', getline(1))
  call assert_false(&insertmode)

  " clean up
  bw!
endfunc

fun! Test_normal41_insert_reg()
  " Test for <c-r>=, <c-r><c-r>= and <c-r><c-o>=
  " in insert mode
  new
  set sts=2 sw=2 ts=8 tw=0
  call append(0, ["aaa\tbbb\tccc", '', '', ''])
  let a=getline(1)
  norm! 2gg0
  exe "norm! a\<c-r>=a\<cr>"
  norm! 3gg0
  exe "norm! a\<c-r>\<c-r>=a\<cr>"
  norm! 4gg0
  exe "norm! a\<c-r>\<c-o>=a\<cr>"
  call assert_equal(['aaa	bbb	ccc', 'aaa bbb	ccc', 'aaa bbb	ccc', 'aaa	bbb	ccc', ''], getline(1, '$'))

  " clean up
  set sts=0 sw=8 ts=8
  bw!
endfunc

func! Test_normal42_halfpage()
  " basic test for Ctrl-D and Ctrl-U
  call Setup_NewWindow()
  call assert_equal(5, &scroll)
  exe "norm! \<c-d>"
  call assert_equal('6', getline('.'))
  exe "norm! 2\<c-d>"
  call assert_equal('8', getline('.'))
  call assert_equal(2, &scroll)
  set scroll=5
  exe "norm! \<c-u>"
  call assert_equal('3', getline('.'))
  1
  set scrolloff=5
  exe "norm! \<c-d>"
  call assert_equal('10', getline('.'))
  exe "norm! \<c-u>"
  call assert_equal('5', getline('.'))
  1
  set scrolloff=99
  exe "norm! \<c-d>"
  call assert_equal('10', getline('.'))
  set scrolloff=0
  100
  exe "norm! $\<c-u>"
  call assert_equal('95', getline('.'))
  call assert_equal([0, 95, 1, 0, 1], getcurpos())
  100
  set nostartofline
  exe "norm! $\<c-u>"
  call assert_equal('95', getline('.'))
  call assert_equal([0, 95, 2, 0, 2147483647], getcurpos())
  " cleanup
  set startofline
  bw!
endfunc

fun! Test_normal43_textobject1()
  " basic tests for text object aw
  new
  call append(0, ['foobar,eins,foobar', 'foo,zwei,foo    '])
  " diw
  norm! 1gg0diw
  call assert_equal([',eins,foobar', 'foo,zwei,foo    ', ''], getline(1,'$'))
  " daw
  norm! 2ggEdaw
  call assert_equal([',eins,foobar', 'foo,zwei,', ''], getline(1, '$'))
  %d
  call append(0, ["foo\teins\tfoobar", "foo\tzwei\tfoo   "])
  " diW
  norm! 2ggwd2iW
  call assert_equal(['foo	eins	foobar', 'foo	foo   ', ''], getline(1,'$'))
  " daW
  norm! 1ggd2aW
  call assert_equal(['foobar', 'foo	foo   ', ''], getline(1,'$'))

  %d
  call append(0, ["foo\teins\tfoobar", "foo\tzwei\tfoo   "])
  " aw in visual line mode switches to characterwise mode
  norm! 2gg$Vawd
  call assert_equal(['foo	eins	foobar', 'foo	zwei	foo'], getline(1,'$'))
  norm! 1gg$Viwd
  call assert_equal(['foo	eins	', 'foo	zwei	foo'], getline(1,'$'))

  " clean up
  bw!
endfunc

func! Test_normal44_textobjects2()
  " basic testing for is and as text objects
  new
  call append(0, ['This is a test. With some sentences!', '', 'Even with a question? And one more. And no sentence here'])
  " Test for dis - does not remove trailing whitespace
  norm! 1gg0dis
  call assert_equal([' With some sentences!', '', 'Even with a question? And one more. And no sentence here', ''], getline(1,'$'))
  " Test for das - removes leading whitespace
  norm! 3ggf?ldas
  call assert_equal([' With some sentences!', '', 'Even with a question? And no sentence here', ''], getline(1,'$'))
  " when used in visual mode, is made characterwise
  norm! 3gg$Visy
  call assert_equal('v', visualmode())
  " reset visualmode()
  norm! 3ggVy
  norm! 3gg$Vasy
  call assert_equal('v', visualmode())
  " basic testing for textobjects a< and at
  %d
  call setline(1, ['<div> ','<a href="foobar" class="foo">xyz</a>','    </div>', ' '])
  " a<
  norm! 1gg0da<
  call assert_equal([' ', '<a href="foobar" class="foo">xyz</a>', '    </div>', ' '], getline(1,'$'))
  norm! 1pj
  call assert_equal([' <div>', '<a href="foobar" class="foo">xyz</a>', '    </div>', ' '], getline(1,'$'))
  " at
  norm! d2at
  call assert_equal([' '], getline(1,'$'))
  %d
  call setline(1, ['<div> ','<a href="foobar" class="foo">xyz</a>','    </div>', ' '])
  " i<
  norm! 1gg0di<
  call assert_equal(['<> ', '<a href="foobar" class="foo">xyz</a>', '    </div>', ' '], getline(1,'$'))
  norm! 1Pj
  call assert_equal(['<div> ', '<a href="foobar" class="foo">xyz</a>', '    </div>', ' '], getline(1,'$'))
  norm! d2it
  call assert_equal(['<div></div>',' '], getline(1,'$'))
  " basic testing for a[ and i[ text object
  %d
  call setline(1, [' ', '[', 'one [two]', 'thre', ']'])
  norm! 3gg0di[
  call assert_equal([' ', '[', ']'], getline(1,'$'))
  call setline(1, [' ', '[', 'one [two]', 'thre', ']'])
  norm! 3gg0ftd2a[
  call assert_equal([' '], getline(1,'$'))
  %d
  " Test for i" when cursor is in front of a quoted object
  call append(0, 'foo "bar"')
  norm! 1gg0di"
  call assert_equal(['foo ""', ''], getline(1,'$'))

  " clean up
  bw!
endfunc

func! Test_normal45_drop()
  if !has("dnd")
    return
  endif
  " basic test for :drop command
  " unfortunately, without a gui, we can't really test much here,
  " so simply test that ~p fails (which uses the drop register)
  new
  call assert_fails(':norm! "~p', 'E353')
  call assert_equal([],  getreg('~', 1, 1))
  " the ~ register is read only
  call assert_fails(':let @~="1"', 'E354')
  bw!
endfunc

func! Test_normal46_ignore()
  " This test uses multi byte characters
  if !has("multi_byte")
    return
  endif

  new
  " How to test this?
  " let's just for now test, that the buffer
  " does not change
  call feedkeys("\<c-s>", 't')
  call assert_equal([''], getline(1,'$'))

  " no valid commands
  exe "norm! \<char-0x100>"
  call assert_equal([''], getline(1,'$'))

  exe "norm! ä"
  call assert_equal([''], getline(1,'$'))

  " clean up
  bw!
endfunc

func! Test_normal47_visual_buf_wipe()
  " This was causing a crash or ml_get error.
  enew!
  call setline(1,'xxx')
  normal $
  new
  call setline(1, range(1,2))
  2
  exe "norm \<C-V>$"
  bw!
  norm yp
  set nomodified
endfunc

func! Test_normal47_autocmd()
  " disabled, does not seem to be possible currently
  throw "Skipped: not possible to test cursorhold autocmd while waiting for input in normal_cmd"
  new
  call append(0, repeat('-',20))
  au CursorHold * call feedkeys('2l', '')
  1
  set updatetime=20
  " should delete 12 chars (d12l)
  call feedkeys('d1', '!')
  call assert_equal('--------', getline(1))

  " clean up
  au! CursorHold
  set updatetime=4000
  bw!
endfunc

func! Test_normal48_wincmd()
  new
  exe "norm! \<c-w>c"
  call assert_equal(1, winnr('$'))
  call assert_fails(":norm! \<c-w>c", "E444")
endfunc

func! Test_normal49_counts()
  new
  call setline(1, 'one two three four five six seven eight nine ten')
  1
  norm! 3d2w
  call assert_equal('seven eight nine ten', getline(1))
  bw!
endfunc

func! Test_normal50_commandline()
  if !has("timers") || !has("cmdline_hist") || !has("vertsplit")
    return
  endif
  func! DoTimerWork(id)
    call assert_equal('[Command Line]', bufname(''))
    " should fail, with E11, but does fail with E23?
    "call feedkeys("\<c-^>", 'tm')

    " should also fail with E11
    call assert_fails(":wincmd p", 'E11')
    " return from commandline window
    call feedkeys("\<cr>")
  endfunc

  let oldlang=v:lang
  lang C
  set updatetime=20
  call timer_start(100, 'DoTimerWork')
  try
    " throws E23, for whatever reason...
    call feedkeys('q:', 'x!')
  catch /E23/
    " no-op
  endtry
  " clean up
  set updatetime=4000
  exe "lang" oldlang
  bw!
endfunc

func! Test_normal51_FileChangedRO()
  if !has("autocmd")
    return
  endif
  call writefile(['foo'], 'Xreadonly.log')
  new Xreadonly.log
  setl ro
  au FileChangedRO <buffer> :call feedkeys("\<c-^>", 'tix')
  call assert_fails(":norm! Af", 'E788')
  call assert_equal(['foo'], getline(1,'$'))
  call assert_equal('Xreadonly.log', bufname(''))

  " cleanup
  bw!
  call delete("Xreadonly.log")
endfunc

func! Test_normal52_rl()
  if !has("rightleft")
    return
  endif
  new
  call setline(1, 'abcde fghij klmnopq')
  norm! 1gg$
  set rl
  call assert_equal(19, col('.'))
  call feedkeys('l', 'tx')
  call assert_equal(18, col('.'))
  call feedkeys('h', 'tx')
  call assert_equal(19, col('.'))
  call feedkeys("\<right>", 'tx')
  call assert_equal(18, col('.'))
  call feedkeys("\<s-right>", 'tx')
  call assert_equal(13, col('.'))
  call feedkeys("\<c-right>", 'tx')
  call assert_equal(7, col('.'))
  call feedkeys("\<c-left>", 'tx')
  call assert_equal(13, col('.'))
  call feedkeys("\<s-left>", 'tx')
  call assert_equal(19, col('.'))
  call feedkeys("<<", 'tx')
  call assert_equal('	abcde fghij klmnopq',getline(1))
  call feedkeys(">>", 'tx')
  call assert_equal('abcde fghij klmnopq',getline(1))

  " cleanup
  set norl
  bw!
endfunc

func! Test_normal53_digraph()
  if !has('digraphs')
    return
  endif
  new
  call setline(1, 'abcdefgh|')
  exe "norm! 1gg0f\<c-k>!!"
  call assert_equal(9, col('.'))
  set cpo+=D
  exe "norm! 1gg0f\<c-k>!!"
  call assert_equal(1, col('.'))

  set cpo-=D
  bw!
endfunc

func! Test_normal54_Ctrl_bsl()
	new
	call setline(1, 'abcdefghijklmn')
	exe "norm! df\<c-\>\<c-n>"
	call assert_equal(['abcdefghijklmn'], getline(1,'$'))
	exe "norm! df\<c-\>\<c-g>"
	call assert_equal(['abcdefghijklmn'], getline(1,'$'))
	exe "norm! df\<c-\>m"
	call assert_equal(['abcdefghijklmn'], getline(1,'$'))
  if !has("multi_byte")
    return
  endif
	call setline(2, 'abcdefghijklmnāf')
	norm! 2gg0
	exe "norm! df\<Char-0x101>"
	call assert_equal(['abcdefghijklmn', 'f'], getline(1,'$'))
	norm! 1gg0
	exe "norm! df\<esc>"
	call assert_equal(['abcdefghijklmn', 'f'], getline(1,'$'))

	" clean up
	bw!
endfunc
