" Test for joining lines.

func Test_join_with_count()
  new
  call setline(1, ['one', 'two', 'three', 'four'])
  normal J
  call assert_equal('one two', getline(1))
  %del
  call setline(1, ['one', 'two', 'three', 'four'])
  normal 10J
  call assert_equal('one two three four', getline(1))

  call setline(1, ['one', '', 'two'])
  normal J
  call assert_equal('one', getline(1))

  call setline(1, ['one', ' ', 'two'])
  normal J
  call assert_equal('one', getline(1))

  call setline(1, ['one', '', '', 'two'])
  normal JJ
  call assert_equal('one', getline(1))

  call setline(1, ['one', ' ', ' ', 'two'])
  normal JJ
  call assert_equal('one', getline(1))

  call setline(1, ['one', '', '', 'two'])
  normal 2J
  call assert_equal('one', getline(1))

  quit!
endfunc

" Tests for setting the '[,'] marks when joining lines.
func Test_join_marks()
  enew
  call append(0, [
	      \ "\t\tO sodales, ludite, vos qui",
	      \ "attamen consulite per voster honur. Tua pulchra " .
	      \ "facies me fay planszer milies",
	      \ "",
	      \ "This line.",
	      \ "Should be joined with the next line",
	      \ "and with this line"])

  normal gg0gqj
  call assert_equal([0, 1, 1, 0], getpos("'["))
  call assert_equal([0, 2, 1, 0], getpos("']"))

  /^This line/;'}-join
  call assert_equal([0, 4, 11, 0], getpos("'["))
  call assert_equal([0, 4, 67, 0], getpos("']"))
  enew!
endfunc
