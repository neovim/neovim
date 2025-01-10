" Test for completion menu

source shared.vim
source screendump.vim
source check.vim

let g:months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
let g:setting = ''

func ListMonths()
  if g:setting != ''
    exe ":set" g:setting
  endif
  let mth = copy(g:months)
  let entered = strcharpart(getline('.'),0,col('.'))
  if !empty(entered)
    let mth = filter(mth, 'v:val=~"^".entered')
  endif
  call complete(1, mth)
  return ''
endfunc

func Test_popup_complete2()
  " Although the popupmenu is not visible, this does not mean completion mode
  " has ended. After pressing <f5> to complete the currently typed char, Vim
  " still stays in the first state of the completion (:h ins-completion-menu),
  " although the popupmenu wasn't shown <c-e> will remove the inserted
  " completed text (:h complete_CTRL-E), while the following <c-e> will behave
  " like expected (:h i_CTRL-E)
  new
  inoremap <f5> <c-r>=ListMonths()<cr>
  call append(1, ["December2015"])
  :1
  call feedkeys("aD\<f5>\<C-E>\<C-E>\<C-E>\<C-E>\<enter>\<esc>", 'tx')
  call assert_equal(["Dece", "", "December2015"], getline(1,3))
  %d
  bw!
endfunc

func Test_popup_complete()
  new
  inoremap <f5> <c-r>=ListMonths()<cr>

  " <C-E> - select original typed text before the completion started
  call feedkeys("aJu\<f5>\<down>\<c-e>\<esc>", 'tx')
  call assert_equal(["Ju"], getline(1,2))
  %d

  " <C-Y> - accept current match
  call feedkeys("a\<f5>". repeat("\<down>",7). "\<c-y>\<esc>", 'tx')
  call assert_equal(["August"], getline(1,2))
  %d

  " <BS> - Delete one character from the inserted text (state: 1)
  " TODO: This should not end the completion, but it does.
  " This should according to the documentation:
  " January
  " but instead, this does
  " Januar
  " (idea is, C-L inserts the match from the popup menu
  " but if the menu is closed, it will insert the character <c-l>
  call feedkeys("aJ\<f5>\<bs>\<c-l>\<esc>", 'tx')
  call assert_equal(["Januar"], getline(1,2))
  %d

  " any-non special character: Stop completion without changing the match
  " and insert the typed character
  call feedkeys("a\<f5>20", 'tx')
  call assert_equal(["January20"], getline(1,2))
  %d

  " any-non printable, non-white character: Add this character and
  " reduce number of matches
  call feedkeys("aJu\<f5>\<c-p>l\<c-y>", 'tx')
  call assert_equal(["Jul"], getline(1,2))
  %d

  " any-non printable, non-white character: Add this character and
  " reduce number of matches
  call feedkeys("aJu\<f5>\<c-p>l\<c-n>\<c-y>", 'tx')
  call assert_equal(["July"], getline(1,2))
  %d

  " any-non printable, non-white character: Add this character and
  " reduce number of matches
  call feedkeys("aJu\<f5>\<c-p>l\<c-e>", 'tx')
  call assert_equal(["Jul"], getline(1,2))
  %d

  " <BS> - Delete one character from the inserted text (state: 2)
  call feedkeys("a\<f5>\<c-n>\<bs>", 'tx')
  call assert_equal(["Februar"], getline(1,2))
  %d

  " <c-l> - Insert one character from the current match
  call feedkeys("aJ\<f5>".repeat("\<c-n>",3)."\<c-l>\<esc>", 'tx')
  call assert_equal(["J"], getline(1,2))
  %d

  " <c-l> - Insert one character from the current match
  call feedkeys("aJ\<f5>".repeat("\<c-n>",4)."\<c-l>\<esc>", 'tx')
  call assert_equal(["January"], getline(1,2))
  %d

  " <c-y> - Accept current selected match
  call feedkeys("aJ\<f5>\<c-y>\<esc>", 'tx')
  call assert_equal(["January"], getline(1,2))
  %d

  " <c-e> - End completion, go back to what was there before selecting a match
  call feedkeys("aJu\<f5>\<c-e>\<esc>", 'tx')
  call assert_equal(["Ju"], getline(1,2))
  %d

  " <PageUp> - Select a match several entries back
  call feedkeys("a\<f5>\<PageUp>\<c-y>\<esc>", 'tx')
  call assert_equal([""], getline(1,2))
  %d

  " <PageUp><PageUp> - Select a match several entries back
  call feedkeys("a\<f5>\<PageUp>\<PageUp>\<c-y>\<esc>", 'tx')
  call assert_equal(["December"], getline(1,2))
  %d

  " <PageUp><PageUp><PageUp> - Select a match several entries back
  call feedkeys("a\<f5>\<PageUp>\<PageUp>\<PageUp>\<c-y>\<esc>", 'tx')
  call assert_equal(["February"], getline(1,2))
  %d

  " <PageDown> - Select a match several entries further
  call feedkeys("a\<f5>\<PageDown>\<c-y>\<esc>", 'tx')
  call assert_equal(["November"], getline(1,2))
  %d

  " <PageDown><PageDown> - Select a match several entries further
  call feedkeys("a\<f5>\<PageDown>\<PageDown>\<c-y>\<esc>", 'tx')
  call assert_equal(["December"], getline(1,2))
  %d

  " <PageDown><PageDown><PageDown> - Select a match several entries further
  call feedkeys("a\<f5>\<PageDown>\<PageDown>\<PageDown>\<c-y>\<esc>", 'tx')
  call assert_equal([""], getline(1,2))
  %d

  " <PageDown><PageDown><PageDown><PageDown> - Select a match several entries further
  call feedkeys("a\<f5>".repeat("\<PageDown>",4)."\<c-y>\<esc>", 'tx')
  call assert_equal(["October"], getline(1,2))
  %d

  " <Up> - Select a match don't insert yet
  call feedkeys("a\<f5>\<Up>\<c-y>\<esc>", 'tx')
  call assert_equal([""], getline(1,2))
  %d

  " <Up><Up> - Select a match don't insert yet
  call feedkeys("a\<f5>\<Up>\<Up>\<c-y>\<esc>", 'tx')
  call assert_equal(["December"], getline(1,2))
  %d

  " <Up><Up><Up> - Select a match don't insert yet
  call feedkeys("a\<f5>\<Up>\<Up>\<Up>\<c-y>\<esc>", 'tx')
  call assert_equal(["November"], getline(1,2))
  %d

  " <Tab> - Stop completion and insert the match
  call feedkeys("a\<f5>\<Tab>\<c-y>\<esc>", 'tx')
  call assert_equal(["January	"], getline(1,2))
  %d

  " <Space> - Stop completion and insert the match
  call feedkeys("a\<f5>".repeat("\<c-p>",5)." \<esc>", 'tx')
  call assert_equal(["September "], getline(1,2))
  %d

  " <Enter> - Use the text and insert line break (state: 1)
  call feedkeys("a\<f5>\<enter>\<esc>", 'tx')
  call assert_equal(["January", ''], getline(1,2))
  %d

  " <Enter> - Insert the current selected text (state: 2)
  call feedkeys("a\<f5>".repeat("\<Up>",5)."\<enter>\<esc>", 'tx')
  call assert_equal(["September"], getline(1,2))
  %d

  " Insert match immediately, if there is only one match
  " <c-y> selects a character from the line above
  call append(0, ["December2015"])
  call feedkeys("aD\<f5>\<C-Y>\<C-Y>\<C-Y>\<C-Y>\<enter>\<esc>", 'tx')
  call assert_equal(["December2015", "December2015", ""], getline(1,3))
  %d

  " use menuone for 'completeopt'
  " Since for the first <c-y> the menu is still shown, will only select
  " three letters from the line above
  set completeopt&vim
  set completeopt+=menuone
  call append(0, ["December2015"])
  call feedkeys("aD\<f5>\<C-Y>\<C-Y>\<C-Y>\<C-Y>\<enter>\<esc>", 'tx')
  call assert_equal(["December2015", "December201", ""], getline(1,3))
  %d

  " use longest for 'completeopt'
  set completeopt&vim
  call feedkeys("aM\<f5>\<C-N>\<C-P>\<c-e>\<enter>\<esc>", 'tx')
  set completeopt+=longest
  call feedkeys("aM\<f5>\<C-N>\<C-P>\<c-e>\<enter>\<esc>", 'tx')
  call assert_equal(["M", "Ma", ""], getline(1,3))
  %d

  " use noselect/noinsert for 'completeopt'
  set completeopt&vim
  call feedkeys("aM\<f5>\<enter>\<esc>", 'tx')
  set completeopt+=noselect
  call feedkeys("aM\<f5>\<enter>\<esc>", 'tx')
  set completeopt-=noselect completeopt+=noinsert
  call feedkeys("aM\<f5>\<enter>\<esc>", 'tx')
  call assert_equal(["March", "M", "March"], getline(1,4))
  %d
endfunc


func Test_popup_completion_insertmode()
  new
  inoremap <F5> <C-R>=ListMonths()<CR>

  call feedkeys("a\<f5>\<down>\<enter>\<esc>", 'tx')
  call assert_equal('February', getline(1))
  %d
  " Set noinsertmode
  let g:setting = 'noinsertmode'
  call feedkeys("a\<f5>\<down>\<enter>\<esc>", 'tx')
  call assert_equal('February', getline(1))
  call assert_false(pumvisible())
  %d
  " Go through all matches, until none is selected
  let g:setting = ''
  call feedkeys("a\<f5>". repeat("\<c-n>",12)."\<enter>\<esc>", 'tx')
  call assert_equal('', getline(1))
  %d
  " select previous entry
  call feedkeys("a\<f5>\<c-p>\<enter>\<esc>", 'tx')
  call assert_equal('', getline(1))
  %d
  " select last entry
  call feedkeys("a\<f5>\<c-p>\<c-p>\<enter>\<esc>", 'tx')
  call assert_equal('December', getline(1))

  iunmap <F5>
endfunc

func Test_noinsert_complete()
  func! s:complTest1() abort
    eval ['source', 'soundfold']->complete(1)
    return ''
  endfunc

  func! s:complTest2() abort
    call complete(1, ['source', 'soundfold'])
    return ''
  endfunc

  new
  set completeopt+=noinsert
  inoremap <F5>  <C-R>=s:complTest1()<CR>
  call feedkeys("i\<F5>soun\<CR>\<CR>\<ESC>.", 'tx')
  call assert_equal('soundfold', getline(1))
  call assert_equal('soundfold', getline(2))
  bwipe!

  new
  inoremap <F5>  <C-R>=s:complTest2()<CR>
  call feedkeys("i\<F5>\<CR>\<ESC>", 'tx')
  call assert_equal('source', getline(1))
  bwipe!

  set completeopt-=noinsert
  iunmap <F5>
endfunc

func Test_complete_no_filter()
  func! s:complTest1() abort
    call complete(1, [{'word': 'foobar'}])
    return ''
  endfunc
  func! s:complTest2() abort
    call complete(1, [{'word': 'foobar', 'equal': 1}])
    return ''
  endfunc

  let completeopt = &completeopt

  " without equal=1
  new
  set completeopt=menuone,noinsert,menu
  inoremap <F5>  <C-R>=s:complTest1()<CR>
  call feedkeys("i\<F5>z\<CR>\<CR>\<ESC>.", 'tx')
  call assert_equal('z', getline(1))
  bwipe!

  " with equal=1
  new
  set completeopt=menuone,noinsert,menu
  inoremap <F5>  <C-R>=s:complTest2()<CR>
  call feedkeys("i\<F5>z\<CR>\<CR>\<ESC>.", 'tx')
  call assert_equal('foobar', getline(1))
  bwipe!

  let &completeopt = completeopt
  iunmap <F5>
endfunc

func Test_compl_vim_cmds_after_register_expr()
  func! s:test_func()
    return 'autocmd '
  endfunc
  augroup AAAAA_Group
    au!
  augroup END

  new
  call feedkeys("i\<c-r>=s:test_func()\<CR>\<C-x>\<C-v>\<Esc>", 'tx')
  call assert_equal('autocmd AAAAA_Group', getline(1))
  autocmd! AAAAA_Group
  augroup! AAAAA_Group
  bwipe!
endfunc

func Test_compl_ignore_mappings()
  call setline(1, ['foo', 'bar', 'baz', 'foobar'])
  inoremap <C-P> (C-P)
  inoremap <C-N> (C-N)
  normal! G
  call feedkeys("o\<C-X>\<C-N>\<C-N>\<C-N>\<C-P>\<C-N>\<C-Y>", 'tx')
  call assert_equal('baz', getline('.'))
  " Also test with unsimplified keys
  call feedkeys("o\<C-X>\<*C-N>\<*C-N>\<*C-N>\<*C-P>\<*C-N>\<C-Y>", 'tx')
  call assert_equal('baz', getline('.'))
  iunmap <C-P>
  iunmap <C-N>
  bwipe!
endfunc

func DummyCompleteOne(findstart, base)
  if a:findstart
    return 0
  else
    wincmd n
    return ['onedef', 'oneDEF']
  endif
endfunc

" Test that nothing happens if the 'completefunc' tries to open
" a new window (fails to open window, continues)
func Test_completefunc_opens_new_window_one()
  new
  let winid = win_getid()
  setlocal completefunc=DummyCompleteOne
  call setline(1, 'one')
  /^one
  call assert_fails('call feedkeys("A\<C-X>\<C-U>\<C-N>\<Esc>", "x")', 'E565:')
  call assert_equal(winid, win_getid())
  call assert_equal('onedef', getline(1))
  q!
endfunc

" Test that nothing happens if the 'completefunc' opens
" a new window (no completion, no crash)
func DummyCompleteTwo(findstart, base)
  if a:findstart
    wincmd n
    return 0
  else
    return ['twodef', 'twoDEF']
  endif
endfunc

" Test that nothing happens if the 'completefunc' opens
" a new window (no completion, no crash)
func Test_completefunc_opens_new_window_two()
  new
  let winid = win_getid()
  setlocal completefunc=DummyCompleteTwo
  call setline(1, 'two')
  /^two
  call assert_fails('call feedkeys("A\<C-X>\<C-U>\<C-N>\<Esc>", "x")', 'E565:')
  call assert_equal(winid, win_getid())
  call assert_equal('twodef', getline(1))
  q!
endfunc

func DummyCompleteThree(findstart, base)
  if a:findstart
    return 0
  else
    return ['threedef', 'threeDEF']
  endif
endfunc

:"Test that 'completefunc' works when it's OK.
func Test_completefunc_works()
  new
  let winid = win_getid()
  setlocal completefunc=DummyCompleteThree
  call setline(1, 'three')
  /^three
  call feedkeys("A\<C-X>\<C-U>\<C-N>\<Esc>", "x")
  call assert_equal(winid, win_getid())
  call assert_equal('threeDEF', getline(1))
  q!
endfunc

func DummyCompleteFour(findstart, base)
  if a:findstart
    return 0
  else
    call complete_add('four1')
    eval 'four2'->complete_add()
    call complete_check()
    call complete_add('four3')
    call complete_add('four4')
    call complete_check()
    call complete_add('four5')
    call complete_add('four6')
    return []
  endif
endfunc

" Test that 'omnifunc' works when it's OK.
func Test_omnifunc_with_check()
  new
  setlocal omnifunc=DummyCompleteFour
  call setline(1, 'four')
  /^four
  call feedkeys("A\<C-X>\<C-O>\<C-N>\<Esc>", "x")
  call assert_equal('four2', getline(1))

  call setline(1, 'four')
  /^four
  call feedkeys("A\<C-X>\<C-O>\<C-N>\<C-N>\<Esc>", "x")
  call assert_equal('four3', getline(1))

  call setline(1, 'four')
  /^four
  call feedkeys("A\<C-X>\<C-O>\<C-N>\<C-N>\<C-N>\<C-N>\<Esc>", "x")
  call assert_equal('four5', getline(1))

  q!
endfunc

func UndoComplete()
  call complete(1, ['January', 'February', 'March',
        \ 'April', 'May', 'June', 'July', 'August', 'September',
        \ 'October', 'November', 'December'])
  return ''
endfunc

" Test that no undo item is created when no completion is inserted
func Test_complete_no_undo()
  set completeopt=menu,preview,noinsert,noselect
  inoremap <Right> <C-R>=UndoComplete()<CR>
  new
  call feedkeys("ixxx\<CR>\<CR>yyy\<Esc>k", 'xt')
  call feedkeys("iaaa\<Esc>0", 'xt')
  call assert_equal('aaa', getline(2))
  call feedkeys("i\<Right>\<Esc>", 'xt')
  call assert_equal('aaa', getline(2))
  call feedkeys("u", 'xt')
  call assert_equal('', getline(2))

  call feedkeys("ibbb\<Esc>0", 'xt')
  call assert_equal('bbb', getline(2))
  call feedkeys("A\<Right>\<Down>\<CR>\<Esc>", 'xt')
  call assert_equal('January', getline(2))
  call feedkeys("u", 'xt')
  call assert_equal('bbb', getline(2))

  call feedkeys("A\<Right>\<C-N>\<Esc>", 'xt')
  call assert_equal('January', getline(2))
  call feedkeys("u", 'xt')
  call assert_equal('bbb', getline(2))

  iunmap <Right>
  set completeopt&
  q!
endfunc

func DummyCompleteFive(findstart, base)
  if a:findstart
    return 0
  else
    return [
          \   { 'word': 'January', 'info': "info1-1\n1-2\n1-3" },
          \   { 'word': 'February', 'info': "info2-1\n2-2\n2-3" },
          \   { 'word': 'March', 'info': "info3-1\n3-2\n3-3" },
          \   { 'word': 'April', 'info': "info4-1\n4-2\n4-3" },
          \   { 'word': 'May', 'info': "info5-1\n5-2\n5-3" },
          \ ]
  endif
endfunc

" Test that 'completefunc' on Scratch buffer with preview window works when
" it's OK.
func Test_completefunc_with_scratch_buffer()
  CheckFeature quickfix

  new +setlocal\ buftype=nofile\ bufhidden=wipe\ noswapfile
  set completeopt+=preview
  setlocal completefunc=DummyCompleteFive
  call feedkeys("A\<C-X>\<C-U>\<C-N>\<C-N>\<C-N>\<Esc>", "x")
  call assert_equal(['April'], getline(1, '$'))
  pclose
  q!
  set completeopt&
endfunc

" <C-E> - select original typed text before the completion started without
" auto-wrap text.
func Test_completion_ctrl_e_without_autowrap()
  new
  let tw_save = &tw
  set tw=78
  let li = [
        \ '"                                                        zzz',
        \ '" zzzyyyyyyyyyyyyyyyyyyy']
  call setline(1, li)
  0
  call feedkeys("A\<C-X>\<C-N>\<C-E>\<Esc>", "tx")
  call assert_equal(li, getline(1, '$'))

  let &tw = tw_save
  q!
endfunc

func DummyCompleteSix()
  call complete(1, ['Hello', 'World'])
  return ''
endfunction

" complete() correctly clears the list of autocomplete candidates
" See #1411
func Test_completion_clear_candidate_list()
  new
  %d
  " select first entry from the completion popup
  call feedkeys("a    xxx\<C-N>\<C-R>=DummyCompleteSix()\<CR>", "tx")
  call assert_equal('Hello', getline(1))
  %d
  " select second entry from the completion popup
  call feedkeys("a    xxx\<C-N>\<C-R>=DummyCompleteSix()\<CR>\<C-N>", "tx")
  call assert_equal('World', getline(1))
  %d
  " select original text
  call feedkeys("a    xxx\<C-N>\<C-R>=DummyCompleteSix()\<CR>\<C-N>\<C-N>", "tx")
  call assert_equal('    xxx', getline(1))
  %d
  " back at first entry from completion list
  call feedkeys("a    xxx\<C-N>\<C-R>=DummyCompleteSix()\<CR>\<C-N>\<C-N>\<C-N>", "tx")
  call assert_equal('Hello', getline(1))

  bw!
endfunc

func Test_completion_respect_bs_option()
  new
  let li = ["aaa", "aaa12345", "aaaabcdef", "aaaABC"]

  set bs=indent,eol
  call setline(1, li)
  1
  call feedkeys("A\<C-X>\<C-N>\<C-P>\<BS>\<BS>\<BS>\<Esc>", "tx")
  call assert_equal('aaa', getline(1))

  %d
  set bs=indent,eol,start
  call setline(1, li)
  1
  call feedkeys("A\<C-X>\<C-N>\<C-P>\<BS>\<BS>\<BS>\<Esc>", "tx")
  call assert_equal('', getline(1))

  bw!
endfunc

func CompleteUndo() abort
  call complete(1, g:months)
  return ''
endfunc

func Test_completion_can_undo()
  inoremap <Right> <c-r>=CompleteUndo()<cr>
  set completeopt+=noinsert,noselect

  new
  call feedkeys("a\<Right>a\<Esc>", 'xt')
  call assert_equal('a', getline(1))
  undo
  call assert_equal('', getline(1))

  bwipe!
  set completeopt&
  iunmap <Right>
endfunc

func Test_completion_comment_formatting()
  new
  setl formatoptions=tcqro
  call feedkeys("o/*\<cr>\<cr>/\<esc>", 'tx')
  call assert_equal(['', '/*', ' *', ' */'], getline(1,4))
  %d
  call feedkeys("o/*\<cr>foobar\<cr>/\<esc>", 'tx')
  call assert_equal(['', '/*', ' * foobar', ' */'], getline(1,4))
  %d
  try
    call feedkeys("o/*\<cr>\<cr>\<c-x>\<c-u>/\<esc>", 'tx')
    call assert_report('completefunc not set, should have failed')
  catch
    call assert_exception('E764:')
  endtry
  call assert_equal(['', '/*', ' *', ' */'], getline(1,4))
  bwipe!
endfunc

func MessCompleteMonths()
  for m in split("Jan Feb Mar Apr May Jun Jul Aug Sep")
    call complete_add(m)
    if complete_check()
      break
    endif
  endfor
  return []
endfunc

func MessCompleteMore()
  call complete(1, split("Oct Nov Dec"))
  return []
endfunc

func MessComplete(findstart, base)
  if a:findstart
    let line = getline('.')
    let start = col('.') - 1
    while start > 0 && line[start - 1] =~ '\a'
      let start -= 1
    endwhile
    return start
  else
    call MessCompleteMonths()
    call MessCompleteMore()
    return []
  endif
endfunc

func Test_complete_func_mess()
  " Calling complete() after complete_add() in 'completefunc' is wrong, but it
  " should not crash.
  set completefunc=MessComplete
  new
  call setline(1, 'Ju')
  call assert_fails('call feedkeys("A\<c-x>\<c-u>/\<esc>", "tx")', 'E565:')
  call assert_equal('Jan/', getline(1))
  bwipe!
  set completefunc=
endfunc

func Test_complete_CTRLN_startofbuffer()
  new
  call setline(1, [ 'organize(cupboard, 3, 2);',
        \ 'prioritize(bureau, 8, 7);',
        \ 'realize(bannister, 4, 4);',
        \ 'moralize(railing, 3,9);'])
  let expected=['cupboard.organize(3, 2);',
        \ 'bureau.prioritize(8, 7);',
        \ 'bannister.realize(4, 4);',
        \ 'railing.moralize(3,9);']
  call feedkeys("qai\<c-n>\<c-n>.\<esc>3wdW\<cr>q3@a", 'tx')
  call assert_equal(expected, getline(1,'$'))
  bwipe!
endfunc

func Test_popup_and_window_resize()
  CheckFeature terminal
  CheckFeature quickfix
  CheckNotGui
  let g:test_is_flaky = 1

  let h = winheight(0)
  if h < 15
    return
  endif
  let rows = h / 3
  let buf = term_start([GetVimProg(), '--clean', '-c', 'set noswapfile'], {'term_rows': rows})
  call term_sendkeys(buf, (h / 3 - 1) . "o\<esc>")
  " Wait for the nested Vim to exit insert mode, where it will show the ruler.
  " Need to trigger a redraw.
  call WaitFor({-> execute("redraw") == "" && term_getline(buf, rows) =~ '\<' . rows . ',.*Bot'})

  call term_sendkeys(buf, "Gi\<c-x>")
  call term_sendkeys(buf, "\<c-v>")
  call TermWait(buf, 50)
  " popup first entry "!" must be at the top
  call WaitForAssert({-> assert_match('^!\s*$', term_getline(buf, 1))})
  exe 'resize +' . (h - 1)
  call TermWait(buf, 50)
  redraw!
  " popup shifted down, first line is now empty
  call WaitForAssert({-> assert_equal('', term_getline(buf, 1))})
  sleep 100m
  " popup is below cursor line and shows first match "!"
  call WaitForAssert({-> assert_match('^!\s*$', term_getline(buf, term_getcursor(buf)[0] + 1))})
  " cursor line also shows !
  call assert_match('^!\s*$', term_getline(buf, term_getcursor(buf)[0]))
  bwipe!
endfunc

func Test_popup_and_preview_autocommand()
  CheckFeature python
  CheckFeature quickfix
  if winheight(0) < 15
    throw 'Skipped: window height insufficient'
  endif

  " This used to crash Vim
  new
  augroup MyBufAdd
    au!
    au BufAdd * nested tab sball
  augroup END
  set omnifunc=pythoncomplete#Complete
  call setline(1, 'import os')
  " make the line long
  call setline(2, '                                 os.')
  $
  call feedkeys("A\<C-X>\<C-O>\<C-N>\<C-N>\<C-N>\<enter>\<esc>", 'tx')
  call assert_equal("import os", getline(1))
  call assert_match('                                 os.\(EX_IOERR\|O_CREAT\)$', getline(2))
  call assert_equal(1, winnr('$'))
  " previewwindow option is not set
  call assert_equal(0, &previewwindow)
  norm! gt
  call assert_equal(0, &previewwindow)
  norm! gT
  call assert_equal(10, tabpagenr('$'))
  tabonly
  pclose
  augroup MyBufAdd
    au!
  augroup END
  augroup! MyBufAdd
  bw!
endfunc

func s:run_popup_and_previewwindow_dump(lines, dumpfile)
  CheckScreendump
  CheckFeature quickfix

  call writefile(a:lines, 'Xscript', 'D')
  let buf = RunVimInTerminal('-S Xscript', {})

  " wait for the script to finish
  call TermWait(buf)

  " Test that popup and previewwindow do not overlap.
  call term_sendkeys(buf, "o")
  call TermWait(buf, 50)
  call term_sendkeys(buf, "\<C-X>\<C-N>")
  call VerifyScreenDump(buf, a:dumpfile, {})

  call term_sendkeys(buf, "\<Esc>u")
  call StopVimInTerminal(buf)
endfunc

func Test_popup_and_previewwindow_dump_pedit()
  let lines =<< trim END
    set previewheight=9
    silent! pedit
    call setline(1, map(repeat(["ab"], 10), "v:val .. v:key"))
    exec "norm! G\<C-E>\<C-E>"
  END
  call s:run_popup_and_previewwindow_dump(lines, 'Test_popup_and_previewwindow_pedit')
endfunc

func Test_popup_and_previewwindow_dump_pbuffer()
  let lines =<< trim END
    set previewheight=9
    silent! pbuffer
    call setline(1, map(repeat(["ab"], 10), "v:val .. v:key"))
    exec "norm! G\<C-E>\<C-E>\<C-E>"
  END
  call s:run_popup_and_previewwindow_dump(lines, 'Test_popup_and_previewwindow_pbuffer')
endfunc

func Test_balloon_split()
  CheckFunction balloon_split

  call assert_equal([
        \ 'tempname: 0x555555e380a0 "/home/mool/.viminfz.tmp"',
        \ ], balloon_split(
        \ 'tempname: 0x555555e380a0 "/home/mool/.viminfz.tmp"'))
  call assert_equal([
        \ 'one two three four one two three four one two thre',
        \ 'e four',
        \ ], balloon_split(
        \ 'one two three four one two three four one two three four'))

  eval 'struct = {one = 1, two = 2, three = 3}'
        \ ->balloon_split()
        \ ->assert_equal([
        \   'struct = {',
        \   '  one = 1,',
        \   '  two = 2,',
        \   '  three = 3}',
        \ ])

  call assert_equal([
        \ 'struct = {',
        \ '  one = 1,',
        \ '  nested = {',
        \ '    n1 = "yes",',
        \ '    n2 = "no"}',
        \ '  two = 2}',
        \ ], balloon_split(
        \ 'struct = {one = 1, nested = {n1 = "yes", n2 = "no"} two = 2}'))
  call assert_equal([
        \ 'struct = 0x234 {',
        \ '  long = 2343 "\\"some long string that will be wr',
        \ 'apped in two\\"",',
        \ '  next = 123}',
        \ ], balloon_split(
        \ 'struct = 0x234 {long = 2343 "\\"some long string that will be wrapped in two\\"", next = 123}'))
  call assert_equal([
        \ 'Some comment',
        \ '',
        \ 'typedef this that;',
        \ ], balloon_split(
        \ "Some comment\n\ntypedef this that;"))
endfunc

func Test_popup_position()
  CheckScreendump

  let lines =<< trim END
    123456789_123456789_123456789_a
    123456789_123456789_123456789_b
                123
  END
  call writefile(lines, 'Xtest')
  let buf = RunVimInTerminal('Xtest', {})
  call term_sendkeys(buf, ":vsplit\<CR>")

  " default pumwidth in left window: overlap in right window
  call term_sendkeys(buf, "GA\<C-N>")
  call VerifyScreenDump(buf, 'Test_popup_position_01', {'rows': 8})
  call term_sendkeys(buf, "\<Esc>u")

  " default pumwidth: fill until right of window
  call term_sendkeys(buf, "\<C-W>l")
  call term_sendkeys(buf, "GA\<C-N>")
  call VerifyScreenDump(buf, 'Test_popup_position_02', {'rows': 8})

  " larger pumwidth: used as minimum width
  call term_sendkeys(buf, "\<Esc>u")
  call term_sendkeys(buf, ":set pumwidth=30\<CR>")
  call term_sendkeys(buf, "GA\<C-N>")
  call VerifyScreenDump(buf, 'Test_popup_position_03', {'rows': 8})

  " completed text wider than the window and 'pumwidth' smaller than available
  " space
  call term_sendkeys(buf, "\<Esc>u")
  call term_sendkeys(buf, ":set pumwidth=20\<CR>")
  call term_sendkeys(buf, "ggI123456789_\<Esc>")
  call term_sendkeys(buf, "jI123456789_\<Esc>")
  call term_sendkeys(buf, "GA\<C-N>")
  call VerifyScreenDump(buf, 'Test_popup_position_04', {'rows': 10})

  call term_sendkeys(buf, "\<Esc>u")
  call StopVimInTerminal(buf)
  call delete('Xtest')
endfunc

func Test_popup_command()
  CheckFeature menu

  menu Test.Foo Foo
  call assert_fails('popup Test.Foo', 'E336:')
  call assert_fails('popup Test.Foo.X', 'E327:')
  call assert_fails('popup Foo', 'E337:')
  unmenu Test.Foo
endfunc

func Test_popup_command_dump()
  CheckFeature menu
  CheckScreendump

  let script =<< trim END
    func StartTimer()
      call timer_start(100, {-> ChangeMenu()})
    endfunc
    func ChangeMenu()
      aunmenu PopUp.&Paste
      nnoremenu 1.40 PopUp.&Paste :echomsg "pasted"<CR>
      echomsg 'changed'
    endfunc
  END
  call writefile(script, 'XtimerScript', 'D')

  let lines =<< trim END
	one two three four five
	and one two Xthree four five
	one more two three four five
  END
  call writefile(lines, 'Xtest', 'D')
  let buf = RunVimInTerminal('-S XtimerScript Xtest', {})
  call term_sendkeys(buf, ":source $VIMRUNTIME/menu.vim\<CR>")
  call term_sendkeys(buf, "/X\<CR>:popup PopUp\<CR>")
  call VerifyScreenDump(buf, 'Test_popup_command_01', {})

  " go to the Paste entry in the menu
  call term_sendkeys(buf, "jj")
  call VerifyScreenDump(buf, 'Test_popup_command_02', {})

  " Select a word
  call term_sendkeys(buf, "j\<CR>")
  call VerifyScreenDump(buf, 'Test_popup_command_03', {})

  call term_sendkeys(buf, "\<Esc>")

  if has('rightleft')
    call term_sendkeys(buf, ":set rightleft\<CR>")
    call term_sendkeys(buf, "/X\<CR>:popup PopUp\<CR>")
    call VerifyScreenDump(buf, 'Test_popup_command_rl', {})
    call term_sendkeys(buf, "\<Esc>:set norightleft\<CR>")
  endif

  " Set a timer to change a menu entry while it's displayed.  The text should
  " not change but the command does.  Making the screendump also verifies that
  " "changed" shows up, which means the timer triggered.
  call term_sendkeys(buf, "/X\<CR>:call StartTimer() | popup PopUp\<CR>")
  call VerifyScreenDump(buf, 'Test_popup_command_04', {})

  " Select the Paste entry, executes the changed menu item.
  call term_sendkeys(buf, "jj\<CR>")
  call VerifyScreenDump(buf, 'Test_popup_command_05', {})

  call term_sendkeys(buf, "\<Esc>")

  " Add a window toolbar to the window and check the :popup menu position.
  call term_sendkeys(buf, ":nnoremenu WinBar.TEST :\<CR>")
  call term_sendkeys(buf, "/X\<CR>:popup PopUp\<CR>")
  call VerifyScreenDump(buf, 'Test_popup_command_06', {})

  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
endfunc

" Test position of right-click menu when clicking near window edge.
func Test_mouse_popup_position()
  CheckFeature menu
  CheckScreendump

  let script =<< trim END
    set mousemodel=popup_setpos
    source $VIMRUNTIME/menu.vim
    call setline(1, join(range(20)))
    func Trigger(col)
      call test_setmouse(1, a:col)
      call feedkeys("\<RightMouse>", 't')
    endfunc
  END
  call writefile(script, 'XmousePopupPosition', 'D')
  let buf = RunVimInTerminal('-S XmousePopupPosition', #{rows: 20, cols: 50})

  call term_sendkeys(buf, ":call Trigger(45)\<CR>")
  call VerifyScreenDump(buf, 'Test_mouse_popup_position_01', {})
  call term_sendkeys(buf, "\<Esc>")

  if has('rightleft')
    call term_sendkeys(buf, ":set rightleft\<CR>")
    call term_sendkeys(buf, ":call Trigger(50 + 1 - 45)\<CR>")
    call VerifyScreenDump(buf, 'Test_mouse_popup_position_02', {})
    call term_sendkeys(buf, "\<Esc>:set norightleft\<CR>")
  endif

  call StopVimInTerminal(buf)
endfunc

func Test_popup_complete_backwards()
  new
  call setline(1, ['Post', 'Port', 'Po'])
  let expected=['Post', 'Port', 'Port']
  call cursor(3,2)
  call feedkeys("A\<C-X>". repeat("\<C-P>", 3). "rt\<cr>", 'tx')
  call assert_equal(expected, getline(1,'$'))
  bwipe!
endfunc

func Test_popup_complete_backwards_ctrl_p()
  new
  call setline(1, ['Post', 'Port', 'Po'])
  let expected=['Post', 'Port', 'Port']
  call cursor(3,2)
  call feedkeys("A\<C-P>\<C-N>rt\<cr>", 'tx')
  call assert_equal(expected, getline(1,'$'))
  bwipe!
endfunc

func Test_complete_o_tab()
  CheckFunction test_override
  let s:o_char_pressed = 0

  fun! s:act_on_text_changed()
    if s:o_char_pressed
      let s:o_char_pressed = 0
      call feedkeys("\<c-x>\<c-n>", 'i')
    endif
  endfunc

  set completeopt=menu,noselect
  new
  imap <expr> <buffer> <tab> pumvisible() ? "\<c-p>" : "X"
  autocmd! InsertCharPre <buffer> let s:o_char_pressed = (v:char ==# 'o')
  autocmd! TextChangedI <buffer> call <sid>act_on_text_changed()
  call setline(1,  ['hoard', 'hoax', 'hoarse', ''])
  let l:expected = ['hoard', 'hoax', 'hoarse', 'hoax', 'hoax']
  call cursor(4,1)
  call test_override("char_avail", 1)
  call feedkeys("Ahoa\<tab>\<tab>\<c-y>\<esc>", 'tx')
  call feedkeys("oho\<tab>\<tab>\<c-y>\<esc>", 'tx')
  call assert_equal(l:expected, getline(1,'$'))

  call test_override("char_avail", 0)
  bwipe!
  set completeopt&
  delfunc s:act_on_text_changed
endfunc

func Test_menu_only_exists_in_terminal()
  CheckCommand tlmenu
  CheckNotGui

  tlnoremenu  &Edit.&Paste<Tab>"+gP  <C-W>"+
  aunmenu *
  try
    popup Edit
    call assert_false(1, 'command should have failed')
  catch
    call assert_exception('E328:')
  endtry
endfunc

" This used to crash before patch 8.1.1424
func Test_popup_delete_when_shown()
  CheckFeature menu
  CheckNotGui

  func Func()
    popup Foo
    return "\<Ignore>"
  endfunc

  nmenu Foo.Bar :
  nnoremap <expr> <F2> Func()
  call feedkeys("\<F2>\<F2>\<Esc>", 'xt')

  delfunc Func
  nunmenu Foo.Bar
  nunmap <F2>
endfunc

func Test_popup_complete_info_01()
  new
  inoremap <buffer><F5> <C-R>=complete_info().mode<CR>
  func s:complTestEval() abort
    call complete(1, ['aa', 'ab'])
    return ''
  endfunc
  inoremap <buffer><F6> <C-R>=s:complTestEval()<CR>
  call writefile([
        \ 'dummy	dummy.txt	1',
        \], 'Xdummy.txt')
  setlocal tags=Xdummy.txt
  setlocal dictionary=Xdummy.txt
  setlocal thesaurus=Xdummy.txt
  setlocal omnifunc=syntaxcomplete#Complete
  setlocal completefunc=syntaxcomplete#Complete
  setlocal spell
  for [keys, mode_name] in [
        \ ["", ''],
        \ ["\<C-X>", 'ctrl_x'],
        \ ["\<C-X>\<C-N>", 'keyword'],
        \ ["\<C-X>\<C-P>", 'keyword'],
        \ ["\<C-X>\<C-E>", 'scroll'],
        \ ["\<C-X>\<C-Y>", 'scroll'],
        \ ["\<C-X>\<C-E>\<C-E>\<C-Y>", 'scroll'],
        \ ["\<C-X>\<C-Y>\<C-E>\<C-Y>", 'scroll'],
        \ ["\<C-X>\<C-L>", 'whole_line'],
        \ ["\<C-X>\<C-F>", 'files'],
        \ ["\<C-X>\<C-]>", 'tags'],
        \ ["\<C-X>\<C-D>", 'path_defines'],
        \ ["\<C-X>\<C-I>", 'path_patterns'],
        \ ["\<C-X>\<C-K>", 'dictionary'],
        \ ["\<C-X>\<C-T>", 'thesaurus'],
        \ ["\<C-X>\<C-V>", 'cmdline'],
        \ ["\<C-X>\<C-U>", 'function'],
        \ ["\<C-X>\<C-O>", 'omni'],
        \ ["\<C-X>s", 'spell'],
        \ ["\<F6>", 'eval'],
        \]
    call feedkeys("i" . keys . "\<F5>\<Esc>", 'tx')
    call assert_equal(mode_name, getline('.'))
    %d
  endfor
  call delete('Xdummy.txt')
  bwipe!
endfunc

func UserDefinedComplete(findstart, base)
  if a:findstart
    return 0
  else
    return [
          \   { 'word': 'Jan', 'menu': 'January' },
          \   { 'word': 'Feb', 'menu': 'February' },
          \   { 'word': 'Mar', 'menu': 'March' },
          \   { 'word': 'Apr', 'menu': 'April' },
          \   { 'word': 'May', 'menu': 'May' },
          \ ]
  endif
endfunc

func GetCompleteInfo()
  if empty(g:compl_what)
    let g:compl_info = complete_info()
  else
    let g:compl_info = g:compl_what->complete_info()
  endif
  return ''
endfunc

func Test_popup_complete_info_02()
  new
  inoremap <buffer><F5> <C-R>=GetCompleteInfo()<CR>
  setlocal completefunc=UserDefinedComplete

  let d = {
    \   'mode': 'function',
    \   'pum_visible': 1,
    \   'items': [
    \     {'word': 'Jan', 'menu': 'January', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \     {'word': 'Feb', 'menu': 'February', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \     {'word': 'Mar', 'menu': 'March', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \     {'word': 'Apr', 'menu': 'April', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''},
    \     {'word': 'May', 'menu': 'May', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''}
    \   ],
    \   'selected': 0,
    \ }

  let g:compl_what = []
  call feedkeys("i\<C-X>\<C-U>\<F5>", 'tx')
  call assert_equal(d, g:compl_info)

  let g:compl_what = ['mode', 'pum_visible', 'selected']
  call remove(d, 'items')
  call feedkeys("i\<C-X>\<C-U>\<F5>", 'tx')
  call assert_equal(d, g:compl_info)

  let g:compl_what = ['mode']
  call remove(d, 'selected')
  call remove(d, 'pum_visible')
  call feedkeys("i\<C-X>\<C-U>\<F5>", 'tx')
  call assert_equal(d, g:compl_info)
  bwipe!
endfunc

func Test_popup_complete_info_no_pum()
  new
  call assert_false( pumvisible() )
  let no_pum_info = complete_info()
  let d = {
        \   'mode': '',
        \   'pum_visible': 0,
        \   'items': [],
        \   'selected': -1,
        \  }
  call assert_equal( d, complete_info() )
  bwipe!
endfunc

func Test_CompleteChanged()
  new
  call setline(1, ['foo', 'bar', 'foobar', ''])
  set complete=. completeopt=noinsert,noselect,menuone
  function! OnPumChange()
    let g:event = copy(v:event)
    let g:item = get(v:event, 'completed_item', {})
    let g:word = get(g:item, 'word', v:null)
    let l:line = getline('.')
    if g:word == v:null && l:line == "bc"
      let g:word = l:line
    endif
  endfunction
  augroup AAAAA_Group
    au!
    autocmd CompleteChanged * :call OnPumChange()
  augroup END
  call cursor(4, 1)

  call feedkeys("Sf\<C-N>", 'tx')
  call assert_equal({'completed_item': {}, 'width': 15.0,
        \ 'height': 2.0, 'size': 2,
        \ 'col': 0.0, 'row': 4.0, 'scrollbar': v:false}, g:event)
  call feedkeys("a\<C-N>\<C-N>\<C-E>", 'tx')
  call assert_equal('foo', g:word)
  call feedkeys("a\<C-N>\<C-N>\<C-N>\<C-E>", 'tx')
  call assert_equal('foobar', g:word)
  call feedkeys("a\<C-N>\<C-N>\<C-N>\<C-N>\<C-E>", 'tx')
  call assert_equal(v:null, g:word)
  call feedkeys("a\<C-N>\<C-N>\<C-N>\<C-N>\<C-P>", 'tx')
  call assert_equal('foobar', g:word)
  call feedkeys("S\<C-N>bc", 'tx')
  call assert_equal("bc", g:word)

  func Omni_test(findstart, base)
    if a:findstart
      return col(".")
    endif
    return [#{word: "one"}, #{word: "two"}, #{word: "five"}]
  endfunc
  set omnifunc=Omni_test
  set completeopt=menu,menuone
  call feedkeys("i\<C-X>\<C-O>\<BS>\<BS>\<BS>f", 'tx')
  call assert_equal('five', g:word)
  call feedkeys("i\<C-X>\<C-O>\<BS>\<BS>\<BS>f\<BS>", 'tx')
  call assert_equal('one', g:word)

  autocmd! AAAAA_Group
  set complete& completeopt&
  delfunc! OnPumChange
  delfunc! Omni_test
  bw!
endfunc

func GetPumPosition()
  call assert_true( pumvisible() )
  let g:pum_pos = pum_getpos()
  return ''
endfunc

func Test_pum_getpos()
  new
  inoremap <buffer><F5> <C-R>=GetPumPosition()<CR>
  setlocal completefunc=UserDefinedComplete

   let d = {
    \   'height':    5.0,
    \   'width':     15.0,
    \   'row':       1.0,
    \   'col':       0.0,
    \   'size':      5,
    \   'scrollbar': v:false,
    \ }
  call feedkeys("i\<C-X>\<C-U>\<F5>", 'tx')
  call assert_equal(d, g:pum_pos)

  call assert_false( pumvisible() )
  call assert_equal( {}, pum_getpos() )
  bw!
  unlet g:pum_pos
endfunc

" Test for the popup menu with the 'rightleft' option set
func Test_pum_rightleft()
  CheckFeature rightleft
  CheckScreendump

  let lines =<< trim END
    abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz
    vim
    victory
  END
  call writefile(lines, 'Xtest1')
  let buf = RunVimInTerminal('--cmd "set rightleft" Xtest1', {})
  call term_wait(buf)
  call term_sendkeys(buf, "Go\<C-P>")
  call VerifyScreenDump(buf, 'Test_pum_rightleft_01', {'rows': 8})
  call term_sendkeys(buf, "\<C-P>\<C-Y>")
  call term_wait(buf)
  redraw!
  call assert_match('\s*miv', Screenline(5))

  " Test for expanding tabs to spaces in the popup menu
  let lines =<< trim END
    one	two
    one	three
    four
  END
  call writefile(lines, 'Xtest2')
  call term_sendkeys(buf, "\<Esc>:e! Xtest2\<CR>")
  call term_wait(buf)
  call term_sendkeys(buf, "Goone\<C-X>\<C-L>")
  call term_wait(buf)
  redraw!
  call VerifyScreenDump(buf, 'Test_pum_rightleft_02', {'rows': 7})
  call term_sendkeys(buf, "\<C-Y>")
  call term_wait(buf)
  redraw!
  call assert_match('\s*eerht     eno', Screenline(4))

  call StopVimInTerminal(buf)
  call delete('Xtest1')
  call delete('Xtest2')
endfunc

" Test for a popup menu with a scrollbar
func Test_pum_scrollbar()
  CheckScreendump
  let lines =<< trim END
    one
    two
    three
  END
  call writefile(lines, 'Xtest1')
  let buf = RunVimInTerminal('--cmd "set pumheight=2" Xtest1', {})
  call term_wait(buf)
  call term_sendkeys(buf, "Go\<C-P>\<C-P>\<C-P>")
  call VerifyScreenDump(buf, 'Test_pum_scrollbar_01', {'rows': 7})
  call term_sendkeys(buf, "\<C-E>\<Esc>dd")
  call term_wait(buf)

  if has('rightleft')
    call term_sendkeys(buf, ":set rightleft\<CR>")
    call term_wait(buf)
    call term_sendkeys(buf, "Go\<C-P>\<C-P>\<C-P>")
    call VerifyScreenDump(buf, 'Test_pum_scrollbar_02', {'rows': 7})
  endif

  call StopVimInTerminal(buf)
  call delete('Xtest1')
endfunc

" Test default highlight groups for popup menu
func Test_pum_highlights_default()
  CheckScreendump
  let lines =<< trim END
    func CompleteFunc( findstart, base )
      if a:findstart
        return 0
      endif
      return {
            \ 'words': [
            \ { 'word': 'aword1', 'menu': 'extra text 1', 'kind': 'W', },
            \ { 'word': 'aword2', 'menu': 'extra text 2', 'kind': 'W', },
            \ { 'word': 'aword3', 'menu': 'extra text 3', 'kind': 'W', },
            \]}
    endfunc
    set completeopt=menu
    set completefunc=CompleteFunc
  END
  call writefile(lines, 'Xscript', 'D')
  let buf = RunVimInTerminal('-S Xscript', {})
  call TermWait(buf)
  call term_sendkeys(buf, "iaw\<C-X>\<C-u>")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_pum_highlights_01', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>u")
  call TermWait(buf)
  call StopVimInTerminal(buf)
endfunc

" Test custom highlight groups for popup menu
func Test_pum_highlights_custom()
  CheckScreendump
  let lines =<< trim END
    func CompleteFunc( findstart, base )
      if a:findstart
        return 0
      endif
      return {
            \ 'words': [
            \ { 'word': 'aword1', 'menu': 'extra text 1', 'kind': 'W', },
            \ { 'word': 'aword2', 'menu': 'extra text 2', 'kind': 'W', },
            \ { 'word': 'aword3', 'menu': 'extra text 3', 'kind': 'W', },
            \]}
    endfunc
    set completeopt=menu
    set completefunc=CompleteFunc
    hi PmenuKind      ctermfg=1 ctermbg=225
    hi PmenuKindSel   ctermfg=1 ctermbg=7
    hi PmenuExtra     ctermfg=243 ctermbg=225
    hi PmenuExtraSel  ctermfg=0 ctermbg=7
  END
  call writefile(lines, 'Xscript', 'D')
  let buf = RunVimInTerminal('-S Xscript', {})
  call TermWait(buf)
  call term_sendkeys(buf, "iaw\<C-X>\<C-u>")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_pum_highlights_02', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>u")
  call TermWait(buf)
  call StopVimInTerminal(buf)
endfunc

" Test match relate highlight group in pmenu
func Test_pum_highlights_match()
  CheckScreendump
  let lines =<< trim END
    func Omni_test(findstart, base)
      if a:findstart
        return col(".")
      endif
      return {
            \ 'words': [
            \ { 'word': 'foo', 'kind': 'fookind' },
            \ { 'word': 'foofoo', 'kind': 'fookind' },
            \ { 'word': 'foobar', 'kind': 'fookind' },
            \ { 'word': 'fooBaz', 'kind': 'fookind' },
            \ { 'word': 'foobala', 'kind': 'fookind' },
            \ { 'word': '你好' },
            \ { 'word': '你好吗' },
            \ { 'word': '你不好吗' },
            \ { 'word': '你可好吗' },
            \]}
    endfunc

    func Comp()
      let col = col('.')
      if getline('.') == 'f'
        let col -= 1
      endif
      call complete(col, [
            \ #{word: "foo", icase: 1},
            \ #{word: "Foobar", icase: 1},
            \ #{word: "fooBaz", icase: 1},
            \])
      return ''
    endfunc

    set omnifunc=Omni_test
    set completeopt=menu,noinsert,fuzzy
    hi PmenuMatchSel  ctermfg=6 ctermbg=7
    hi PmenuMatch     ctermfg=4 ctermbg=225
  END
  call writefile(lines, 'Xscript', 'D')
  let  buf = RunVimInTerminal('-S Xscript', {})
  call TermWait(buf)
  call term_sendkeys(buf, "i\<C-X>\<C-O>")
  call TermWait(buf, 50)
  call term_sendkeys(buf, "fo")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_pum_highlights_03', {})
  call term_sendkeys(buf, "\<Esc>S\<C-X>\<C-O>")
  call TermWait(buf, 50)
  call term_sendkeys(buf, "你")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_pum_highlights_04', {})
  call term_sendkeys(buf, "吗")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_pum_highlights_05', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  if has('rightleft')
    call term_sendkeys(buf, ":set rightleft\<CR>")
    call TermWait(buf, 50)
    call term_sendkeys(buf, "S\<C-X>\<C-O>")
    call TermWait(buf, 50)
    call term_sendkeys(buf, "fo")
    call TermWait(buf, 50)
    call VerifyScreenDump(buf, 'Test_pum_highlights_06', {})
    call term_sendkeys(buf, "\<Esc>S\<C-X>\<C-O>")
    call TermWait(buf, 50)
    call term_sendkeys(buf, "你")
    call VerifyScreenDump(buf, 'Test_pum_highlights_06a', {})
    call term_sendkeys(buf, "吗")
    call VerifyScreenDump(buf, 'Test_pum_highlights_06b', {})
    call term_sendkeys(buf, "\<C-E>\<Esc>")
    call term_sendkeys(buf, ":set norightleft\<CR>")
    call TermWait(buf)
  endif

  call term_sendkeys(buf, ":set completeopt-=fuzzy\<CR>")
  call TermWait(buf)
  call term_sendkeys(buf, "S\<C-X>\<C-O>")
  call TermWait(buf, 50)
  call term_sendkeys(buf, "fo")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_pum_highlights_07', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  if has('rightleft')
    call term_sendkeys(buf, ":set rightleft\<CR>")
    call TermWait(buf, 50)
    call term_sendkeys(buf, "S\<C-X>\<C-O>")
    call TermWait(buf, 50)
    call term_sendkeys(buf, "fo")
    call TermWait(buf, 50)
    call VerifyScreenDump(buf, 'Test_pum_highlights_08', {})
    call term_sendkeys(buf, "\<C-E>\<Esc>")
    call term_sendkeys(buf, ":set norightleft\<CR>")
  endif

  call term_sendkeys(buf, "S\<C-R>=Comp()\<CR>f")
  call VerifyScreenDump(buf, 'Test_pum_highlights_09', {})
  call term_sendkeys(buf, "o\<BS>\<C-R>=Comp()\<CR>")
  call VerifyScreenDump(buf, 'Test_pum_highlights_09', {})

  " issue #15095 wrong select
  call term_sendkeys(buf, "\<ESC>:set completeopt=fuzzy,menu\<CR>")
  call TermWait(buf)
  call term_sendkeys(buf, "S hello helio hero h\<C-X>\<C-P>")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_pum_highlights_10', {})

  call term_sendkeys(buf, "\<ESC>S hello helio hero h\<C-X>\<C-P>\<C-P>")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_pum_highlights_11', {})

  call term_sendkeys(buf, "\<C-E>\<Esc>")
  call TermWait(buf)

  call StopVimInTerminal(buf)
endfunc

func Test_pum_user_abbr_hlgroup()
  CheckScreendump
  let lines =<< trim END
    let s:var = 0
    func CompleteFunc(findstart, base)
      if a:findstart
        return 0
      endif
      if s:var == 1
        return {
              \ 'words': [
              \ { 'word': 'aword1', 'abbr_hlgroup': 'StrikeFake' },
              \ { 'word': '你好', 'abbr_hlgroup': 'StrikeFake' },
              \]}
      endif
      return {
            \ 'words': [
            \ { 'word': 'aword1', 'menu': 'extra text 1', 'kind': 'W', 'abbr_hlgroup': 'StrikeFake' },
            \ { 'word': 'aword2', 'menu': 'extra text 2', 'kind': 'W', },
            \ { 'word': '你好', 'menu': 'extra text 3', 'kind': 'W', 'abbr_hlgroup': 'StrikeFake' },
            \]}
    endfunc
    func ChangeVar()
      let s:var = 1
    endfunc
    set completeopt=menu
    set completefunc=CompleteFunc

    hi StrikeFake ctermfg=9
    func HlMatch()
      hi PmenuMatchSel  ctermfg=6 ctermbg=7 cterm=underline
      hi PmenuMatch     ctermfg=4 ctermbg=225 cterm=underline
    endfunc
  END
  call writefile(lines, 'Xscript', 'D')
  let buf = RunVimInTerminal('-S Xscript', {})

  call TermWait(buf)
  call term_sendkeys(buf, "Saw\<C-X>\<C-U>")
  call VerifyScreenDump(buf, 'Test_pum_highlights_12', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call TermWait(buf)
  call term_sendkeys(buf, ":call HlMatch()\<CR>")

  call TermWait(buf)
  call term_sendkeys(buf, "Saw\<C-X>\<C-U>")
  call VerifyScreenDump(buf, 'Test_pum_highlights_13', {})
  call term_sendkeys(buf, "\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_highlights_14', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call TermWait(buf)
  call term_sendkeys(buf, ":call ChangeVar()\<CR>")
  call TermWait(buf)
  call term_sendkeys(buf, "S\<C-X>\<C-U>")
  call VerifyScreenDump(buf, 'Test_pum_highlights_17', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call StopVimInTerminal(buf)
endfunc

func Test_pum_user_kind_hlgroup()
  CheckScreendump
  let lines =<< trim END
    func CompleteFunc(findstart, base)
      if a:findstart
        return 0
      endif
      return {
            \ 'words': [
            \ { 'word': 'aword1', 'menu': 'extra text 1', 'kind': 'variable', 'kind_hlgroup': 'KindVar', 'abbr_hlgroup': 'StrikeFake' },
            \ { 'word': 'aword2', 'menu': 'extra text 2', 'kind': 'function', 'kind_hlgroup': 'KindFunc' },
            \ { 'word': '你好', 'menu': 'extra text 3', 'kind': 'class', 'kind_hlgroup': 'KindClass'  },
            \]}
    endfunc
    set completeopt=menu
    set completefunc=CompleteFunc

    hi StrikeFake ctermfg=9
    hi KindVar ctermfg=yellow
    hi KindFunc ctermfg=blue
    hi KindClass ctermfg=green
  END
  call writefile(lines, 'Xscript', 'D')
  let buf = RunVimInTerminal('-S Xscript', {})

  call TermWait(buf)
  call term_sendkeys(buf, "S\<C-X>\<C-U>")
  call VerifyScreenDump(buf, 'Test_pum_highlights_16', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call StopVimInTerminal(buf)
endfunc

func Test_pum_completeitemalign()
  CheckScreendump
  let lines =<< trim END
    func Omni_test(findstart, base)
      if a:findstart
        return col(".")
      endif
      return {
            \ 'words': [
            \ { 'word': 'foo', 'kind': 'S', 'menu': 'menu' },
            \ { 'word': 'bar', 'kind': 'T', 'menu': 'menu' },
            \ { 'word': '你好', 'kind': 'C', 'menu': '中文' },
            \]}
    endfunc

    func Omni_long(findstart, base)
      if a:findstart
        return col(".")
      endif
      return {
            \ 'words': [
            \ { 'word': 'loooong_foo', 'kind': 'S', 'menu': 'menu' },
            \ { 'word': 'loooong_bar', 'kind': 'T', 'menu': 'menu' },
            \]}
    endfunc
    set omnifunc=Omni_test
    command! -nargs=0 T1 set cia=abbr,kind,menu
    command! -nargs=0 T2 set cia=abbr,menu,kind
    command! -nargs=0 T3 set cia=kind,abbr,menu
    command! -nargs=0 T4 set cia=kind,menu,abbr
    command! -nargs=0 T5 set cia=menu,abbr,kind
    command! -nargs=0 T6 set cia=menu,kind,abbr
    command! -nargs=0 T7 set cia&
  END
  call writefile(lines, 'Xscript', 'D')
  let  buf = RunVimInTerminal('-S Xscript', {})
  call TermWait(buf)

  " T1 is default
  call term_sendkeys(buf, ":T1\<CR>S\<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_completeitemalign_01', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  " T2
  call term_sendkeys(buf, ":T2\<CR>S\<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_completeitemalign_02', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  " T3
  call term_sendkeys(buf, ":T3\<CR>S\<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_completeitemalign_03', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  " T4
  call term_sendkeys(buf, ":T4\<CR>S\<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_completeitemalign_04', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  " T5
  call term_sendkeys(buf, ":T5\<CR>S\<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_completeitemalign_05', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  " T6
  call term_sendkeys(buf, ":T6\<CR>S\<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_completeitemalign_06', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call term_sendkeys(buf, ":set columns=12 cmdheight=2 omnifunc=Omni_long\<CR>S\<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_completeitemalign_07', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>:T7\<CR>")
  call StopVimInTerminal(buf)
endfunc

func Test_pum_keep_select()
  CheckScreendump
  let lines =<< trim END
    set completeopt=menu,menuone,noinsert
  END
  call writefile(lines, 'Xscript', 'D')
  let buf = RunVimInTerminal('-S Xscript', {})
  call TermWait(buf)

  call term_sendkeys(buf, "ggSFab\<CR>Five\<CR>find\<CR>film\<CR>\<C-X>\<C-P>")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_pum_keep_select_01', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")
  call TermWait(buf, 50)

  call term_sendkeys(buf, "S\<C-X>\<C-P>")
  call TermWait(buf, 50)
  call term_sendkeys(buf, "F")
  call VerifyScreenDump(buf, 'Test_pum_keep_select_02', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call TermWait(buf, 50)
  call StopVimInTerminal(buf)
endfunc

func Test_pum_matchins_highlight()
  CheckScreendump
  let lines =<< trim END
    let g:change = 0
    func Omni_test(findstart, base)
      if a:findstart
        return col(".")
      endif
      if g:change == 0
        return [#{word: "foo"}, #{word: "bar"}, #{word: "你好"}]
      endif
      return [#{word: "foo", info: "info"}, #{word: "bar"}, #{word: "你好"}]
    endfunc
    set omnifunc=Omni_test
    hi ComplMatchIns ctermfg=red
  END
  call writefile(lines, 'Xscript', 'D')
  let buf = RunVimInTerminal('-S Xscript', {})

  call TermWait(buf)
  call term_sendkeys(buf, "Sαβγ \<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_01', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call TermWait(buf)
  call term_sendkeys(buf, "Sαβγ \<C-X>\<C-O>\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_02', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call TermWait(buf)
  call term_sendkeys(buf, "Sαβγ \<C-X>\<C-O>\<C-N>\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_03', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  " restore after accept
  call TermWait(buf)
  call term_sendkeys(buf, "Sαβγ \<C-X>\<C-O>\<C-Y>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_04', {})
  call term_sendkeys(buf, "\<Esc>")

  " restore after cancel completion
  call TermWait(buf)
  call term_sendkeys(buf, "Sαβγ \<C-X>\<C-O>\<Space>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_05', {})
  call term_sendkeys(buf, "\<Esc>")

  " text after the inserted text shouldn't be highlighted
  call TermWait(buf)
  call term_sendkeys(buf, "0ea \<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_07', {})
  call term_sendkeys(buf, "\<C-P>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_08', {})
  call term_sendkeys(buf, "\<C-P>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_09', {})
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_10', {})
  call term_sendkeys(buf, "\<Esc>")

  call term_sendkeys(buf, ":let g:change=1\<CR>S\<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_11', {})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
endfunc

func Test_pum_matchins_highlight_combine()
  CheckScreendump
  let lines =<< trim END
    func Omni_test(findstart, base)
      if a:findstart
        return col(".")
      endif
      return [#{word: "foo"}, #{word: "bar"}, #{word: "你好"}]
    endfunc
    set omnifunc=Omni_test
    hi Normal ctermbg=blue
    hi CursorLine cterm=underline ctermbg=green
    set cursorline
    call setline(1, 'aaa bbb')
  END
  call writefile(lines, 'Xscript', 'D')
  let buf = RunVimInTerminal('-S Xscript', {})

  " when ComplMatchIns is not set, CursorLine applies normally
  call term_sendkeys(buf, "0ea \<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_combine_01', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_combine_02', {})
  call term_sendkeys(buf, "\<BS>\<Esc>")

  " when ComplMatchIns is set, it is applied over CursorLine
  call TermWait(buf)
  call term_sendkeys(buf, ":hi ComplMatchIns ctermbg=red ctermfg=yellow\<CR>")
  call TermWait(buf)
  call term_sendkeys(buf, "0ea \<C-X>\<C-O>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_combine_03', {})
  call term_sendkeys(buf, "\<C-P>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_combine_04', {})
  call term_sendkeys(buf, "\<C-P>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_combine_05', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_combine_06', {})
  call term_sendkeys(buf, "\<Esc>")

  " Does not highlight the compl leader
  call TermWait(buf)
  call term_sendkeys(buf, ":set cot+=menuone,noselect\<CR>")
  call TermWait(buf)
  call term_sendkeys(buf, "S\<C-X>\<C-O>f\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_combine_07', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call term_sendkeys(buf, ":set cot+=fuzzy\<CR>")
  call TermWait(buf)
  call term_sendkeys(buf, "S\<C-X>\<C-O>f\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_matchins_combine_08', {})
  call term_sendkeys(buf, "\<C-E>\<Esc>")

  call StopVimInTerminal(buf)
endfunc

" this used to crash
func Test_popup_completion_many_ctrlp()
  new
  let candidates=repeat(['a0'], 99)
  call setline(1, candidates)
  exe ":norm! VGg\<C-A>"
  norm! G
  call feedkeys("o" .. repeat("\<c-p>", 100), 'tx')
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
