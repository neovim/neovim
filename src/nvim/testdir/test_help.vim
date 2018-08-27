
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
