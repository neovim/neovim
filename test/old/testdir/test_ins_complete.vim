" Test for insert completion

source screendump.vim
source check.vim
source vim9.vim

" Test for insert expansion
func Test_ins_complete()
  edit test_ins_complete.vim
  " The files in the current directory interferes with the files
  " used by this test. So use a separate directory for the test.
  call mkdir('Xdir')
  cd Xdir

  set ff=unix
  call writefile(["test11\t36Gepeto\t/Tag/",
	      \ "asd\ttest11file\t36G",
	      \ "Makefile\tto\trun"], 'Xtestfile')
  call writefile(['', 'start of testfile',
	      \ 'ru',
	      \ 'run1',
	      \ 'run2',
	      \ 'STARTTEST',
	      \ 'ENDTEST',
	      \ 'end of testfile'], 'Xtestdata')
  set ff&

  enew!
  edit Xtestdata
  new
  call append(0, ['#include "Xtestfile"', ''])
  call cursor(2, 1)

  set cot=
  set cpt=.,w
  " add-expands (word from next line) from other window
  exe "normal iru\<C-N>\<C-N>\<C-X>\<C-N>\<Esc>\<C-A>"
  call assert_equal('run1 run3', getline('.'))
  " add-expands (current buffer first)
  exe "normal o\<C-P>\<C-X>\<C-N>"
  call assert_equal('run3 run3', getline('.'))
  " Local expansion, ends in an empty line (unless it becomes a global
  " expansion)
  exe "normal o\<C-X>\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>"
  call assert_equal('', getline('.'))
  " starts Local and switches to global add-expansion
  exe "normal o\<C-X>\<C-P>\<C-P>\<C-X>\<C-X>\<C-N>\<C-X>\<C-N>\<C-N>"
  call assert_equal('run1 run2', getline('.'))

  set cpt=.,\ ,w,i
  " i-add-expands and switches to local
  exe "normal OM\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>\<C-X>\<C-X>\<C-X>\<C-P>"
  call assert_equal("Makefile\tto\trun3", getline('.'))
  " add-expands lines (it would end in an empty line if it didn't ignore
  " itself)
  exe "normal o\<C-X>\<C-L>\<C-X>\<C-L>\<C-P>\<C-P>"
  call assert_equal("Makefile\tto\trun3", getline('.'))
  call assert_equal("Makefile\tto\trun3", getline(line('.') - 1))

  set cpt=kXtestfile
  " checks k-expansion, and file expansion (use Xtest11 instead of test11,
  " because TEST11.OUT may match first on DOS)
  write Xtest11.one
  write Xtest11.two
  exe "normal o\<C-N>\<Esc>IX\<Esc>A\<C-X>\<C-F>\<C-N>"
  call assert_equal('Xtest11.two', getline('.'))

  " use CTRL-X CTRL-F to complete Xtest11.one, remove it and then use CTRL-X
  " CTRL-F again to verify this doesn't cause trouble.
  exe "normal oXt\<C-X>\<C-F>\<BS>\<BS>\<BS>\<BS>\<BS>\<BS>\<BS>\<BS>\<C-X>\<C-F>"
  call assert_equal('Xtest11.one', getline('.'))
  normal ddk

  " Test for expanding a non-existing filename
  exe "normal oa1b2X3Y4\<C-X>\<C-F>"
  call assert_equal('a1b2X3Y4', getline('.'))
  normal ddk

  set cpt=w
  " checks make_cyclic in other window
  exe "normal oST\<C-N>\<C-P>\<C-P>\<C-P>\<C-P>"
  call assert_equal('STARTTEST', getline('.'))

  set cpt=u nohid
  " checks unloaded buffer expansion
  only
  exe "normal oEN\<C-N>"
  call assert_equal('ENDTEST', getline('.'))
  " checks adding mode abortion
  exe "normal ounl\<C-N>\<C-X>\<C-X>\<C-P>"
  call assert_equal('unless', getline('.'))

  set cpt=t,d def=^\\k* tags=Xtestfile notagbsearch
  " tag expansion, define add-expansion interrupted
  exe "normal o\<C-X>\<C-]>\<C-X>\<C-D>\<C-X>\<C-D>\<C-X>\<C-X>\<C-D>\<C-X>\<C-D>\<C-X>\<C-D>\<C-X>\<C-D>"
  call assert_equal('test11file	36Gepeto	/Tag/ asd', getline('.'))
  " t-expansion
  exe "normal oa\<C-N>\<Esc>"
  call assert_equal('asd', getline('.'))

  %bw!
  call delete('Xtestfile')
  call delete('Xtest11.one')
  call delete('Xtest11.two')
  call delete('Xtestdata')
  set cpt& cot& def& tags& tagbsearch& hidden&
  cd ..
  call delete('Xdir', 'rf')
endfunc

func Test_ins_complete_invalid_byte()
  if has('unix') && executable('base64')
    " this weird command was causing an illegal memory access
    call writefile(['bm9ybTlvMDCAMM4Dbw4OGA4ODg=='], 'Xinvalid64')
    call system('base64 -d Xinvalid64 > Xinvalid')
    call writefile(['qa!'], 'Xexit')
    call RunVim([], [], " -i NONE -n -X -Z -e -m -s -S Xinvalid -S Xexit")
    call delete('Xinvalid64')
    call delete('Xinvalid')
    call delete('Xexit')
  endif
endfunc

func Test_omni_dash()
  func Omni(findstart, base)
    if a:findstart
        return 5
    else
        echom a:base
	return ['-help', '-v']
    endif
  endfunc
  set omnifunc=Omni
  new
  exe "normal Gofind -\<C-x>\<C-o>"
  call assert_equal("find -help", getline('$'))

  bwipe!
  delfunc Omni
  set omnifunc=
endfunc

func Test_omni_throw()
  let g:CallCount = 0
  func Omni(findstart, base)
    let g:CallCount += 1
    if a:findstart
      throw "he he he"
    endif
  endfunc
  set omnifunc=Omni
  new
  try
    exe "normal ifoo\<C-x>\<C-o>"
    call assert_false(v:true, 'command should have failed')
  catch
    call assert_exception('he he he')
    call assert_equal(1, g:CallCount)
  endtry

  bwipe!
  delfunc Omni
  unlet g:CallCount
  set omnifunc=
endfunc

func Test_completefunc_args()
  let s:args = []
  func! CompleteFunc(findstart, base)
    let s:args += [[a:findstart, empty(a:base)]]
  endfunc
  new

  set completefunc=CompleteFunc
  call feedkeys("i\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([1, 1], s:args[0])
  call assert_equal(0, s:args[1][0])
  set completefunc=

  let s:args = []
  set omnifunc=CompleteFunc
  call feedkeys("i\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([1, 1], s:args[0])
  call assert_equal(0, s:args[1][0])
  set omnifunc=

  bwipe!
  unlet s:args
  delfunc CompleteFunc
endfunc

func s:CompleteDone_CompleteFuncNone( findstart, base )
  throw 'skipped: Nvim does not support v:none'
  if a:findstart
    return 0
  endif

  return v:none
endfunc

func s:CompleteDone_CompleteFuncDict( findstart, base )
  if a:findstart
    return 0
  endif

  return {
	  \ 'words': [
	    \ {
	      \ 'word': 'aword',
	      \ 'abbr': 'wrd',
	      \ 'menu': 'extra text',
	      \ 'info': 'words are cool',
	      \ 'kind': 'W',
	      \ 'user_data': ['one', 'two']
	    \ }
	  \ ]
	\ }
endfunc

func s:CompleteDone_CheckCompletedItemNone()
  let s:called_completedone = 1
endfunc

func s:CompleteDone_CheckCompletedItemDict(pre)
  call assert_equal( 'aword',          v:completed_item[ 'word' ] )
  call assert_equal( 'wrd',            v:completed_item[ 'abbr' ] )
  call assert_equal( 'extra text',     v:completed_item[ 'menu' ] )
  call assert_equal( 'words are cool', v:completed_item[ 'info' ] )
  call assert_equal( 'W',              v:completed_item[ 'kind' ] )
  call assert_equal( ['one', 'two'],   v:completed_item[ 'user_data' ] )

  if a:pre
    call assert_equal('function', complete_info().mode)
  endif

  let s:called_completedone = 1
endfunc

func Test_CompleteDoneNone()
  throw 'skipped: Nvim does not support v:none'
  au CompleteDone * :call <SID>CompleteDone_CheckCompletedItemNone()
  let oldline = join(map(range(&columns), 'nr2char(screenchar(&lines-1, v:val+1))'), '')

  set completefunc=<SID>CompleteDone_CompleteFuncNone
  execute "normal a\<C-X>\<C-U>\<C-Y>"
  set completefunc&
  let newline = join(map(range(&columns), 'nr2char(screenchar(&lines-1, v:val+1))'), '')

  call assert_true(s:called_completedone)
  call assert_equal(oldline, newline)

  let s:called_completedone = 0
  au! CompleteDone
endfunc

func Test_CompleteDone_vevent_keys()
  func OnDone()
    let g:complete_word = get(v:event, 'complete_word', v:null)
    let g:complete_type = get(v:event, 'complete_type', v:null)
  endfunction

  autocmd CompleteDone * :call OnDone()

  func CompleteFunc(findstart, base)
    if a:findstart
      return col(".")
    endif
    return [#{word: "foo"}, #{word: "bar"}]
  endfunc
  set omnifunc=CompleteFunc
  set completefunc=CompleteFunc
  set completeopt+=menuone

  new
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'tx')
  call assert_equal('', g:complete_word)
  call assert_equal('omni', g:complete_type)

  call feedkeys("S\<C-X>\<C-O>\<C-Y>\<Esc>", 'tx')
  call assert_equal('foo', g:complete_word)
  call assert_equal('omni', g:complete_type)

  call feedkeys("S\<C-X>\<C-O>\<C-N>\<C-Y>\<Esc>0", 'tx')
  call assert_equal('bar', g:complete_word)
  call assert_equal('omni', g:complete_type)

  call feedkeys("Shello vim visual v\<C-X>\<C-N>\<ESC>", 'tx')
  call assert_equal('', g:complete_word)
  call assert_equal('keyword', g:complete_type)

  call feedkeys("Shello vim visual v\<C-X>\<C-N>\<C-Y>", 'tx')
  call assert_equal('vim', g:complete_word)
  call assert_equal('keyword', g:complete_type)

  call feedkeys("Shello vim visual v\<C-X>\<C-N>\<C-Y>", 'tx')
  call assert_equal('vim', g:complete_word)
  call assert_equal('keyword', g:complete_type)

  call feedkeys("Shello vim\<CR>completion test\<CR>\<C-X>\<C-l>\<C-Y>", 'tx')
  call assert_equal('completion test', g:complete_word)
  call assert_equal('whole_line', g:complete_type)

  call feedkeys("S\<C-X>\<C-U>\<C-Y>", 'tx')
  call assert_equal('foo', g:complete_word)
  call assert_equal('function', g:complete_type)

  inoremap <buffer> <f3> <cmd>call complete(1, ["red", "blue"])<cr>
  call feedkeys("S\<f3>\<C-Y>", 'tx')
  call assert_equal('red', g:complete_word)
  call assert_equal('eval', g:complete_type)

  call feedkeys("S\<C-X>\<C-V>\<C-Y>", 'tx')
  call assert_equal('!', g:complete_word)
  call assert_equal('cmdline', g:complete_type)

  call writefile([''], 'foo_test', 'D')
  call feedkeys("Sfoo\<C-X>\<C-F>\<C-Y>\<Esc>", 'tx')
  call assert_equal('foo_test', g:complete_word)
  call assert_equal('files', g:complete_type)

  call writefile(['hello help'], 'test_case.txt', 'D')
  set dictionary=test_case.txt
  call feedkeys("ggdGSh\<C-X>\<C-K>\<C-Y>\<Esc>", 'tx')
  call assert_equal('hello', g:complete_word)
  call assert_equal('dictionary', g:complete_type)

  set spell spelllang=en_us
  call feedkeys("STheatre\<C-X>s\<C-Y>\<Esc>", 'tx')
  call assert_equal('Theater', g:complete_word)
  call assert_equal('spell', g:complete_type)

  bwipe!
  set completeopt& omnifunc& completefunc& spell& spelllang& dictionary&
  autocmd! CompleteDone
  delfunc OnDone
  delfunc CompleteFunc
  unlet g:complete_word
  unlet g:complete_type
endfunc

func Test_CompleteDoneDict()
  au CompleteDonePre * :call <SID>CompleteDone_CheckCompletedItemDict(1)
  au CompleteDone * :call <SID>CompleteDone_CheckCompletedItemDict(0)

  set completefunc=<SID>CompleteDone_CompleteFuncDict
  execute "normal a\<C-X>\<C-U>\<C-Y>"
  set completefunc&

  call assert_equal(['one', 'two'], v:completed_item[ 'user_data' ])
  call assert_true(s:called_completedone)

  let s:called_completedone = 0
  au! CompleteDone
endfunc

func s:CompleteDone_CompleteFuncDictNoUserData(findstart, base)
  if a:findstart
    return 0
  endif

  return {
	  \ 'words': [
	    \ {
	      \ 'word': 'aword',
	      \ 'abbr': 'wrd',
	      \ 'menu': 'extra text',
	      \ 'info': 'words are cool',
	      \ 'kind': 'W',
	    \ }
	  \ ]
	\ }
endfunc

func s:CompleteDone_CheckCompletedItemDictNoUserData()
  call assert_equal( 'aword',          v:completed_item[ 'word' ] )
  call assert_equal( 'wrd',            v:completed_item[ 'abbr' ] )
  call assert_equal( 'extra text',     v:completed_item[ 'menu' ] )
  call assert_equal( 'words are cool', v:completed_item[ 'info' ] )
  call assert_equal( 'W',              v:completed_item[ 'kind' ] )
  call assert_equal( '',               v:completed_item[ 'user_data' ] )

  let s:called_completedone = 1
endfunc

func Test_CompleteDoneDictNoUserData()
  au CompleteDone * :call <SID>CompleteDone_CheckCompletedItemDictNoUserData()

  set completefunc=<SID>CompleteDone_CompleteFuncDictNoUserData
  execute "normal a\<C-X>\<C-U>\<C-Y>"
  set completefunc&

  call assert_equal('', v:completed_item[ 'user_data' ])
  call assert_true(s:called_completedone)

  let s:called_completedone = 0
  au! CompleteDone
endfunc

func s:CompleteDone_CompleteFuncList(findstart, base)
  if a:findstart
    return 0
  endif

  return [ 'aword' ]
endfunc

func s:CompleteDone_CheckCompletedItemList()
  call assert_equal( 'aword', v:completed_item[ 'word' ] )
  call assert_equal( '',      v:completed_item[ 'abbr' ] )
  call assert_equal( '',      v:completed_item[ 'menu' ] )
  call assert_equal( '',      v:completed_item[ 'info' ] )
  call assert_equal( '',      v:completed_item[ 'kind' ] )
  call assert_equal( '',      v:completed_item[ 'user_data' ] )

  let s:called_completedone = 1
endfunc

func Test_CompleteDoneList()
  au CompleteDone * :call <SID>CompleteDone_CheckCompletedItemList()

  set completefunc=<SID>CompleteDone_CompleteFuncList
  execute "normal a\<C-X>\<C-U>\<C-Y>"
  set completefunc&

  call assert_equal('', v:completed_item[ 'user_data' ])
  call assert_true(s:called_completedone)

  let s:called_completedone = 0
  au! CompleteDone
endfunc

func Test_CompleteDone_undo()
  au CompleteDone * call append(0, "prepend1")
  new
  call setline(1, ["line1", "line2"])
  call feedkeys("Go\<C-X>\<C-N>\<CR>\<ESC>", "tx")
  call assert_equal(["prepend1", "line1", "line2", "line1", ""],
              \     getline(1, '$'))
  undo
  call assert_equal(["line1", "line2"], getline(1, '$'))
  bwipe!
  au! CompleteDone
endfunc

func Test_CompleteDone_modify()
  let value = {
        \ 'word': '',
        \ 'abbr': '',
        \ 'menu': '',
        \ 'info': '',
        \ 'kind': '',
        \ 'user_data': '',
        \ }
  let v:completed_item = value
  call assert_equal(value, v:completed_item)
endfunc

func CompleteTest(findstart, query)
  if a:findstart
    return col('.')
  endif
  return ['matched']
endfunc

func Test_completefunc_info()
  new
  set completeopt=menuone
  set completefunc=CompleteTest
  call feedkeys("i\<C-X>\<C-U>\<C-R>\<C-R>=string(complete_info())\<CR>\<ESC>", "tx")
  call assert_equal("matched{'pum_visible': 1, 'mode': 'function', 'selected': 0, 'items': [{'word': 'matched', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''}]}", getline(1))
  bwipe!
  set completeopt&
  set completefunc&
endfunc

func CompleteInfoUserDefinedFn(findstart, query)
  " User defined function (i_CTRL-X_CTRL-U)
  if a:findstart
    return col('.')
  endif
  return [{'word': 'foo'}, {'word': 'bar'}, {'word': 'baz'}, {'word': 'qux'}]
endfunc

func CompleteInfoTestUserDefinedFn(mvmt, idx, noselect)
  new
  if a:noselect
    set completeopt=menuone,popup,noinsert,noselect
  else
    set completeopt=menu,preview
  endif
  set completefunc=CompleteInfoUserDefinedFn
  call feedkeys("i\<C-X>\<C-U>" . a:mvmt . "\<C-R>\<C-R>=string(complete_info())\<CR>\<ESC>", "tx")
  let completed = a:idx != -1 ? ['foo', 'bar', 'baz', 'qux']->get(a:idx) : ''
  call assert_equal(completed. "{'pum_visible': 1, 'mode': 'function', 'selected': " . a:idx . ", 'items': [" .
        \ "{'word': 'foo', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''}, " .
        \ "{'word': 'bar', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''}, " .
        \ "{'word': 'baz', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''}, " .
        \ "{'word': 'qux', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''}" .
        \ "]}", getline(1))
  bwipe!
  set completeopt&
  set completefunc&
endfunc

func Test_complete_info_user_defined_fn()
  " forward
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>", 1, v:true)
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>\<C-N>", 2, v:true)
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>", 2, v:false)
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>\<C-N>", 3, v:false)
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>\<C-N>\<C-N>", -1, v:false)
  " backward
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-P>", 2, v:true)
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-P>\<C-P>", 1, v:true)
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>", -1, v:true)
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-P>", 3, v:false)
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-P>\<C-P>", 2, v:false)
  " forward backward
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>\<C-N>\<C-P>", 1, v:true)
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>\<C-P>", 0, v:true)
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>\<C-N>\<C-P>", 2, v:false)
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>\<C-N>\<C-N>\<C-P>", 3, v:false)
  call CompleteInfoTestUserDefinedFn("\<C-N>\<C-N>\<C-P>", 1, v:false)
  " backward forward
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>\<C-N>", 0, v:true)
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-P>\<C-P>\<C-N>", 2, v:true)
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>\<C-N>", 1, v:false)
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-P>\<C-P>\<C-N>", 3, v:false)
  call CompleteInfoTestUserDefinedFn("\<C-P>\<C-N>\<C-N>", 1, v:false)
endfunc

" Test that mouse scrolling/movement should not interrupt completion.
func Test_mouse_scroll_move_during_completion()
  new
  com! -buffer TestCommand1 echo 'TestCommand1'
  com! -buffer TestCommand2 echo 'TestCommand2'
  call setline(1, ['', '', '', '', ''])
  call cursor(5, 1)

  " Without completion menu scrolling can move text.
  set completeopt-=menu wrap
  call feedkeys("ccT\<C-X>\<C-V>\<ScrollWheelDown>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))
  call assert_notequal(1, winsaveview().topline)
  call feedkeys("ccT\<C-X>\<C-V>\<ScrollWheelUp>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))
  call assert_equal(1, winsaveview().topline)
  set nowrap
  call feedkeys("ccT\<C-X>\<C-V>\<ScrollWheelRight>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))
  call assert_notequal(0, winsaveview().leftcol)
  call feedkeys("ccT\<C-X>\<C-V>\<ScrollWheelLeft>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))
  call assert_equal(0, winsaveview().leftcol)
  call feedkeys("ccT\<C-X>\<C-V>\<MouseMove>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))

  " With completion menu scrolling cannot move text.
  set completeopt+=menu wrap
  call feedkeys("ccT\<C-X>\<C-V>\<ScrollWheelDown>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))
  call assert_equal(1, winsaveview().topline)
  call feedkeys("ccT\<C-X>\<C-V>\<ScrollWheelUp>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))
  call assert_equal(1, winsaveview().topline)
  set nowrap
  call feedkeys("ccT\<C-X>\<C-V>\<ScrollWheelRight>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))
  call assert_equal(0, winsaveview().leftcol)
  call feedkeys("ccT\<C-X>\<C-V>\<ScrollWheelLeft>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))
  call assert_equal(0, winsaveview().leftcol)
  call feedkeys("ccT\<C-X>\<C-V>\<MouseMove>\<C-V>", 'tx')
  call assert_equal('TestCommand2', getline('.'))

  bwipe!
  set completeopt& wrap&
endfunc

" Check that when using feedkeys() typeahead does not interrupt searching for
" completions.
func Test_compl_feedkeys()
  new
  set completeopt=menuone,noselect
  call feedkeys("ajump ju\<C-X>\<C-N>\<C-P>\<ESC>", "tx")
  call assert_equal("jump jump", getline(1))
  bwipe!
  set completeopt&
endfunc

func s:ComplInCmdwin_GlobalCompletion(a, l, p)
  return 'global'
endfunc

func s:ComplInCmdwin_LocalCompletion(a, l, p)
  return 'local'
endfunc

func Test_compl_in_cmdwin()
  set wildmenu wildchar=<Tab>
  com! -nargs=1 -complete=command GetInput let input = <q-args>
  com! -buffer TestCommand echo 'TestCommand'
  let w:test_winvar = 'winvar'
  let b:test_bufvar = 'bufvar'

  " User-defined commands
  let input = ''
  call feedkeys("q:iGetInput T\<C-x>\<C-v>\<CR>", 'tx!')
  call assert_equal('TestCommand', input)

  let input = ''
  call feedkeys("q::GetInput T\<Tab>\<CR>:q\<CR>", 'tx!')
  call assert_equal('T', input)

  com! -nargs=1 -complete=var GetInput let input = <q-args>
  " Window-local variables
  let input = ''
  call feedkeys("q:iGetInput w:test_\<C-x>\<C-v>\<CR>", 'tx!')
  call assert_equal('w:test_winvar', input)

  let input = ''
  call feedkeys("q::GetInput w:test_\<Tab>\<CR>:q\<CR>", 'tx!')
  call assert_equal('w:test_', input)

  " Buffer-local variables
  let input = ''
  call feedkeys("q:iGetInput b:test_\<C-x>\<C-v>\<CR>", 'tx!')
  call assert_equal('b:test_bufvar', input)

  let input = ''
  call feedkeys("q::GetInput b:test_\<Tab>\<CR>:q\<CR>", 'tx!')
  call assert_equal('b:test_', input)


  " Argument completion of buffer-local command
  func s:ComplInCmdwin_GlobalCompletionList(a, l, p)
    return ['global']
  endfunc

  func s:ComplInCmdwin_LocalCompletionList(a, l, p)
    return ['local']
  endfunc

  func s:ComplInCmdwin_CheckCompletion(arg)
    call assert_equal('local', a:arg)
  endfunc

  com! -nargs=1 -complete=custom,<SID>ComplInCmdwin_GlobalCompletion
       \ TestCommand call s:ComplInCmdwin_CheckCompletion(<q-args>)
  com! -buffer -nargs=1 -complete=custom,<SID>ComplInCmdwin_LocalCompletion
       \ TestCommand call s:ComplInCmdwin_CheckCompletion(<q-args>)
  call feedkeys("q:iTestCommand \<Tab>\<CR>", 'tx!')

  com! -nargs=1 -complete=customlist,<SID>ComplInCmdwin_GlobalCompletionList
       \ TestCommand call s:ComplInCmdwin_CheckCompletion(<q-args>)
  com! -buffer -nargs=1 -complete=customlist,<SID>ComplInCmdwin_LocalCompletionList
       \ TestCommand call s:ComplInCmdwin_CheckCompletion(<q-args>)

  call feedkeys("q:iTestCommand \<Tab>\<CR>", 'tx!')

  func! s:ComplInCmdwin_CheckCompletion(arg)
    call assert_equal('global', a:arg)
  endfunc
  new
  call feedkeys("q:iTestCommand \<Tab>\<CR>", 'tx!')
  quit

  delfunc s:ComplInCmdwin_GlobalCompletion
  delfunc s:ComplInCmdwin_LocalCompletion
  delfunc s:ComplInCmdwin_GlobalCompletionList
  delfunc s:ComplInCmdwin_LocalCompletionList
  delfunc s:ComplInCmdwin_CheckCompletion

  delcom -buffer TestCommand
  delcom TestCommand
  delcom GetInput
  unlet w:test_winvar
  unlet b:test_bufvar
  set wildmenu& wildchar&
endfunc

" Test for insert path completion with completeslash option
func Test_ins_completeslash()
  CheckMSWindows

  call mkdir('Xdir')
  let orig_shellslash = &shellslash
  set cpt&
  new

  set noshellslash

  set completeslash=
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir\', getline('.'))

  set completeslash=backslash
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir\', getline('.'))

  set completeslash=slash
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir/', getline('.'))

  set shellslash

  set completeslash=
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir/', getline('.'))

  set completeslash=backslash
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir\', getline('.'))

  set completeslash=slash
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir/', getline('.'))
  %bw!
  call delete('Xdir', 'rf')

  set noshellslash
  set completeslash=slash
  call assert_true(stridx(globpath(&rtp, 'syntax/*.vim', 1, 1)[0], '\') != -1)

  let &shellslash = orig_shellslash
  set completeslash=
endfunc

func Test_pum_stopped_by_timer()
  CheckScreendump

  let lines =<< trim END
    call setline(1, ['hello', 'hullo', 'heeee', ''])
    func StartCompl()
      call timer_start(100, { -> execute('stopinsert') })
      call feedkeys("Gah\<C-N>")
    endfunc
  END

  call writefile(lines, 'Xpumscript')
  let buf = RunVimInTerminal('-S Xpumscript', #{rows: 12})
  call term_sendkeys(buf, ":call StartCompl()\<CR>")
  call TermWait(buf, 200)
  call term_sendkeys(buf, "k")
  call VerifyScreenDump(buf, 'Test_pum_stopped_by_timer', {})

  call StopVimInTerminal(buf)
  call delete('Xpumscript')
endfunc

func Test_complete_stopinsert_startinsert()
  nnoremap <F2> <Cmd>startinsert<CR>
  inoremap <F2> <Cmd>stopinsert<CR>
  " This just checks if this causes an error
  call feedkeys("i\<C-X>\<C-N>\<F2>\<F2>", 'x')
  nunmap <F2>
  iunmap <F2>
endfunc

func Test_pum_with_folds_two_tabs()
  CheckScreendump

  let lines =<< trim END
    set fdm=marker
    call setline(1, ['" x {{{1', '" a some text'])
    call setline(3, range(&lines)->map({_, val -> '" a' .. val}))
    norm! zm
    tab sp
    call feedkeys('2Gzv', 'xt')
    call feedkeys("0fa", 'xt')
  END

  call writefile(lines, 'Xpumscript')
  let buf = RunVimInTerminal('-S Xpumscript', #{rows: 10})
  call TermWait(buf, 50)
  call term_sendkeys(buf, "a\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_with_folds_two_tabs', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
  call delete('Xpumscript')
endfunc

func Test_pum_with_preview_win()
  CheckScreendump

  let lines =<< trim END
    funct Omni_test(findstart, base)
      if a:findstart
        return col(".") - 1
      endif
      return [#{word: "one", info: "1info"}, #{word: "two", info: "2info"}, #{word: "three", info: "3info"}]
    endfunc
    set omnifunc=Omni_test
    set completeopt+=longest
  END

  call writefile(lines, 'Xpreviewscript')
  let buf = RunVimInTerminal('-S Xpreviewscript', #{rows: 12})
  call term_sendkeys(buf, "Gi\<C-X>\<C-O>")
  call TermWait(buf, 200)
  call term_sendkeys(buf, "\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_with_preview_win', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
  call delete('Xpreviewscript')
endfunc

func Test_scrollbar_on_wide_char()
  CheckScreendump

  let lines =<< trim END
    call setline(1, ['a', '            啊啊啊',
                        \ '             哦哦哦',
                        \ '              呃呃呃'])
    call setline(5, range(10)->map({i, v -> 'aa' .. v .. 'bb'}))
  END
  call writefile(lines, 'Xwidescript')
  let buf = RunVimInTerminal('-S Xwidescript', #{rows: 10})
  call term_sendkeys(buf, "A\<C-N>")
  call VerifyScreenDump(buf, 'Test_scrollbar_on_wide_char', {})

  call StopVimInTerminal(buf)
  call delete('Xwidescript')
endfunc

" Test for inserting the tag search pattern in insert mode
func Test_ins_compl_tag_sft()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t/^int first() {}$/",
        \ "second\tXfoo\t/^int second() {}$/",
        \ "third\tXfoo\t/^int third() {}$/"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int second() {}
    int third() {}
  [CODE]
  call writefile(code, 'Xfoo')

  enew
  set showfulltag
  exe "normal isec\<C-X>\<C-]>\<C-N>\<CR>"
  call assert_equal('int second() {}', getline(1))
  set noshowfulltag

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe!
endfunc

" Test for 'completefunc' deleting text
func Test_completefunc_error()
  new
  " delete text when called for the first time
  func CompleteFunc(findstart, base)
    if a:findstart == 1
      normal dd
      return col('.') - 1
    endif
    return ['a', 'b']
  endfunc
  set completefunc=CompleteFunc
  call setline(1, ['', 'abcd', ''])
  call assert_fails('exe "normal 2G$a\<C-X>\<C-U>"', 'E565:')

  " delete text when called for the second time
  func CompleteFunc2(findstart, base)
    if a:findstart == 1
      return col('.') - 1
    endif
    normal dd
    return ['a', 'b']
  endfunc
  set completefunc=CompleteFunc2
  call setline(1, ['', 'abcd', ''])
  call assert_fails('exe "normal 2G$a\<C-X>\<C-U>"', 'E565:')

  " Jump to a different window from the complete function
  func CompleteFunc3(findstart, base)
    if a:findstart == 1
      return col('.') - 1
    endif
    wincmd p
    return ['a', 'b']
  endfunc
  set completefunc=CompleteFunc3
  new
  call assert_fails('exe "normal a\<C-X>\<C-U>"', 'E565:')
  close!

  set completefunc&
  delfunc CompleteFunc
  delfunc CompleteFunc2
  delfunc CompleteFunc3
  close!
endfunc

" Test for returning non-string values from 'completefunc'
func Test_completefunc_invalid_data()
  new
  func! CompleteFunc(findstart, base)
    if a:findstart == 1
      return col('.') - 1
    endif
    return [{}, '', 'moon']
  endfunc
  set completefunc=CompleteFunc
  exe "normal i\<C-X>\<C-U>"
  call assert_equal('moon', getline(1))
  set completefunc&
  close!
endfunc

" Test for errors in using complete() function
func Test_complete_func_error()
  call assert_fails('call complete(1, ["a"])', 'E785:')
  func ListColors()
    call complete(col('.'), "blue")
  endfunc
  call assert_fails('exe "normal i\<C-R>=ListColors()\<CR>"', 'E474:')
  func ListMonths()
    call complete(col('.'), test_null_list())
  endfunc
  " Nvim allows a NULL list
  " call assert_fails('exe "normal i\<C-R>=ListMonths()\<CR>"', 'E474:')
  delfunc ListColors
  delfunc ListMonths
  call assert_fails('call complete_info({})', 'E714:')
  call assert_equal([], complete_info(['items']).items)
endfunc

" Test for recursively starting completion mode using complete()
func Test_recursive_complete_func()
  func ListColors()
    call complete(5, ["red", "blue"])
    return ''
  endfunc
  new
  call setline(1, ['a1', 'a2'])
  set complete=.
  exe "normal Goa\<C-X>\<C-L>\<C-R>=ListColors()\<CR>\<C-N>"
  call assert_equal('a2blue', getline(3))
  delfunc ListColors
  bw!
endfunc

" Test for using complete() with completeopt+=longest
func Test_complete_with_longest()
  new
  inoremap <buffer> <f3> <cmd>call complete(1, ["iaax", "iaay", "iaaz"])<cr>

  " default: insert first match
  set completeopt&
  call setline(1, ['i'])
  exe "normal Aa\<f3>\<esc>"
  call assert_equal('iaax', getline(1))

  " with longest: insert longest prefix
  set completeopt+=longest
  call setline(1, ['i'])
  exe "normal Aa\<f3>\<esc>"
  call assert_equal('iaa', getline(1))
  set completeopt&
  bwipe!
endfunc

" Test for buffer-local value of 'completeopt'
func Test_completeopt_buffer_local()
  set completeopt=menu
  new
  call setline(1, ['foofoo', 'foobar', 'foobaz', ''])
  call assert_equal('', &l:completeopt)
  call assert_equal('menu', &completeopt)
  call assert_equal('menu', &g:completeopt)

  setlocal bufhidden=hide
  enew
  call setline(1, ['foofoo', 'foobar', 'foobaz', ''])
  call assert_equal('', &l:completeopt)
  call assert_equal('menu', &completeopt)
  call assert_equal('menu', &g:completeopt)

  setlocal completeopt+=fuzzy,noinsert
  call assert_equal('menu,fuzzy,noinsert', &l:completeopt)
  call assert_equal('menu,fuzzy,noinsert', &completeopt)
  call assert_equal('menu', &g:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>bz\<C-Y>", 'tnix')
  call assert_equal('foobaz', getline('.'))

  setlocal completeopt=
  call assert_equal('', &l:completeopt)
  call assert_equal('menu', &completeopt)
  call assert_equal('menu', &g:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>\<C-Y>", 'tnix')
  call assert_equal('foofoo', getline('.'))

  setlocal completeopt+=longest
  call assert_equal('menu,longest', &l:completeopt)
  call assert_equal('menu,longest', &completeopt)
  call assert_equal('menu', &g:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>\<C-X>\<C-Z>", 'tnix')
  call assert_equal('foo', getline('.'))

  setlocal bufhidden=hide
  buffer #
  call assert_equal('', &l:completeopt)
  call assert_equal('menu', &completeopt)
  call assert_equal('menu', &g:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>\<C-Y>", 'tnix')
  call assert_equal('foofoo', getline('.'))

  setlocal completeopt+=fuzzy,noinsert
  call assert_equal('menu,fuzzy,noinsert', &l:completeopt)
  call assert_equal('menu,fuzzy,noinsert', &completeopt)
  call assert_equal('menu', &g:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>bz\<C-Y>", 'tnix')
  call assert_equal('foobaz', getline('.'))

  buffer #
  call assert_equal('menu,longest', &l:completeopt)
  call assert_equal('menu,longest', &completeopt)
  call assert_equal('menu', &g:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>\<C-X>\<C-Z>", 'tnix')
  call assert_equal('foo', getline('.'))

  setlocal bufhidden=wipe
  buffer! #
  bwipe!
  call assert_equal('', &l:completeopt)
  call assert_equal('menu', &completeopt)
  call assert_equal('menu', &g:completeopt)

  new | only
  call setline(1, ['foofoo', 'foobar', 'foobaz', ''])
  set completeopt&
  setlocal completeopt=menu,fuzzy,noinsert
  setglobal completeopt=menu,longest
  call assert_equal('menu,fuzzy,noinsert', &completeopt)
  call assert_equal('menu,fuzzy,noinsert', &l:completeopt)
  call assert_equal('menu,longest', &g:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>bz\<C-Y>", 'tnix')
  call assert_equal('foobaz', getline('.'))
  setlocal bufhidden=wipe
  new | only!
  call setline(1, ['foofoo', 'foobar', 'foobaz', ''])
  call assert_equal('menu,longest', &completeopt)
  call assert_equal('menu,longest', &g:completeopt)
  call assert_equal('', &l:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>\<C-X>\<C-Z>", 'tnix')
  call assert_equal('foo', getline('.'))
  bwipe!

  new | only
  call setline(1, ['foofoo', 'foobar', 'foobaz', ''])
  set completeopt&
  setlocal completeopt=menu,fuzzy,noinsert
  set completeopt=menu,longest
  call assert_equal('menu,longest', &completeopt)
  call assert_equal('menu,longest', &g:completeopt)
  call assert_equal('', &l:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>\<C-X>\<C-Z>", 'tnix')
  call assert_equal('foo', getline('.'))
  setlocal bufhidden=wipe
  new | only!
  call setline(1, ['foofoo', 'foobar', 'foobaz', ''])
  call assert_equal('menu,longest', &completeopt)
  call assert_equal('menu,longest', &g:completeopt)
  call assert_equal('', &l:completeopt)
  call feedkeys("Gccf\<C-X>\<C-N>\<C-X>\<C-Z>", 'tnix')
  call assert_equal('foo', getline('.'))
  bwipe!

  set completeopt&
endfunc

" Test for completing words following a completed word in a line
func Test_complete_wrapscan()
  " complete words from another buffer
  new
  call setline(1, ['one two', 'three four'])
  new
  setlocal complete=w
  call feedkeys("itw\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>", 'xt')
  call assert_equal('two three four', getline(1))
  close!
  " complete words from the current buffer
  setlocal complete=.
  %d
  call setline(1, ['one two', ''])
  call cursor(2, 1)
  call feedkeys("ion\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>", 'xt')
  call assert_equal('one two one two', getline(2))
  close!
endfunc

" Test for completing special characters
func Test_complete_special_chars()
  new
  call setline(1, 'int .*[-\^$ func float')
  call feedkeys("oin\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>", 'xt')
  call assert_equal('int .*[-\^$ func float', getline(2))
  close!
endfunc

" Test for completion when text is wrapped across lines.
func Test_complete_across_line()
  new
  call setline(1, ['red green blue', 'one two three'])
  setlocal textwidth=20
  exe "normal 2G$a re\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>"
  call assert_equal(['one two three red', 'green blue one'], getline(2, '$'))
  close!
endfunc

" Test for completing words with a '.' at the end of a word.
func Test_complete_joinspaces()
  new
  call setline(1, ['one two.', 'three. four'])
  set joinspaces
  exe "normal Goon\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>"
  call assert_equal("one two.  three. four", getline(3))
  set joinspaces&
  bw!
endfunc

" Test for using CTRL-L to add one character when completing matching
func Test_complete_add_onechar()
  new
  call setline(1, ['wool', 'woodwork'])
  call feedkeys("Gowoo\<C-P>\<C-P>\<C-P>\<C-L>f", 'xt')
  call assert_equal('woof', getline(3))

  " use 'ignorecase' and backspace to erase characters from the prefix string
  " and then add letters using CTRL-L
  %d
  set ignorecase backspace=2
  setlocal complete=.
  call setline(1, ['workhorse', 'workload'])
  normal Go
  exe "normal aWOR\<C-P>\<bs>\<bs>\<bs>\<bs>\<bs>\<bs>\<C-L>\<C-L>\<C-L>"
  call assert_equal('workh', getline(3))
  set ignorecase& backspace&
  close!
endfunc

" Test for using CTRL-X CTRL-L to complete whole lines lines
func Test_complete_wholeline()
  new
  " complete one-line
  call setline(1, ['a1', 'a2'])
  exe "normal ggoa\<C-X>\<C-L>"
  call assert_equal(['a1', 'a1', 'a2'], getline(1, '$'))
  " go to the next match (wrapping around the buffer)
  exe "normal 2GCa\<C-X>\<C-L>\<C-N>"
  call assert_equal(['a1', 'a', 'a2'], getline(1, '$'))
  " go to the next match
  exe "normal 2GCa\<C-X>\<C-L>\<C-N>\<C-N>"
  call assert_equal(['a1', 'a2', 'a2'], getline(1, '$'))
  exe "normal 2GCa\<C-X>\<C-L>\<C-N>\<C-N>\<C-N>"
  call assert_equal(['a1', 'a1', 'a2'], getline(1, '$'))
  " repeat the test using CTRL-L
  " go to the next match (wrapping around the buffer)
  exe "normal 2GCa\<C-X>\<C-L>\<C-L>"
  call assert_equal(['a1', 'a2', 'a2'], getline(1, '$'))
  " go to the next match
  exe "normal 2GCa\<C-X>\<C-L>\<C-L>\<C-L>"
  call assert_equal(['a1', 'a', 'a2'], getline(1, '$'))
  exe "normal 2GCa\<C-X>\<C-L>\<C-L>\<C-L>\<C-L>"
  call assert_equal(['a1', 'a1', 'a2'], getline(1, '$'))
  %d
  " use CTRL-X CTRL-L to add one more line
  call setline(1, ['a1', 'b1'])
  setlocal complete=.
  exe "normal ggOa\<C-X>\<C-L>\<C-X>\<C-L>\<C-X>\<C-L>"
  call assert_equal(['a1', 'b1', '', 'a1', 'b1'], getline(1, '$'))
  bw!
endfunc

" Test insert completion with 'cindent' (adjust the indent)
func Test_complete_with_cindent()
  new
  setlocal cindent
  call setline(1, ['if (i == 1)', "    j = 2;"])
  exe "normal Go{\<CR>i\<C-X>\<C-L>\<C-X>\<C-L>\<CR>}"
  call assert_equal(['{', "\tif (i == 1)", "\t\tj = 2;", '}'], getline(3, '$'))

  %d
  call setline(1, ['when while', '{', ''])
  setlocal cinkeys+==while
  exe "normal Giwh\<C-P> "
  call assert_equal("\twhile ", getline('$'))
  close!
endfunc

" Test for <CTRL-X> <CTRL-V> completion. Complete commands and functions
func Test_complete_cmdline()
  new
  exe "normal icaddb\<C-X>\<C-V>"
  call assert_equal('caddbuffer', getline(1))
  exe "normal ocall getqf\<C-X>\<C-V>"
  call assert_equal('call getqflist(', getline(2))
  exe "normal oabcxyz(\<C-X>\<C-V>"
  call assert_equal('abcxyz(', getline(3))
  com! -buffer TestCommand1 echo 'TestCommand1'
  com! -buffer TestCommand2 echo 'TestCommand2'
  write! TestCommand1Test
  write! TestCommand2Test
  " Test repeating <CTRL-X> <CTRL-V> and switching to another CTRL-X mode
  exe "normal oT\<C-X>\<C-V>\<C-X>\<C-V>\<C-X>\<C-F>\<Esc>"
  call assert_equal('TestCommand2Test', getline(4))
  call delete('TestCommand1Test')
  call delete('TestCommand2Test')
  delcom TestCommand1
  delcom TestCommand2
  close!
endfunc

" Test for <CTRL-X> <CTRL-Z> stopping completion without changing the match
func Test_complete_stop()
  new
  func Save_mode1()
    let g:mode1 = mode(1)
    return ''
  endfunc
  func Save_mode2()
    let g:mode2 = mode(1)
    return ''
  endfunc
  inoremap <F1> <C-R>=Save_mode1()<CR>
  inoremap <F2> <C-R>=Save_mode2()<CR>
  call setline(1, ['aaa bbb ccc '])
  exe "normal A\<C-N>\<C-P>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('aaa bbb ccc ', getline(1))
  exe "normal A\<C-N>\<Down>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('aaa bbb ccc aaa', getline(1))
  set completeopt+=noselect
  exe "normal A \<C-N>\<Down>\<Down>\<C-L>\<C-L>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('aaa bbb ccc aaa bb', getline(1))
  set completeopt&
  exe "normal A d\<C-N>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('aaa bbb ccc aaa bb d', getline(1))
  com! -buffer TestCommand1 echo 'TestCommand1'
  com! -buffer TestCommand2 echo 'TestCommand2'
  exe "normal oT\<C-X>\<C-V>\<C-X>\<C-V>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('TestCommand2', getline(2))
  delcom TestCommand1
  delcom TestCommand2
  unlet g:mode1
  unlet g:mode2
  iunmap <F1>
  iunmap <F2>
  delfunc Save_mode1
  delfunc Save_mode2
  close!
endfunc

" Test for typing CTRL-R in insert completion mode to insert a register
" content.
func Test_complete_reginsert()
  new
  call setline(1, ['a1', 'a12', 'a123', 'a1234'])

  " if a valid CTRL-X mode key is returned from <C-R>=, then it should be
  " processed. Otherwise, CTRL-X mode should be stopped and the key should be
  " inserted.
  exe "normal Goa\<C-P>\<C-R>=\"\\<C-P>\"\<CR>"
  call assert_equal('a123', getline(5))
  let @r = "\<C-P>\<C-P>"
  exe "normal GCa\<C-P>\<C-R>r"
  call assert_equal('a12', getline(5))
  exe "normal GCa\<C-P>\<C-R>=\"x\"\<CR>"
  call assert_equal('a1234x', getline(5))
  bw!
endfunc

func Test_issue_7021()
  CheckMSWindows

  let orig_shellslash = &shellslash
  set noshellslash

  set completeslash=slash
  call assert_false(expand('~') =~ '/')

  let &shellslash = orig_shellslash
  set completeslash=
endfunc

" Test for 'longest' setting in 'completeopt' with latin1 and utf-8 encodings
func Test_complete_longest_match()
  " for e in ['latin1', 'utf-8']
  for e in ['utf-8']
    exe 'set encoding=' .. e
    new
    set complete=.
    set completeopt=menu,longest
    call setline(1, ['pfx_a1', 'pfx_a12', 'pfx_a123', 'pfx_b1'])
    exe "normal Gopfx\<C-P>"
    call assert_equal('pfx_', getline(5))
    bw!
  endfor

  " Test for completing additional words with longest match set
  new
  call setline(1, ['abc1', 'abd2'])
  exe "normal Goab\<C-P>\<C-X>\<C-P>"
  call assert_equal('ab', getline(3))
  bw!
  set complete& completeopt&
endfunc

" Test for removing the first displayed completion match and selecting the
" match just before that.
func Test_complete_erase_firstmatch()
  new
  call setline(1, ['a12', 'a34', 'a56'])
  set complete=.
  exe "normal Goa\<C-P>\<BS>\<BS>3\<CR>"
  call assert_equal('a34', getline('$'))
  set complete&
  bw!
endfunc

" Test for completing words from unloaded buffers
func Test_complete_from_unloadedbuf()
  call writefile(['abc'], "Xfile1")
  call writefile(['def'], "Xfile2")
  edit Xfile1
  edit Xfile2
  new | close
  enew
  bunload Xfile1 Xfile2
  set complete=u
  " complete from an unloaded buffer
  exe "normal! ia\<C-P>"
  call assert_equal('abc', getline(1))
  exe "normal! od\<C-P>"
  call assert_equal('def', getline(2))
  set complete&
  %bw!
  call delete("Xfile1")
  call delete("Xfile2")
endfunc

" Test for completing whole lines from unloaded buffers
func Test_complete_wholeline_unloadedbuf()
  call writefile(['a line1', 'a line2', 'a line3'], "Xfile1")
  edit Xfile1
  enew
  set complete=u
  exe "normal! ia\<C-X>\<C-L>\<C-P>"
  call assert_equal('a line2', getline(1))
  %d
  " completing from an unlisted buffer should fail
  bdel Xfile1
  exe "normal! ia\<C-X>\<C-L>\<C-P>"
  call assert_equal('a', getline(1))
  set complete&
  %bw!
  call delete("Xfile1")
endfunc

" Test for completing words from unlisted buffers
func Test_complete_from_unlistedbuf()
  call writefile(['abc'], "Xfile1")
  call writefile(['def'], "Xfile2")
  edit Xfile1
  edit Xfile2
  new | close
  bdel Xfile1 Xfile2
  set complete=U
  " complete from an unlisted buffer
  exe "normal! ia\<C-P>"
  call assert_equal('abc', getline(1))
  exe "normal! od\<C-P>"
  call assert_equal('def', getline(2))
  set complete&
  %bw!
  call delete("Xfile1")
  call delete("Xfile2")
endfunc

" Test for completing whole lines from unlisted buffers
func Test_complete_wholeline_unlistedbuf()
  call writefile(['a line1', 'a line2', 'a line3'], "Xfile1")
  edit Xfile1
  enew
  set complete=U
  " completing from an unloaded buffer should fail
  exe "normal! ia\<C-X>\<C-L>\<C-P>"
  call assert_equal('a', getline(1))
  %d
  bdel Xfile1
  exe "normal! ia\<C-X>\<C-L>\<C-P>"
  call assert_equal('a line2', getline(1))
  set complete&
  %bw!
  call delete("Xfile1")
endfunc

" Test for adding a multibyte character using CTRL-L in completion mode
func Test_complete_mbyte_char_add()
  new
  set complete=.
  call setline(1, 'abė')
  exe "normal! oa\<C-P>\<BS>\<BS>\<C-L>\<C-L>"
  call assert_equal('abė', getline(2))
  " Test for a leader with multibyte character
  %d
  call setline(1, 'abėĕ')
  exe "normal! oabė\<C-P>"
  call assert_equal('abėĕ', getline(2))
  bw!
endfunc

" Test for using <C-X><C-P> for local expansion even if 'complete' is set to
" not to complete matches from the local buffer. Also test using multiple
" <C-X> to cancel the current completion mode.
func Test_complete_local_expansion()
  new
  set complete=t
  call setline(1, ['abc', 'def'])
  exe "normal! Go\<C-X>\<C-P>"
  call assert_equal("def", getline(3))
  exe "normal! Go\<C-P>"
  call assert_equal("", getline(4))
  exe "normal! Go\<C-X>\<C-N>"
  call assert_equal("abc", getline(5))
  exe "normal! Go\<C-N>"
  call assert_equal("", getline(6))

  " use multiple <C-X> to cancel the previous completion mode
  exe "normal! Go\<C-P>\<C-X>\<C-P>"
  call assert_equal("", getline(7))
  exe "normal! Go\<C-P>\<C-X>\<C-X>\<C-P>"
  call assert_equal("", getline(8))
  exe "normal! Go\<C-P>\<C-X>\<C-X>\<C-X>\<C-P>"
  call assert_equal("abc", getline(9))

  " interrupt the current completion mode
  set completeopt=menu,noinsert
  exe "normal! Go\<C-X>\<C-F>\<C-X>\<C-X>\<C-P>\<C-Y>"
  call assert_equal("abc", getline(10))

  " when only one <C-X> is used to interrupt, do normal expansion
  exe "normal! Go\<C-X>\<C-F>\<C-X>\<C-P>"
  call assert_equal("", getline(11))
  set completeopt&

  " using two <C-X> in non-completion mode and restarting the same mode
  exe "normal! God\<C-X>\<C-X>\<C-P>\<C-X>\<C-X>\<C-P>\<C-Y>"
  call assert_equal("def", getline(12))

  " test for adding a match from the original empty text
  %d
  call setline(1, 'abc def g')
  exe "normal! o\<C-X>\<C-P>\<C-N>\<C-X>\<C-P>"
  call assert_equal('def', getline(2))
  exe "normal! 0C\<C-X>\<C-N>\<C-P>\<C-X>\<C-N>"
  call assert_equal('abc', getline(2))

  bw!
endfunc

" Test for undoing changes after a insert-mode completion
func Test_complete_undo()
  new
  set complete=.
  " undo with 'ignorecase'
  call setline(1, ['ABOVE', 'BELOW'])
  set ignorecase
  exe "normal! Goab\<C-G>u\<C-P>"
  call assert_equal("ABOVE", getline(3))
  undo
  call assert_equal("ab", getline(3))
  set ignorecase&
  %d
  " undo with longest match
  set completeopt=menu,longest
  call setline(1, ['above', 'about'])
  exe "normal! Goa\<C-G>u\<C-P>"
  call assert_equal("abo", getline(3))
  undo
  call assert_equal("a", getline(3))
  set completeopt&
  %d
  " undo for line completion
  call setline(1, ['above that change', 'below that change'])
  exe "normal! Goabove\<C-G>u\<C-X>\<C-L>"
  call assert_equal("above that change", getline(3))
  undo
  call assert_equal("above", getline(3))

  bw!
endfunc

" Test for completing a very long word
func Test_complete_long_word()
  set complete&
  new
  call setline(1, repeat('x', 950) .. ' one two three')
  exe "normal! Gox\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>"
  call assert_equal(repeat('x', 950) .. ' one two three', getline(2))
  %d
  " should fail when more than 950 characters are in a word
  call setline(1, repeat('x', 951) .. ' one two three')
  exe "normal! Gox\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>"
  call assert_equal(repeat('x', 951), getline(2))

  " Test for adding a very long word to an existing completion
  %d
  call setline(1, ['abc', repeat('x', 1016) .. '012345'])
  exe "normal! Goab\<C-P>\<C-X>\<C-P>"
  call assert_equal('abc ' .. repeat('x', 1016) .. '0123', getline(3))
  bw!
endfunc

" Test for some fields in the complete items used by complete()
func Test_complete_items()
  func CompleteItems(idx)
    let items = [[#{word: "one", dup: 1, user_data: 'u1'}, #{word: "one", dup: 1, user_data: 'u2'}],
          \ [#{word: "one", dup: 0, user_data: 'u3'}, #{word: "one", dup: 0, user_data: 'u4'}],
          \ [#{word: "one", icase: 1, user_data: 'u7'}, #{word: "oNE", icase: 1, user_data: 'u8'}],
          \ [#{user_data: 'u9'}],
          \ [#{word: "", user_data: 'u10'}],
          \ [#{word: "", empty: 1, user_data: 'u11'}]]
    call complete(col('.'), items[a:idx])
    return ''
  endfunc
  new
  exe "normal! i\<C-R>=CompleteItems(0)\<CR>\<C-N>\<C-Y>"
  call assert_equal('u2', v:completed_item.user_data)
  call assert_equal('one', getline(1))
  exe "normal! o\<C-R>=CompleteItems(1)\<CR>\<C-Y>"
  call assert_equal('u3', v:completed_item.user_data)
  call assert_equal('one', getline(2))
  exe "normal! o\<C-R>=CompleteItems(1)\<CR>\<C-N>"
  call assert_equal('', getline(3))
  set completeopt=menu,noinsert
  exe "normal! o\<C-R>=CompleteItems(2)\<CR>one\<C-N>\<C-Y>"
  call assert_equal('oNE', getline(4))
  call assert_equal('u8', v:completed_item.user_data)
  set completeopt&
  exe "normal! o\<C-R>=CompleteItems(3)\<CR>"
  call assert_equal('', getline(5))
  exe "normal! o\<C-R>=CompleteItems(4)\<CR>"
  call assert_equal('', getline(6))
  exe "normal! o\<C-R>=CompleteItems(5)\<CR>"
  call assert_equal('', getline(7))
  call assert_equal('u11', v:completed_item.user_data)
  " pass invalid argument to complete()
  let cmd = "normal! o\<C-R>=complete(1, [[]])\<CR>"
  call assert_fails('exe cmd', 'E730:')
  bw!
  delfunc CompleteItems
endfunc

" Test for the "refresh" item in the dict returned by an insert completion
" function
func Test_complete_item_refresh_always()
  let g:CallCount = 0
  func! Tcomplete(findstart, base)
    if a:findstart
      " locate the start of the word
      let line = getline('.')
      let start = col('.') - 1
      while start > 0 && line[start - 1] =~ '\a'
        let start -= 1
      endwhile
      return start
    else
      let g:CallCount += 1
      let res = ["update1", "update12", "update123"]
      return #{words: res, refresh: 'always'}
    endif
  endfunc
  new
  set completeopt=menu,longest
  set completefunc=Tcomplete
  exe "normal! iup\<C-X>\<C-U>\<BS>\<BS>\<BS>\<BS>\<BS>"
  call assert_equal('up', getline(1))
  call assert_equal(6, g:CallCount)
  set completeopt&
  set completefunc&
  bw!
  delfunc Tcomplete
endfunc

" Test for completing from a thesaurus file without read permission
func Test_complete_unreadable_thesaurus_file()
  CheckUnix
  CheckNotRoot

  call writefile(['about', 'above'], 'Xfile')
  call setfperm('Xfile', '---r--r--')
  new
  set complete=sXfile
  exe "normal! ia\<C-P>"
  call assert_equal('a', getline(1))
  bw!
  call delete('Xfile')
  set complete&
endfunc

" Test to ensure 'Scanning...' messages are not recorded in messages history
func Test_z1_complete_no_history()
  new
  messages clear
  let currmess = execute('messages')
  setlocal dictionary=README.txt
  exe "normal owh\<C-X>\<C-K>"
  exe "normal owh\<C-N>"
  call assert_equal(currmess, execute('messages'))
  bwipe!
endfunc

" A mapping is not used for the key after CTRL-X.
func Test_no_mapping_for_ctrl_x_key()
  new
  inoremap <buffer> <C-K> <Cmd>let was_mapped = 'yes'<CR>
  setlocal dictionary=README.txt
  call feedkeys("aexam\<C-X>\<C-K> ", 'xt')
  call assert_equal('example ', getline(1))
  call assert_false(exists('was_mapped'))
  bwipe!
endfunc

" Test for different ways of setting the 'completefunc' option
func Test_completefunc_callback()
  func CompleteFunc1(callnr, findstart, base)
    call add(g:CompleteFunc1Args, [a:callnr, a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  func CompleteFunc2(findstart, base)
    call add(g:CompleteFunc2Args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc

  let lines =<< trim END
    #" Test for using a global function name
    LET &completefunc = 'g:CompleteFunc2'
    new
    call setline(1, 'global')
    LET g:CompleteFunc2Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[1, ''], [0, 'global']], g:CompleteFunc2Args)
    bw!

    #" Test for using a function()
    set completefunc=function('g:CompleteFunc1',\ [10])
    new
    call setline(1, 'one')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[10, 1, ''], [10, 0, 'one']], g:CompleteFunc1Args)
    bw!

    #" Using a funcref variable to set 'completefunc'
    VAR Fn = function('g:CompleteFunc1', [11])
    LET &completefunc = Fn
    new
    call setline(1, 'two')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[11, 1, ''], [11, 0, 'two']], g:CompleteFunc1Args)
    bw!

    #" Using string(funcref_variable) to set 'completefunc'
    LET Fn = function('g:CompleteFunc1', [12])
    LET &completefunc = string(Fn)
    new
    call setline(1, 'two')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[12, 1, ''], [12, 0, 'two']], g:CompleteFunc1Args)
    bw!

    #" Test for using a funcref()
    set completefunc=funcref('g:CompleteFunc1',\ [13])
    new
    call setline(1, 'three')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[13, 1, ''], [13, 0, 'three']], g:CompleteFunc1Args)
    bw!

    #" Using a funcref variable to set 'completefunc'
    LET Fn = funcref('g:CompleteFunc1', [14])
    LET &completefunc = Fn
    new
    call setline(1, 'four')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[14, 1, ''], [14, 0, 'four']], g:CompleteFunc1Args)
    bw!

    #" Using a string(funcref_variable) to set 'completefunc'
    LET Fn = funcref('g:CompleteFunc1', [15])
    LET &completefunc = string(Fn)
    new
    call setline(1, 'four')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[15, 1, ''], [15, 0, 'four']], g:CompleteFunc1Args)
    bw!

    #" Test for using a lambda function with set
    VAR optval = "LSTART a, b LMIDDLE CompleteFunc1(16, a, b) LEND"
    LET optval = substitute(optval, ' ', '\\ ', 'g')
    exe "set completefunc=" .. optval
    new
    call setline(1, 'five')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[16, 1, ''], [16, 0, 'five']], g:CompleteFunc1Args)
    bw!

    #" Set 'completefunc' to a lambda expression
    LET &completefunc = LSTART a, b LMIDDLE CompleteFunc1(17, a, b) LEND
    new
    call setline(1, 'six')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[17, 1, ''], [17, 0, 'six']], g:CompleteFunc1Args)
    bw!

    #" Set 'completefunc' to string(lambda_expression)
    LET &completefunc = 'LSTART a, b LMIDDLE CompleteFunc1(18, a, b) LEND'
    new
    call setline(1, 'six')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[18, 1, ''], [18, 0, 'six']], g:CompleteFunc1Args)
    bw!

    #" Set 'completefunc' to a variable with a lambda expression
    VAR Lambda = LSTART a, b LMIDDLE CompleteFunc1(19, a, b) LEND
    LET &completefunc = Lambda
    new
    call setline(1, 'seven')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[19, 1, ''], [19, 0, 'seven']], g:CompleteFunc1Args)
    bw!

    #" Set 'completefunc' to a string(variable with a lambda expression)
    LET Lambda = LSTART a, b LMIDDLE CompleteFunc1(20, a, b) LEND
    LET &completefunc = string(Lambda)
    new
    call setline(1, 'seven')
    LET g:CompleteFunc1Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[20, 1, ''], [20, 0, 'seven']], g:CompleteFunc1Args)
    bw!

    #" Test for using a lambda function with incorrect return value
    LET Lambda = LSTART a, b LMIDDLE strlen(a) LEND
    LET &completefunc = Lambda
    new
    call setline(1, 'eight')
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    bw!

    #" Test for clearing the 'completefunc' option
    set completefunc=''
    set completefunc&
    call assert_fails("set completefunc=function('abc')", "E700:")
    call assert_fails("set completefunc=funcref('abc')", "E700:")

    #" set 'completefunc' to a non-existing function
    set completefunc=CompleteFunc2
    call setline(1, 'five')
    call assert_fails("set completefunc=function('NonExistingFunc')", 'E700:')
    call assert_fails("LET &completefunc = function('NonExistingFunc')", 'E700:')
    LET g:CompleteFunc2Args = []
    call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    call assert_equal([[1, ''], [0, 'five']], g:CompleteFunc2Args)
    bw!
  END
  call CheckLegacyAndVim9Success(lines)

  " Test for using a script-local function name
  func s:CompleteFunc3(findstart, base)
    call add(g:CompleteFunc3Args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set completefunc=s:CompleteFunc3
  new
  call setline(1, 'script1')
  let g:CompleteFunc3Args = []
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'script1']], g:CompleteFunc3Args)
  bw!

  let &completefunc = 's:CompleteFunc3'
  new
  call setline(1, 'script2')
  let g:CompleteFunc3Args = []
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'script2']], g:CompleteFunc3Args)
  bw!
  delfunc s:CompleteFunc3

  " In Vim9 script s: can be omitted
  let lines =<< trim END
      vim9script
      var CompleteFunc4Args = []
      def CompleteFunc4(findstart: bool, base: string): any
        add(CompleteFunc4Args, [findstart, base])
        return findstart ? 0 : []
      enddef
      set completefunc=CompleteFunc4
      new
      setline(1, 'script1')
      feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
      assert_equal([[1, ''], [0, 'script1']], CompleteFunc4Args)
      bw!
  END
  call CheckScriptSuccess(lines)

  " invalid return value
  let &completefunc = {a -> 'abc'}
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')

  " Using Vim9 lambda expression in legacy context should fail
  set completefunc=(a,\ b)\ =>\ CompleteFunc1(21,\ a,\ b)
  new | only
  let g:CompleteFunc1Args = []
  call assert_fails('call feedkeys("A\<C-X>\<C-U>\<Esc>", "x")', 'E117:')
  call assert_equal([], g:CompleteFunc1Args)

  " set 'completefunc' to a partial with dict. This used to cause a crash.
  func SetCompleteFunc()
    let params = {'complete': function('g:DictCompleteFunc')}
    let &completefunc = params.complete
  endfunc
  func g:DictCompleteFunc(_) dict
  endfunc
  call SetCompleteFunc()
  new
  call SetCompleteFunc()
  bw
  call test_garbagecollect_now()
  new
  set completefunc=
  wincmd w
  set completefunc=
  %bw!
  delfunc g:DictCompleteFunc
  delfunc SetCompleteFunc

  " Vim9 tests
  let lines =<< trim END
    vim9script

    def Vim9CompleteFunc(callnr: number, findstart: number, base: string): any
      add(g:Vim9completeFuncArgs, [callnr, findstart, base])
      return findstart ? 0 : []
    enddef

    # Test for using a def function with completefunc
    set completefunc=function('Vim9CompleteFunc',\ [60])
    new | only
    setline(1, 'one')
    g:Vim9completeFuncArgs = []
    feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    assert_equal([[60, 1, ''], [60, 0, 'one']], g:Vim9completeFuncArgs)
    bw!

    # Test for using a global function name
    &completefunc = g:CompleteFunc2
    new | only
    setline(1, 'two')
    g:CompleteFunc2Args = []
    feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'two']], g:CompleteFunc2Args)
    bw!

    # Test for using a script-local function name
    def LocalCompleteFunc(findstart: number, base: string): any
      add(g:LocalCompleteFuncArgs, [findstart, base])
      return findstart ? 0 : []
    enddef
    &completefunc = LocalCompleteFunc
    new | only
    setline(1, 'three')
    g:LocalCompleteFuncArgs = []
    feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'three']], g:LocalCompleteFuncArgs)
    bw!
  END
  call CheckScriptSuccess(lines)

  " cleanup
  set completefunc&
  delfunc CompleteFunc1
  delfunc CompleteFunc2
  unlet g:CompleteFunc1Args g:CompleteFunc2Args
  %bw!
endfunc

" Test for different ways of setting the 'omnifunc' option
func Test_omnifunc_callback()
  func OmniFunc1(callnr, findstart, base)
    call add(g:OmniFunc1Args, [a:callnr, a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  func OmniFunc2(findstart, base)
    call add(g:OmniFunc2Args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc

  let lines =<< trim END
    #" Test for using a function name
    LET &omnifunc = 'g:OmniFunc2'
    new
    call setline(1, 'zero')
    LET g:OmniFunc2Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[1, ''], [0, 'zero']], g:OmniFunc2Args)
    bw!

    #" Test for using a function()
    set omnifunc=function('g:OmniFunc1',\ [10])
    new
    call setline(1, 'one')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[10, 1, ''], [10, 0, 'one']], g:OmniFunc1Args)
    bw!

    #" Using a funcref variable to set 'omnifunc'
    VAR Fn = function('g:OmniFunc1', [11])
    LET &omnifunc = Fn
    new
    call setline(1, 'two')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[11, 1, ''], [11, 0, 'two']], g:OmniFunc1Args)
    bw!

    #" Using a string(funcref_variable) to set 'omnifunc'
    LET Fn = function('g:OmniFunc1', [12])
    LET &omnifunc = string(Fn)
    new
    call setline(1, 'two')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[12, 1, ''], [12, 0, 'two']], g:OmniFunc1Args)
    bw!

    #" Test for using a funcref()
    set omnifunc=funcref('g:OmniFunc1',\ [13])
    new
    call setline(1, 'three')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[13, 1, ''], [13, 0, 'three']], g:OmniFunc1Args)
    bw!

    #" Use let to set 'omnifunc' to a funcref
    LET Fn = funcref('g:OmniFunc1', [14])
    LET &omnifunc = Fn
    new
    call setline(1, 'four')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[14, 1, ''], [14, 0, 'four']], g:OmniFunc1Args)
    bw!

    #" Using a string(funcref) to set 'omnifunc'
    LET Fn = funcref("g:OmniFunc1", [15])
    LET &omnifunc = string(Fn)
    new
    call setline(1, 'four')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[15, 1, ''], [15, 0, 'four']], g:OmniFunc1Args)
    bw!

    #" Test for using a lambda function with set
    VAR optval = "LSTART a, b LMIDDLE OmniFunc1(16, a, b) LEND"
    LET optval = substitute(optval, ' ', '\\ ', 'g')
    exe "set omnifunc=" .. optval
    new
    call setline(1, 'five')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[16, 1, ''], [16, 0, 'five']], g:OmniFunc1Args)
    bw!

    #" Set 'omnifunc' to a lambda expression
    LET &omnifunc = LSTART a, b LMIDDLE OmniFunc1(17, a, b) LEND
    new
    call setline(1, 'six')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[17, 1, ''], [17, 0, 'six']], g:OmniFunc1Args)
    bw!

    #" Set 'omnifunc' to a string(lambda_expression)
    LET &omnifunc = 'LSTART a, b LMIDDLE OmniFunc1(18, a, b) LEND'
    new
    call setline(1, 'six')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[18, 1, ''], [18, 0, 'six']], g:OmniFunc1Args)
    bw!

    #" Set 'omnifunc' to a variable with a lambda expression
    VAR Lambda = LSTART a, b LMIDDLE OmniFunc1(19, a, b) LEND
    LET &omnifunc = Lambda
    new
    call setline(1, 'seven')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[19, 1, ''], [19, 0, 'seven']], g:OmniFunc1Args)
    bw!

    #" Set 'omnifunc' to a string(variable with a lambda expression)
    LET Lambda = LSTART a, b LMIDDLE OmniFunc1(20, a, b) LEND
    LET &omnifunc = string(Lambda)
    new
    call setline(1, 'seven')
    LET g:OmniFunc1Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[20, 1, ''], [20, 0, 'seven']], g:OmniFunc1Args)
    bw!

    #" Test for using a lambda function with incorrect return value
    LET Lambda = LSTART a, b LMIDDLE strlen(a) LEND
    LET &omnifunc = Lambda
    new
    call setline(1, 'eight')
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    bw!

    #" Test for clearing the 'omnifunc' option
    set omnifunc=''
    set omnifunc&
    call assert_fails("set omnifunc=function('abc')", "E700:")
    call assert_fails("set omnifunc=funcref('abc')", "E700:")

    #" set 'omnifunc' to a non-existing function
    set omnifunc=OmniFunc2
    call setline(1, 'nine')
    call assert_fails("set omnifunc=function('NonExistingFunc')", 'E700:')
    call assert_fails("LET &omnifunc = function('NonExistingFunc')", 'E700:')
    LET g:OmniFunc2Args = []
    call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    call assert_equal([[1, ''], [0, 'nine']], g:OmniFunc2Args)
    bw!
  END
  call CheckLegacyAndVim9Success(lines)

  " Test for using a script-local function name
  func s:OmniFunc3(findstart, base)
    call add(g:OmniFunc3Args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set omnifunc=s:OmniFunc3
  new
  call setline(1, 'script1')
  let g:OmniFunc3Args = []
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'script1']], g:OmniFunc3Args)
  bw!

  let &omnifunc = 's:OmniFunc3'
  new
  call setline(1, 'script2')
  let g:OmniFunc3Args = []
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'script2']], g:OmniFunc3Args)
  bw!
  delfunc s:OmniFunc3

  " invalid return value
  let &omnifunc = {a -> 'abc'}
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')

  " Using Vim9 lambda expression in legacy context should fail
  set omnifunc=(a,\ b)\ =>\ OmniFunc1(21,\ a,\ b)
  new | only
  let g:OmniFunc1Args = []
  call assert_fails('call feedkeys("A\<C-X>\<C-O>\<Esc>", "x")', 'E117:')
  call assert_equal([], g:OmniFunc1Args)

  " set 'omnifunc' to a partial with dict. This used to cause a crash.
  func SetOmniFunc()
    let params = {'omni': function('g:DictOmniFunc')}
    let &omnifunc = params.omni
  endfunc
  func g:DictOmniFunc(_) dict
  endfunc
  call SetOmniFunc()
  new
  call SetOmniFunc()
  bw
  call test_garbagecollect_now()
  new
  set omnifunc=
  wincmd w
  set omnifunc=
  %bw!
  delfunc g:DictOmniFunc
  delfunc SetOmniFunc

  " Vim9 tests
  let lines =<< trim END
    vim9script

    def Vim9omniFunc(callnr: number, findstart: number, base: string): any
      add(g:Vim9omniFunc_Args, [callnr, findstart, base])
      return findstart ? 0 : []
    enddef

    # Test for using a def function with omnifunc
    set omnifunc=function('Vim9omniFunc',\ [60])
    new | only
    setline(1, 'one')
    g:Vim9omniFunc_Args = []
    feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    assert_equal([[60, 1, ''], [60, 0, 'one']], g:Vim9omniFunc_Args)
    bw!

    # Test for using a global function name
    &omnifunc = g:OmniFunc2
    new | only
    setline(1, 'two')
    g:OmniFunc2Args = []
    feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'two']], g:OmniFunc2Args)
    bw!

    # Test for using a script-local function name
    def LocalOmniFunc(findstart: number, base: string): any
      add(g:LocalOmniFuncArgs, [findstart, base])
      return findstart ? 0 : []
    enddef
    &omnifunc = LocalOmniFunc
    new | only
    setline(1, 'three')
    g:LocalOmniFuncArgs = []
    feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'three']], g:LocalOmniFuncArgs)
    bw!
  END
  call CheckScriptSuccess(lines)

  " cleanup
  set omnifunc&
  delfunc OmniFunc1
  delfunc OmniFunc2
  unlet g:OmniFunc1Args g:OmniFunc2Args
  %bw!
endfunc

" Test for different ways of setting the 'thesaurusfunc' option
func Test_thesaurusfunc_callback()
  func TsrFunc1(callnr, findstart, base)
    call add(g:TsrFunc1Args, [a:callnr, a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  func TsrFunc2(findstart, base)
    call add(g:TsrFunc2Args, [a:findstart, a:base])
    return a:findstart ? 0 : ['sunday']
  endfunc

  let lines =<< trim END
    #" Test for using a function name
    LET &thesaurusfunc = 'g:TsrFunc2'
    new
    call setline(1, 'zero')
    LET g:TsrFunc2Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[1, ''], [0, 'zero']], g:TsrFunc2Args)
    bw!

    #" Test for using a function()
    set thesaurusfunc=function('g:TsrFunc1',\ [10])
    new
    call setline(1, 'one')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[10, 1, ''], [10, 0, 'one']], g:TsrFunc1Args)
    bw!

    #" Using a funcref variable to set 'thesaurusfunc'
    VAR Fn = function('g:TsrFunc1', [11])
    LET &thesaurusfunc = Fn
    new
    call setline(1, 'two')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[11, 1, ''], [11, 0, 'two']], g:TsrFunc1Args)
    bw!

    #" Using a string(funcref_variable) to set 'thesaurusfunc'
    LET Fn = function('g:TsrFunc1', [12])
    LET &thesaurusfunc = string(Fn)
    new
    call setline(1, 'two')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[12, 1, ''], [12, 0, 'two']], g:TsrFunc1Args)
    bw!

    #" Test for using a funcref()
    set thesaurusfunc=funcref('g:TsrFunc1',\ [13])
    new
    call setline(1, 'three')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[13, 1, ''], [13, 0, 'three']], g:TsrFunc1Args)
    bw!

    #" Using a funcref variable to set 'thesaurusfunc'
    LET Fn = funcref('g:TsrFunc1', [14])
    LET &thesaurusfunc = Fn
    new
    call setline(1, 'four')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[14, 1, ''], [14, 0, 'four']], g:TsrFunc1Args)
    bw!

    #" Using a string(funcref_variable) to set 'thesaurusfunc'
    LET Fn = funcref('g:TsrFunc1', [15])
    LET &thesaurusfunc = string(Fn)
    new
    call setline(1, 'four')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[15, 1, ''], [15, 0, 'four']], g:TsrFunc1Args)
    bw!

    #" Test for using a lambda function
    VAR optval = "LSTART a, b LMIDDLE TsrFunc1(16, a, b) LEND"
    LET optval = substitute(optval, ' ', '\\ ', 'g')
    exe "set thesaurusfunc=" .. optval
    new
    call setline(1, 'five')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[16, 1, ''], [16, 0, 'five']], g:TsrFunc1Args)
    bw!

    #" Test for using a lambda function with set
    LET &thesaurusfunc = LSTART a, b LMIDDLE TsrFunc1(17, a, b) LEND
    new
    call setline(1, 'six')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[17, 1, ''], [17, 0, 'six']], g:TsrFunc1Args)
    bw!

    #" Set 'thesaurusfunc' to a string(lambda expression)
    LET &thesaurusfunc = 'LSTART a, b LMIDDLE TsrFunc1(18, a, b) LEND'
    new
    call setline(1, 'six')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[18, 1, ''], [18, 0, 'six']], g:TsrFunc1Args)
    bw!

    #" Set 'thesaurusfunc' to a variable with a lambda expression
    VAR Lambda = LSTART a, b LMIDDLE TsrFunc1(19, a, b) LEND
    LET &thesaurusfunc = Lambda
    new
    call setline(1, 'seven')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[19, 1, ''], [19, 0, 'seven']], g:TsrFunc1Args)
    bw!

    #" Set 'thesaurusfunc' to a string(variable with a lambda expression)
    LET Lambda = LSTART a, b LMIDDLE TsrFunc1(20, a, b) LEND
    LET &thesaurusfunc = string(Lambda)
    new
    call setline(1, 'seven')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[20, 1, ''], [20, 0, 'seven']], g:TsrFunc1Args)
    bw!

    #" Test for using a lambda function with incorrect return value
    LET Lambda = LSTART a, b LMIDDLE strlen(a) LEND
    LET &thesaurusfunc = Lambda
    new
    call setline(1, 'eight')
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    bw!

    #" Test for clearing the 'thesaurusfunc' option
    set thesaurusfunc=''
    set thesaurusfunc&
    call assert_fails("set thesaurusfunc=function('abc')", "E700:")
    call assert_fails("set thesaurusfunc=funcref('abc')", "E700:")

    #" set 'thesaurusfunc' to a non-existing function
    set thesaurusfunc=TsrFunc2
    call setline(1, 'ten')
    call assert_fails("set thesaurusfunc=function('NonExistingFunc')", 'E700:')
    call assert_fails("LET &thesaurusfunc = function('NonExistingFunc')", 'E700:')
    LET g:TsrFunc2Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    call assert_equal([[1, ''], [0, 'ten']], g:TsrFunc2Args)
    bw!

    #" Use a buffer-local value and a global value
    set thesaurusfunc&
    setlocal thesaurusfunc=function('g:TsrFunc1',\ [22])
    call setline(1, 'sun')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", "x")
    call assert_equal('sun', getline(1))
    call assert_equal([[22, 1, ''], [22, 0, 'sun']], g:TsrFunc1Args)
    new
    call setline(1, 'sun')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", "x")
    call assert_equal('sun', getline(1))
    call assert_equal([], g:TsrFunc1Args)
    set thesaurusfunc=function('g:TsrFunc1',\ [23])
    wincmd w
    call setline(1, 'sun')
    LET g:TsrFunc1Args = []
    call feedkeys("A\<C-X>\<C-T>\<Esc>", "x")
    call assert_equal('sun', getline(1))
    call assert_equal([[22, 1, ''], [22, 0, 'sun']], g:TsrFunc1Args)
    :%bw!
  END
  call CheckLegacyAndVim9Success(lines)

  " Test for using a script-local function name
  func s:TsrFunc3(findstart, base)
    call add(g:TsrFunc3Args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc

  set tsrfu=s:TsrFunc3
  new
  call setline(1, 'script1')
  let g:TsrFunc3Args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'script1']], g:TsrFunc3Args)
  bw!

  let &tsrfu = 's:TsrFunc3'
  new
  call setline(1, 'script2')
  let g:TsrFunc3Args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'script2']], g:TsrFunc3Args)
  bw!

  new | only
  set thesaurusfunc=
  setlocal thesaurusfunc=NoSuchFunc
  setglobal thesaurusfunc=s:TsrFunc3
  call assert_equal('NoSuchFunc', &thesaurusfunc)
  call assert_equal('NoSuchFunc', &l:thesaurusfunc)
  call assert_equal('s:TsrFunc3', &g:thesaurusfunc)
  new | only
  call assert_equal('s:TsrFunc3', &thesaurusfunc)
  call assert_equal('s:TsrFunc3', &g:thesaurusfunc)
  call assert_equal('', &l:thesaurusfunc)
  call setline(1, 'script1')
  let g:TsrFunc3Args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'script1']], g:TsrFunc3Args)
  bw!

  new | only
  set thesaurusfunc=
  setlocal thesaurusfunc=NoSuchFunc
  set thesaurusfunc=s:TsrFunc3
  call assert_equal('s:TsrFunc3', &thesaurusfunc)
  call assert_equal('s:TsrFunc3', &g:thesaurusfunc)
  call assert_equal('', &l:thesaurusfunc)
  call setline(1, 'script1')
  let g:TsrFunc3Args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'script1']], g:TsrFunc3Args)
  setlocal bufhidden=wipe
  new | only!
  call assert_equal('s:TsrFunc3', &thesaurusfunc)
  call assert_equal('s:TsrFunc3', &g:thesaurusfunc)
  call assert_equal('', &l:thesaurusfunc)
  call setline(1, 'script1')
  let g:TsrFunc3Args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'script1']], g:TsrFunc3Args)
  bw!

  delfunc s:TsrFunc3

  " invalid return value
  let &thesaurusfunc = {a -> 'abc'}
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')

  " Using Vim9 lambda expression in legacy context should fail
  set thesaurusfunc=(a,\ b)\ =>\ TsrFunc1(21,\ a,\ b)
  new | only
  let g:TsrFunc1Args = []
  call assert_fails('call feedkeys("A\<C-X>\<C-T>\<Esc>", "x")', 'E117:')
  call assert_equal([], g:TsrFunc1Args)
  bw!

  " set 'thesaurusfunc' to a partial with dict. This used to cause a crash.
  func SetTsrFunc()
    let params = {'thesaurus': function('g:DictTsrFunc')}
    let &thesaurusfunc = params.thesaurus
  endfunc
  func g:DictTsrFunc(_) dict
  endfunc
  call SetTsrFunc()
  new
  call SetTsrFunc()
  bw
  call test_garbagecollect_now()
  new
  set thesaurusfunc=
  wincmd w
  %bw!
  delfunc SetTsrFunc

  " set buffer-local 'thesaurusfunc' to a partial with dict. This used to
  " cause a crash.
  func SetLocalTsrFunc()
    let params = {'thesaurus': function('g:DictTsrFunc')}
    let &l:thesaurusfunc = params.thesaurus
  endfunc
  call SetLocalTsrFunc()
  call test_garbagecollect_now()
  call SetLocalTsrFunc()
  set thesaurusfunc=
  bw!
  delfunc g:DictTsrFunc
  delfunc SetLocalTsrFunc

  " Vim9 tests
  let lines =<< trim END
    vim9script

    def Vim9tsrFunc(callnr: number, findstart: number, base: string): any
      add(g:Vim9tsrFunc_Args, [callnr, findstart, base])
      return findstart ? 0 : []
    enddef

    # Test for using a def function with thesaurusfunc
    set thesaurusfunc=function('Vim9tsrFunc',\ [60])
    new | only
    setline(1, 'one')
    g:Vim9tsrFunc_Args = []
    feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    assert_equal([[60, 1, ''], [60, 0, 'one']], g:Vim9tsrFunc_Args)
    bw!

    # Test for using a global function name
    &thesaurusfunc = g:TsrFunc2
    new | only
    setline(1, 'two')
    g:TsrFunc2Args = []
    feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'two']], g:TsrFunc2Args)
    bw!

    # Test for using a script-local function name
    def LocalTsrFunc(findstart: number, base: string): any
      add(g:LocalTsrFuncArgs, [findstart, base])
      return findstart ? 0 : []
    enddef
    &thesaurusfunc = LocalTsrFunc
    new | only
    setline(1, 'three')
    g:LocalTsrFuncArgs = []
    feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'three']], g:LocalTsrFuncArgs)
    bw!
  END
  call CheckScriptSuccess(lines)

  " cleanup
  set thesaurusfunc&
  delfunc TsrFunc1
  delfunc TsrFunc2
  unlet g:TsrFunc1Args g:TsrFunc2Args
  %bw!
endfunc

func FooBarComplete(findstart, base)
  if a:findstart
    return col('.') - 1
  else
    return ["Foo", "Bar", "}"]
  endif
endfunc

func Test_complete_smartindent()
  new
  setlocal smartindent completefunc=FooBarComplete

  exe "norm! o{\<cr>\<c-x>\<c-u>\<c-p>}\<cr>\<esc>"
  let result = getline(1,'$')
  call assert_equal(['', '{','}',''], result)
  bw!
  delfunction! FooBarComplete
endfunc

func Test_complete_overrun()
  " this was going past the end of the copied text
  new
  sil norm si0s0
  bwipe!
endfunc

func Test_infercase_very_long_line()
  " this was truncating the line when inferring case
  new
  let longLine = "blah "->repeat(300)
  let verylongLine = "blah "->repeat(400)
  call setline(1, verylongLine)
  call setline(2, longLine)
  set ic infercase
  exe "normal 2Go\<C-X>\<C-L>\<Esc>"
  call assert_equal(longLine, getline(3))

  " check that the too long text is NUL terminated
  %del
  norm o
  norm 1987ax
  exec "norm ox\<C-X>\<C-L>"
  call assert_equal(repeat('x', 1987), getline(3))

  bwipe!
  set noic noinfercase
endfunc

func Test_ins_complete_add()
  " this was reading past the end of allocated memory
  new
  norm o
  norm 7o
  sil! norm o

  bwipe!
endfunc

func Test_ins_complete_end_of_line()
  " this was reading past the end of the line
  new
  norm 8oý 
  sil! norm o

  bwipe!
endfunc

func s:Tagfunc(t,f,o)
  bwipe!
  return []
endfunc

" This was using freed memory, since 'complete' was in a wiped out buffer.
" Also using a window that was closed.
func Test_tagfunc_wipes_out_buffer()
  new
  set complete=.,t,w,b,u,i
  se tagfunc=s:Tagfunc
  sil norm i

  bwipe!
endfunc

func Test_ins_complete_popup_position()
  CheckScreendump

  let lines =<< trim END
      vim9script
      set nowrap
      setline(1, ['one', 'two', 'this is line ', 'four'])
      prop_type_add('test', {highlight: 'Error'})
      prop_add(3, 0, {
          text_align: 'above',
          text: 'The quick brown fox jumps over the lazy dog',
          type: 'test'
      })
  END
  call writefile(lines, 'XinsPopup', 'D')
  let buf = RunVimInTerminal('-S XinsPopup', #{rows: 10})

  call term_sendkeys(buf, "3GA\<C-N>")
  call VerifyScreenDump(buf, 'Test_ins_complete_popup_position_1', {})

  call StopVimInTerminal(buf)
endfunc

func GetCompleteInfo()
  let g:compl_info = complete_info()
  return ''
endfunc

func Test_completion_restart()
  new
  set complete=. completeopt=menuone backspace=2
  call setline(1, 'workhorse workhorse')
  exe "normal $a\<C-N>\<BS>\<BS>\<C-R>=GetCompleteInfo()\<CR>"
  call assert_equal(1, len(g:compl_info['items']))
  call assert_equal('workhorse', g:compl_info['items'][0]['word'])
  set complete& completeopt& backspace&
  bwipe!
endfunc

func Test_complete_info_index()
  new
  call setline(1, ["aaa", "bbb", "ccc", "ddd", "eee", "fff"])
  inoremap <buffer><F5> <C-R>=GetCompleteInfo()<CR>

  " Ensure 'index' in complete_info() is coherent with the 'items' array.

  set completeopt=menu,preview
  " Search forward
  call feedkeys("Go\<C-X>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("aaa", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("bbb", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("ccc", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<C-N>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("ddd", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("eee", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("fff", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  " Search forward: unselected item
  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal(6 , len(g:compl_info['items']))
  call assert_equal(-1 , g:compl_info['selected'])

  " Search backward
  call feedkeys("Go\<C-X>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("fff", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-P>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("eee", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-P>\<C-P>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("ddd", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-P>\<C-P>\<C-P>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("ccc", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("bbb", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("aaa", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  " search backwards: unselected item
  call feedkeys("Go\<C-X>\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal(6 , len(g:compl_info['items']))
  call assert_equal(-1 , g:compl_info['selected'])

  " switch direction: forwards, then backwards
  call feedkeys("Go\<C-X>\<C-N>\<C-P>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("fff", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  " switch direction: forwards, then backwards, then forwards again
  call feedkeys("Go\<C-X>\<C-N>\<C-P>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<C-P>\<C-P>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("aaa", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))

  " switch direction: backwards, then forwards
  call feedkeys("Go\<C-X>\<C-P>\<C-N>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("aaa", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  " switch direction: backwards, then forwards, then backwards again
  call feedkeys("Go\<C-X>\<C-P>\<C-P>\<C-N>\<C-N>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("fff", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))

  " Add 'noselect', check that 'selected' is -1 when nothing is selected.
  set completeopt+=noselect
  " Search forward.
  call feedkeys("Go\<C-X>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal(-1, g:compl_info['selected'])

  " Search backward.
  call feedkeys("Go\<C-X>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal(-1, g:compl_info['selected'])

  call feedkeys("Go\<C-X>\<C-N>\<C-P>\<F5>\<Esc>_dd", 'tx')
  call assert_equal(5, g:compl_info['selected'])
  call assert_equal(6 , len(g:compl_info['items']))
  call assert_equal("fff", g:compl_info['items'][g:compl_info['selected']]['word'])
  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal("aaa", g:compl_info['items'][g:compl_info['selected']]['word'])
  call assert_equal(6 , len(g:compl_info['items']))
  call feedkeys("Go\<C-X>\<C-N>\<F5>\<Esc>_dd", 'tx')
  call assert_equal(-1, g:compl_info['selected'])
  call assert_equal(6 , len(g:compl_info['items']))

  set completeopt&
  bwipe!
endfunc

func Test_complete_changed_complete_info()
  CheckRunVimInTerminal
  " this used to crash vim, see #13929
  let lines =<< trim END
    set completeopt=menuone
    autocmd CompleteChanged * call complete_info(['items'])
    call feedkeys("iii\<cr>\<c-p>")
  END
  call writefile(lines, 'Xsegfault', 'D')
  let buf = RunVimInTerminal('-S Xsegfault', #{rows: 5})
  call WaitForAssert({-> assert_match('^ii', term_getline(buf, 1))}, 1000)
  call StopVimInTerminal(buf)
endfunc

func Test_completefunc_first_call_complete_add()
  new

  func Complete(findstart, base) abort
    if a:findstart
      let col = col('.')
      call complete_add('#')
      return col - 1
    else
      return []
    endif
  endfunc

  set completeopt=longest completefunc=Complete
  " This used to cause heap-buffer-overflow
  call assert_fails('call feedkeys("ifoo#\<C-X>\<C-U>", "xt")', 'E840:')

  delfunc Complete
  set completeopt& completefunc&
  bwipe!
endfunc

func Test_complete_opt_fuzzy()
  func OnPumChange()
    let g:item = get(v:event, 'completed_item', {})
    let g:word = get(g:item, 'word', v:null)
    let g:abbr = get(g:item, 'abbr', v:null)
    let g:selected = get(complete_info(['selected']), 'selected')
  endfunction

  augroup AAAAA_Group
    au!
    autocmd CompleteChanged * :call OnPumChange()
  augroup END

  func Omni_test(findstart, base)
    if a:findstart
      return col(".")
    endif
    return [#{word: "foo"}, #{word: "foobar"}, #{word: "fooBaz"}, #{word: "foobala"}, #{word: "你好吗"}, #{word: "我好"}]
  endfunc

  new
  set omnifunc=Omni_test
  set completeopt+=noinsert,fuzzy
  call feedkeys("Gi\<C-x>\<C-o>", 'tx')
  call assert_equal('foo', g:word)
  call feedkeys("S\<C-x>\<C-o>fb", 'tx')
  call assert_equal('fooBaz', g:word)
  call feedkeys("S\<C-x>\<C-o>fa", 'tx')
  call assert_equal('foobar', g:word)
  " select next
  call feedkeys("S\<C-x>\<C-o>fb\<C-n>", 'tx')
  call assert_equal('foobar', g:word)
  " can cyclically select next
  call feedkeys("S\<C-x>\<C-o>fb\<C-n>\<C-n>\<C-n>", 'tx')
  call assert_equal(v:null, g:word)
  " select prev
  call feedkeys("S\<C-x>\<C-o>fb\<C-p>", 'tx')
  call assert_equal(v:null, g:word)
  " can cyclically select prev
  call feedkeys("S\<C-x>\<C-o>fb\<C-p>\<C-p>\<C-p>\<C-p>", 'tx')
  call assert_equal('fooBaz', g:word)

  func Comp()
    call complete(col('.'), ["fooBaz", "foobar", "foobala"])
    return ''
  endfunc
  call feedkeys("i\<C-R>=Comp()\<CR>", 'tx')
  call assert_equal('fooBaz', g:word)

  " respect noselect
  set completeopt+=noselect
  call feedkeys("S\<C-x>\<C-o>fb", 'tx')
  call assert_equal(v:null, g:word)
  call feedkeys("S\<C-x>\<C-o>fb\<C-n>", 'tx')
  call assert_equal('fooBaz', g:word)

  " test case for nosort option
  set cot=menuone,menu,noinsert,fuzzy,nosort
  " "fooBaz" should have a higher score when the leader is "fb".
  " With "nosort", "foobar" should still be shown first in the popup menu.
  call feedkeys("S\<C-x>\<C-o>fb", 'tx')
  call assert_equal('foobar', g:word)
  call feedkeys("S\<C-x>\<C-o>好", 'tx')
  call assert_equal("你好吗", g:word)

  set cot+=noselect
  call feedkeys("S\<C-x>\<C-o>好", 'tx')
  call assert_equal(v:null, g:word)
  call feedkeys("S\<C-x>\<C-o>好\<C-N>", 'tx')
  call assert_equal('你好吗', g:word)

  " "nosort" shouldn't enable fuzzy filtering when "fuzzy" isn't present.
  set cot=menuone,noinsert,nosort
  call feedkeys("S\<C-x>\<C-o>fooB\<C-Y>", 'tx')
  call assert_equal('fooBaz', getline('.'))

  set cot=menuone,fuzzy,nosort
  func CompAnother()
    call complete(col('.'), [#{word: "do" }, #{word: "echo"}, #{word: "for (${1:expr1}, ${2:expr2}, ${3:expr3}) {\n\t$0\n}", abbr: "for" }, #{word: "foo"}])
    return ''
  endfunc
  call feedkeys("i\<C-R>=CompAnother()\<CR>\<C-N>\<C-N>", 'tx')
  call assert_equal("for", g:abbr)
  call assert_equal(2, g:selected)

  set cot+=noinsert
  call feedkeys("i\<C-R>=CompAnother()\<CR>f", 'tx')
  call assert_equal("for", g:abbr)
  call assert_equal(2, g:selected)

  set cot=menu,menuone,noselect,fuzzy
  call feedkeys("i\<C-R>=CompAnother()\<CR>\<C-N>\<C-N>\<C-N>\<C-N>", 'tx')
  call assert_equal("foo", g:word)
  call feedkeys("i\<C-R>=CompAnother()\<CR>\<C-P>", 'tx')
  call assert_equal("foo", g:word)
  call feedkeys("i\<C-R>=CompAnother()\<CR>\<C-P>\<C-P>", 'tx')
  call assert_equal("for", g:abbr)

  " clean up
  set omnifunc=
  bw!
  set complete& completeopt&
  autocmd! AAAAA_Group
  augroup! AAAAA_Group
  delfunc OnPumChange
  delfunc Omni_test
  delfunc Comp
  unlet g:item
  unlet g:word
  unlet g:abbr
endfunc

func Test_complete_fuzzy_collect()
  new
  redraw  " need this to prevent NULL dereference in Nvim
  set completefuzzycollect=keyword,files,whole_line
  call setline(1, ['hello help hero h'])
  " Use "!" flag of feedkeys() so that ex_normal_busy is not set and
  " ins_compl_check_keys() is not skipped.
  " Add a "0" after the <Esc> to avoid waiting for an escape sequence.
  call feedkeys("A\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('hello help hero hello', getline('.'))
  set completeopt+=noinsert
  call setline(1, ['hello help hero h'])
  call feedkeys("A\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('hello help hero h', getline('.'))

  set completeopt-=noinsert
  call setline(1, ['xyz  yxz  x'])
  call feedkeys("A\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('xyz  yxz  xyz', getline('.'))
  " can fuzzy get yxz when use Ctrl-N twice
  call setline(1, ['xyz  yxz  x'])
  call feedkeys("A\<C-X>\<C-N>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('xyz  yxz  yxz', getline('.'))

  call setline(1, ['你好 你'])
  call feedkeys("A\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('你好 你好', getline('.'))
  call setline(1, ['你的 我的 的'])
  call feedkeys("A\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('你的 我的 你的', getline('.'))
  " can fuzzy get multiple-byte word when use Ctrl-N twice
  call setline(1, ['你的 我的 的'])
  call feedkeys("A\<C-X>\<C-N>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('你的 我的 我的', getline('.'))

  " fuzzy on file
  call writefile([''], 'fobar', 'D')
  call writefile([''], 'foobar', 'D')
  call setline(1, ['fob'])
  call cursor(1, 1)
  call feedkeys("A\<C-X>\<C-f>\<Esc>0", 'tx!')
  call assert_equal('fobar', getline('.'))
  call feedkeys("Sfob\<C-X>\<C-f>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('foobar', getline('.'))
  call feedkeys("S../\<C-X>\<C-f>\<Esc>0", 'tx!')
  call assert_match('../*', getline('.'))
  call feedkeys("S../td\<C-X>\<C-f>\<Esc>0", 'tx!')
  call assert_match('../testdir', getline('.'))

  " can get completion from other buffer
  vnew
  call setline(1, ["completeness,", "compatibility", "Composite", "Omnipotent"])
  wincmd p
  call feedkeys("Somp\<C-N>\<Esc>0", 'tx!')
  call assert_equal('completeness', getline('.'))
  call feedkeys("Somp\<C-N>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('compatibility', getline('.'))
  call feedkeys("Somp\<C-P>\<Esc>0", 'tx!')
  call assert_equal('Omnipotent', getline('.'))
  call feedkeys("Somp\<C-P>\<C-P>\<Esc>0", 'tx!')
  call assert_equal('Composite', getline('.'))
  call feedkeys("S omp\<C-N>\<Esc>0", 'tx!')
  call assert_equal(' completeness', getline('.'))

  " fuzzy on whole line completion
  call setline(1, ["world is on fire", "no one can save me but you", 'user can execute', ''])
  call cursor(4, 1)
  call feedkeys("Swio\<C-X>\<C-L>\<Esc>0", 'tx!')
  call assert_equal('world is on fire', getline('.'))
  call feedkeys("Su\<C-X>\<C-L>\<C-P>\<Esc>0", 'tx!')
  call assert_equal('no one can save me but you', getline('.'))

  " issue #15412
  call setline(1, ['alpha bravio charlie'])
  call feedkeys("Salpha\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('alpha bravio', getline('.'))
  call feedkeys("Salp\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('alpha', getline('.'))
  call feedkeys("A\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('alpha bravio', getline('.'))
  call feedkeys("A\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('alpha bravio charlie', getline('.'))

  set complete-=i
  call feedkeys("Salp\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('alpha', getline('.'))
  call feedkeys("A\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('alpha bravio', getline('.'))
  call feedkeys("A\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('alpha bravio charlie', getline('.'))

  call setline(1, ['alpha bravio charlie', 'alpha another'])
  call feedkeys("Salpha\<C-X>\<C-N>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('alpha another', getline('.'))
  call setline(1, ['你好 我好', '你好 他好'])
  call feedkeys("S你好\<C-X>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('你好 我好', getline('.'))
  call feedkeys("S你好\<C-X>\<C-N>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('你好 他好', getline('.'))

  " issue #15526
  set completeopt=menuone,menu,noselect
  call setline(1, ['Text', 'ToText', ''])
  call cursor(3, 1)
  call feedkeys("STe\<C-X>\<C-N>x\<CR>\<Esc>0", 'tx!')
  call assert_equal('Tex', getline(line('.') - 1))

  call setline(1, ['fuzzy', 'fuzzycollect', 'completefuzzycollect'])
  call feedkeys("Gofuzzy\<C-X>\<C-N>\<C-N>\<C-N>\<CR>\<Esc>0", 'tx!')
  call assert_equal('fuzzycollect', getline(line('.') - 1))
  call feedkeys("Gofuzzy\<C-X>\<C-N>\<C-N>\<C-N>\<C-N>\<CR>\<Esc>0", 'tx!')
  call assert_equal('completefuzzycollect', getline(line('.') - 1))

  " keywords in 'dictonary'
  call writefile(['hello', 'think'], 'test_dict.txt', 'D')
  set dict=test_dict.txt
  call feedkeys("Sh\<C-X>\<C-K>\<C-N>\<CR>\<Esc>0", 'tx!')
  call assert_equal('hello', getline(line('.') - 1))
  call feedkeys("Sh\<C-X>\<C-K>\<C-N>\<C-N>\<CR>\<Esc>0", 'tx!')
  call assert_equal('think', getline(line('.') - 1))

  call setline(1, ['foo bar fuzzy', 'completefuzzycollect'])
  call feedkeys("Gofuzzy\<C-X>\<C-N>\<C-N>\<C-N>\<C-Y>\<Esc>0", 'tx!')
  call assert_equal('completefuzzycollect', getline('.'))

  bw!
  bw!
  set dict&
  set completeopt& cfc& cpt&
endfunc

func Test_cfc_with_longest()
  new
  set completefuzzycollect=keyword,files,whole_line
  set completeopt=menu,menuone,longest,fuzzy

  " keyword
  exe "normal ggdGShello helio think h\<C-X>\<C-N>\<ESC>"
  call assert_equal("hello helio think hel", getline('.'))
  exe "normal hello helio think h\<C-X>\<C-P>\<ESC>"
  call assert_equal("hello helio think hel", getline('.'))

  " skip non-consecutive prefixes
  exe "normal ggdGShello helio heo\<C-X>\<C-N>\<ESC>"
  call assert_equal("hello helio heo", getline('.'))

  " kdcit
  call writefile(['help'], 'test_keyword.txt', 'D')
  set complete=ktest_keyword.txt
  exe "normal ggdGSh\<C-N>\<ESC>"
  " auto insert help when only have one match
  call assert_equal("help", getline('.'))
  call writefile(['hello', 'help', 'think'], 'xtest_keyword.txt', 'D')
  set complete=kxtest_keyword.txt
  " auto insert hel
  exe "normal ggdGSh\<C-N>\<ESC>"
  call assert_equal("hel", getline('.'))

  " line start with a space
  call writefile([' hello'], 'test_case1.txt', 'D')
  set complete=ktest_case1.txt
  exe "normal ggdGSh\<C-N>\<ESC>"
  call assert_equal("hello", getline('.'))

  " multiple matches
  set complete=ktest_case2.txt
  call writefile([' hello help what'], 'test_case2.txt', 'D')
  exe "normal ggdGSh\<C-N>\<C-N>\<C-N>\<C-N>\<ESC>"
  call assert_equal("what", getline('.'))

  " multiple lines of matches
  set complete=ktest_case3.txt
  call writefile([' hello help what', 'hola', '     hey'], 'test_case3.txt', 'D')
  exe "normal ggdGSh\<C-N>\<C-N>\<ESC>"
  call assert_equal("hey", getline('.'))
  exe "normal ggdGSh\<C-N>\<C-N>\<C-N>\<C-N>\<ESC>"
  call assert_equal("hola", getline('.'))

  set complete=ktest_case4.txt
  call writefile(['  auto int   enum register', 'why'], 'test_case4.txt', 'D')
  exe "normal ggdGSe\<C-N>\<C-N>\<ESC>"
  call assert_equal("enum", getline('.'))

  set complete=ktest_case5.txt
  call writefile(['hello friends', 'go', 'hero'], 'test_case5.txt', 'D')
  exe "normal ggdGSh\<C-N>\<C-N>\<ESC>"
  call assert_equal("hero", getline('.'))
  set complete&

  " file
  call writefile([''], 'hello', 'D')
  call writefile([''], 'helio', 'D')
  exe "normal ggdGS./h\<C-X>\<C-f>\<ESC>"
  call assert_equal('./hel', getline('.'))

  " word
  call setline(1, ['what do you think', 'why i have that', ''])
  call cursor(3,1)
  call feedkeys("Sw\<C-X>\<C-l>\<C-N>\<Esc>0", 'tx!')
  call assert_equal('wh', getline('.'))

  exe "normal ggdG"
  " auto complete when only one match
  exe "normal Shello\<CR>h\<C-X>\<C-N>\<esc>"
  call assert_equal('hello', getline('.'))
  exe "normal Sh\<C-N>\<C-P>\<esc>"
  call assert_equal('hello', getline('.'))

  exe "normal Shello\<CR>h\<C-X>\<C-N>\<Esc>cch\<C-X>\<C-N>\<Esc>"
  call assert_equal('hello', getline('.'))

  " continue search for new leader after insert common prefix
  exe "normal ohellokate\<CR>h\<C-X>\<C-N>k\<C-y>\<esc>"
  call assert_equal('hellokate', getline('.'))

  bw!
  set completeopt&
  set completefuzzycollect&
endfunc

func Test_completefuzzycollect_with_completeslash()
  CheckMSWindows

  call writefile([''], 'fobar', 'D')
  let orig_shellslash = &shellslash
  set cpt&
  new
  set completefuzzycollect=files
  set noshellslash

  " Test with completeslash unset
  set completeslash=
  call setline(1, ['.\fob'])
  call feedkeys("A\<C-X>\<C-F>\<Esc>0", 'tx!')
  call assert_equal('.\fobar', getline('.'))

  " Test with completeslash=backslash
  set completeslash=backslash
  call feedkeys("S.\\fob\<C-X>\<C-F>\<Esc>0", 'tx!')
  call assert_equal('.\fobar', getline('.'))

  " Test with completeslash=slash
  set completeslash=slash
  call feedkeys("S.\\fob\<C-X>\<C-F>\<Esc>0", 'tx!')
  call assert_equal('./fobar', getline('.'))

  " Reset and clean up
  let &shellslash = orig_shellslash
  set completeslash=
  set completefuzzycollect&
  %bw!
endfunc

" Check that tie breaking is stable for completeopt+=fuzzy (which should
" behave the same on different platforms).
func Test_complete_fuzzy_match_tie()
  new
  set completeopt+=fuzzy,noselect
  call setline(1, ['aaabbccc', 'aaabbCCC', 'aaabbcccc', 'aaabbCCCC', ''])

  call feedkeys("Gcc\<C-X>\<C-N>ab\<C-N>\<C-Y>", 'tx')
  call assert_equal('aaabbccc', getline('.'))
  call feedkeys("Gcc\<C-X>\<C-N>ab\<C-N>\<C-N>\<C-Y>", 'tx')
  call assert_equal('aaabbCCC', getline('.'))
  call feedkeys("Gcc\<C-X>\<C-N>ab\<C-N>\<C-N>\<C-N>\<C-Y>", 'tx')
  call assert_equal('aaabbcccc', getline('.'))
  call feedkeys("Gcc\<C-X>\<C-N>ab\<C-N>\<C-N>\<C-N>\<C-N>\<C-Y>", 'tx')
  call assert_equal('aaabbCCCC', getline('.'))

  bwipe!
  set completeopt&
endfunc

func Test_complete_backwards_default()
  new
  call append(1, ['foobar', 'foobaz'])
  new
  call feedkeys("i\<c-p>", 'tx')
  call assert_equal('foobaz', getline('.'))
  bw!
  bw!
endfunc

func Test_complete_info_matches()
  let g:what = ['matches']
  func ShownInfo()
    let g:compl_info = complete_info(g:what)
    return ''
  endfunc
  set completeopt+=noinsert

  new
  call setline(1, ['aaa', 'aab', 'aba', 'abb'])
  inoremap <buffer><F5> <C-R>=ShownInfo()<CR>

  call feedkeys("Go\<C-X>\<C-N>\<F5>\<Esc>dd", 'tx')
  call assert_equal([
    \ {'word': 'aaa', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \ {'word': 'aab', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \ {'word': 'aba', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \ {'word': 'abb', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \], g:compl_info['matches'])

  call feedkeys("Goa\<C-X>\<C-N>b\<F5>\<Esc>dd", 'tx')
  call assert_equal([
    \ {'word': 'aba', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \ {'word': 'abb', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \], g:compl_info['matches'])

  " items and matches both in what
  let g:what = ['items', 'matches']
  call feedkeys("Goa\<C-X>\<C-N>b\<F5>\<Esc>dd", 'tx')
  call assert_equal([
    \ {'word': 'aaa', 'menu': '', 'user_data': '', 'match': v:false, 'info': '', 'kind': '', 'abbr': ''},
    \ {'word': 'aab', 'menu': '', 'user_data': '', 'match': v:false, 'info': '', 'kind': '', 'abbr': ''},
    \ {'word': 'aba', 'menu': '', 'user_data': '', 'match': v:true, 'info': '', 'kind': '', 'abbr': ''},
    \ {'word': 'abb', 'menu': '', 'user_data': '', 'match': v:true, 'info': '', 'kind': '', 'abbr': ''},
    \], g:compl_info['items'])
  call assert_false(has_key(g:compl_info, 'matches'))

  bw!
  unlet g:what
  delfunc ShownInfo
  set cot&
endfunc

func Test_complete_info_completed()
  func ShownInfo()
    let g:compl_info = complete_info(['completed'])
    return ''
  endfunc
  set completeopt+=noinsert

  new
  call setline(1, ['aaa', 'aab', 'aba', 'abb'])
  inoremap <buffer><F5> <C-R>=ShownInfo()<CR>

  call feedkeys("Go\<C-X>\<C-N>\<F5>\<Esc>dd", 'tx')
  call assert_equal({'word': 'aaa', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},  g:compl_info['completed'])

  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<F5>\<Esc>dd", 'tx')
  call assert_equal({'word': 'aab', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},  g:compl_info['completed'])

  call feedkeys("Go\<C-X>\<C-N>\<C-N>\<C-N>\<C-N>\<F5>\<Esc>dd", 'tx')
  call assert_equal({'word': 'abb', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},  g:compl_info['completed'])

  set completeopt+=noselect
  call feedkeys("Go\<C-X>\<C-N>\<F5>\<Esc>dd", 'tx')
  call assert_equal({}, g:compl_info)

  bw!
  delfunc ShownInfo
  set cot&
endfunc

function Test_completeopt_preinsert()
  func Omni_test(findstart, base)
    if a:findstart
      return col(".")
    endif
    return [#{word: "fobar"}, #{word: "foobar"}, #{word: "你的"}, #{word: "你好世界"}]
  endfunc
  set omnifunc=Omni_test
  set completeopt=menu,menuone,preinsert
  func GetLine()
    let g:line = getline('.')
    let g:col = col('.')
  endfunc

  new
  inoremap <buffer><F5> <C-R>=GetLine()<CR>
  call feedkeys("S\<C-X>\<C-O>f\<F5>\<ESC>", 'tx')
  call assert_equal("fobar", g:line)
  call assert_equal(2, g:col)

  call feedkeys("S\<C-X>\<C-O>foo\<F5><ESC>", 'tx')
  call assert_equal("foobar", g:line)

  call feedkeys("S\<C-X>\<C-O>foo\<BS>\<BS>\<BS>", 'tx')
  call assert_equal("", getline('.'))

  " delete a character and input new leader
  call feedkeys("S\<C-X>\<C-O>foo\<BS>b\<F5>\<ESC>", 'tx')
  call assert_equal("fobar", g:line)
  call assert_equal(4, g:col)

  " delete preinsert when prepare completion
  call feedkeys("S\<C-X>\<C-O>f\<Space>", 'tx')
  call assert_equal("f ", getline('.'))

  call feedkeys("S\<C-X>\<C-O>你\<F5>\<ESC>", 'tx')
  call assert_equal("你的", g:line)
  call assert_equal(4, g:col)

  call feedkeys("S\<C-X>\<C-O>你好\<F5>\<ESC>", 'tx')
  call assert_equal("你好世界", g:line)
  call assert_equal(7, g:col)

  call feedkeys("Shello   wo\<Left>\<Left>\<Left>\<C-X>\<C-O>f\<F5>\<ESC>", 'tx')
  call assert_equal("hello  fobar wo", g:line)
  call assert_equal(9, g:col)

  call feedkeys("Shello   wo\<Left>\<Left>\<Left>\<C-X>\<C-O>f\<BS>\<F5>\<ESC>", 'tx')
  call assert_equal("hello   wo", g:line)
  call assert_equal(8, g:col)

  call feedkeys("Shello   wo\<Left>\<Left>\<Left>\<C-X>\<C-O>foo\<F5>\<ESC>", 'tx')
  call assert_equal("hello  foobar wo", g:line)
  call assert_equal(11, g:col)

  call feedkeys("Shello   wo\<Left>\<Left>\<Left>\<C-X>\<C-O>foo\<BS>b\<F5>\<ESC>", 'tx')
  call assert_equal("hello  fobar wo", g:line)
  call assert_equal(11, g:col)

  " confirm
  call feedkeys("S\<C-X>\<C-O>f\<C-Y>", 'tx')
  call assert_equal("fobar", getline('.'))
  call assert_equal(5, col('.'))

  " cancel
  call feedkeys("S\<C-X>\<C-O>fo\<C-E>", 'tx')
  call assert_equal("fo", getline('.'))
  call assert_equal(2, col('.'))

  call feedkeys("S hello hero\<CR>h\<C-X>\<C-N>\<F5>\<ESC>", 'tx')
  call assert_equal("hello", g:line)
  call assert_equal(2, col('.'))

  call feedkeys("Sh\<C-X>\<C-N>\<C-Y>", 'tx')
  call assert_equal("hello", getline('.'))
  call assert_equal(5, col('.'))

  " delete preinsert part
  call feedkeys("S\<C-X>\<C-O>fo ", 'tx')
  call assert_equal("fo ", getline('.'))
  call assert_equal(3, col('.'))

  call feedkeys("She\<C-X>\<C-N>\<C-U>", 'tx')
  call assert_equal("", getline('.'))
  call assert_equal(1, col('.'))

  call feedkeys("She\<C-X>\<C-N>\<C-W>", 'tx')
  call assert_equal("", getline('.'))
  call assert_equal(1, col('.'))

  " whole line
  call feedkeys("Shello hero\<CR>\<C-X>\<C-L>\<F5>\<ESC>", 'tx')
  call assert_equal("hello hero", g:line)
  call assert_equal(1, g:col)

  call feedkeys("Shello hero\<CR>he\<C-X>\<C-L>\<F5>\<ESC>", 'tx')
  call assert_equal("hello hero", g:line)
  call assert_equal(3, g:col)

  call feedkeys("Shello hero\<CR>h\<C-X>\<C-N>er\<F5>\<ESC>", 'tx')
  call assert_equal("hero", g:line)
  call assert_equal(4, g:col)

  " can not work with fuzzy
  set cot+=fuzzy
  call feedkeys("S\<C-X>\<C-O>", 'tx')
  call assert_equal("fobar", getline('.'))
  call assert_equal(5, col('.'))

  " test for fuzzy and noinsert
  set cot+=noinsert
  call feedkeys("S\<C-X>\<C-O>fb\<F5>\<ESC>", 'tx')
  call assert_equal("fb", g:line)
  call assert_equal(3, g:col)

  call feedkeys("S\<C-X>\<C-O>你\<F5>\<ESC>", 'tx')
  call assert_equal("你", g:line)
  call assert_equal(4, g:col)

  call feedkeys("S\<C-X>\<C-O>fb\<C-Y>", 'tx')
  call assert_equal("fobar", getline('.'))
  call assert_equal(5, col('.'))

  " When the pum is not visible, the preinsert has no effect
  set cot=preinsert
  call feedkeys("Sfoo1 foo2\<CR>f\<C-X>\<C-N>bar", 'tx')
  call assert_equal("foo1bar", getline('.'))
  call assert_equal(7, col('.'))

  set cot=preinsert,menuone
  call feedkeys("Sfoo1 foo2\<CR>f\<C-X>\<C-N>\<F5>\<ESC>", 'tx')
  call assert_equal("foo1", g:line)
  call assert_equal(2, g:col)

  inoremap <buffer> <f3> <cmd>call complete(4, [{'word': "fobar"}, {'word': "foobar"}])<CR>
  call feedkeys("Swp.\<F3>\<F5>\<BS>\<ESC>", 'tx')
  call assert_equal("wp.fobar", g:line)
  call assert_equal(4, g:col)
  call assert_equal("wp.", getline('.'))

  bw!
  set cot&
  set omnifunc&
  delfunc Omni_test
endfunc

" Check that mark positions are correct after triggering multiline completion.
func Test_complete_multiline_marks()
  func Omni_test(findstart, base)
    if a:findstart
      return col(".")
    endif
    return [
          \ #{word: "func ()\n\t\nend"},
          \ #{word: "foobar"},
          \ #{word: "你好\n\t\n我好"}
          \ ]
  endfunc
  set omnifunc=Omni_test

  new
  let lines = mapnew(range(10), 'string(v:val)')
  call setline(1, lines)
  call setpos("'a", [0, 3, 1, 0])

  call feedkeys("A \<C-X>\<C-O>\<C-E>\<BS>", 'tx')
  call assert_equal(lines, getline(1, '$'))
  call assert_equal([0, 3, 1, 0], getpos("'a"))

  call feedkeys("A \<C-X>\<C-O>\<C-N>\<C-E>\<BS>", 'tx')
  call assert_equal(lines, getline(1, '$'))
  call assert_equal([0, 3, 1, 0], getpos("'a"))

  call feedkeys("A \<C-X>\<C-O>\<C-N>\<C-N>\<C-E>\<BS>", 'tx')
  call assert_equal(lines, getline(1, '$'))
  call assert_equal([0, 3, 1, 0], getpos("'a"))

  call feedkeys("A \<C-X>\<C-O>\<C-N>\<C-N>\<C-N>\<C-E>\<BS>", 'tx')
  call assert_equal(lines, getline(1, '$'))
  call assert_equal([0, 3, 1, 0], getpos("'a"))

  call feedkeys("A \<C-X>\<C-O>\<C-Y>", 'tx')
  call assert_equal(['0 func ()', "\t", 'end'] + lines[1:], getline(1, '$'))
  call assert_equal([0, 5, 1, 0], getpos("'a"))

  bw!
  set omnifunc&
  delfunc Omni_test
endfunc

func Test_complete_append_selected_match_default()
  " when typing a normal character during completion,
  " completion is ended, see
  " :h popupmenu-completion ("There are three states:")
  func PrintMenuWords()
    let info = complete_info(["selected", "matches"])
    call map(info.matches, {_, v -> v.word})
    return info
  endfunc

  new
  call setline(1, ["fo", "foo", "foobar", "fobarbaz"])
  exe "normal! Gof\<c-n>\<c-r>=PrintMenuWords()\<cr>"
  call assert_equal('fo{''matches'': [''fo'', ''foo'', ''foobar'', ''fobarbaz''], ''selected'': 0}', getline(5))
  %d
  call setline(1, ["fo", "foo", "foobar", "fobarbaz"])
  exe "normal! Gof\<c-n>o\<c-r>=PrintMenuWords()\<cr>"
  call assert_equal('foo{''matches'': [], ''selected'': -1}', getline(5))
  %d
  set completeopt=menu,noselect
  call setline(1, ["fo", "foo", "foobar", "fobarbaz"])
  exe "normal! Gof\<c-n>\<c-n>o\<c-r>=PrintMenuWords()\<cr>"
  call assert_equal('foo{''matches'': [], ''selected'': -1}', getline(5))
  bw!

  set completeopt&
  delfunc PrintMenuWords
endfunc

" vim: shiftwidth=2 sts=2 expandtab nofoldenable
