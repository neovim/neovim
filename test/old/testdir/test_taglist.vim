" test taglist(), tagfiles() functions and :tags command

source view_util.vim

func Test_taglist()
  call writefile([
	\ "FFoo\tXfoo\t1",
	\ "FBar\tXfoo\t2",
	\ "BFoo\tXbar\t1",
	\ "BBar\tXbar\t2",
	\ "Kindly\tXbar\t3;\"\tv\tfile:",
	\ "Lambda\tXbar\t3;\"\tλ\tfile:",
	\ "Command\tXbar\tcall cursor(3, 4)|;\"\td",
	\ ], 'Xtags')
  set tags=Xtags
  split Xtext

  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo"), {i, v -> v.name}))
  call assert_equal(['FFoo', 'BFoo'], map("Foo"->taglist("Xtext"), {i, v -> v.name}))
  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo", "Xfoo"), {i, v -> v.name}))
  call assert_equal(['BFoo', 'FFoo'], map(taglist("Foo", "Xbar"), {i, v -> v.name}))

  let kindly = taglist("Kindly")
  call assert_equal(1, len(kindly))
  call assert_equal('v', kindly[0]['kind'])
  call assert_equal('3', kindly[0]['cmd'])
  call assert_equal(1, kindly[0]['static'])
  call assert_equal('Xbar', kindly[0]['filename'])

  let lambda = taglist("Lambda")
  call assert_equal(1, len(lambda))
  call assert_equal('λ', lambda[0]['kind'])

  let cmd = taglist("Command")
  call assert_equal(1, len(cmd))
  call assert_equal('d', cmd[0]['kind'])
  call assert_equal('call cursor(3, 4)', cmd[0]['cmd'])

  " Use characters with value > 127 in the tag extra field.
  call writefile([
	\ "vFoo\tXfoo\t4" .. ';"' .. "\ttypename:int\ta£££\tv",
	\ ], 'Xtags')
  call assert_equal('v', taglist('vFoo')[0].kind)

  call assert_fails("let l=taglist([])", 'E730:')

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
  call assert_fails('tag ' . repeat('x', 1020), ['E433', 'E426'])
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
  " Nvim: expectation(s) based on tags in build dir (added to &rtp).
  "       Filter out the '../../../runtime/doc/tags'.
  call filter(tf, 'v:val != "../../../runtime/doc/tags"')
  call assert_equal(1, len(tf))
  call assert_equal(fnamemodify(expand('$BUILD_DIR/runtime/doc/tags'), ':p:gs?\\?/?'),
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

" Check that specifying a stop directory in 'tags' works properly.
func Test_tagfiles_stopdir()
  let save_cwd = getcwd()

  call mkdir('Xtagsdir1/Xtagsdir2/Xtagsdir3', 'pR')
  call writefile([], 'Xtagsdir1/Xtags', 'D')

  cd Xtagsdir1/
  let &tags = './Xtags;' .. fnamemodify('..', ':p')
  call assert_equal(1, len(tagfiles()))

  cd Xtagsdir2/
  let &tags = './Xtags;' .. fnamemodify('..', ':p')
  call assert_equal(1, len(tagfiles()))

  cd Xtagsdir3/
  let &tags = './Xtags;' .. fnamemodify('..', ':p')
  call assert_equal(0, len(tagfiles()))

  let &tags = './Xtags;../'
  call assert_equal(0, len(tagfiles()))

  cd ..
  call assert_equal(1, len(tagfiles()))

  cd ..
  call assert_equal(1, len(tagfiles()))

  let &tags = './Xtags;..'
  call assert_equal(1, len(tagfiles()))

  cd Xtagsdir2/
  call assert_equal(1, len(tagfiles()))

  cd Xtagsdir3/
  call assert_equal(0, len(tagfiles()))

  set tags&
  call chdir(save_cwd)
endfunc

" Test for ignoring comments in a tags file
func Test_tagfile_ignore_comments()
  call writefile([
	\ "!_TAG_PROGRAM_NAME	/Test tags generator/",
	\ "FBar\tXfoo\t2" .. ';"' .. "\textrafield\tf",
	\ "!_TAG_FILE_FORMAT	2	/extended format/",
	\ ], 'Xtags')
  set tags=Xtags

  let l = taglist('.*')
  call assert_equal(1, len(l))
  call assert_equal('FBar', l[0].name)

  set tags&
  call delete('Xtags')
endfunc

" Test for using an excmd in a tags file to position the cursor (instead of a
" search pattern or a line number)
func Test_tagfile_excmd()
  call writefile([
	\ "vFoo\tXfoo\tcall cursor(3, 4)" .. '|;"' .. "\tv",
	\ ], 'Xtags')
  set tags=Xtags

  let l = taglist('.*')
  call assert_equal([{
	      \ 'cmd' : 'call cursor(3, 4)',
	      \ 'static' : 0,
	      \ 'name' : 'vFoo',
	      \ 'kind' : 'v',
	      \ 'filename' : 'Xfoo'}], l)

  set tags&
  call delete('Xtags')
endfunc

" Test for duplicate fields in a tag in a tags file
func Test_duplicate_field()
  call writefile([
	\ "vFoo\tXfoo\t4" .. ';"' .. "\ttypename:int\ttypename:int\tv",
	\ ], 'Xtags')
  set tags=Xtags

  let l = taglist('.*')
  call assert_equal([{
	      \ 'cmd' : '4',
	      \ 'static' : 0,
	      \ 'name' : 'vFoo',
	      \ 'kind' : 'v',
	      \ 'typename' : 'int',
	      \ 'filename' : 'Xfoo'}], l)

  set tags&
  call delete('Xtags')
endfunc

" Test for tag address with ;
func Test_tag_addr_with_semicolon()
  call writefile([
	      \ "Func1\tXfoo\t6;/^Func1/" .. ';"' .. "\tf"
	      \ ], 'Xtags')
  set tags=Xtags

  let l = taglist('.*')
  call assert_equal([{
	      \ 'cmd' : '6;/^Func1/',
	      \ 'static' : 0,
	      \ 'name' : 'Func1',
	      \ 'kind' : 'f',
	      \ 'filename' : 'Xfoo'}], l)

  set tags&
  call delete('Xtags')
endfunc

" Test for format error in a tags file
func Test_format_error()
  call writefile(['vFoo-Xfoo-4'], 'Xtags')
  set tags=Xtags

  let caught_exception = v:false
  try
    let l = taglist('.*')
  catch /E431:/
    " test succeeded
    let caught_exception = v:true
  catch
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry
  call assert_true(caught_exception)

  " no field after the filename for a tag
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "foo\tXfile"], 'Xtags')
  call assert_fails("echo taglist('foo')", 'E431:')

  set tags&
  call delete('Xtags')
endfunc

" Test for :tag command completion with 'wildoptions' set to 'tagfile'
func Test_tag_complete_wildoptions()
  call writefile(["foo\ta.c\t10;\"\tf", "bar\tb.c\t20;\"\td"], 'Xtags')
  set tags=Xtags
  set wildoptions=tagfile

  call feedkeys(":tag \<C-D>\<C-R>=Screenline(&lines - 1)\<CR> : "
        \ .. "\<C-R>=Screenline(&lines - 2)\<CR>\<C-B>\"\<CR>", 'xt')

  call assert_equal('"tag bar d b.c : foo f a.c', @:)

  call delete('Xtags')
  set wildoptions&
  set tags&
endfunc

func Test_tag_complete_with_overlong_line()
  let tagslines =<< trim END
      !_TAG_FILE_FORMAT	2	//
      !_TAG_FILE_SORTED	1	//
      !_TAG_FILE_ENCODING	utf-8	//
      inboundGSV	a	1;"	r
      inboundGovernor	a	2;"	kind:⊢	type:forall (muxMode :: MuxMode) socket peerAddr versionNumber m a b. (MonadAsync m, MonadCatch m, MonadEvaluate m, MonadThrow m, MonadThrow (STM m), MonadTime m, MonadTimer m, MonadMask m, Ord peerAddr, HasResponder muxMode ~ True) => Tracer m (RemoteTransitionTrace peerAddr) -> Tracer m (InboundGovernorTrace peerAddr) -> ServerControlChannel muxMode peerAddr ByteString m a b -> DiffTime -> MuxConnectionManager muxMode socket peerAddr versionNumber ByteString m a b -> StrictTVar m InboundGovernorObservableState -> m Void
      inboundGovernorCounters	a	3;"	kind:⊢	type:InboundGovernorState muxMode peerAddr m a b -> InboundGovernorCounters
  END
  call writefile(tagslines, 'Xtags')
  set tags=Xtags

  " try with binary search
  set tagbsearch
  call feedkeys(":tag inbou\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"tag inboundGSV inboundGovernor inboundGovernorCounters', @:)
  " try with linear search
  set notagbsearch
  call feedkeys(":tag inbou\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"tag inboundGSV inboundGovernor inboundGovernorCounters', @:)
  set tagbsearch&

  call delete('Xtags')
  set tags&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
