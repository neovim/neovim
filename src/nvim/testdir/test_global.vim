source check.vim

func Test_yank_put_clipboard()
  new
  call setline(1, ['a', 'b', 'c'])
  set clipboard=unnamed
  g/^/normal yyp
  call assert_equal(['a', 'a', 'b', 'b', 'c', 'c'], getline(1, 6))

  set clipboard&
  bwipe!
endfunc

func Test_global_set_clipboard()
  CheckFeature clipboard_working
  new
  set clipboard=unnamedplus
  let @+='clipboard' | g/^/set cb= | let @" = 'unnamed' | put
  call assert_equal(['','unnamed'], getline(1, '$'))
  set clipboard&
  bwipe!
endfunc

func Test_nested_global()
  new
  call setline(1, ['nothing', 'found', 'found bad', 'bad'])
  call assert_fails('g/found/3v/bad/s/^/++/', 'E147')
  g/found/v/bad/s/^/++/
  call assert_equal(['nothing', '++found', 'found bad', 'bad'], getline(1, 4))
  bwipe!
endfunc
