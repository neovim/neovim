" test execute()

func NestedEval()
  let nested = execute('echo "nested\nlines"')
  echo 'got: "' . nested . '"'
endfunc

func NestedRedir()
  redir => var
  echo 'broken'
  redir END
endfunc

func Test_execute_string()
  call assert_equal("\nnocompatible", execute('set compatible?'))
  call assert_equal("\nsomething\nnice", execute('echo "something\nnice"'))
  call assert_equal("noendofline", execute('echon "noendofline"'))
  call assert_equal("", execute(123))

  call assert_equal("\ngot: \"\nnested\nlines\"", execute('call NestedEval()'))
  redir => redired
  echo 'this'
  let evaled = execute('echo "that"')
  echo 'theend'
  redir END
" Nvim supports execute('... :redir ...'), so this test is intentionally
" disabled.
"  call assert_equal("\nthis\ntheend", redired)
  call assert_equal("\nthat", evaled)

  call assert_fails('call execute("doesnotexist")', 'E492:')
  call assert_fails('call execute(3.4)', 'E806:')
" Nvim supports execute('... :redir ...'), so this test is intentionally
" disabled.
"  call assert_fails('call execute("call NestedRedir()")', 'E930:')

  call assert_equal("\nsomething", execute('echo "something"', ''))
  call assert_equal("\nsomething", execute('echo "something"', 'silent'))
  call assert_equal("\nsomething", execute('echo "something"', 'silent!'))
  call assert_equal("", execute('burp', 'silent!'))
  call assert_fails('call execute("echo \"x\"", 3.4)', 'E806:')

  call assert_equal("", execute(""))
endfunc

func Test_execute_list()
  call assert_equal("\nsomething\nnice", execute(['echo "something"', 'echo "nice"']))
  let l = ['for n in range(0, 3)',
	\  'echo n',
	\  'endfor']
  call assert_equal("\n0\n1\n2\n3", execute(l))

  call assert_equal("", execute([]))
  call assert_equal("", execute(v:_null_list))
endfunc

func Test_execute_does_not_change_col()
  echo ''
  echon 'abcd'
  let x = execute('silent echo 234343')
  echon 'xyz'
  let text = ''
  for col in range(1, 7)
    let text .= nr2char(screenchar(&lines, col))
  endfor
  call assert_equal('abcdxyz', text)
endfunc

func Test_execute_not_silent()
  echo ''
  echon 'abcd'
  let x = execute('echon 234', '')
  echo 'xyz'
  let text1 = ''
  for col in range(1, 8)
    let text1 .= nr2char(screenchar(&lines - 1, col))
  endfor
  call assert_equal('abcd234 ', text1)
  let text2 = ''
  for col in range(1, 4)
    let text2 .= nr2char(screenchar(&lines, col))
  endfor
  call assert_equal('xyz ', text2)
endfunc
