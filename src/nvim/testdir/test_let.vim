" Tests for the :let command.

func Test_let()
  " Test to not autoload when assigning.  It causes internal error.
  set runtimepath+=./sautest
  let Test104#numvar = function('tr')
  call assert_equal("function('tr')", string(Test104#numvar))

  let a = 1
  let b = 2

  let out = execute('let a b')
  let s = "\na                     #1\nb                     #2"
  call assert_equal(s, out)

  let out = execute('let {0 == 1 ? "a" : "b"}')
  let s = "\nb                     #2"
  call assert_equal(s, out)

  let out = execute('let {0 == 1 ? "a" : "b"} a')
  let s = "\nb                     #2\na                     #1"
  call assert_equal(s, out)

  let out = execute('let a {0 == 1 ? "a" : "b"}')
  let s = "\na                     #1\nb                     #2"
  call assert_equal(s, out)
endfunc
