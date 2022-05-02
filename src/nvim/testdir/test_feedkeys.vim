" Test feedkeys() function.

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

" vim: shiftwidth=2 sts=2 expandtab
