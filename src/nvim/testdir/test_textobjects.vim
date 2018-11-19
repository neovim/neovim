" Test for textobjects

if !has('textobjects')
  finish
endif

func CpoM(line, useM, expected)
  new

  if a:useM
    set cpoptions+=M
  else
    set cpoptions-=M
  endif

  call setline(1, a:line)

  call setreg('"', '')
  normal! ggfrmavi)y
  call assert_equal(getreg('"'), a:expected[0])

  call setreg('"', '')
  normal! `afbmavi)y
  call assert_equal(getreg('"'), a:expected[1])

  call setreg('"', '')
  normal! `afgmavi)y
  call assert_equal(getreg('"'), a:expected[2])

  q!
endfunc

func Test_inner_block_without_cpo_M()
  call CpoM('(red \(blue) green)', 0, ['red \(blue', 'red \(blue', ''])
endfunc

func Test_inner_block_with_cpo_M_left_backslash()
  call CpoM('(red \(blue) green)', 1, ['red \(blue) green', 'blue', 'red \(blue) green'])
endfunc

func Test_inner_block_with_cpo_M_right_backslash()
  call CpoM('(red (blue\) green)', 1, ['red (blue\) green', 'blue\', 'red (blue\) green'])
endfunc

func Test_quote_selection_selection_exclusive()
  new
  call setline(1, "a 'bcde' f")
  set selection=exclusive
  exe "norm! fdvhi'y"
  call assert_equal('bcde', @")
  set selection&vim
  bw!
endfunc

" Tests for string and html text objects
func Test_string_html_objects()
  enew!

  let t = '"wo\"rd\\" foo'
  put =t
  normal! da"
  call assert_equal('foo', getline('.'))

  let t = "'foo' 'bar' 'piep'"
  put =t
  normal! 0va'a'rx
  call assert_equal("xxxxxxxxxxxx'piep'", getline('.'))

  let t = "bla bla `quote` blah"
  put =t
  normal! 02f`da`
  call assert_equal("bla bla blah", getline('.'))

  let t = 'out " in "noXno"'
  put =t
  normal! 0fXdi"
  call assert_equal('out " in ""', getline('.'))

  let t = "\"'\" 'blah' rep 'buh'"
  put =t
  normal! 03f'vi'ry
  call assert_equal("\"'\" 'blah'yyyyy'buh'", getline('.'))

  set quoteescape=+*-
  let t = "bla `s*`d-`+++`l**` b`la"
  put =t
  normal! di`
  call assert_equal("bla `` b`la", getline('.'))

  let t = 'voo "nah" sdf " asdf" sdf " sdf" sd'
  put =t
  normal! $F"va"oha"i"rz
  call assert_equal('voo "zzzzzzzzzzzzzzzzzzzzzzzzzzzzsd', getline('.'))

  let t = "-<b>asdf<i>Xasdf</i>asdf</b>-"
  put =t
  normal! fXdit
  call assert_equal('-<b>asdf<i></i>asdf</b>-', getline('.'))

  let t = "-<b>asdX<i>a<i />sdf</i>asdf</b>-"
  put =t
  normal! 0fXdit
  call assert_equal('-<b></b>-', getline('.'))

  let t = "-<b>asdf<i>Xasdf</i>asdf</b>-"
  put =t
  normal! fXdat
  call assert_equal('-<b>asdfasdf</b>-', getline('.'))

  let t = "-<b>asdX<i>as<b />df</i>asdf</b>-"
  put =t
  normal! 0fXdat
  call assert_equal('--', getline('.'))

  let t = "-<b>\ninnertext object\n</b>"
  put =t
  normal! dit
  call assert_equal('-<b></b>', getline('.'))

  set quoteescape&
  enew!
endfunc

func Test_empty_html_tag()
  new
  call setline(1, '<div></div>')
  normal 0citxxx
  call assert_equal('<div>xxx</div>', getline(1))

  call setline(1, '<div></div>')
  normal 0f<cityyy
  call assert_equal('<div>yyy</div>', getline(1))

  call setline(1, '<div></div>')
  normal 0f<vitsaaa
  call assert_equal('aaa', getline(1))

  bwipe!
endfunc

" Tests for match() and matchstr()
func Test_match()
  call assert_equal("b", matchstr("abcd", ".", 0, 2))
  call assert_equal("bc", matchstr("abcd", "..", 0, 2))
  call assert_equal("c", matchstr("abcd", ".", 2, 0))
  call assert_equal("a", matchstr("abcd", ".", 0, -1))
  call assert_equal(-1, match("abcd", ".", 0, 5))
  call assert_equal(0 , match("abcd", ".", 0, -1))
  call assert_equal(0 , match('abc', '.', 0, 1))
  call assert_equal(1 , match('abc', '.', 0, 2))
  call assert_equal(2 , match('abc', '.', 0, 3))
  call assert_equal(-1, match('abc', '.', 0, 4))
  call assert_equal(1 , match('abc', '.', 1, 1))
  call assert_equal(2 , match('abc', '.', 2, 1))
  call assert_equal(-1, match('abc', '.', 3, 1))
  call assert_equal(3 , match('abc', '$', 0, 1))
  call assert_equal(-1, match('abc', '$', 0, 2))
  call assert_equal(3 , match('abc', '$', 1, 1))
  call assert_equal(3 , match('abc', '$', 2, 1))
  call assert_equal(3 , match('abc', '$', 3, 1))
  call assert_equal(-1, match('abc', '$', 4, 1))
  call assert_equal(0 , match('abc', '\zs', 0, 1))
  call assert_equal(1 , match('abc', '\zs', 0, 2))
  call assert_equal(2 , match('abc', '\zs', 0, 3))
  call assert_equal(3 , match('abc', '\zs', 0, 4))
  call assert_equal(-1, match('abc', '\zs', 0, 5))
  call assert_equal(1 , match('abc', '\zs', 1, 1))
  call assert_equal(2 , match('abc', '\zs', 2, 1))
  call assert_equal(3 , match('abc', '\zs', 3, 1))
  call assert_equal(-1, match('abc', '\zs', 4, 1))
endfunc

" This was causing an illegal memory access
func Test_inner_tag()
  new
  norm ixxx
  call feedkeys("v", 'xt')
  insert
x
x
.
  norm it
  q!
endfunc

func Test_sentence()
  enew!
  call setline(1, 'A sentence.  A sentence?  A sentence!')

  normal yis
  call assert_equal('A sentence.', @")
  normal yas
  call assert_equal('A sentence.  ', @")

  normal )

  normal yis
  call assert_equal('A sentence?', @")
  normal yas
  call assert_equal('A sentence?  ', @")

  normal )

  normal yis
  call assert_equal('A sentence!', @")
  normal yas
  call assert_equal('  A sentence!', @")

  normal 0
  normal 2yis
  call assert_equal('A sentence.  ', @")
  normal 3yis
  call assert_equal('A sentence.  A sentence?', @")
  normal 2yas
  call assert_equal('A sentence.  A sentence?  ', @")

  %delete _
endfunc

func Test_sentence_with_quotes()
  enew!
  call setline(1, 'A "sentence."  A sentence.')

  normal yis
  call assert_equal('A "sentence."', @")
  normal yas
  call assert_equal('A "sentence."  ', @")

  normal )

  normal yis
  call assert_equal('A sentence.', @")
  normal yas
  call assert_equal('  A sentence.', @")

  %delete _
endfunc

func! Test_sentence_with_cursor_on_delimiter()
  enew!
  call setline(1, "A '([sentence.])'  A sentence.")

  normal! 15|yis
  call assert_equal("A '([sentence.])'", @")
  normal! 15|yas
  call assert_equal("A '([sentence.])'  ", @")

  normal! 16|yis
  call assert_equal("A '([sentence.])'", @")
  normal! 16|yas
  call assert_equal("A '([sentence.])'  ", @")

  normal! 17|yis
  call assert_equal("A '([sentence.])'", @")
  normal! 17|yas
  call assert_equal("A '([sentence.])'  ", @")

  %delete _
endfunc
