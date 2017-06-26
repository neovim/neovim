" test 'taglist' function

func Test_taglist()
  call writefile([
	\ "FFoo\tXfoo\t1",
	\ "FBar\tXfoo\t2",
	\ "BFoo\tXbar\t1",
	\ "BBar\tXbar\t2"
	\ ], 'Xtags')
  set tags=Xtags
  split Xtext

  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo"), {i, v -> v.name}))
  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo", "Xtext"), {i, v -> v.name}))
  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo", "Xfoo"), {i, v -> v.name}))
  call assert_equal(['BFoo', 'FFoo'], map(taglist("Foo", "Xbar"), {i, v -> v.name}))

  call delete('Xtags')
  bwipe
endfunc

func Test_taglist_native_etags()
  if !has('emacs_tags')
    return
  endif
  call writefile([
	\ "\x0c",
	\ "src/os_unix.c,13491",
	\ "set_signals(\x7f1335,32699",
	\ "reset_signals(\x7f1407,34136",
	\ ], 'Xtags')

  set tags=Xtags

  call assert_equal([['set_signals', '1335,32699'], ['reset_signals', '1407,34136']],
	\ map(taglist('set_signals'), {i, v -> [v.name, v.cmd]}))

  call delete('Xtags')
endfunc

func Test_taglist_ctags_etags()
  if !has('emacs_tags')
    return
  endif
  call writefile([
	\ "\x0c",
	\ "src/os_unix.c,13491",
	\ "set_signals(void)\x7fset_signals\x011335,32699",
	\ "reset_signals(void)\x7freset_signals\x011407,34136",
	\ ], 'Xtags')

  set tags=Xtags

  call assert_equal([['set_signals', '1335,32699'], ['reset_signals', '1407,34136']],
	\ map(taglist('set_signals'), {i, v -> [v.name, v.cmd]}))

  call delete('Xtags')
endfunc
