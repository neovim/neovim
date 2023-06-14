" Tests for the :let command.

source vim9.vim

func Test_let()
  " Test to not autoload when assigning.  It causes internal error.
  set runtimepath+=./sautest
  let Test104#numvar = function('tr')
  call assert_equal("function('tr')", string(Test104#numvar))

  let foo#tr = function('tr')
  call assert_equal("function('tr')", string(foo#tr))
  unlet foo#tr

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

  " Test for displaying a string variable
  let s = 'vim'
  let out = execute('let s')
  let s = "\ns                      vim"
  call assert_equal(s, out)

  " Test for displaying a list variable
  let l = [1, 2]
  let out = execute('let l')
  let s = "\nl                     [1, 2]"
  call assert_equal(s, out)

  " Test for displaying a dict variable
  let d = {'k' : 'v'}
  let out = execute('let d')
  let s = "\nd                     {'k': 'v'}"
  call assert_equal(s, out)

  " Test for displaying a function reference variable
  let F = function('min')
  let out = execute('let F')
  let s = "\nF                     *min()"
  call assert_equal(s, out)

  let x = 0
  if 0 | let x = 1 | endif
  call assert_equal(0, x)

  " Display a list item using an out of range index
  let l = [10]
  call assert_fails('let l[1]', 'E684:')

  " List special variable dictionaries
  let g:Test_Global_Var = 5
  call assert_match("\nTest_Global_Var       #5", execute('let g:'))
  unlet g:Test_Global_Var

  let b:Test_Buf_Var = 8
  call assert_match("\nb:Test_Buf_Var        #8", execute('let b:'))
  unlet b:Test_Buf_Var

  let w:Test_Win_Var = 'foo'
  call assert_equal("\nw:Test_Win_Var         foo", execute('let w:'))
  unlet w:Test_Win_Var

  let t:Test_Tab_Var = 'bar'
  call assert_equal("\nt:Test_Tab_Var         bar", execute('let t:'))
  unlet t:Test_Tab_Var

  let s:Test_Script_Var = [7]
  call assert_match("\ns:Test_Script_Var     \\[7]", execute('let s:'))
  unlet s:Test_Script_Var

  let l:Test_Local_Var = {'k' : 5}
  call assert_match("\nl:Test_Local_Var      {'k': 5}", execute('let l:'))
  call assert_match("v:errors              []", execute('let v:'))

  " Test for assigning multiple list items
  let l = [1, 2, 3]
  let [l[0], l[1]] = [10, 20]
  call assert_equal([10, 20, 3], l)

  " Test for errors in conditional expression
  call assert_fails('let val = [] ? 1 : 2', 'E745:')
  call assert_fails('let val = 1 ? 5+ : 6', 'E121:')
  call assert_fails('let val = 1 ? 0 : 5+', 'E15:')
  call assert_false(exists('val'))

  " Test for errors in logical operators
  let @a = 'if [] || 0 | let val = 2 | endif'
  call assert_fails('exe @a', 'E745:')
  call assert_fails('call feedkeys(":let val = 0 || []\<cr>", "xt")', 'E745:')
  call assert_fails('exe "let val = [] && 5"', 'E745:')
  call assert_fails('exe "let val = 6 && []"', 'E745:')
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
  let b += [1]
endfunction

func s:set_varg8(...) abort
  let b = a:000
  call add(b, 1)
endfunction

func s:set_varg9(...) abort
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
  call assert_fails('call s:set_varg8(1)', 'E742:')
  call s:set_varg9([0])
endfunction

func Test_let_utf8_environment()
  let $a = 'ĀĒĪŌŪあいうえお'
  call assert_equal('ĀĒĪŌŪあいうえお', $a)
endfunc

func Test_let_no_type_checking()
  let v = 1
  let v = [1,2,3]
  let v = {'a': 1, 'b': 2}
  let v = 3.4
  let v = 'hello'
endfunc

func Test_let_termcap()
  throw 'Skipped: Nvim does not support termcap options'
  " Terminal code
  let old_t_te = &t_te
  let &t_te = "\<Esc>[yes;"
  call assert_match('t_te.*^[[yes;', execute("set termcap"))
  let &t_te = old_t_te

  if exists("+t_k1")
    " Key code
    let old_t_k1 = &t_k1
    let &t_k1 = "that"
    call assert_match('t_k1.*that', execute("set termcap"))
    let &t_k1 = old_t_k1
  endif

  call assert_fails('let x = &t_xx', 'E113:')
  let &t_xx = "yes"
  call assert_equal("yes", &t_xx)
  let &t_xx = ""
  call assert_fails('let x = &t_xx', 'E113:')
endfunc

func Test_let_option_error()
  let _w = &tw
  let &tw = 80
  call assert_fails('let &tw .= 1', ['E734:', 'E734:'])
  call assert_fails('let &tw .= []', ['E734:', 'E734:'])
  call assert_fails('let &tw = []', ['E745:', 'E745:'])
  call assert_fails('let &tw += []', ['E745:', 'E745:'])
  call assert_equal(80, &tw)
  let &tw = _w

  let _w = &autoread
  let &autoread = 1
  call assert_fails('let &autoread .= 1', ['E734:', 'E734:'])
  call assert_fails('let &autoread .= []', ['E734:', 'E734:'])
  call assert_fails('let &autoread = []', ['E745:', 'E745:'])
  call assert_fails('let &autoread += []', ['E745:', 'E745:'])
  call assert_equal(1, &autoread)
  let &autoread = _w

  let _w = &fillchars
  let &fillchars = "vert:|"
  call assert_fails('let &fillchars += "diff:-"', ['E734:', 'E734:'])
  call assert_fails('let &fillchars += []', ['E734:', 'E734:'])
  call assert_fails('let &fillchars = []', ['E730:', 'E730:'])
  call assert_fails('let &fillchars .= []', ['E730:', 'E730:'])
  call assert_equal("vert:|", &fillchars)
  let &fillchars = _w

  call assert_fails('let &nosuchoption = 1', ['E355:', 'E355:'])
  call assert_fails('let &nosuchoption = ""', ['E355:', 'E355:'])
  call assert_fails('let &nosuchoption = []', ['E355:', 'E355:'])
  call assert_fails('let &t_xx = []', ['E730:', 'E730:'])
endfunc

" Errors with the :let statement
func Test_let_errors()
  let s = 'abcd'
  call assert_fails('let s[1] = 5', 'E689:')

  let l = [1, 2, 3]
  call assert_fails('let l[:] = 5', 'E709:')

  call assert_fails('let x:lnum=5', ['E121:', 'E488:'])
  call assert_fails('let v:=5', 'E461:')
  call assert_fails('let [a]', 'E474:')
  call assert_fails('let [a, b] = [', 'E697:')
  call assert_fails('let [a, b] = [10, 20', 'E696:')
  call assert_fails('let [a, b] = 10', 'E714:')
  call assert_fails('let [a, , b] = [10, 20]', 'E475:')
  call assert_fails('let [a, b&] = [10, 20]', 'E475:')
  call assert_fails('let $ = 10', 'E475:')
  call assert_fails('let $FOO[1] = "abc"', 'E18:')
  call assert_fails('let &buftype[1] = "nofile"', 'E18:')
  let s = "var"
  let var = 1
  call assert_fails('let var += [1,2]', 'E734:')
  call assert_fails('let {s}.1 = 2', 'E1203:')
  call assert_fails('let a[1] = 5', 'E121:')
  let l = [[1,2]]
  call assert_fails('let l[:][0] = [5]', 'E708:')
  let d = {'k' : 4}
  call assert_fails('let d.# = 5', 'E488:')
  call assert_fails('let d.m += 5', 'E716:')
  call assert_fails('let m = d[{]', 'E15:')
  let l = [1, 2]
  call assert_fails('let l[2] = 0', 'E684:')
  call assert_fails('let l[0:1] = [1, 2, 3]', 'E710:')
  call assert_fails('let l[-2:-3] = [3, 4]', 'E684:')
  call assert_fails('let l[0:4] = [5, 6]', 'E711:')
  call assert_fails('let l -= 2', 'E734:')
  call assert_fails('let l += 2', 'E734:')
  call assert_fails('let g:["a;b"] = 10', 'E461:')
  call assert_fails('let g:.min = function("max")', 'E704:')
  call assert_fails('let g:cos = "" | let g:.cos = {-> 42}', 'E704:')
  if has('channel')
    let ch = test_null_channel()
    call assert_fails('let ch += 1', 'E734:')
  endif
  call assert_fails('let name = "a" .. "b",', 'E488: Trailing characters: ,')

  " This test works only when the language is English
  if v:lang == "C" || v:lang =~ '^[Ee]n'
    call assert_fails('let [a ; b;] = [10, 20]',
          \ 'Double ; in list of variables')
  endif
endfunc

func Test_let_heredoc_fails()
  call assert_fails('let v =<< marker', 'E991:')
  try
    exe "let v =<< TEXT | abc | TEXT"
    call assert_report('No exception thrown')
  catch /E488:/
  catch
    call assert_report('Caught exception: ' .. v:exception)
  endtry

  try
    let &commentstring =<< trim TEXT
      change
      insert
      append
    TEXT
    call assert_report('No exception thrown')
  catch /E730:/
  catch
    call assert_report('Caught exception: ' .. v:exception)
  endtry

  try
    let $SOME_ENV_VAR =<< trim TEXT
      change
      insert
      append
    TEXT
    call assert_report('No exception thrown')
  catch /E730:/
  catch
    call assert_report('Caught exception: ' .. v:exception)
  endtry

  try
    let @r =<< trim TEXT
      change
      insert
      append
    TEXT
    call assert_report('No exception thrown')
  catch /E730:/
  catch
    call assert_report('Caught exception: ' .. v:exception)
  endtry

  let text =<< trim END
  func WrongSyntax()
    let v =<< that there
  endfunc
  END
  call writefile(text, 'XheredocFail')
  call assert_fails('source XheredocFail', 'E1145:')
  call delete('XheredocFail')

  let text =<< trim CodeEnd
  func MissingEnd()
    let v =<< END
  endfunc
  CodeEnd
  call writefile(text, 'XheredocWrong')
  call assert_fails('source XheredocWrong', 'E1145:')
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

  call writefile(['let v =<< TEXT', 'abc'], 'XheredocMissingMarker')
  call assert_fails('source XheredocMissingMarker', 'E990:')
  call delete('XheredocMissingMarker')
endfunc

func Test_let_heredoc_trim_no_indent_marker()
  let text =<< trim END
  Text
  with
  indent
END
  call assert_equal(['Text', 'with', 'indent'], text)
endfunc

func Test_let_interpolated()
  call assert_equal('{text}', $'{{text}}')
  call assert_equal('{{text}}', $'{{{{text}}}}')
  let text = 'text'
  call assert_equal('text{{', $'{text .. "{{"}')
  call assert_equal('text{{', $"{text .. '{{'}")
  call assert_equal('text{{', $'{text .. '{{'}')
  call assert_equal('text{{', $"{text .. "{{"}")
endfunc

" Test for the setting a variable using the heredoc syntax.
" Keep near the end, this messes up highlighting.
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

  " unpack assignment without whitespace
  let[a,b,c]=<<END
change
insert
append
END
  call assert_equal(['change', 'insert', 'append'], [a, b, c])

  " curly braces name and list slice assignment
  let foo_3_bar = ['', '', '']
  let foo_{1 + 2}_bar[ : ] =<< END
change
insert
append
END
  call assert_equal(['change', 'insert', 'append'], foo_3_bar)

  " dictionary key containing brackets and spaces
  let d = {'abc] 123': 'baz'}
  let d[d['abc] 123'] .. '{'] =<< END
change
insert
append
END
  call assert_equal(['change', 'insert', 'append'], d['baz{'])
endfunc

" Test for evaluating Vim expressions in a heredoc using {expr}
" Keep near the end, this messes up highlighting.
func Test_let_heredoc_eval()
  let str = ''
  let code =<< trim eval END
    let a = {5 + 10}
    let b = {min([10, 6])} + {max([4, 6])}
    {str}
    let c = "abc{str}d"
  END
  call assert_equal(['let a = 15', 'let b = 6 + 6', '', 'let c = "abcd"'], code)

  let $TESTVAR = "Hello"
  let code =<< eval trim END
    let s = "{$TESTVAR}"
  END
  call assert_equal(['let s = "Hello"'], code)

  let code =<< eval END
    let s = "{$TESTVAR}"
END
  call assert_equal(['    let s = "Hello"'], code)

  let a = 10
  let data =<< eval END
{a}
END
  call assert_equal(['10'], data)

  let x = 'X'
  let code =<< eval trim END
    let a = {{abc}}
    let b = {x}
    let c = {{
  END
  call assert_equal(['let a = {abc}', 'let b = X', 'let c = {'], code)

  let code = 'xxx'
  let code =<< eval trim END
    let n = {5 +
    6}
  END
  call assert_equal('xxx', code)

  let code =<< eval trim END
     let n = {min([1, 2]} + {max([3, 4])}
  END
  call assert_equal('xxx', code)

  let lines =<< trim LINES
      let text =<< eval trim END
        let b = {
      END
  LINES
  call CheckScriptFailure(lines, 'E1279:')

  let lines =<< trim LINES
      let text =<< eval trim END
        let b = {abc
      END
  LINES
  call CheckScriptFailure(lines, 'E1279:')

  let lines =<< trim LINES
      let text =<< eval trim END
        let b = {}
      END
  LINES
  call CheckScriptFailure(lines, 'E15:')

  " skipped heredoc
  if 0
    let msg =<< trim eval END
        n is: {n}
    END
  endif

  " Test for sourcing a script containing a heredoc with invalid expression.
  " Variable assignment should fail, if expression evaluation fails
  new
  let g:Xvar = 'test'
  let g:b = 10
  let lines =<< trim END
    let Xvar =<< eval CODE
    let a = 1
    let b = {5+}
    let c = 2
    CODE
    let g:Count += 1
  END
  call setline(1, lines)
  let g:Count = 0
  call assert_fails('source', 'E15:')
  call assert_equal(1, g:Count)
  call setline(3, 'let b = {abc}')
  call assert_fails('source', 'E121:')
  call assert_equal(2, g:Count)
  call setline(3, 'let b = {abc} + {min([9, 4])} + 2')
  call assert_fails('source', 'E121:')
  call assert_equal(3, g:Count)
  call assert_equal('test', g:Xvar)
  call assert_equal(10, g:b)
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
