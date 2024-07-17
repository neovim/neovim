" Test for timers

source check.vim
CheckFeature timers

source screendump.vim
source shared.vim
source term_util.vim
source load.vim

func SetUp()
  call timer_stopall()
endfunc

func MyHandler(timer)
  let g:val += 1
endfunc

func MyHandlerWithLists(lists, timer)
  let x = string(a:lists)
endfunc

func Test_timer_oneshot()
  let g:test_is_flaky = 1
  let g:val = 0
  let timer = timer_start(50, 'MyHandler')
  let slept = WaitFor('g:val == 1')
  call assert_equal(1, g:val)
  if has('reltime')
    call assert_inrange(40, LoadAdjust(120), slept)
  else
    call assert_inrange(20, 120, slept)
  endif
endfunc

func Test_timer_repeat_three()
  let g:test_is_flaky = 1
  let g:val = 0
  let timer = timer_start(50, 'MyHandler', {'repeat': 3})
  let slept = WaitFor('g:val == 3')
  call assert_equal(3, g:val)
  if has('reltime')
    call assert_inrange(120, LoadAdjust(250), slept)
  else
    call assert_inrange(80, 200, slept)
  endif
endfunc

func Test_timer_repeat_many()
  let g:test_is_flaky = 1
  let g:val = 0
  let timer = timer_start(50, 'MyHandler', {'repeat': -1})
  sleep 200m
  call timer_stop(timer)
  call assert_inrange((has('mac') ? 1 : 2), LoadAdjust(5), g:val)
endfunc

func Test_timer_with_partial_callback()
  let g:test_is_flaky = 1
  let g:val = 0
  let meow = {'one': 1}
  function meow.bite(...)
    let g:val += self.one
  endfunction

  call timer_start(50, meow.bite)
  let slept = WaitFor('g:val == 1')
  call assert_equal(1, g:val)
  if has('reltime')
    call assert_inrange(40, LoadAdjust(130), slept)
  else
    call assert_inrange(20, 100, slept)
  endif
endfunc

func Test_timer_retain_partial()
  call timer_start(50, function('MyHandlerWithLists', [['a']]))
  call test_garbagecollect_now()
  sleep 100m
endfunc

func Test_timer_info()
  let id = timer_start(1000, 'MyHandler')
  let info = id->timer_info()
  call assert_equal(id, info[0]['id'])
  call assert_equal(1000, info[0]['time'])
  call assert_equal("function('MyHandler')", string(info[0]['callback']))

  let found = 0
  for info in timer_info()
    if info['id'] == id
      let found += 1
    endif
  endfor
  call assert_equal(1, found)

  call timer_stop(id)
  call assert_equal([], timer_info(id))

  call assert_fails('call timer_info("abc")', 'E1210:')

  " check repeat count inside the callback
  let g:timer_repeat = []
  let tid = timer_start(10, {tid -> execute("call add(g:timer_repeat, timer_info(tid)[0].repeat)")}, #{repeat: 3})
  call WaitForAssert({-> assert_equal([2, 1, 0], g:timer_repeat)})
  unlet g:timer_repeat
endfunc

func Test_timer_stopall()
  let id1 = timer_start(1000, 'MyHandler')
  let id2 = timer_start(2000, 'MyHandler')
  let info = timer_info()
  call assert_equal(2, len(info))

  call timer_stopall()
  let info = timer_info()
  call assert_equal(0, len(info))
endfunc

func Test_timer_paused()
  let g:test_is_flaky = 1
  let g:val = 0

  let id = timer_start(50, 'MyHandler')
  let info = timer_info(id)
  call assert_equal(0, info[0]['paused'])

  eval id->timer_pause(1)
  let info = timer_info(id)
  call assert_equal(1, info[0]['paused'])
  sleep 200m
  call assert_equal(0, g:val)

  call timer_pause(id, 0)
  let info = timer_info(id)
  call assert_equal(0, info[0]['paused'])

  let slept = WaitFor('g:val == 1')
  call assert_equal(1, g:val)
  if has('reltime')
    call assert_inrange(0, LoadAdjust(140), slept)
  else
    call assert_inrange(0, 10, slept)
  endif

  call assert_fails('call timer_pause("abc", 1)', 'E39:')
endfunc

func StopMyself(timer)
  let g:called += 1
  if g:called == 2
    call timer_stop(a:timer)
  endif
endfunc

func Test_timer_delete_myself()
  let g:called = 0
  let t = timer_start(10, 'StopMyself', {'repeat': -1})
  call WaitForAssert({-> assert_equal(2, g:called)})
  call assert_equal(2, g:called)
  call assert_equal([], timer_info(t))
endfunc

func StopTimer1(timer)
  let g:timer2 = 10->timer_start('StopTimer2')
  " avoid maxfuncdepth error
  call timer_pause(g:timer1, 1)
  sleep 20m
endfunc

func StopTimer2(timer)
  call timer_stop(g:timer1)
endfunc

func Test_timer_stop_in_callback()
  let g:test_is_flaky = 1
  call assert_equal(0, len(timer_info()))
  let g:timer1 = timer_start(10, 'StopTimer1')
  let slept = 0
  for i in range(10)
    if len(timer_info()) == 0
      break
    endif
    sleep 10m
    let slept += 10
  endfor
  " This should take only 30 msec, but on Mac it's often longer
  call assert_inrange(0, 50, slept)
endfunc

func StopTimerAll(timer)
  call timer_stopall()
endfunc

func Test_timer_stop_all_in_callback()
  let g:test_is_flaky = 1
  call assert_equal(0, len(timer_info()))
  call timer_start(10, 'StopTimerAll')
  call assert_equal(1, len(timer_info()))
  let slept = 0
  for i in range(10)
    if len(timer_info()) == 0
      break
    endif
    sleep 10m
    let slept += 10
  endfor
  call assert_inrange(0, 30, slept)
endfunc

func FeedkeysCb(timer)
  call feedkeys("hello\<CR>", 'nt')
endfunc

func InputCb(timer)
  call timer_start(10, 'FeedkeysCb')
  let g:val = input('?')
  call Resume()
endfunc

func Test_timer_input_in_timer()
  let g:val = ''
  call timer_start(10, 'InputCb')
  call Standby(1000)
  call assert_equal('hello', g:val)
endfunc

func FuncWithError(timer)
  let g:call_count += 1
  if g:call_count == 4
    return
  endif
  doesnotexist
endfunc

func Test_timer_errors()
  let g:call_count = 0
  let timer = timer_start(10, 'FuncWithError', {'repeat': -1})
  " Timer will be stopped after failing 3 out of 3 times.
  call WaitForAssert({-> assert_equal(3, g:call_count)})
  sleep 50m
  call assert_equal(3, g:call_count)

  call assert_fails('call timer_start(100, "MyHandler", "abc")', 'E1206:')
  call assert_fails('call timer_start(100, [])', 'E921:')
  call assert_fails('call timer_stop("abc")', 'E1210:')
endfunc

func FuncWithCaughtError(timer)
  let g:call_count += 1
  try
    doesnotexist
  catch
    " nop
  endtry
endfunc

func Test_timer_catch_error()
  let g:call_count = 0
  let timer = timer_start(10, 'FuncWithCaughtError', {'repeat': 4})
  " Timer will not be stopped.
  call WaitForAssert({-> assert_equal(4, g:call_count)})
  sleep 50m
  call assert_equal(4, g:call_count)
endfunc

func FeedAndPeek(timer)
  " call test_feedinput('a')
  call nvim_input('a')
  call getchar(1)
endfunc

func Interrupt(timer)
  " eval "\<C-C>"->test_feedinput()
  call nvim_input("\<C-C>")
endfunc

func Test_timer_peek_and_get_char()
  if !has('unix') && !has('gui_running')
    throw 'Skipped: cannot feed low-level input'
  endif

  call timer_start(0, 'FeedAndPeek')
  let intr = timer_start(100, 'Interrupt')
  let c = getchar()
  call assert_equal(char2nr('a'), c)
  eval intr->timer_stop()
endfunc

func Test_timer_getchar_zero()
  if has('win32') && !has('gui_running')
    throw 'Skipped: cannot feed low-level input'
  endif
  CheckFunction reltimefloat

  " Measure the elapsed time to avoid a hang when it fails.
  let start = reltime()
  let id = timer_start(20, {-> feedkeys('x', 'L')})
  let c = 0
  while c == 0 && reltimefloat(reltime(start)) < 0.2
    let c = getchar(0)
    sleep 10m
  endwhile
  call assert_equal('x', nr2char(c))
  call timer_stop(id)
endfunc

func Test_timer_ex_mode()
  " Function with an empty line.
  func Foo(...)

  endfunc
  let timer = timer_start(40, function('g:Foo'), {'repeat':-1})
  " This used to throw error E749.
  exe "normal Qsleep 100m\rvi\r"
  call timer_stop(timer)
endfunc

func Test_timer_restore_count()
  CheckRunVimInTerminal
  " Check that v:count is saved and restored, not changed by a timer.
  call writefile([
        \ 'nnoremap <expr><silent> L v:count ? v:count . "l" : "l"',
        \ 'func Doit(id)',
        \ '  normal 3j',
        \ 'endfunc',
        \ 'call timer_start(100, "Doit")',
	\ ], 'Xtrcscript')
  call writefile([
        \ '1-1234',
        \ '2-1234',
        \ '3-1234',
	\ ], 'Xtrctext')
  let buf = RunVimInTerminal('-S Xtrcscript Xtrctext', {})

  " Wait for the timer to move the cursor to the third line.
  call WaitForAssert({-> assert_equal(3, term_getcursor(buf)[0])})
  call assert_equal(1, term_getcursor(buf)[1])
  " Now check that v:count has not been set to 3
  call term_sendkeys(buf, 'L')
  call WaitForAssert({-> assert_equal(2, term_getcursor(buf)[1])})

  call StopVimInTerminal(buf)
  call delete('Xtrcscript')
  call delete('Xtrctext')
endfunc

" Test that the garbage collector isn't triggered if a timer callback invokes
" vgetc().
func Test_nocatch_timer_garbage_collect()
  " FIXME: why does this fail only on MacOS M1?
  try
    CheckNotMacM1
    throw 'Skipped: Nvim does not support test_garbagecollect_soon(), test_override()'
  catch /Skipped/
    let g:skipped_reason = v:exception
    return
  endtry

  " 'uptimetime. must be bigger than the timer timeout
  set ut=200
  call test_garbagecollect_soon()
  call test_override('no_wait_return', 0)
  func CauseAnError(id)
    " This will show an error and wait for Enter.
    let a = {'foo', 'bar'}
  endfunc
  func FeedChar(id)
    call feedkeys(":\<CR>", 't')
  endfunc
  call timer_start(300, 'FeedChar')
  call timer_start(100, 'CauseAnError')
  let x = getchar()   " wait for error in timer
  let x = getchar(0)  " read any remaining chars
  let x = getchar(0)

  set ut&
  call test_override('no_wait_return', 1)
  delfunc CauseAnError
  delfunc FeedChar
endfunc

func Test_timer_error_in_timer_callback()
  if !has('terminal') || (has('win32') && has('gui_running'))
    throw 'Skipped: cannot run Vim in a terminal window'
  endif

  let lines =<< trim [CODE]
  func Func(timer)
    " fail to create list
    let x = [
  endfunc
  set updatetime=50
  call timer_start(1, 'Func')
  [CODE]
  call writefile(lines, 'Xtest.vim')

  let buf = term_start(GetVimCommandCleanTerm() .. ' -S Xtest.vim', {'term_rows': 8})
  let job = term_getjob(buf)
  call WaitForAssert({-> assert_notequal('', term_getline(buf, 8))})

  " GC must not run during timer callback, which can make Vim crash.
  call TermWait(buf, 50)
  call term_sendkeys(buf, "\<CR>")
  call TermWait(buf, 50)
  call assert_equal('run', job_status(job))

  call term_sendkeys(buf, ":qall!\<CR>")
  call WaitFor({-> job_status(job) ==# 'dead'})
  if has('unix')
    call assert_equal('', job_info(job).termsig)
  endif

  call delete('Xtest.vim')
  exe buf .. 'bwipe!'
endfunc

" Test for garbage collection when a timer is still running
func Test_timer_garbage_collect()
  let timer = timer_start(1000, function('MyHandler'), {'repeat' : 10})
  call test_garbagecollect_now()
  let l = timer_info(timer)
  call assert_equal(function('MyHandler'), l[0].callback)
  call timer_stop(timer)
endfunc

func Test_timer_invalid_callback()
  call assert_fails('call timer_start(0, "0")', 'E921')
endfunc

func Test_timer_changing_function_list()
  CheckRunVimInTerminal

  " Create a large number of functions.  Should get the "more" prompt.
  " The typing "G" triggers the timer, which changes the function table.
  let lines =<< trim END
    for func in map(range(1,99), "'Func' .. v:val")
      exe "func " .. func .. "()"
      endfunc
    endfor
    au CmdlineLeave : call timer_start(0, {-> 0})
  END
  call writefile(lines, 'XTest_timerchange')
  let buf = RunVimInTerminal('-S XTest_timerchange', #{rows: 10})
  call term_sendkeys(buf, ":fu\<CR>")
  call WaitForAssert({-> assert_match('-- More --', term_getline(buf, 10))})
  call term_sendkeys(buf, "G")
  call WaitForAssert({-> assert_match('E454', term_getline(buf, 9))})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
  call delete('XTest_timerchange')
endfunc

func Test_timer_using_win_execute_undo_sync()
  let bufnr1 = bufnr()
  new
  let g:bufnr2 = bufnr()
  let g:winid = win_getid()
  exe "buffer " .. bufnr1
  wincmd w
  call setline(1, ['test'])
  autocmd InsertEnter * call timer_start(100, { -> win_execute(g:winid, 'buffer ' .. g:bufnr2) })
  call timer_start(200, { -> feedkeys("\<CR>bbbb\<Esc>") })
  call feedkeys("Oaaaa", 'x!t')
  " will hang here until the second timer fires
  call assert_equal(['aaaa', 'bbbb', 'test'], getline(1, '$'))
  undo
  call assert_equal(['test'], getline(1, '$'))

  bwipe!
  bwipe!
  unlet g:winid
  unlet g:bufnr2
  au! InsertEnter
endfunc

" vim: shiftwidth=2 sts=2 expandtab
