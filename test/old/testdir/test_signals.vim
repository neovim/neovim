" Test signal handling.

source check.vim
source term_util.vim

CheckUnix

source shared.vim

" Check whether a signal is available on this system.
func HasSignal(signal)
  let signals = system('kill -l')
  return signals =~# '\<' .. a:signal .. '\>'
endfunc

" Test signal WINCH (window resize signal)
func Test_signal_WINCH()
  throw 'skipped: Nvim cannot avoid terminal resize'
  CheckNotGui
  if !HasSignal('WINCH')
    throw 'Skipped: WINCH signal not supported'
  endif

  " We do not actually want to change the size of the terminal.
  let old_WS = ''
  if exists('&t_WS')
    let old_WS = &t_WS
    let &t_WS = ''
  endif

  let old_lines = &lines
  let old_columns = &columns
  let new_lines = &lines - 2
  let new_columns = &columns - 2

  exe 'set lines=' .. new_lines
  exe 'set columns=' .. new_columns
  call assert_equal(new_lines, &lines)
  call assert_equal(new_columns, &columns)

  " Send signal and wait for signal to be processed.
  " 'lines' and 'columns' should have been restored
  " after handing signal WINCH.
  exe 'silent !kill -s WINCH ' .. getpid()
  call WaitForAssert({-> assert_equal(old_lines, &lines)})
  call assert_equal(old_columns, &columns)

  if old_WS != ''
    let &t_WS = old_WS
  endif
endfunc

" Test signal PWR, which should update the swap file.
func Test_signal_PWR()
  if !HasSignal('PWR')
    throw 'Skipped: PWR signal not supported'
  endif

  " Set a very large 'updatetime' and 'updatecount', so that we can be sure
  " that swap file is updated as a result of sending PWR signal, and not
  " because of exceeding 'updatetime' or 'updatecount' when changing buffer.
  set updatetime=100000 updatecount=100000
  new Xtest_signal_PWR
  let swap_name = swapname('%')
  call setline(1, '123')
  preserve
  let swap_content = readfile(swap_name, 'b')

  " Update the buffer and check that the swap file is not yet updated,
  " since we set 'updatetime' and 'updatecount' to large values.
  call setline(1, 'abc')
  call assert_equal(swap_content, readfile(swap_name, 'b'))

  " Sending PWR signal should update the swap file.
  exe 'silent !kill -s PWR ' .. getpid()
  call WaitForAssert({-> assert_notequal(swap_content, readfile(swap_name, 'b'))})

  bwipe!
  set updatetime& updatecount&
endfunc

" Test signal INT. Handler sets got_int. It should be like typing CTRL-C.
func Test_signal_INT()
  CheckRunVimInTerminal
  if !HasSignal('INT')
    throw 'Skipped: INT signal not supported'
  endif

  let buf = RunVimInTerminal('', {'rows': 6})
  let pid_vim = term_getjob(buf)->job_info().process

  " Check that an endless loop in Vim is interrupted by signal INT.
  call term_sendkeys(buf, ":call setline(1, 'running')\n")
  call term_sendkeys(buf, ":while 1 | endwhile\n")
  call WaitForAssert({-> assert_equal(':while 1 | endwhile', term_getline(buf, 6))})
  exe 'silent !kill -s INT ' .. pid_vim
  sleep 50m
  call term_sendkeys(buf, ":call setline(1, 'INTERRUPTED')\n")
  call WaitForAssert({-> assert_equal('INTERRUPTED', term_getline(buf, 1))})

  call StopVimInTerminal(buf)
endfunc

" Test signal TSTP. Handler sets got_tstp.
func Test_signal_TSTP()
  CheckRunVimInTerminal
  if !HasSignal('TSTP')
    throw 'Skipped: TSTP signal not supported'
  endif

  " If test fails once, it can leave temporary files and trying to rerun
  " the test would then fail again if they are not deleted first.
  call delete('.Xsig_TERM.swp')
  call delete('XsetupAucmd')
  call delete('XautoOut1')
  call delete('XautoOut2')
  let lines =<< trim END
    au VimSuspend * call writefile(["VimSuspend triggered"], "XautoOut1", "as")
    au VimResume * call writefile(["VimResume triggered"], "XautoOut2", "as")
  END
  call writefile(lines, 'XsetupAucmd')

  let buf = RunVimInTerminal('-S XsetupAucmd Xsig_TERM', {'rows': 6})
  let pid_vim = term_getjob(buf)->job_info().process

  call term_sendkeys(buf, ":call setline(1, 'foo')\n")
  call WaitForAssert({-> assert_equal('foo', term_getline(buf, 1))})

  call assert_false(filereadable('Xsig_TERM'))

  " After TSTP the file is not saved (same function as ^Z)
  exe 'silent !kill -s TSTP ' .. pid_vim
  call WaitForAssert({-> assert_true(filereadable('.Xsig_TERM.swp'))})
  sleep 100m

  " We resume after the suspend.  Sleep a bit for the signal to take effect,
  " also when running under valgrind. 
  exe 'silent !kill -s CONT ' .. pid_vim
  call WaitForAssert({-> assert_true(filereadable('XautoOut2'))})
  sleep 10m

  call StopVimInTerminal(buf)

  let result = readfile('XautoOut1')
  call assert_equal(["VimSuspend triggered"], result)
  let result = readfile('XautoOut2')
  call assert_equal(["VimResume triggered"], result)

  %bwipe!
  call delete('.Xsig_TERM.swp')
  call delete('XsetupAucmd')
  call delete('XautoOut1')
  call delete('XautoOut2')
endfunc

" Test a deadly signal.
"
" There are several deadly signals: SISEGV, SIBUS, SIGTERM...
" Test uses signal SIGTERM as it does not create a core
" dump file unlike SIGSEGV, SIGBUS, etc. See "man 7 signals.
"
" Vim should exit with a deadly signal and unsaved changes
" should be recoverable from the swap file preserved as a
" result of the deadly signal handler.
func Test_deadly_signal_TERM()
  if !HasSignal('TERM')
    throw 'Skipped: TERM signal not supported'
  endif
  CheckRunVimInTerminal

  " If test fails once, it can leave temporary files and trying to rerun
  " the test would then fail again if they are not deleted first.
  call delete('.Xsig_TERM.swp')
  call delete('XsetupAucmd')
  call delete('XautoOut')
  let lines =<< trim END
    au VimLeave * call writefile(["VimLeave triggered"], "XautoOut", "as")
    au VimLeavePre * call writefile(["VimLeavePre triggered"], "XautoOut", "as")
  END
  call writefile(lines, 'XsetupAucmd')

  let buf = RunVimInTerminal('-S XsetupAucmd Xsig_TERM', {'rows': 6})
  let pid_vim = term_getjob(buf)->job_info().process

  call term_sendkeys(buf, ":call setline(1, 'foo')\n")
  call WaitForAssert({-> assert_equal('foo', term_getline(buf, 1))})

  call assert_false(filereadable('Xsig_TERM'))
  exe 'silent !kill -s TERM '  .. pid_vim
  call WaitForAssert({-> assert_true(filereadable('.Xsig_TERM.swp'))})

  " Don't call StopVimInTerminal() as it expects job to be still running.
  call WaitForAssert({-> assert_equal("finished", term_getstatus(buf))})

  new
  silent recover .Xsig_TERM.swp
  call assert_equal(['foo'], getline(1, '$'))

  let result = readfile('XautoOut')
  call assert_equal(["VimLeavePre triggered", "VimLeave triggered"], result)

  %bwipe!
  call delete('.Xsig_TERM.swp')
  call delete('XsetupAucmd')
  call delete('XautoOut')
endfunc

" vim: ts=8 sw=2 sts=2 tw=80 fdm=marker
