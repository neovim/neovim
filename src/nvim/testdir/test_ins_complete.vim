source screendump.vim
source check.vim

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

  set cpt=.,w,i
  " i-add-expands and switches to local
  exe "normal OM\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>\<C-X>\<C-X>\<C-X>\<C-P>"
  call assert_equal("Makefile\tto\trun3", getline('.'))
  " add-expands lines (it would end in an empty line if it didn't ignored
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

func s:CompleteDone_CompleteFuncNone( findstart, base )
  throw 'skipped: Nvim does not support v:none'
  if a:findstart
    return 0
  endif

  return v:none
endfunc

function! s:CompleteDone_CompleteFuncDict( findstart, base )
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
endfunction

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
              \ 'kind': 'W'
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

func Test_issue_7021()
  CheckMSWindows

  let orig_shellslash = &shellslash
  set noshellslash

  set completeslash=slash
  call assert_false(expand('~') =~ '/')

  let &shellslash = orig_shellslash
  set completeslash=
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
  call term_wait(buf, 100)
  call term_sendkeys(buf, "a\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_with_folds_two_tabs', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
  call delete('Xpumscript')
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

" Test to ensure 'Scanning...' messages are not recorded in messages history
func Test_z1_complete_no_history()
  new
  messages clear
  let currmess = execute('messages')
  setlocal dictionary=README.txt
  exe "normal owh\<C-X>\<C-K>"
  exe "normal owh\<C-N>"
  call assert_equal(currmess, execute('messages'))
  close!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
