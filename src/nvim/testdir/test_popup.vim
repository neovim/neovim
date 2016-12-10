" Test for completion menu

function! ComplTest() abort
  call complete(1, ['source', 'soundfold'])
  return ''
endfunction

function! Test() abort
  call complete(1, ['source', 'soundfold'])
  return ''
endfunction

func Test_noinsert_complete()
  new
  set completeopt+=noinsert
  inoremap <F5>  <C-R>=ComplTest()<CR>
  call feedkeys("i\<F5>soun\<CR>\<CR>\<ESC>.", 'tx')
  call assert_equal('soundfold', getline(1))
  call assert_equal('soundfold', getline(2))
  bwipe!

  new
  inoremap <F5>  <C-R>=Test()<CR>
  call feedkeys("i\<F5>\<CR>\<ESC>", 'tx')
  call assert_equal('source', getline(1))
  bwipe!

  set completeopt-=noinsert
  iunmap <F5>
endfunc

let g:months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
let g:setting = ''

func ListMonths()
  if g:setting != ''
    exe ":set" g:setting
  endif
  call complete(col('.'), g:months)
  return ''
endfunc

func! Test_popup_completion_insertmode()
  inoremap <F5> <C-R>=ListMonths()<CR>
  new
  call feedkeys("a\<F5>\<down>\<enter>\<esc>", 'tx')
  call assert_equal('February', getline(1))
  %d
  let g:setting = 'noinsertmode'
  call feedkeys("a\<F5>\<down>\<enter>\<esc>", 'tx')
  call assert_equal('February', getline(1))
  call assert_false(pumvisible())
  %d
  let g:setting = ''
  call feedkeys("a\<F5>". repeat("\<c-n>",12)."\<enter>\<esc>", 'tx')
  call assert_equal('', getline(1))
  %d
  call feedkeys("a\<F5>\<c-p>\<enter>\<esc>", 'tx')
  call assert_equal('', getline(1))
  %d
  call feedkeys("a\<F5>\<c-p>\<c-p>\<enter>\<esc>", 'tx')
  call assert_equal('December', getline(1))
  bwipe!
  iunmap <F5>
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
endfunction

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

:"Test that 'completefunc' works when it's OK.
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

" <C-E> - select original typed text before the completion started without
" auto-wrap text.
func Test_completion_ctrl_e_without_autowrap()
  new
  let tw_save=&tw
  set tw=78
  let li = [
        \ '"                                                        zzz',
        \ '" zzzyyyyyyyyyyyyyyyyyyy']
  call setline(1, li)
  0
  call feedkeys("A\<C-X>\<C-N>\<C-E>\<Esc>", "tx")
  call assert_equal(li, getline(1, '$'))

  let &tw=tw_save
  q!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
