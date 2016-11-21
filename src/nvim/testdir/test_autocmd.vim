" Tests for autocommands

func Test_vim_did_enter()
  call assert_false(v:vim_did_enter)

  " This script will never reach the main loop, can't check if v:vim_did_enter
  " becomes one.
endfunc

if !has('timers')
  finish
endif

func ExitInsertMode(id)
  call feedkeys("\<Esc>")
endfunc

func Test_cursorhold_insert()
  let g:triggered = 0
  au CursorHoldI * let g:triggered += 1
  set updatetime=20
  call timer_start(100, 'ExitInsertMode')
  call feedkeys('a', 'x!')
  call assert_equal(1, g:triggered)
endfunc
