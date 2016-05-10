" Tests for :help! {subject}

func Test_help_tagjump()
  " /^start tags$/+1,/^end tags$/-1w! Xtags
  " echomsg 'VISIBILITY'
  pwd
  helptags ++t .
  " set tags=Xtags
  set tags=../../../build/runtime/doc/tags
  help
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*help.txt\*')
  helpclose

  exec "help! ('textwidth'"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ "\\*'textwidth'\\*")
  helpclose

  exec "help! ('buflisted'),"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ "\\*'buflisted'\\*")
  helpclose

  exec "help! abs({expr})"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*abs()\*')
  helpclose

  exec "help! arglistid([{winnr}"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*arglistid()\*')
  helpclose
endfunc

" start tags
" ('textwidth')   Xtext  3
" ('buflisted')  Xtext  2
" abs({expr})    Xtext  4
" arglistid([{winnr}]) Xtext 5
" end tags
