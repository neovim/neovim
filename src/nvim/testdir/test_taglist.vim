" test taglist(), tagfiles() functions and :tags command

func Test_taglist()
  call writefile([
	\ "FFoo\tXfoo\t1",
	\ "FBar\tXfoo\t2",
	\ "BFoo\tXbar\t1",
	\ "BBar\tXbar\t2",
	\ "Kindly\tXbar\t3;\"\tv\tfile:",
	\ "Command\tXbar\tcall cursor(3, 4)|;\"\td",
	\ ], 'Xtags')
  set tags=Xtags
  split Xtext

  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo"), {i, v -> v.name}))
  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo", "Xtext"), {i, v -> v.name}))
  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo", "Xfoo"), {i, v -> v.name}))
  call assert_equal(['BFoo', 'FFoo'], map(taglist("Foo", "Xbar"), {i, v -> v.name}))

  let kind = taglist("Kindly")
  call assert_equal(1, len(kind))
  call assert_equal('v', kind[0]['kind'])
  call assert_equal('3', kind[0]['cmd'])
  call assert_equal(1, kind[0]['static'])
  call assert_equal('Xbar', kind[0]['filename'])

  let cmd = taglist("Command")
  call assert_equal(1, len(cmd))
  call assert_equal('d', cmd[0]['kind'])
  call assert_equal('call cursor(3, 4)', cmd[0]['cmd'])

  call delete('Xtags')
  set tags&
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
  set tags&
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
  set tags&
endfunc

func Test_tags_too_long()
  call assert_fails('tag ' . repeat('x', 1020), 'E426')
  tags
endfunc

func Test_tagfiles()
  call assert_equal([], tagfiles())

  call writefile(["FFoo\tXfoo\t1"], 'Xtags1')
  call writefile(["FBar\tXbar\t1"], 'Xtags2')
  set tags=Xtags1,Xtags2
  call assert_equal(['Xtags1', 'Xtags2'], tagfiles())

  help
  let tf = tagfiles()
  call assert_equal(1, len(tf))
  call assert_equal(fnamemodify(expand('$VIMRUNTIME/doc/tags'), ':p:gs?\\?/?'),
	\           fnamemodify(tf[0], ':p:gs?\\?/?'))
  helpclose
  call assert_equal(['Xtags1', 'Xtags2'], tagfiles())
  " Nvim: defaults to "./tags;,tags", which might cause false positives.
  set tags=./tags,tags
  call assert_equal([], tagfiles())

  call delete('Xtags1')
  call delete('Xtags2')
  bd
endfunc

" For historical reasons we support a tags file where the last line is missing
" the newline.
func Test_tagsfile_without_trailing_newline()
  call writefile(["Foo\tfoo\t1"], 'Xtags', 'b')
  set tags=Xtags

  let tl = taglist('.*')
  call assert_equal(1, len(tl))
  call assert_equal('Foo', tl[0].name)

  call delete('Xtags')
  set tags&
endfunc
