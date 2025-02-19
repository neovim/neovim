" Test for Select-mode

source check.vim
" CheckNotGui
" CheckUnix

source shared.vim
source mouse.vim

" Test for select mode
func Test_selectmode_basic()
  new
  call setline(1, range(1,100))
  50
  norm! gHy
  call assert_equal('y51', getline('.'))
  call setline(1, range(1,100))
  50
  exe ":norm! V9jo\<c-g>y"
  call assert_equal('y60', getline('.'))
  call setline(1, range(1,100))
  50
  " call feedkeys(":set im\n\<c-o>gHc\<c-o>:set noim\n", 'tx')
  call feedkeys("i\<c-o>gHc\<esc>", 'tx')
  call assert_equal('c51', getline('.'))
  " clean up
  bw!
endfunc

" Test for starting selectmode
func Test_selectmode_start()
  new
  set selectmode=key keymodel=startsel
  call setline(1, ['abc', 'def', 'ghi'])
  call cursor(1, 4)
  call feedkeys("A\<s-home>start\<esc>", 'txin')
  call assert_equal(['startdef', 'ghi'], getline(1, '$'))
  " start select mode again with gv
  set selectmode=cmd
  call feedkeys('gvabc', 'xt')
  call assert_equal('abctdef', getline(1))
  " arrow keys without shift should not start selection
  call feedkeys("A\<Home>\<Right>\<Left>ro", 'xt')
  call assert_equal('roabctdef', getline(1))
  set selectmode= keymodel=
  bw!
endfunc

" Test for characterwise select mode
func Test_characterwise_select_mode()
  new

  " Select mode maps
  snoremap <lt>End> <End>
  snoremap <lt>Down> <Down>
  snoremap <lt>Del> <Del>

  " characterwise select mode: delete middle line
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal Gkkgh\<End>\<Del>"
  call assert_equal(['', 'b', 'c'], getline(1, '$'))

  " characterwise select mode: delete middle two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal Gkkgh\<Down>\<End>\<Del>"
  call assert_equal(['', 'c'], getline(1, '$'))

  " characterwise select mode: delete last line
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal Ggh\<End>\<Del>"
  call assert_equal(['', 'a', 'b', ''], getline(1, '$'))

  " characterwise select mode: delete last two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal Gkgh\<Down>\<End>\<Del>"
  call assert_equal(['', 'a', ''], getline(1, '$'))

  " CTRL-H in select mode behaves like 'x'
  call setline(1, 'abcdef')
  exe "normal! gggh\<Right>\<Right>\<Right>\<C-H>"
  call assert_equal('ef', getline(1))

  " CTRL-O in select mode switches to visual mode for one command
  call setline(1, 'abcdef')
  exe "normal! gggh\<C-O>3lm"
  call assert_equal('mef', getline(1))

  sunmap <lt>End>
  sunmap <lt>Down>
  sunmap <lt>Del>
  bwipe!
endfunc

" Test for linewise select mode
func Test_linewise_select_mode()
  new

  " linewise select mode: delete middle line
  call append('$', ['a', 'b', 'c'])
  exe "normal GkkgH\<Del>"
  call assert_equal(['', 'b', 'c'], getline(1, '$'))

  " linewise select mode: delete middle two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal GkkgH\<Down>\<Del>"
  call assert_equal(['', 'c'], getline(1, '$'))

  " linewise select mode: delete last line
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal GgH\<Del>"
  call assert_equal(['', 'a', 'b'], getline(1, '$'))

  " linewise select mode: delete last two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal GkgH\<Down>\<Del>"
  call assert_equal(['', 'a'], getline(1, '$'))

  bwipe!
endfunc

" Test for blockwise select mode (g CTRL-H)
func Test_blockwise_select_mode()
  new
  call setline(1, ['foo', 'bar'])
  call feedkeys("g\<BS>\<Right>\<Down>mm", 'xt')
  call assert_equal(['mmo', 'mmr'], getline(1, '$'))
  close!
endfunc

" Test for using visual mode maps in select mode
func Test_select_mode_map()
  new
  vmap <buffer> <F2> 3l
  call setline(1, 'Test line')
  call feedkeys("gh\<F2>map", 'xt')
  call assert_equal('map line', getline(1))

  vmap <buffer> <F2> ygV
  call feedkeys("0gh\<Right>\<Right>\<F2>cwabc", 'xt')
  call assert_equal('abc line', getline(1))

  vmap <buffer> <F2> :<C-U>let v=100<CR>
  call feedkeys("gggh\<Right>\<Right>\<F2>foo", 'xt')
  call assert_equal('foo line', getline(1))

  " reselect the select mode using gv from a visual mode map
  vmap <buffer> <F2> gv
  set selectmode=cmd
  call feedkeys("0gh\<F2>map", 'xt')
  call assert_equal('map line', getline(1))
  set selectmode&

  close!
endfunc

" Test double/triple/quadruple click to start 'select' mode
func Test_term_mouse_multiple_clicks_to_select_mode()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)

  " 'mousetime' must be sufficiently large, or else the test is flaky when
  " using a ssh connection with X forwarding; i.e. ssh -X.
  " set mouse=a term=xterm mousetime=1000
  set mouse=a mousetime=1000
  set selectmode=mouse
  new

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val

    " Single-click and drag should 'select' the characters
    call setline(1, ['foo [foo bar] foo', 'foo'])
    call MouseLeftClick(1, 3)
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftDrag(1, 13)
    call MouseLeftRelease(1, 13)
    norm! o
    call assert_equal(['foo foo', 'foo'], getline(1, '$'), msg)

    " Double-click on word should visually 'select' the word.
    call setline(1, ['foo [foo bar] foo', 'foo'])
    call MouseLeftClick(1, 2)
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftRelease(1, 2)
    call MouseLeftClick(1, 2)
    call assert_equal(32, getcharmod(), msg) " double-click
    call MouseLeftRelease(1, 2)
    call assert_equal('s', mode(), msg)
    norm! bar
    call assert_equal(['bar [foo bar] foo', 'foo'], getline(1, '$'), msg)

    " Double-click on opening square bracket should visually
    " 'select' the whole [foo bar].
    call setline(1, ['foo [foo bar] foo', 'foo'])
    call MouseLeftClick(1, 5)
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftRelease(1, 5)
    call MouseLeftClick(1, 5)
    call assert_equal(32, getcharmod(), msg) " double-click
    call MouseLeftRelease(1, 5)
    call assert_equal('s', mode(), msg)
    norm! bar
    call assert_equal(['foo bar foo', 'foo'], getline(1, '$'), msg)

    " To guarantee that the next click is not counted as a triple click
    call MouseRightClick(1, 1)
    call MouseRightRelease(1, 1)

    " Triple-click should visually 'select' the whole line.
    call setline(1, ['foo [foo bar] foo', 'foo'])
    call MouseLeftClick(1, 3)
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftRelease(1, 3)
    call MouseLeftClick(1, 3)
    call assert_equal(32, getcharmod(), msg) " double-click
    call MouseLeftRelease(1, 3)
    call MouseLeftClick(1, 3)
    call assert_equal(64, getcharmod(), msg) " triple-click
    call MouseLeftRelease(1, 3)
    call assert_equal('S', mode(), msg)
    norm! baz
    call assert_equal(['bazfoo'], getline(1, '$'), msg)

    " Quadruple-click should start visual block 'select'.
    call setline(1, ['aaaaaa', 'bbbbbb'])
    call MouseLeftClick(1, 2)
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftRelease(1, 2)
    call MouseLeftClick(1, 2)
    call assert_equal(32, getcharmod(), msg) " double-click
    call MouseLeftRelease(1, 2)
    call MouseLeftClick(1, 2)
    call assert_equal(64, getcharmod(), msg) " triple-click
    call MouseLeftRelease(1, 2)
    call MouseLeftClick(1, 2)
    call assert_equal(96, getcharmod(), msg) " quadruple-click
    call MouseLeftDrag(2, 4)
    call MouseLeftRelease(2, 4)
    call assert_equal("\<c-s>", mode(), msg)
    norm! x
    call assert_equal(['axaa', 'bxbb'], getline(1, '$'), msg)
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  set mousetime&
  set selectmode&
  " call test_override('no_query_mouse', 0)
  bwipe!
endfunc

" Test for selecting a register with CTRL-R
func Test_selectmode_register()
  new

  " Default behavior: use unnamed register
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>a"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('f', getreg('"'))
  call assert_equal('baz', getreg('a'))

  " Use the black hole register
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>\<c-r>_a"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('bar', getreg('"'))
  call assert_equal('baz', getreg('a'))

  " Invalid register: use unnamed register
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>\<c-r>?a"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('f', getreg('"'))
  call assert_equal('baz', getreg('a'))

  " Use unnamed register
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>\<c-r>\"a"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('f', getreg('"'))
  call assert_equal('baz', getreg('a'))

  " use specicifed register, unnamed register is also written
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>\<c-r>aa"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('f', getreg('"'))
  call assert_equal('f', getreg('a'))

  bw!
endfunc

func Test_ins_ctrl_o_in_insert_mode_resets_selectmode()
  new
  " ctrl-o in insert mode resets restart_VIsual_select
  call setline(1, 'abcdef')
  call cursor(1, 1)
  exe "norm! \<c-v>\<c-g>\<c-o>c\<c-o>\<c-v>\<right>\<right>IABC"
  call assert_equal('ABCbcdef', getline(1))

  bwipe!
endfunc

" Test that an :lmap mapping for a printable keypad key is applied when typing
" it in Select mode.
func Test_selectmode_keypad_lmap()
  new
  lnoremap <buffer> <kPoint> ???
  lnoremap <buffer> <kEnter> !!!
  setlocal iminsert=1
  call setline(1, 'abcdef')
  call feedkeys("gH\<kPoint>\<Esc>", 'tx')
  call assert_equal(['???'], getline(1, '$'))
  call feedkeys("gH\<kEnter>\<Esc>", 'tx')
  call assert_equal(['!!!'], getline(1, '$'))

  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
