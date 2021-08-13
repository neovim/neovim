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

" Test for the :copy command
func Test_copy()
  new

  call setline(1, ['L1', 'L2', 'L3', 'L4'])
  " copy lines in a range to inside the range
  1,3copy 2
  call assert_equal(['L1', 'L2', 'L1', 'L2', 'L3', 'L3', 'L4'], getline(1, 7))

  close!
endfunc

" Test for the :file command
func Test_file_cmd()
  call assert_fails('3file', 'E474:')
  call assert_fails('0,0file', 'E474:')
  call assert_fails('0file abc', 'E474:')
endfunc

" Test for the :drop command
func Test_drop_cmd()
  call writefile(['L1', 'L2'], 'Xfile')
  enew | only
  drop Xfile
  call assert_equal('L2', getline(2))
  " Test for switching to an existing window
  below new
  drop Xfile
  call assert_equal(1, winnr())
  " Test for splitting the current window
  enew | only
  set modified
  drop Xfile
  call assert_equal(2, winnr('$'))
  " Check for setting the argument list
  call assert_equal(['Xfile'], argv())
  enew | only!
  call delete('Xfile')
endfunc

" Test for the :append command
func Test_append_cmd()
  new
  call setline(1, ['  L1'])
  call feedkeys(":append\<CR>  L2\<CR>  L3\<CR>.\<CR>", 'xt')
  call assert_equal(['  L1', '  L2', '  L3'], getline(1, '$'))
  %delete _
  " append after a specific line
  call setline(1, ['  L1', '  L2', '  L3'])
  call feedkeys(":2append\<CR>  L4\<CR>  L5\<CR>.\<CR>", 'xt')
  call assert_equal(['  L1', '  L2', '  L4', '  L5', '  L3'], getline(1, '$'))
  %delete _
  " append with toggling 'autoindent'
  call setline(1, ['  L1'])
  call feedkeys(":append!\<CR>  L2\<CR>  L3\<CR>.\<CR>", 'xt')
  call assert_equal(['  L1', '    L2', '      L3'], getline(1, '$'))
  call assert_false(&autoindent)
  %delete _
  " append with 'autoindent' set and toggling 'autoindent'
  set autoindent
  call setline(1, ['  L1'])
  call feedkeys(":append!\<CR>  L2\<CR>  L3\<CR>.\<CR>", 'xt')
  call assert_equal(['  L1', '  L2', '  L3'], getline(1, '$'))
  call assert_true(&autoindent)
  set autoindent&
  close!
endfunc

" Test for the :insert command
func Test_insert_cmd()
  set noautoindent " test assumes noautoindent, but it's on by default in Nvim
  new
  call setline(1, ['  L1'])
  call feedkeys(":insert\<CR>  L2\<CR>  L3\<CR>.\<CR>", 'xt')
  call assert_equal(['  L2', '  L3', '  L1'], getline(1, '$'))
  %delete _
  " insert before a specific line
  call setline(1, ['  L1', '  L2', '  L3'])
  call feedkeys(":2insert\<CR>  L4\<CR>  L5\<CR>.\<CR>", 'xt')
  call assert_equal(['  L1', '  L4', '  L5', '  L2', '  L3'], getline(1, '$'))
  %delete _
  " insert with toggling 'autoindent'
  call setline(1, ['  L1'])
  call feedkeys(":insert!\<CR>  L2\<CR>  L3\<CR>.\<CR>", 'xt')
  call assert_equal(['    L2', '      L3', '  L1'], getline(1, '$'))
  call assert_false(&autoindent)
  %delete _
  " insert with 'autoindent' set and toggling 'autoindent'
  set autoindent
  call setline(1, ['  L1'])
  call feedkeys(":insert!\<CR>  L2\<CR>  L3\<CR>.\<CR>", 'xt')
  call assert_equal(['  L2', '  L3', '  L1'], getline(1, '$'))
  call assert_true(&autoindent)
  set autoindent&
  close!
endfunc

" Test for the :change command
func Test_change_cmd()
  set noautoindent " test assumes noautoindent, but it's on by default in Nvim
  new
  call setline(1, ['  L1', 'L2', 'L3'])
  call feedkeys(":change\<CR>  L4\<CR>  L5\<CR>.\<CR>", 'xt')
  call assert_equal(['  L4', '  L5', 'L2', 'L3'], getline(1, '$'))
  %delete _
  " change a specific line
  call setline(1, ['  L1', '  L2', '  L3'])
  call feedkeys(":2change\<CR>  L4\<CR>  L5\<CR>.\<CR>", 'xt')
  call assert_equal(['  L1', '  L4', '  L5', '  L3'], getline(1, '$'))
  %delete _
  " change with toggling 'autoindent'
  call setline(1, ['  L1', 'L2', 'L3'])
  call feedkeys(":change!\<CR>  L4\<CR>  L5\<CR>.\<CR>", 'xt')
  call assert_equal(['    L4', '      L5', 'L2', 'L3'], getline(1, '$'))
  call assert_false(&autoindent)
  %delete _
  " change with 'autoindent' set and toggling 'autoindent'
  set autoindent
  call setline(1, ['  L1', 'L2', 'L3'])
  call feedkeys(":change!\<CR>  L4\<CR>  L5\<CR>.\<CR>", 'xt')
  call assert_equal(['  L4', '  L5', 'L2', 'L3'], getline(1, '$'))
  call assert_true(&autoindent)
  set autoindent&
  close!
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

func Test_confirm_write_ro()
  CheckNotGui
  CheckRunVimInTerminal

  call writefile(['foo'], 'Xconfirm_write_ro')
  let lines =<< trim END
    set nobackup ff=unix cmdheight=2
    edit Xconfirm_write_ro
    norm Abar
  END
  call writefile(lines, 'Xscript')
  let buf = RunVimInTerminal('-S Xscript', {'rows': 20})

  " Try to write with 'ro' option.
  call term_sendkeys(buf, ":set ro | confirm w\n")
  call WaitForAssert({-> assert_match("^'readonly' option is set for \"Xconfirm_write_ro\"\. *$",
        \            term_getline(buf, 18))}, 1000)
  call WaitForAssert({-> assert_match('^Do you wish to write anyway? *$',
        \            term_getline(buf, 19))}, 1000)
  call WaitForAssert({-> assert_match('^(Y)es, \[N\]o: *$', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, 'N')
  call WaitForAssert({-> assert_match('^ *$', term_getline(buf, 19))}, 1000)
  call WaitForAssert({-> assert_match('.* All$', term_getline(buf, 20))}, 1000)
  call assert_equal(['foo'], readfile('Xconfirm_write_ro'))

  call term_sendkeys(buf, ":confirm w\n")
  call WaitForAssert({-> assert_match("^'readonly' option is set for \"Xconfirm_write_ro\"\. *$",
        \            term_getline(buf, 18))}, 1000)
  call WaitForAssert({-> assert_match('^Do you wish to write anyway? *$',
        \            term_getline(buf, 19))}, 1000)
  call WaitForAssert({-> assert_match('^(Y)es, \[N\]o: *$', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, 'Y')
  call WaitForAssert({-> assert_match('^"Xconfirm_write_ro" 1L, 7B written$',
        \            term_getline(buf, 19))}, 1000)
  call assert_equal(['foobar'], readfile('Xconfirm_write_ro'))

  " Try to write with read-only file permissions.
  call setfperm('Xconfirm_write_ro', 'r--r--r--')
  call term_sendkeys(buf, ":set noro | undo | confirm w\n")
  call WaitForAssert({-> assert_match("^File permissions of \"Xconfirm_write_ro\" are read-only\. *$",
        \            term_getline(buf, 17))}, 1000)
  call WaitForAssert({-> assert_match('^It may still be possible to write it\. *$',
        \            term_getline(buf, 18))}, 1000)
  call WaitForAssert({-> assert_match('^Do you wish to try? *$', term_getline(buf, 19))}, 1000)
  call WaitForAssert({-> assert_match('^(Y)es, \[N\]o: *$', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, 'Y')
  call WaitForAssert({-> assert_match('^"Xconfirm_write_ro" 1L, 4B written$',
        \            term_getline(buf, 19))}, 1000)
  call assert_equal(['foo'], readfile('Xconfirm_write_ro'))

  call StopVimInTerminal(buf)
  call delete('Xscript')
  call delete('Xconfirm_write_ro')
endfunc

func Test_confirm_write_partial_file()
  CheckNotGui
  CheckRunVimInTerminal

  call writefile(['a', 'b', 'c', 'd'], 'Xwrite_partial')
  call writefile(['set nobackup ff=unix cmdheight=2',
        \         'edit Xwrite_partial'], 'Xscript')
  let buf = RunVimInTerminal('-S Xscript', {'rows': 20})

  call term_sendkeys(buf, ":confirm 2,3w\n")
  call WaitForAssert({-> assert_match('^Write partial file? *$',
        \            term_getline(buf, 19))}, 1000)
  call WaitForAssert({-> assert_match('^(Y)es, \[N\]o: *$',
        \            term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, 'N')
  call WaitForAssert({-> assert_match('.* All$', term_getline(buf, 20))}, 1000)
  call assert_equal(['a', 'b', 'c', 'd'], readfile('Xwrite_partial'))
  call delete('Xwrite_partial')

  call term_sendkeys(buf, ":confirm 2,3w\n")
  call WaitForAssert({-> assert_match('^Write partial file? *$',
        \            term_getline(buf, 19))}, 1000)
  call WaitForAssert({-> assert_match('^(Y)es, \[N\]o: *$',
        \            term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, 'Y')
  call WaitForAssert({-> assert_match('^"Xwrite_partial" \[New\] 2L, 4B written *$',
        \            term_getline(buf, 19))}, 1000)
  call WaitForAssert({-> assert_match('^Press ENTER or type command to continue *$',
        \            term_getline(buf, 20))}, 1000)
  call assert_equal(['b', 'c'], readfile('Xwrite_partial'))

  call StopVimInTerminal(buf)
  call delete('Xwrite_partial')
  call delete('Xscript')
endfunc

" Test for the :winsize command
func Test_winsize_cmd()
  call assert_fails('winsize 1', 'E465:')
  call assert_fails('winsize 1 x', 'E465:')
  call assert_fails('win_getid(1)', 'E475: Invalid argument: _getid(1)')
  " Actually changing the window size would be flaky.
endfunc
