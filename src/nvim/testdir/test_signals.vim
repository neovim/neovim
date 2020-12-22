" Test signal handling.

if !has('unix')
  finish
endif

source shared.vim

" Check whether a signal is available on this system.
func HasSignal(signal)
  let signals = system('kill -l')
  return signals =~# '\<' .. a:signal .. '\>'
endfunc

" Test signal WINCH (window resize signal)
func Test_signal_WINCH()
  throw 'skipped: Nvim cannot avoid terminal resize'
  if has('gui_running') || !HasSignal('WINCH')
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
    return
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
