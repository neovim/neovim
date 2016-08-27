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
