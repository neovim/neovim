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

" vim: shiftwidth=2 sts=2 expandtab
