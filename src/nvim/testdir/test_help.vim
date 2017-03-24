
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
endfunc
