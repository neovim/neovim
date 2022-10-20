" tests for 'langmap'

source check.vim
CheckFeature langmap

func Test_langmap()
  new
  set langmap=}l,^x,%v

  call setline(1, ['abc'])
  call feedkeys('gg0}^', 'tx')
  call assert_equal('ac', getline(1))

  " in Replace mode
  " need silent! to avoid a delay when entering Insert mode
  call setline(1, ['abcde'])
  silent! call feedkeys("gg0lR%{z\<Esc>00", 'tx')
  call assert_equal('a%{ze', getline(1))

  " in Select mode
  " need silent! to avoid a delay when entering Insert mode
  call setline(1, ['abcde'])
  silent! call feedkeys("gg0}%}\<C-G>}^\<Esc>00", 'tx')
  call assert_equal('a}^de', getline(1))

  " Error cases
  call assert_fails('set langmap=aA,b', 'E357:')
  call assert_fails('set langmap=z;y;y;z', 'E358:')

  " Map character > 256
  enew!
  set langmap=āx,ăl,āx
  call setline(1, ['abcde'])
  call feedkeys('gg2lā', 'tx')
  call assert_equal('abde', getline(1))

  " special characters in langmap
  enew!
  call setline(1, ['Hello World'])
  set langmap=\\;\\,,\\,\\;
  call feedkeys('ggfo,', 'tx')
  call assert_equal(8, col('.'))
  call feedkeys(';', 'tx')
  call assert_equal(5, col('.'))
  set langmap&
  set langmap=\\;\\,;\\,\\;
  call feedkeys('ggfo,', 'tx')
  call assert_equal(8, col('.'))
  call feedkeys(';', 'tx')
  call assert_equal(5, col('.'))

  set langmap=RL
  let g:counter = 0
  nnoremap L;L <Cmd>let g:counter += 1<CR>
  nnoremap <C-L> <Cmd>throw 'This mapping shoud not be triggered'<CR>

  " 'langmap' is applied to keys without modifiers when matching a mapping
  call feedkeys('R;R', 'tx')
  call assert_equal(1, g:counter)
  nunmap L;L
  unlet g:counter

  delete
  call assert_equal('', getline(1))
  undo
  call assert_equal('Hello World', getline(1))
  " 'langmap' does not change Ctrl-R to Ctrl-L for consistency
  call feedkeys("\<*C-R>", 'tx')
  call assert_equal('', getline(1))

  set langmap=6L
  undo
  setlocal bufhidden=hide
  let oldbuf = bufnr()
  enew
  call assert_notequal(oldbuf, bufnr())
  " 'langmap' does not change Ctrl-6 to Ctrl-L for consistency
  " Ctrl-6 becomes Ctrl-^ after merging the Ctrl modifier
  call feedkeys("\<*C-6>", 'tx')
  call assert_equal(oldbuf, bufnr())
  setlocal bufhidden&

  nunmap <C-L>

  set langmap&
  quit!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
