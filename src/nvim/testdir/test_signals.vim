" Test signal handling.

if !has('unix')
  finish
endif

source shared.vim

" Test signal WINCH (window resize signal)
func Test_signal_WINCH()
  throw 'skipped: Nvim cannot avoid terminal resize'
  let signals = system('kill -l')
  if signals !~ '\<WINCH\>'
    " signal WINCH is not available, skip the test.
    return
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

  exe 'set lines=' . new_lines
  exe 'set columns=' . new_columns
  call assert_equal(new_lines, &lines)
  call assert_equal(new_columns, &columns)

  " Send signal and wait for signal to be processed.
  " 'lines' and 'columns' should have been restored
  " after handing signal WINCH.
  exe 'silent !kill -s WINCH ' . getpid()
  call WaitForAssert({-> assert_equal(old_lines, &lines)})
  call assert_equal(old_columns, &columns)

  if old_WS != ''
    let &t_WS = old_WS
  endif
endfunc
