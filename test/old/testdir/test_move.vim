" Test the ":move" command.

source check.vim
source screendump.vim

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
  call assert_fails("move -100", 'E16:')
  call assert_fails("move +100", 'E16:')
  call assert_fails('move', 'E16:')
  call assert_fails("move 'r", 'E20:')

  %bwipeout!
endfunc

func Test_move_undo()
  CheckScreendump
  CheckRunVimInTerminal

  let lines =<< trim END
      call setline(1, ['First', 'Second', 'Third', 'Fourth'])
  END
  call writefile(lines, 'Xtest_move_undo.vim', 'D')
  let buf = RunVimInTerminal('-S Xtest_move_undo.vim', #{rows: 10, cols: 60, statusoff: 2})

  call term_sendkeys(buf, "gg:move +1\<CR>")
  call VerifyScreenDump(buf, 'Test_move_undo_1', {})

  " here the display would show the last few lines scrolled down
  call term_sendkeys(buf, "u")
  call term_sendkeys(buf, ":\<Esc>")
  call VerifyScreenDump(buf, 'Test_move_undo_2', {})

  call StopVimInTerminal(buf)
endfunc


" vim: shiftwidth=2 sts=2 expandtab
