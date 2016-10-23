" Tests for expressions using utf-8.
if !has('multi_byte')
  finish
endif
scriptencoding utf-8

func Test_strgetchar()
  call assert_equal(char2nr('a'), strgetchar('axb', 0))
  call assert_equal(char2nr('x'), strgetchar('axb', 1))
  call assert_equal(char2nr('b'), strgetchar('axb', 2))

  call assert_equal(-1, strgetchar('axb', -1))
  call assert_equal(-1, strgetchar('axb', 3))
  call assert_equal(-1, strgetchar('', 0))

  call assert_equal(char2nr('a'), strgetchar('àxb', 0))
  call assert_equal(char2nr('̀'), strgetchar('àxb', 1))
  call assert_equal(char2nr('x'), strgetchar('àxb', 2))

  call assert_equal(char2nr('あ'), strgetchar('あaい', 0))
  call assert_equal(char2nr('a'), strgetchar('あaい', 1))
  call assert_equal(char2nr('い'), strgetchar('あaい', 2))
endfunc

func Test_strcharpart()
  call assert_equal('áxb', strcharpart('áxb', 0))
  call assert_equal('á', strcharpart('áxb', 0, 1))
  call assert_equal('x', strcharpart('áxb', 1, 1))

  call assert_equal('a', strcharpart('àxb', 0, 1))
  call assert_equal('̀', strcharpart('àxb', 1, 1))
  call assert_equal('x', strcharpart('àxb', 2, 1))
endfunc
