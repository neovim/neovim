" Tests for :help! {subject}

func SetUp()
  " v:progpath is …/build/bin/nvim and we need …/build/runtime
  " to be added to &rtp
  let builddir = fnamemodify(exepath(v:progpath), ':h:h')
  let s:rtp = &rtp
  let &rtp .= printf(',%s/runtime', builddir)
endfunc

func TearDown()
  let &rtp = s:rtp
endfunc

func Test_help_tagjump()
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

  exec "help! arglistid([{winnr})"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*arglistid()\*')
  helpclose
endfunc
