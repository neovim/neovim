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

func s:set_arg1(a) abort
  let a:a = 1
endfunction

func s:set_arg2(a) abort
  let a:b = 1
endfunction

func s:set_arg3(a) abort
  let b = a:
  let b['a'] = 1
endfunction

func s:set_arg4(a) abort
  let b = a:
  let b['a'] = 1
endfunction

func s:set_arg5(a) abort
  let b = a:
  let b['a'][0] = 1
endfunction

func s:set_arg6(a) abort
  let a:a[0] = 1
endfunction

func s:set_arg7(a) abort
  call extend(a:, {'a': 1})
endfunction

func s:set_arg8(a) abort
  call extend(a:, {'b': 1})
endfunction

func s:set_arg9(a) abort
  let a:['b'] = 1
endfunction

func s:set_arg10(a) abort
  let b = a:
  call extend(b, {'a': 1})
endfunction

func s:set_arg11(a) abort
  let b = a:
  call extend(b, {'b': 1})
endfunction

func s:set_arg12(a) abort
  let b = a:
  let b['b'] = 1
endfunction

func Test_let_arg_fail()
  call assert_fails('call s:set_arg1(1)', 'E46:')
  call assert_fails('call s:set_arg2(1)', 'E461:')
  call assert_fails('call s:set_arg3(1)', 'E46:')
  call assert_fails('call s:set_arg4(1)', 'E46:')
  call assert_fails('call s:set_arg5(1)', 'E46:')
  call s:set_arg6([0])
  call assert_fails('call s:set_arg7(1)', 'E742:')
  call assert_fails('call s:set_arg8(1)', 'E742:')
  call assert_fails('call s:set_arg9(1)', 'E461:')
  call assert_fails('call s:set_arg10(1)', 'E742:')
  call assert_fails('call s:set_arg11(1)', 'E742:')
  call assert_fails('call s:set_arg12(1)', 'E461:')
endfunction

func s:set_varg1(...) abort
  let a:000 = []
endfunction

func s:set_varg2(...) abort
  let a:000[0] = 1
endfunction

func s:set_varg3(...) abort
  let a:000 += [1]
endfunction

func s:set_varg4(...) abort
  call add(a:000, 1)
endfunction

func s:set_varg5(...) abort
  let a:000[0][0] = 1
endfunction

func s:set_varg6(...) abort
  let b = a:000
  let b[0] = 1
endfunction

func s:set_varg7(...) abort
  let b = a:000
  call add(b, 1)
endfunction

func s:set_varg8(...) abort
  let b = a:000
  let b[0][0] = 1
endfunction

func Test_let_varg_fail()
  call assert_fails('call s:set_varg1(1)', 'E46:')
  call assert_fails('call s:set_varg2(1)', 'E742:')
  call assert_fails('call s:set_varg3(1)', 'E46:')
  call assert_fails('call s:set_varg4(1)', 'E742:')
  call s:set_varg5([0])
  call assert_fails('call s:set_varg6(1)', 'E742:')
  call assert_fails('call s:set_varg7(1)', 'E742:')
  call s:set_varg8([0])
endfunction
