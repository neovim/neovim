" Test using the window ID.

func Test_win_getid()
  edit one
  let id1 = win_getid()
  split two
  let id2 = win_getid()
  split three
  let id3 = win_getid()
  tabnew
  edit four
  let id4 = win_getid()
  split five
  let id5 = win_getid()
  tabnext

  wincmd w
  call assert_equal("two", expand("%"))
  call assert_equal(id2, win_getid())
  let nr2 = winnr()
  wincmd w
  call assert_equal("one", expand("%"))
  call assert_equal(id1, win_getid())
  let nr1 = winnr()
  wincmd w
  call assert_equal("three", expand("%"))
  call assert_equal(id3, win_getid())
  let nr3 = winnr()
  tabnext
  call assert_equal("five", expand("%"))
  call assert_equal(id5, win_getid())
  let nr5 = winnr()
  wincmd w
  call assert_equal("four", expand("%"))
  call assert_equal(id4, win_getid())
  let nr4 = winnr()
  tabnext

  exe nr1 . "wincmd w"
  call assert_equal(id1, win_getid())
  exe nr2 . "wincmd w"
  call assert_equal(id2, win_getid())
  exe nr3 . "wincmd w"
  call assert_equal(id3, win_getid())
  tabnext
  exe nr4 . "wincmd w"
  call assert_equal(id4, win_getid())
  exe nr5 . "wincmd w"
  call assert_equal(id5, win_getid())

  call win_gotoid(id2)
  call assert_equal("two", expand("%"))
  call win_gotoid(id4)
  call assert_equal("four", expand("%"))
  call win_gotoid(id1)
  call assert_equal("one", expand("%"))
  call win_gotoid(id5)
  call assert_equal("five", expand("%"))

  call assert_equal(0, win_id2win(9999))
  call assert_equal(nr5, win_id2win(id5))
  call assert_equal(0, win_id2win(id1))
  tabnext
  call assert_equal(nr1, win_id2win(id1))

  call assert_equal([0, 0], win_id2tabwin(9999))
  call assert_equal([1, nr2], win_id2tabwin(id2))
  call assert_equal([2, nr4], win_id2tabwin(id4))

  only!
endfunc
