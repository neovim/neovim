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
