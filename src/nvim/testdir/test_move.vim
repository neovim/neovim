" Test the ":move" command.

func Test_move()
  enew!
  call append(0, ['line 1', 'line 2', 'line 3'])
  g /^$/ delete _
  set nomodified

  move .
  call assert_equal(['line 1', 'line 2', 'line 3'], getline(1, 3))
  call assert_false(&modified)

  1,2move 0
  call assert_equal(['line 1', 'line 2', 'line 3'], getline(1, 3))
  call assert_false(&modified)

  1,3move 3
  call assert_equal(['line 1', 'line 2', 'line 3'], getline(1, 3))
  call assert_false(&modified)

  1move 2
  call assert_equal(['line 2', 'line 1', 'line 3'], getline(1, 3))
  call assert_true(&modified)
  set nomodified

  3move 0
  call assert_equal(['line 3', 'line 2', 'line 1'], getline(1, 3))
  call assert_true(&modified)
  set nomodified

  2,3move 0
  call assert_equal(['line 2', 'line 1', 'line 3'], getline(1, 3))
  call assert_true(&modified)
  set nomodified

  call assert_fails('1,2move 1', 'E134')
  call assert_fails('2,3move 2', 'E134')

  %bwipeout!
endfunc
