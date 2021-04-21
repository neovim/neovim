" Tests for various Ex commands.

source check.vim

func Test_ex_delete()
  new
  call setline(1, ['a', 'b', 'c'])
  2
  " :dl is :delete with the "l" flag, not :dlist
  .dl
  call assert_equal(['a', 'c'], getline(1, 2))
endfunc

func Test_range_error()
  call assert_fails(':.echo 1', 'E481:')
  call assert_fails(':$echo 1', 'E481:')
  call assert_fails(':1,2echo 1', 'E481:')
  call assert_fails(':+1echo 1', 'E481:')
  call assert_fails(':/1/echo 1', 'E481:')
  call assert_fails(':\/echo 1', 'E481:')
  normal vv
  call assert_fails(":'<,'>echo 1", 'E481:')
endfunc

func Test_buffers_lastused()
  edit bufc " oldest

  sleep 1200m
  edit bufa " middle

  sleep 1200m
  edit bufb " newest

  enew

  let ls = split(execute('buffers t', 'silent!'), '\n')
  let bufs = []
  for line in ls
    let bufs += [split(line, '"\s*')[1:2]]
  endfor

  let names = []
  for buf in bufs
    if buf[0] !=# '[No Name]'
      let names += [buf[0]]
    endif
  endfor

  call assert_equal(['bufb', 'bufa', 'bufc'], names)
  call assert_match('[0-2] seconds\= ago', bufs[1][1])

  bwipeout bufa
  bwipeout bufb
  bwipeout bufc
endfunc

" Test for the :confirm command dialog
func Test_confirm_cmd()
  CheckNotGui
  CheckRunVimInTerminal
  call writefile(['foo1'], 'foo')
  call writefile(['bar1'], 'bar')
  " Test for saving all the modified buffers
  let buf = RunVimInTerminal('', {'rows': 20})
  call term_sendkeys(buf, ":set nomore\n")
  call term_sendkeys(buf, ":new foo\n")
  call term_sendkeys(buf, ":call setline(1, 'foo2')\n")
  call term_sendkeys(buf, ":new bar\n")
  call term_sendkeys(buf, ":call setline(1, 'bar2')\n")
  call term_sendkeys(buf, ":wincmd b\n")
  call term_sendkeys(buf, ":confirm qall\n")
  call WaitForAssert({-> assert_match('\[Y\]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: ', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "A")
  call StopVimInTerminal(buf)
  call assert_equal(['foo2'], readfile('foo'))
  call assert_equal(['bar2'], readfile('bar'))
  " Test for discarding all the changes to modified buffers
  let buf = RunVimInTerminal('', {'rows': 20})
  call term_sendkeys(buf, ":set nomore\n")
  call term_sendkeys(buf, ":new foo\n")
  call term_sendkeys(buf, ":call setline(1, 'foo3')\n")
  call term_sendkeys(buf, ":new bar\n")
  call term_sendkeys(buf, ":call setline(1, 'bar3')\n")
  call term_sendkeys(buf, ":wincmd b\n")
  call term_sendkeys(buf, ":confirm qall\n")
  call WaitForAssert({-> assert_match('\[Y\]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: ', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "D")
  call StopVimInTerminal(buf)
  call assert_equal(['foo2'], readfile('foo'))
  call assert_equal(['bar2'], readfile('bar'))
  " Test for saving and discarding changes to some buffers
  let buf = RunVimInTerminal('', {'rows': 20})
  call term_sendkeys(buf, ":set nomore\n")
  call term_sendkeys(buf, ":new foo\n")
  call term_sendkeys(buf, ":call setline(1, 'foo4')\n")
  call term_sendkeys(buf, ":new bar\n")
  call term_sendkeys(buf, ":call setline(1, 'bar4')\n")
  call term_sendkeys(buf, ":wincmd b\n")
  call term_sendkeys(buf, ":confirm qall\n")
  call WaitForAssert({-> assert_match('\[Y\]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: ', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "N")
  call WaitForAssert({-> assert_match('\[Y\]es, (N)o, (C)ancel: ', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "Y")
  call StopVimInTerminal(buf)
  call assert_equal(['foo4'], readfile('foo'))
  call assert_equal(['bar2'], readfile('bar'))

  call delete('foo')
  call delete('bar')
endfunc

func Test_confirm_cmd_cancel()
  CheckNotGui
  CheckRunVimInTerminal

  " Test for closing a window with a modified buffer
  let buf = RunVimInTerminal('', {'rows': 20})
  call term_sendkeys(buf, ":set nomore\n")
  call term_sendkeys(buf, ":new\n")
  call term_sendkeys(buf, ":call setline(1, 'abc')\n")
  call term_sendkeys(buf, ":confirm close\n")
  call WaitForAssert({-> assert_match('^\[Y\]es, (N)o, (C)ancel: *$',
        \ term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "C")
  call WaitForAssert({-> assert_equal('', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, ":confirm close\n")
  call WaitForAssert({-> assert_match('^\[Y\]es, (N)o, (C)ancel: *$',
        \ term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "N")
  call WaitForAssert({-> assert_match('^ *0,0-1         All$',
        \ term_getline(buf, 20))}, 1000)
  call StopVimInTerminal(buf)
endfunc

" Test for the :winsize command
func Test_winsize_cmd()
  call assert_fails('winsize 1', 'E465:')
  call assert_fails('winsize 1 x', 'E465:')
  call assert_fails('win_getid(1)', 'E475: Invalid argument: _getid(1)')
  " Actually changing the window size would be flaky.
endfunc
