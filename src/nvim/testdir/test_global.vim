
func Test_yank_put_clipboard()
  new
  call setline(1, ['a', 'b', 'c'])
  set clipboard=unnamed
  g/^/normal yyp
  call assert_equal(['a', 'a', 'b', 'b', 'c', 'c'], getline(1, 6))

  set clipboard&
  bwipe!
endfunc
