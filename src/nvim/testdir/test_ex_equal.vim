" Test Ex := command.

func Test_ex_equal()
  new
  call setline(1, ["foo\tbar", "bar\tfoo"])

  let a = execute('=')
  call assert_equal("\n2", a)

  let a = execute('=#')
  call assert_equal("\n2\n  1 foo     bar", a)

  let a = execute('=l')
  call assert_equal("\n2\nfoo^Ibar$", a)

  let a = execute('=p')
  call assert_equal("\n2\nfoo     bar", a)

  let a = execute('=l#')
  call assert_equal("\n2\n  1 foo^Ibar$", a)

  let a = execute('=p#')
  call assert_equal("\n2\n  1 foo     bar", a)

  let a = execute('.=')
  call assert_equal("\n1", a)

  call assert_fails('3=', 'E16:')
  call assert_fails('=x', 'E488:')

  bwipe!
endfunc
