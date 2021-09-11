" test execute()

source view_util.vim

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
" Nvim supports execute('... :redir ...'), so this test is intentionally
" disabled.
"  call assert_fails('call execute("call NestedRedir()")', 'E930:')

  call assert_equal("\nsomething", execute('echo "something"', ''))
  call assert_equal("\nsomething", execute('echo "something"', 'silent'))
  call assert_equal("\nsomething", execute('echo "something"', 'silent!'))
  call assert_equal("", execute('burp', 'silent!'))
  if has('float')
    call assert_fails('call execute(3.4)', 'E492:')
    call assert_equal("\nx", execute("echo \"x\"", 3.4))
  endif

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

func Test_win_execute()
  let thiswin = win_getid()
  new
  let otherwin = win_getid()
  call setline(1, 'the new window')
  call win_gotoid(thiswin)
  let line = win_execute(otherwin, 'echo getline(1)')
  call assert_match('the new window', line)
  let line = win_execute(134343, 'echo getline(1)')
  call assert_equal('', line)

  if has('textprop')
    let popupwin = popup_create('the popup win', {'line': 2, 'col': 3})
    redraw
    let line = win_execute(popupwin, 'echo getline(1)')
    call assert_match('the popup win', line)

    call popup_close(popupwin)
  endif

  call win_gotoid(otherwin)
  bwipe!
endfunc

func Test_win_execute_update_ruler()
  enew
  call setline(1, range(500))
  20
  split
  let winid = win_getid()
  set ruler
  wincmd w
  let height = winheight(winid)
  redraw
  call assert_match('20,1', Screenline(height + 1))
  let line = win_execute(winid, 'call cursor(100, 1)')
  redraw
  call assert_match('100,1', Screenline(height + 1))

  bwipe!
endfunc

func Test_win_execute_other_tab()
  let thiswin = win_getid()
  tabnew
  call win_execute(thiswin, 'let xyz = 1')
  call assert_equal(1, xyz)
  tabclose
  unlet xyz
endfunc
