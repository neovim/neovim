" Tests for system() and systemlist()

function! Test_System()
  if !executable('echo') || !executable('cat') || !executable('wc')
    return
  endif
  call assert_equal("123\n", system('echo 123'))
  call assert_equal(['123'], systemlist('echo 123'))
  call assert_equal('123',   system('cat', '123'))
  call assert_equal(['123'], systemlist('cat', '123'))
  call assert_equal(["as\<NL>df"], systemlist('cat', ["as\<NL>df"]))
  new Xdummy
  call setline(1, ['asdf', "pw\<NL>er", 'xxxx'])
  call assert_equal("3\n",  system('wc -l', bufnr('%')))
  call assert_equal(['3'],  systemlist('wc -l', bufnr('%')))
  call assert_equal(['asdf', "pw\<NL>er", 'xxxx'],  systemlist('cat', bufnr('%')))
  bwipe!

  call assert_fails('call system("wc -l", 99999)', 'E86:')
endfunction
