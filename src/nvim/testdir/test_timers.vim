" Test for timers

if !has('timers')
  finish
endif

source shared.vim
source term_util.vim
source load.vim

func MyHandler(timer)
  let g:val += 1
endfunc

func MyHandlerWithLists(lists, timer)
  let x = string(a:lists)
endfunc

func Test_oneshot()
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

func Test_repeat_three()
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

func Test_repeat_many()
  call timer_stopall()
  let g:val = 0
  let timer = timer_start(50, 'MyHandler', {'repeat': -1})
  if has('mac')
    sleep 200m
  endif
  sleep 200m
  call timer_stop(timer)
  call assert_inrange((has('mac') ? 1 : 2), LoadAdjust(5), g:val)
endfunc

func Test_with_partial_callback()
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

func Test_retain_partial()
  call timer_start(50, function('MyHandlerWithLists', [['a']]))
  call garbagecollect()
  sleep 100m
endfunc

func Test_info()
  let id = timer_start(1000, 'MyHandler')
  let info = timer_info(id)
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
endfunc

func Test_stopall()
  call timer_stopall()
  let id1 = timer_start(1000, 'MyHandler')
  let id2 = timer_start(2000, 'MyHandler')
  let info = timer_info()
  call assert_equal(2, len(info))

  call timer_stopall()
  let info = timer_info()
  call assert_equal(0, len(info))
endfunc

func Test_paused()
  let g:val = 0

  let id = timer_start(50, 'MyHandler')
  let info = timer_info(id)
  call assert_equal(0, info[0]['paused'])

  call timer_pause(id, 1)
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
endfunc

func StopMyself(timer)
  let g:called += 1
  if g:called == 2
    call timer_stop(a:timer)
  endif
endfunc

func Test_delete_myself()
  let g:called = 0
  let t = timer_start(10, 'StopMyself', {'repeat': -1})
  call WaitForAssert({-> assert_equal(2, g:called)})
  call assert_equal(2, g:called)
  call assert_equal([], timer_info(t))
endfunc

func StopTimer1(timer)
  let g:timer2 = timer_start(10, 'StopTimer2')
  " avoid maxfuncdepth error
  call timer_pause(g:timer1, 1)
  sleep 40m
endfunc

func StopTimer2(timer)
  call timer_stop(g:timer1)
endfunc

func Test_stop_in_callback()
  let g:timer1 = timer_start(10, 'StopTimer1')
  sleep 40m
endfunc

func StopTimerAll(timer)
  call timer_stopall()
endfunc

func Test_stop_all_in_callback()
  call timer_stopall()
  let g:timer1 = timer_start(10, 'StopTimerAll')
  let info = timer_info()
  call assert_equal(1, len(info))
  if has('mac')
    sleep 100m
  endif
  sleep 40m
  let info = timer_info()
  call assert_equal(0, len(info))
endfunc

func FeedkeysCb(timer)
  call feedkeys("hello\<CR>", 'nt')
endfunc

func InputCb(timer)
  call timer_start(10, 'FeedkeysCb')
  let g:val = input('?')
  call Resume()
endfunc

func Test_input_in_timer()
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
  " call test_feedinput("\<C-C>")
  call nvim_input("\<C-C>")
endfunc

func Test_peek_and_get_char()
  if !has('unix') && !has('gui_running')
    return
  endif
  call timer_start(0, 'FeedAndPeek')
  let intr = timer_start(100, 'Interrupt')
  let c = getchar()
  call assert_equal(char2nr('a'), c)
  call timer_stop(intr)
endfunc

func Test_getchar_zero()
  if has('win32') && !has('gui_running')
    " Console: no low-level input
    return
  endif

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

func Test_ex_mode()
  " Function with an empty line.
  func Foo(...)

  endfunc
  let timer = timer_start(40, function('g:Foo'), {'repeat':-1})
  " This used to throw error E749.
  exe "normal Qsleep 100m\rvi\r"
  call timer_stop(timer)
endfunc

func Test_restore_count()
  if !CanRunVimInTerminal()
    return
  endif
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
func Test_nocatch_garbage_collect()
  CheckFunction test_garbagecollect_soon
  CheckFunction test_override
  " 'uptimetime. must be bigger than the timer timeout
  set ut=200
  call test_garbagecollect_soon()
  call test_override('no_wait_return', 0)
  func CauseAnError(id)
    " This will show an error and wait for Enter.
    let a = {'foo', 'bar'}
  endfunc
  func FeedChar(id)
    call feedkeys('x', 't')
  endfunc
  call timer_start(300, 'FeedChar')
  call timer_start(100, 'CauseAnError')
  let x = getchar()

  set ut&
  call test_override('no_wait_return', 1)
  delfunc CauseAnError
  delfunc FeedChar
endfunc

func Test_error_in_timer_callback()
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
  call term_wait(buf, 100)
  call term_sendkeys(buf, "\<CR>")
  call term_wait(buf, 100)
  call assert_equal('run', job_status(job))

  call term_sendkeys(buf, ":qall!\<CR>")
  call WaitFor({-> job_status(job) ==# 'dead'})
  if has('unix')
    call assert_equal('', job_info(job).termsig)
  endif

  call delete('Xtest.vim')
  exe buf .. 'bwipe!'
endfunc

func Test_timer_invalid_callback()
  call assert_fails('call timer_start(0, "0")', 'E921')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
