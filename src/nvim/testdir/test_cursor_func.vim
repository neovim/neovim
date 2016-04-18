" Tests for cursor().

func Test_wrong_arguments()
  try
    call cursor(1. 3)
    " not reached
    call assert_false(1)
  catch
    call assert_exception('E474:')
  endtry
endfunc

func Test_move_cursor()
  new
  call setline(1, ['aaa', 'bbb', 'ccc', 'ddd'])

  call cursor([1, 1, 0, 1])
  call assert_equal([1, 1, 0, 1], getcurpos()[1:])
  call cursor([4, 3, 0, 3])
  call assert_equal([4, 3, 0, 3], getcurpos()[1:])

  call cursor(2, 2)
  call assert_equal([2, 2, 0, 2], getcurpos()[1:])
  " line number zero keeps the line number
  call cursor(0, 1)
  call assert_equal([2, 1, 0, 1], getcurpos()[1:])
  " col number zero keeps the column
  call cursor(3, 0)
  call assert_equal([3, 1, 0, 1], getcurpos()[1:])
  " below last line goes to last line
  call cursor(9, 1)
  call assert_equal([4, 1, 0, 1], getcurpos()[1:])

  quit!
endfunc

" Very short version of what matchparen does.
function s:Highlight_Matching_Pair()
  let save_cursor = getcurpos()
  call setpos('.', save_cursor)
endfunc

func Test_curswant_with_autocommand()
  new
  call setline(1, ['func()', '{', '}', '----'])
  autocmd! CursorMovedI * call s:Highlight_Matching_Pair()
  call disable_char_avail_for_testing(1)
  exe "normal! 3Ga\<Down>X\<Esc>"
  call disable_char_avail_for_testing(0)
  call assert_equal('-X---', getline(4))
  autocmd! CursorMovedI *
  quit!
endfunc

