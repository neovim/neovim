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

func Test_global_error()
  call assert_fails('g\\a', 'E10:')
  call assert_fails('g', 'E148:')
  call assert_fails('g/\(/y', 'E476:')
endfunc

" Test for printing lines using :g with different search patterns
func Test_global_print()
  new
  call setline(1, ['foo', 'bar', 'foo', 'foo'])
  let @/ = 'foo'
  let t = execute("g/")->trim()->split("\n")
  call assert_equal(['foo', 'foo', 'foo'], t)

  " Test for Vi compatible patterns
  let @/ = 'bar'
  let t = execute('g\/')->trim()->split("\n")
  call assert_equal(['bar'], t)

  normal gg
  s/foo/foo/
  let t = execute('g\&')->trim()->split("\n")
  call assert_equal(['foo', 'foo', 'foo'], t)

  let @/ = 'bar'
  let t = execute('g?')->trim()->split("\n")
  call assert_equal(['bar'], t)

  " Test for the 'Pattern found in every line' message
  let v:statusmsg = ''
  v/foo\|bar/p
  call assert_notequal('', v:statusmsg)

  close!
endfunc

func Test_wrong_delimiter()
  call assert_fails('g x^bxd', 'E146:')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
