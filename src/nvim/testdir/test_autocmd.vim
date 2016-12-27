" Tests for autocommands

func Test_vim_did_enter()
  call assert_false(v:vim_did_enter)

  " This script will never reach the main loop, can't check if v:vim_did_enter
  " becomes one.
endfunc

if has('timers')
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

  func Test_cursorhold_insert_ctrl_x()
    let g:triggered = 0
    au CursorHoldI * let g:triggered += 1
    set updatetime=20
    call timer_start(100, 'ExitInsertMode')
    " CursorHoldI does not trigger after CTRL-X
    call feedkeys("a\<C-X>", 'x!')
    call assert_equal(0, g:triggered)
  endfunc
endif

function Test_bufunload()
  augroup test_bufunload_group
    autocmd!
    autocmd BufUnload * call add(s:li, "bufunload")
    autocmd BufDelete * call add(s:li, "bufdelete")
    autocmd BufWipeout * call add(s:li, "bufwipeout")
  augroup END

  let s:li=[]
  new
  setlocal bufhidden=
  bunload
  call assert_equal(["bufunload", "bufdelete"], s:li)

  let s:li=[]
  new
  setlocal bufhidden=delete
  bunload
  call assert_equal(["bufunload", "bufdelete"], s:li)

  let s:li=[]
  new
  setlocal bufhidden=unload
  bwipeout
  call assert_equal(["bufunload", "bufdelete", "bufwipeout"], s:li)

  augroup! test_bufunload_group
endfunc
