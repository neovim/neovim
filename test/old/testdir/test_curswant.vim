" Tests for not changing curswant

source check.vim
source term_util.vim

func Test_curswant()
  new
  call append(0, ['1234567890', '12345'])

  normal! ggf8j
  call assert_equal(7, winsaveview().curswant)
  let &tabstop=&tabstop
  call assert_equal(4, winsaveview().curswant)

  normal! ggf8j
  call assert_equal(7, winsaveview().curswant)
  let &timeoutlen=&timeoutlen
  call assert_equal(7, winsaveview().curswant)

  normal! ggf8j
  call assert_equal(7, winsaveview().curswant)
  let &ttimeoutlen=&ttimeoutlen
  call assert_equal(7, winsaveview().curswant)

  bw!
endfunc

func Test_normal_gm()
  CheckRunVimInTerminal
  let lines =<< trim END
    call setline(1, repeat(["  abcd\tefgh\tij"], 10))
    call cursor(1, 1)
  END
  call writefile(lines, 'XtestCurswant', 'D')
  let buf = RunVimInTerminal('-S XtestCurswant', #{rows: 10})
  if has("folding")
    call term_sendkeys(buf, "jVjzf")
    " gm
    call term_sendkeys(buf, "gmk")
    call term_sendkeys(buf, ":echo virtcol('.')\<cr>")
    call WaitFor({-> term_getline(buf, 10) =~ '^18\s\+'})
    " g0
    call term_sendkeys(buf, "jg0k")
    call term_sendkeys(buf, ":echo virtcol('.')\<cr>")
    call WaitFor({-> term_getline(buf, 10) =~ '^1\s\+'})
    " g^
    call term_sendkeys(buf, "jg^k")
    call term_sendkeys(buf, ":echo virtcol('.')\<cr>")
    call WaitFor({-> term_getline(buf, 10) =~ '^3\s\+'})
  endif
  call term_sendkeys(buf, ":call cursor(10, 1)\<cr>")
  " gm
  call term_sendkeys(buf, "gmk")
  call term_sendkeys(buf, ":echo virtcol('.')\<cr>")
  call term_wait(buf)
  call WaitFor({-> term_getline(buf, 10) =~ '^18\s\+'})
  " g0
  call term_sendkeys(buf, "g0k")
  call term_sendkeys(buf, ":echo virtcol('.')\<cr>")
  call WaitFor({-> term_getline(buf, 10) =~ '^1\s\+'})
  " g^
  call term_sendkeys(buf, "g^k")
  call term_sendkeys(buf, ":echo virtcol('.')\<cr>")
  call WaitFor({-> term_getline(buf, 10) =~ '^3\s\+'})
  " clean up
  call StopVimInTerminal(buf)
  wincmd p
  wincmd c
endfunc

" vim: shiftwidth=2 sts=2 expandtab
