" Tests for system() and systemlist()

function! Test_System()
  if !executable('echo') || !executable('cat') || !executable('wc')
    return
  endif
  let out = system('echo 123')
  " On Windows we may get a trailing space.
  if out != "123 \n"
    call assert_equal("123\n", out)
  endif

  let out = systemlist('echo 123')
  " On Windows we may get a trailing space and CR.
  if out != ["123 \r"]
    call assert_equal(['123'], out)
  endif

  call assert_equal('123',   system('cat', '123'))
  call assert_equal(['123'], systemlist('cat', '123'))
  call assert_equal(["as\<NL>df"], systemlist('cat', ["as\<NL>df"]))

  new Xdummy
  call setline(1, ['asdf', "pw\<NL>er", 'xxxx'])
  let out = system('wc -l', bufnr('%'))
  " On OS/X we get leading spaces
  let out = substitute(out, '^ *', '', '')
  call assert_equal("3\n", out)

  let out = systemlist('wc -l', bufnr('%'))
  " On Windows we may get a trailing CR.
  if out != ["3\r"]
    " On OS/X we get leading spaces
    if type(out) == v:t_list
      let out[0] = substitute(out[0], '^ *', '', '')
    endif
    call assert_equal(['3'],  out)
  endif

  let out = systemlist('cat', bufnr('%'))
  " On Windows we may get a trailing CR.
  if out != ["asdf\r", "pw\<NL>er\r", "xxxx\r"]
    call assert_equal(['asdf', "pw\<NL>er", 'xxxx'],  out)
  endif
  bwipe!

  call assert_fails('call system("wc -l", 99999)', 'E86:')
endfunction
