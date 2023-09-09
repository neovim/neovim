" Tests for character input and feedkeys() function.

func Test_feedkeys_x_with_empty_string()
  new
  call feedkeys("ifoo\<Esc>")
  call assert_equal('', getline('.'))
  call feedkeys('', 'x')
  call assert_equal('foo', getline('.'))

  " check it goes back to normal mode immediately.
  call feedkeys('i', 'x')
  call assert_equal('foo', getline('.'))
  quit!
endfunc

func Test_feedkeys_with_abbreviation()
  new
  inoreabbrev trigger value
  call feedkeys("atrigger ", 'x')
  call feedkeys("atrigger ", 'x')
  call assert_equal('value value ', getline(1))
  bwipe!
  iunabbrev trigger
endfunc

func Test_feedkeys_escape_special()
  nnoremap … <Cmd>let g:got_ellipsis += 1<CR>
  call feedkeys('…', 't')
  call assert_equal('…', getcharstr())
  let g:got_ellipsis = 0
  call feedkeys('…', 'xt')
  call assert_equal(1, g:got_ellipsis)
  unlet g:got_ellipsis
  nunmap …
endfunc

func Test_input_simplify_ctrl_at()
  new
  " feeding unsimplified CTRL-@ should still trigger i_CTRL-@
  call feedkeys("ifoo\<Esc>A\<*C-@>x", 'xt')
  call assert_equal('foofo', getline(1))
  bw!
endfunc

func Test_input_simplify_noremap()
  call feedkeys("i\<*C-M>", 'nx')
  call assert_equal('', getline(1))
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  bw!
endfunc

func Test_input_simplify_timedout()
  inoremap <C-M>a b
  call feedkeys("i\<*C-M>", 'xt')
  call assert_equal('', getline(1))
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  iunmap <C-M>a
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
