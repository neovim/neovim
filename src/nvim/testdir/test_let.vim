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

func Test_let_utf8_environment()
  let $a = 'ĀĒĪŌŪあいうえお'
  call assert_equal('ĀĒĪŌŪあいうえお', $a)
endfunc

func Test_let_heredoc_fails()
  call assert_fails('let v =<< marker', 'E991:')

  let text =<< trim END
  func WrongSyntax()
    let v =<< that there
  endfunc
  END
  call writefile(text, 'XheredocFail')
  call assert_fails('source XheredocFail', 'E126:')
  call delete('XheredocFail')

  let text =<< trim CodeEnd
  func MissingEnd()
    let v =<< END
  endfunc
  CodeEnd
  call writefile(text, 'XheredocWrong')
  call assert_fails('source XheredocWrong', 'E126:')
  call delete('XheredocWrong')

  let text =<< trim TEXTend
    let v =<< " comment
  TEXTend
  call writefile(text, 'XheredocNoMarker')
  call assert_fails('source XheredocNoMarker', 'E172:')
  call delete('XheredocNoMarker')

  let text =<< trim TEXTend
    let v =<< text
  TEXTend
  call writefile(text, 'XheredocBadMarker')
  call assert_fails('source XheredocBadMarker', 'E221:')
  call delete('XheredocBadMarker')
endfunc

func Test_let_heredoc_trim_no_indent_marker()
  let text =<< trim END
  Text
  with
  indent
END
  call assert_equal(['Text', 'with', 'indent'], text)
endfunc

" Test for the setting a variable using the heredoc syntax
func Test_let_heredoc()
  let var1 =<< END
Some sample text
	Text with indent
  !@#$%^&*()-+_={}|[]\~`:";'<>?,./
END

  call assert_equal(["Some sample text", "\tText with indent", "  !@#$%^&*()-+_={}|[]\\~`:\";'<>?,./"], var1)

  let var2 =<< XXX
Editor
XXX
  call assert_equal(['Editor'], var2)

  let var3 =<<END
END
  call assert_equal([], var3)

  let var3 =<<END
vim

end
  END
END 
END
  call assert_equal(['vim', '', 'end', '  END', 'END '], var3)

  let var1 =<< trim END
  Line1
    Line2
  	Line3
   END
  END
  call assert_equal(['Line1', '  Line2', "\tLine3", ' END'], var1)

  let var1 =<< trim !!!
	Line1
	 line2
		Line3
	!!!
  !!!
  call assert_equal(['Line1', ' line2', "\tLine3", '!!!',], var1)

  let var1 =<< trim XX
    Line1
  XX
  call assert_equal(['Line1'], var1)

  " ignore "endfunc"
  let var1 =<< END
something
endfunc
END
  call assert_equal(['something', 'endfunc'], var1)

  " ignore "endfunc" with trim
  let var1 =<< trim END
  something
  endfunc
  END
  call assert_equal(['something', 'endfunc'], var1)

  " ignore "python << xx"
  let var1 =<<END
something
python << xx
END
  call assert_equal(['something', 'python << xx'], var1)

  " ignore "python << xx" with trim
  let var1 =<< trim END
  something
  python << xx
  END
  call assert_equal(['something', 'python << xx'], var1)

  " ignore "append"
  let var1 =<< E
something
app
E
  call assert_equal(['something', 'app'], var1)

  " ignore "append" with trim
  let var1 =<< trim END
  something
  app
  END
  call assert_equal(['something', 'app'], var1)

  let check = []
  if 0
     let check =<< trim END
       from heredoc
     END
  endif
  call assert_equal([], check)

  " unpack assignment
  let [a, b, c] =<< END
     x
     \y
     z
END
  call assert_equal(['     x', '     \y', '     z'], [a, b, c])
endfunc
