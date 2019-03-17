" Test for timers

if !has('timers')
  finish
endif

source shared.vim
source load.vim

func MyHandler(timer)
  let g:val += 1
endfunc

func MyHandlerWithLists(lists, timer)
  let x = string(a:lists)
endfunc

func s:assert_inrange(lower, upper, actual)
  return assert_inrange(a:lower, LoadAdjust(a:upper), a:actual)
endfunc

func Test_oneshot()
  let g:val = 0
  let timer = timer_start(50, 'MyHandler')
  let slept = WaitFor('g:val == 1')
  call assert_equal(1, g:val)
  if has('reltime')
    call s:assert_inrange(40, 120, slept)
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
    call s:assert_inrange(120, 250, slept)
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
  call s:assert_inrange((has('mac') ? 1 : 2), 4, g:val)
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
    call s:assert_inrange(40, 130, slept)
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
    call s:assert_inrange(0, 140, slept)
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
  call WaitFor('g:called == 2')
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
  call WaitFor('g:call_count == 4')
  sleep 50m
  call assert_equal(4, g:call_count)
endfunc

func FeedAndPeek(timer)
  call test_feedinput('a')
  call getchar(1)
endfunc

func Interrupt(timer)
  call test_feedinput("\<C-C>")
endfunc

func Test_peek_and_get_char()
  throw 'skipped: Nvim does not support test_feedinput()'
  if !has('unix') && !has('gui_running')
    return
  endif
  call timer_start(0, 'FeedAndPeek')
  let intr = timer_start(100, 'Interrupt')
  let c = getchar()
  call assert_equal(char2nr('a'), c)
  call timer_stop(intr)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
