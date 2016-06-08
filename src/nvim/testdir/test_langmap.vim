" tests for 'langmap'

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

  quit!
endfunc
