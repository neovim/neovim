" Test for Select-mode

source shared.vim

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

" vim: shiftwidth=2 sts=2 expandtab
