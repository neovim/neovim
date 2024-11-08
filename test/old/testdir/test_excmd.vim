" Tests for various Ex commands.

source check.vim
source shared.vim
source term_util.vim
source screendump.vim

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
  call assert_fails(":\\xcenter", 'E10:')
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

  " Specifying a count before using : to run an ex-command
  exe "normal! gg4:yank\<CR>"
  call assert_equal("L1\nL2\nL1\nL2\n", @")

  close!
endfunc

" Test for the :file command
func Test_file_cmd()
  call assert_fails('3file', 'E474:')
  call assert_fails('0,0file', 'E474:')
  call assert_fails('0file abc', 'E474:')
  if !has('win32')
    " Change the name of the buffer to the same name
    new Xfile1
    file Xfile1
    call assert_equal('Xfile1', @%)
    call assert_equal('Xfile1', @#)
    bw!
  endif
endfunc

" Test for the :drop command
func Test_drop_cmd()
  call writefile(['L1', 'L2'], 'Xdropfile', 'D')
  " Test for reusing the current buffer
  enew | only
  let expected_nr = bufnr()
  drop Xdropfile
  call assert_equal(expected_nr, bufnr())
  call assert_equal('L2', getline(2))
  " Test for switching to an existing window
  below new
  drop Xdropfile
  call assert_equal(1, winnr())
  " Test for splitting the current window (set nohidden)
  enew | only
  set modified
  drop Xdropfile
  call assert_equal(2, winnr('$'))
  " Not splitting the current window even if modified (set hidden)
  set hidden
  enew | only
  set modified
  drop Xdropfile
  call assert_equal(1, winnr('$'))
  " Check for setting the argument list
  call assert_equal(['Xdropfile'], argv())
  enew | only!
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

func Test_append_cmd_empty_buf()
  CheckRunVimInTerminal
  let lines =<< trim END
    func Timer(timer)
      append
    aaaaa
    bbbbb
    .
    endfunc
    call timer_start(10, 'Timer')
  END
  call writefile(lines, 'Xtest_append_cmd_empty_buf')
  let buf = RunVimInTerminal('-S Xtest_append_cmd_empty_buf', {'rows': 6})
  call WaitForAssert({-> assert_equal('bbbbb', term_getline(buf, 2))})
  call WaitForAssert({-> assert_equal('aaaaa', term_getline(buf, 1))})

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xtest_append_cmd_empty_buf')
endfunc

" Test for the :insert command
func Test_insert_cmd()
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

func Test_insert_cmd_empty_buf()
  CheckRunVimInTerminal
  let lines =<< trim END
    func Timer(timer)
      insert
    aaaaa
    bbbbb
    .
    endfunc
    call timer_start(10, 'Timer')
  END
  call writefile(lines, 'Xtest_insert_cmd_empty_buf')
  let buf = RunVimInTerminal('-S Xtest_insert_cmd_empty_buf', {'rows': 6})
  call WaitForAssert({-> assert_equal('bbbbb', term_getline(buf, 2))})
  call WaitForAssert({-> assert_equal('aaaaa', term_getline(buf, 1))})

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xtest_insert_cmd_empty_buf')
endfunc

" Test for the :change command
func Test_change_cmd()
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

" Test for the :language command
func Test_language_cmd()
  CheckFeature multi_lang

  call assert_fails('language ctype non_existing_lang', 'E197:')
  call assert_fails('language time non_existing_lang', 'E197:')
endfunc

" Test for the :confirm command dialog
func Test_confirm_cmd()
  CheckNotGui
  CheckRunVimInTerminal

  call writefile(['foo1'], 'Xfoo')
  call writefile(['bar1'], 'Xbar')

  " Test for saving all the modified buffers
  let lines =<< trim END
    set nomore
    new Xfoo
    call setline(1, 'foo2')
    new Xbar
    call setline(1, 'bar2')
    wincmd b
  END
  call writefile(lines, 'Xscript')
  let buf = RunVimInTerminal('-S Xscript', {'rows': 20})
  call term_sendkeys(buf, ":confirm qall\n")
  call WaitForAssert({-> assert_match('\[Y\]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: ', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "A")
  call StopVimInTerminal(buf)

  call assert_equal(['foo2'], readfile('Xfoo'))
  call assert_equal(['bar2'], readfile('Xbar'))

  " Test for discarding all the changes to modified buffers
  let lines =<< trim END
    set nomore
    new Xfoo
    call setline(1, 'foo3')
    new Xbar
    call setline(1, 'bar3')
    wincmd b
  END
  call writefile(lines, 'Xscript')
  let buf = RunVimInTerminal('-S Xscript', {'rows': 20})
  call term_sendkeys(buf, ":confirm qall\n")
  call WaitForAssert({-> assert_match('\[Y\]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: ', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "D")
  call StopVimInTerminal(buf)

  call assert_equal(['foo2'], readfile('Xfoo'))
  call assert_equal(['bar2'], readfile('Xbar'))

  " Test for saving and discarding changes to some buffers
  let lines =<< trim END
    set nomore
    new Xfoo
    call setline(1, 'foo4')
    new Xbar
    call setline(1, 'bar4')
    wincmd b
  END
  call writefile(lines, 'Xscript')
  let buf = RunVimInTerminal('-S Xscript', {'rows': 20})
  call term_sendkeys(buf, ":confirm qall\n")
  call WaitForAssert({-> assert_match('\[Y\]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: ', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "N")
  call WaitForAssert({-> assert_match('\[Y\]es, (N)o, (C)ancel: ', term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, "Y")
  call StopVimInTerminal(buf)

  call assert_equal(['foo4'], readfile('Xfoo'))
  call assert_equal(['bar2'], readfile('Xbar'))

  call delete('Xscript')
  call delete('Xfoo')
  call delete('Xbar')
endfunc

func Test_confirm_cmd_cancel()
  CheckNotGui
  CheckRunVimInTerminal

  " Test for closing a window with a modified buffer
  let lines =<< trim END
    set nomore
    new
    call setline(1, 'abc')
  END
  call writefile(lines, 'Xscript')
  let buf = RunVimInTerminal('-S Xscript', {'rows': 20})
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
  call delete('Xscript')
endfunc

" The ":confirm" prompt was sometimes used with the terminal in cooked mode.
" This test verifies that a "\<CR>" character is NOT required to respond to a
" prompt from the ":conf q" and ":conf wq" commands.
func Test_confirm_q_wq()
  CheckNotGui
  CheckRunVimInTerminal

  call writefile(['foo'], 'Xfoo')

  let lines =<< trim END
    set hidden nomore
    call setline(1, 'abc')
    edit Xfoo
  END
  call writefile(lines, 'Xscript')
  let buf = RunVimInTerminal('-S Xscript', {'rows': 20})
  call term_sendkeys(buf, ":confirm q\n")
  call WaitForAssert({-> assert_match('^\[Y\]es, (N)o, (C)ancel: *$',
        \ term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, 'C')
  call WaitForAssert({-> assert_notmatch('^\[Y\]es, (N)o, (C)ancel: C*$',
        \ term_getline(buf, 20))}, 1000)

  call term_sendkeys(buf, ":edit Xfoo\n")
  call term_sendkeys(buf, ":confirm wq\n")
  call WaitForAssert({-> assert_match('^\[Y\]es, (N)o, (C)ancel: *$',
        \ term_getline(buf, 20))}, 1000)
  call term_sendkeys(buf, 'C')
  call WaitForAssert({-> assert_notmatch('^\[Y\]es, (N)o, (C)ancel: C*$',
        \ term_getline(buf, 20))}, 1000)
  call StopVimInTerminal(buf)

  call delete('Xscript')
  call delete('Xfoo')
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

" Test for the :print command
func Test_print_cmd()
  call assert_fails('print', 'E749:')
endfunc

" Test for the :winsize command
func Test_winsize_cmd()
  call assert_fails('winsize 1', 'E465:')
  call assert_fails('winsize 1 x', 'E465:')
  call assert_fails('win_getid(1)', 'E475: Invalid argument: _getid(1)')
  " Actually changing the window size would be flaky.
endfunc

" Test for the :redir command
" NOTE: if you run tests as root this will fail.  Don't run tests as root!
func Test_redir_cmd()
  call assert_fails('redir @@', 'E475:')
  call assert_fails('redir abc', 'E475:')
  call assert_fails('redir => 1abc', 'E474:')
  call assert_fails('redir => a b', 'E488:')
  call assert_fails('redir => abc[1]', 'E121:')
  let b = 0zFF
  call assert_fails('redir =>> b', 'E734:')
  unlet b

  if has('unix')
    " Redirecting to a directory name
    call mkdir('Xdir')
    call assert_fails('redir > Xdir', 'E17:')
    call delete('Xdir', 'd')
  endif

  " Test for redirecting to a register
  redir @q> | echon 'clean ' | redir END
  redir @q>> | echon 'water' | redir END
  call assert_equal('clean water', @q)

  " Test for redirecting to a variable
  redir => color | echon 'blue ' | redir END
  redir =>> color | echon 'sky' | redir END
  call assert_equal('blue sky', color)
endfunc

func Test_redir_cmd_readonly()
  CheckNotRoot

  " Redirecting to a read-only file
  call writefile([], 'Xfile')
  call setfperm('Xfile', 'r--r--r--')
  call assert_fails('redir! > Xfile', 'E190:')
  call delete('Xfile')
endfunc

" Test for the :filetype command
func Test_filetype_cmd()
  call assert_fails('filetype abc', 'E475:')
endfunc

" Test for the :mode command
func Test_mode_cmd()
  call assert_fails('mode abc', 'E359:')
endfunc

" Test for the :sleep command
func Test_sleep_cmd()
  call assert_fails('sleep x', 'E475:')
endfunc

" Test for the :read command
func Test_read_cmd()
  call writefile(['one'], 'Xfile')
  new
  call assert_fails('read', 'E32:')
  edit Xfile
  read
  call assert_equal(['one', 'one'], getline(1, '$'))
  close!
  new
  read Xfile
  call assert_equal(['', 'one'], getline(1, '$'))
  call deletebufline('', 1, '$')
  call feedkeys("Qr Xfile\<CR>visual\<CR>", 'xt')
  call assert_equal(['one'], getline(1, '$'))
  close!
  call delete('Xfile')
endfunc

" Test for running Ex commands when text is locked.
" <C-\>e in the command line is used to lock the text
func Test_run_excmd_with_text_locked()
  " :quit
  let cmd = ":\<C-\>eexecute('quit')\<CR>\<C-C>"
  call assert_fails("call feedkeys(cmd, 'xt')", 'E565:')

  " :qall
  let cmd = ":\<C-\>eexecute('qall')\<CR>\<C-C>"
  call assert_fails("call feedkeys(cmd, 'xt')", 'E565:')

  " :exit
  let cmd = ":\<C-\>eexecute('exit')\<CR>\<C-C>"
  call assert_fails("call feedkeys(cmd, 'xt')", 'E565:')

  " :close - should be ignored
  new
  let cmd = ":\<C-\>eexecute('close')\<CR>\<C-C>"
  call assert_equal(2, winnr('$'))
  close

  call assert_fails("call feedkeys(\":\<C-R>=execute('bnext')\<CR>\", 'xt')", 'E565:')

  " :tabfirst
  tabnew
  call assert_fails("call feedkeys(\":\<C-R>=execute('tabfirst')\<CR>\", 'xt')", 'E565:')
  tabclose
endfunc

" Test for the :verbose command
func Test_verbose_cmd()
  set verbose=3
  call assert_match('  verbose=1\n\s*Last set from ', execute('verbose set vbs'), "\n")
  call assert_equal(['  verbose=0'], split(execute('0verbose set vbs'), "\n"))
  set verbose=0
  call assert_match('  verbose=4\n\s*Last set from .*\n  verbose=0',
        \ execute("4verbose set verbose | set verbose"))
endfunc

" Test for the :delete command and the related abbreviated commands
func Test_excmd_delete()
  new
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['^Ibar$'], split(execute('dl'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['^Ibar$'], split(execute('dell'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['^Ibar$'], split(execute('delel'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['^Ibar$'], split(execute('deletl'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['^Ibar$'], split(execute('deletel'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['        bar'], split(execute('dp'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['        bar'], split(execute('dep'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['        bar'], split(execute('delp'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['        bar'], split(execute('delep'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['        bar'], split(execute('deletp'), "\n"))
  call setline(1, ['foo', "\tbar"])
  call assert_equal(['        bar'], split(execute('deletep'), "\n"))
  close!
endfunc

" Test for commands that are blocked in a sandbox
func Sandbox_tests()
  call assert_fails("call histadd(':', 'ls')", 'E48:')
  call assert_fails("call mkdir('Xdir')", 'E48:')
  call assert_fails("call rename('a', 'b')", 'E48:')
  call assert_fails("call setbufvar(1, 'myvar', 1)", 'E48:')
  call assert_fails("call settabvar(1, 'myvar', 1)", 'E48:')
  call assert_fails("call settabwinvar(1, 1, 'myvar', 1)", 'E48:')
  call assert_fails("call setwinvar(1, 'myvar', 1)", 'E48:')
  call assert_fails("call timer_start(100, '')", 'E48:')
  if has('channel')
    call assert_fails("call prompt_setcallback(1, '')", 'E48:')
    call assert_fails("call prompt_setinterrupt(1, '')", 'E48:')
    call assert_fails("call prompt_setprompt(1, '')", 'E48:')
  endif
  call assert_fails("let $TESTVAR=1", 'E48:')
  call assert_fails("call feedkeys('ivim')", 'E48:')
  call assert_fails("source! Xfile", 'E48:')
  call assert_fails("call delete('Xfile')", 'E48:')
  call assert_fails("call writefile([], 'Xfile')", 'E48:')
  call assert_fails('!ls', 'E48:')
  " call assert_fails('shell', 'E48:')
  call assert_fails('stop', 'E48:')
  call assert_fails('exe "normal \<C-Z>"', 'E48:')
  " set insertmode
  " call assert_fails('call feedkeys("\<C-Z>", "xt")', 'E48:')
  " set insertmode&
  call assert_fails('suspend', 'E48:')
  call assert_fails('call system("ls")', 'E48:')
  call assert_fails('call systemlist("ls")', 'E48:')
  if has('clientserver')
    call assert_fails('let s=remote_expr("gvim", "2+2")', 'E48:')
    if !has('win32')
      " remote_foreground() doesn't throw an error message on MS-Windows
      call assert_fails('call remote_foreground("gvim")', 'E48:')
    endif
    call assert_fails('let s=remote_peek("gvim")', 'E48:')
    call assert_fails('let s=remote_read("gvim")', 'E48:')
    call assert_fails('let s=remote_send("gvim", "abc")', 'E48:')
    call assert_fails('let s=server2client("gvim", "abc")', 'E48:')
  endif
  if has('terminal')
    call assert_fails('terminal', 'E48:')
    call assert_fails('call term_start("vim")', 'E48:')
    call assert_fails('call term_dumpwrite(1, "Xfile")', 'E48:')
  endif
  if has('channel')
    call assert_fails("call ch_logfile('chlog')", 'E48:')
    call assert_fails("call ch_open('localhost:8765')", 'E48:')
  endif
  if has('job')
    call assert_fails("call job_start('vim')", 'E48:')
  endif
  if has('unix') && has('libcall')
    call assert_fails("echo libcall('libc.so', 'getenv', 'HOME')", 'E48:')
  endif
  if has('unix')
    call assert_fails('cd `pwd`', 'E48:')
  endif
  " some options cannot be changed in a sandbox
  call assert_fails('set exrc', 'E48:')
  call assert_fails('set cdpath', 'E48:')
  if has('xim') && has('gui_gtk')
    call assert_fails('set imstyle', 'E48:')
  endif
endfunc

func Test_sandbox()
  sandbox call Sandbox_tests()
endfunc

func Test_command_not_implemented_E319()
  if !has('mzscheme')
    call assert_fails('mzscheme', 'E319:')
  endif
endfunc

func Test_not_break_expression_register()
  call setreg('=', '1+1')
  if 0
    put =1
  endif
  call assert_equal('1+1', getreg('=', 1))
endfunc

func Test_address_line_overflow()
  if !has('nvim') && v:sizeoflong < 8
    throw 'Skipped: only works with 64 bit long ints'
  endif
  new
  call setline(1, range(100))
  call assert_fails('|.44444444444444444444444', 'E1247:')
  call assert_fails('|.9223372036854775806', 'E1247:')
  call assert_fails('.44444444444444444444444d', 'E1247:')
  call assert_equal(range(100)->map('string(v:val)'), getline(1, '$'))

  $
  yank 77777777777777777777
  call assert_equal("99\n", @")

  bwipe!
endfunc

" This was leaving the cursor in line zero
func Test_using_zero_in_range()
  new
  norm o00
  silent!  0;s/\%')
  bwipe!
endfunc

" Test :write after changing name with :file and loading it with :edit
func Test_write_after_rename()
  call writefile(['text'], 'Xfile')

  enew
  file Xfile
  call assert_fails('write', 'E13: File exists (add ! to override)')

  " works OK after ":edit"
  edit
  write

  call delete('Xfile')
  bwipe!
endfunc

" catch address lines overflow
func Test_ex_address_range_overflow()
  call assert_fails(':--+foobar', 'E492:')
endfunc

func Test_drop_modified_file()
  CheckScreendump
  let lines =<< trim END
  call setline(1, 'The quick brown fox jumped over the lazy dogs')
  END
  call writefile([''], 'Xdrop_modified.txt', 'D')
  call writefile(lines, 'Xtest_drop_modified', 'D')
  let buf = RunVimInTerminal('-S Xtest_drop_modified Xdrop_modified.txt', {'rows': 10,'columns': 40})
  call term_sendkeys(buf, ":drop Xdrop_modified.txt\<CR>")
  call VerifyScreenDump(buf, 'Test_drop_modified_1', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
