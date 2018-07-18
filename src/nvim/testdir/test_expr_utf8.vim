" Tests for expressions using utf-8.
if !has('multi_byte')
  finish
endif

func Test_strgetchar()
  call assert_equal(char2nr('á'), strgetchar('áxb', 0))
  call assert_equal(char2nr('x'), strgetchar('áxb', 1))

  call assert_equal(char2nr('a'), strgetchar('àxb', 0))
  call assert_equal(char2nr('̀'), strgetchar('àxb', 1))
  call assert_equal(char2nr('x'), strgetchar('àxb', 2))

  call assert_equal(char2nr('あ'), strgetchar('あaい', 0))
  call assert_equal(char2nr('a'), strgetchar('あaい', 1))
  call assert_equal(char2nr('い'), strgetchar('あaい', 2))
endfunc

func Test_strcharpart()
  call assert_equal('áxb', strcharpart('áxb', 0))
  call assert_equal('á', strcharpart('áxb', 0, 1))
  call assert_equal('x', strcharpart('áxb', 1, 1))

  call assert_equal('いうeお', strcharpart('あいうeお', 1))
  call assert_equal('い', strcharpart('あいうeお', 1, 1))
  call assert_equal('いう', strcharpart('あいうeお', 1, 2))
  call assert_equal('いうe', strcharpart('あいうeお', 1, 3))
  call assert_equal('いうeお', strcharpart('あいうeお', 1, 4))
  call assert_equal('eお', strcharpart('あいうeお', 3))
  call assert_equal('e', strcharpart('あいうeお', 3, 1))

  call assert_equal('あ', strcharpart('あいうeお', -3, 4))

  call assert_equal('a', strcharpart('àxb', 0, 1))
  call assert_equal('̀', strcharpart('àxb', 1, 1))
  call assert_equal('x', strcharpart('àxb', 2, 1))
endfunc
