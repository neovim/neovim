" Test for completion menu

source shared.vim

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
    call complete(1, ['source', 'soundfold'])
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

func DummyCompleteOne(findstart, base)
  if a:findstart
    return 0
  else
    wincmd n
    return ['onedef', 'oneDEF']
  endif
endfunc

" Test that nothing happens if the 'completefunc' opens
" a new window (no completion, no crash)
func Test_completefunc_opens_new_window_one()
  new
  let winid = win_getid()
  setlocal completefunc=DummyCompleteOne
  call setline(1, 'one')
  /^one
  call assert_fails('call feedkeys("A\<C-X>\<C-U>\<C-N>\<Esc>", "x")', 'E839:')
  call assert_notequal(winid, win_getid())
  q!
  call assert_equal(winid, win_getid())
  call assert_equal('', getline(1))
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
  call assert_fails('call feedkeys("A\<C-X>\<C-U>\<C-N>\<Esc>", "x")', 'E764:')
  call assert_notequal(winid, win_getid())
  q!
  call assert_equal(winid, win_getid())
  call assert_equal('two', getline(1))
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
    call complete_add('four2')
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

func DummyCompleteSix()
  call complete(1, ['Hello', 'World'])
  return ''
endfunction

" complete() correctly clears the list of autocomplete candidates
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

func Test_popup_complete_backwards()
  new
  call setline(1, ['Post', 'Port', 'Po'])
  let expected=['Post', 'Port', 'Port']
  call cursor(3,2)
  call feedkeys("A\<C-X>". repeat("\<C-P>", 3). "rt\<cr>", 'tx')
  call assert_equal(expected, getline(1,'$'))
  bwipe!
endfunc

func Test_popup_and_preview_autocommand()
  " This used to crash Vim
  if !has('python')
    return
  endif
  let h = winheight(0)
  if h < 15
    return
  endif
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
  call feedkeys("A\<c-x>\<c-u>/\<esc>", 'tx')
  call assert_equal('Oct/Oct', getline(1))
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
  if !has('terminal') || has('gui_running')
    return
  endif
  let h = winheight(0)
  if h < 15
    return
  endif
  let g:buf = term_start([$NVIM_PRG, '--clean', '-c', 'set noswapfile'], {'term_rows': h / 3})
  call term_sendkeys(g:buf, (h / 3 - 1)."o\<esc>G")
  call term_sendkeys(g:buf, "i\<c-x>")
  call term_wait(g:buf, 200)
  call term_sendkeys(g:buf, "\<c-v>")
  call term_wait(g:buf, 100)
  " popup first entry "!" must be at the top
  call WaitFor('term_getline(g:buf, 1) =~ "^!"')
  call assert_match('^!\s*$', term_getline(g:buf, 1))
  exe 'resize +' . (h - 1)
  call term_wait(g:buf, 100)
  redraw!
  " popup shifted down, first line is now empty
  call WaitFor('term_getline(g:buf, 1) == ""')
  call assert_equal('', term_getline(g:buf, 1))
  sleep 100m
  " popup is below cursor line and shows first match "!"
  call WaitFor('term_getline(g:buf, term_getcursor(g:buf)[0] + 1) =~ "^!"')
  call assert_match('^!\s*$', term_getline(g:buf, term_getcursor(g:buf)[0] + 1))
  " cursor line also shows !
  call assert_match('^!\s*$', term_getline(g:buf, term_getcursor(g:buf)[0]))
  bwipe!
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
    let g:compl_info = complete_info(g:compl_what)
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

" vim: shiftwidth=2 sts=2 expandtab
