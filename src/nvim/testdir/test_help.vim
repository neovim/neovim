
" Tests for :help

func Test_help_restore_snapshot()
  help
  set buftype=
  help
  edit x
  help
  helpclose
endfunc

func Test_help_errors()
  call assert_fails('help doesnotexist', 'E149:')
  call assert_fails('help!', 'E478:')

  new
  set keywordprg=:help
  call setline(1, "   ")
  call assert_fails('normal VK', 'E349:')
  bwipe!
endfunc

func Test_help_keyword()
  new
  set keywordprg=:help
  call setline(1, "  Visual ")
  normal VK
  call assert_match('^Visual mode', getline('.'))
  call assert_equal('help', &ft)
  close
  bwipe!
endfunc

func Test_help_local_additions()
  call mkdir('Xruntime/doc', 'p')
  call writefile(['*mydoc.txt* my awesome doc'], 'Xruntime/doc/mydoc.txt')
  call writefile(['*mydoc-ext.txt* my extended awesome doc'], 'Xruntime/doc/mydoc-ext.txt')
  let rtp_save = &rtp
  set rtp+=./Xruntime
  help
  1
  call search('mydoc.txt')
  call assert_equal('|mydoc.txt| my awesome doc', getline('.'))
  1
  call search('mydoc-ext.txt')
  call assert_equal('|mydoc-ext.txt| my extended awesome doc', getline('.'))
  close

  call delete('Xruntime', 'rf')
  let &rtp = rtp_save
endfunc
