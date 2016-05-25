" Test for timers

if !has('timers')
  finish
endif

func MyHandler(timer)
  let s:val += 1
endfunc

func Test_oneshot()
  let s:val = 0
  let timer = timer_start(50, 'MyHandler')
  sleep 200m
  call assert_equal(1, s:val)
endfunc

func Test_repeat_three()
  let s:val = 0
  let timer = timer_start(50, 'MyHandler', {'repeat': 3})
  sleep 500m
  call assert_equal(3, s:val)
endfunc

func Test_repeat_many()
  let s:val = 0
  let timer = timer_start(50, 'MyHandler', {'repeat': -1})
  sleep 200m
  call timer_stop(timer)
  call assert_true(s:val > 1)
  call assert_true(s:val < 5)
endfunc
