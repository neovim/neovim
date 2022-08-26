" Tests for :undo

func Test_ex_undo()
  new ex-undo
  setlocal ul=10
  exe "normal ione\n\<Esc>"
  setlocal ul=10
  exe "normal itwo\n\<Esc>"
  setlocal ul=10
  exe "normal ithree\n\<Esc>"
  call assert_equal(4, line('$'))
  undo
  call assert_equal(3, line('$'))
  undo 1
  call assert_equal(2, line('$'))
  undo 0
  call assert_equal(1, line('$'))
  quit!
endfunc
