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

  let @"='dummy'
  exe "norm! $gevi'y"
  call assert_equal('bcde', @")

  let @"='dummy'
  exe "norm! 0fbhvi'y"
  call assert_equal('bcde', @")

  set selection&vim
  bw!
endfunc

func Test_quote_selection_selection_exclusive_abort()
  new
  set selection=exclusive
  call setline(1, "'abzzc'")
  let exp_curs = [0, 1, 6, 0]
  call cursor(1,1)
  exe 'norm! fcdvi"'
  " make sure to end visual mode to have a clear state
  exe "norm! \<esc>"
  call assert_equal(exp_curs, getpos('.'))
  call cursor(1,1)
  exe 'norm! fcvi"'
  exe "norm! \<esc>"
  call assert_equal(exp_curs, getpos('.'))
  call cursor(1,2)
  exe 'norm! vfcoi"'
  exe "norm! \<esc>"
  let exp_curs = [0, 1, 2, 0]
  let exp_visu = [0, 1, 7, 0]
  call assert_equal(exp_curs, getpos('.'))
  call assert_equal(exp_visu, getpos("'>"))
  set selection&vim
  bw!
endfunc

" Tests for string and html text objects
func Test_string_html_objects()

  " Nvim only supports set encoding=utf-8
  " for e in ['utf-8', 'latin1', 'cp932']
  for e in ['utf-8']
    enew!
    exe 'set enc=' .. e

    let t = '"wo\"rd\\" foo'
    put =t
    normal! da"
    call assert_equal('foo', getline('.'), e)

    let t = "'foo' 'bar' 'piep'"
    put =t
    normal! 0va'a'rx
    call assert_equal("xxxxxxxxxxxx'piep'", getline('.'), e)

    let t = "bla bla `quote` blah"
    put =t
    normal! 02f`da`
    call assert_equal("bla bla blah", getline('.'), e)

    let t = 'out " in "noXno"'
    put =t
    normal! 0fXdi"
    call assert_equal('out " in ""', getline('.'), e)

    let t = "\"'\" 'blah' rep 'buh'"
    put =t
    normal! 03f'vi'ry
    call assert_equal("\"'\" 'blah'yyyyy'buh'", getline('.'), e)

    set quoteescape=+*-
    let t = "bla `s*`d-`+++`l**` b`la"
    put =t
    normal! di`
    call assert_equal("bla `` b`la", getline('.'), e)

    let t = 'voo "nah" sdf " asdf" sdf " sdf" sd'
    put =t
    normal! $F"va"oha"i"rz
    call assert_equal('voo "zzzzzzzzzzzzzzzzzzzzzzzzzzzzsd', getline('.'), e)

    let t = "-<b>asdf<i>Xasdf</i>asdf</b>-"
    put =t
    normal! fXdit
    call assert_equal('-<b>asdf<i></i>asdf</b>-', getline('.'), e)

    let t = "-<b>asdX<i>a<i />sdf</i>asdf</b>-"
    put =t
    normal! 0fXdit
    call assert_equal('-<b></b>-', getline('.'), e)

    let t = "-<b>asdf<i>Xasdf</i>asdf</b>-"
    put =t
    normal! fXdat
    call assert_equal('-<b>asdfasdf</b>-', getline('.'), e)

    let t = "-<b>asdX<i>as<b />df</i>asdf</b>-"
    put =t
    normal! 0fXdat
    call assert_equal('--', getline('.'), e)

    let t = "-<b>\ninnertext object\n</b>"
    put =t
    normal! dit
    call assert_equal('-<b></b>', getline('.'), e)

    " copy the tag block from leading indentation before the start tag
    let t = "    <b>\ntext\n</b>"
    $put =t
    normal! 2kvaty
    call assert_equal("<b>\ntext\n</b>", @", e)

    " copy the tag block from the end tag
    let t = "<title>\nwelcome\n</title>"
    $put =t
    normal! $vaty
    call assert_equal("<title>\nwelcome\n</title>", @", e)

    " copy the outer tag block from a tag without an end tag
    let t = "<html>\n<title>welcome\n</html>"
    $put =t
    normal! k$vaty
    call assert_equal("<html>\n<title>welcome\n</html>", @", e)

    " nested tag that has < in a different line from >
    let t = "<div><div\n></div></div>"
    $put =t
    normal! k0vaty
    call assert_equal("<div><div\n></div></div>", @", e)

    " nested tag with attribute that has < in a different line from >
    let t = "<div><div\nattr=\"attr\"\n></div></div>"
    $put =t
    normal! 2k0vaty
    call assert_equal("<div><div\nattr=\"attr\"\n></div></div>", @", e)

    set quoteescape&
  endfor

  set enc=utf-8
  bwipe!
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

func Test_sentence_with_cursor_on_delimiter()
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

  " don't get stuck on a quote at the start of a sentence
  %delete _
  call setline(1, ['A sentence.', '"A sentence"?', 'A sentence!'])
  normal gg))
  call assert_equal(3, getcurpos()[1])

  %delete _
  call setline(1, ['A sentence.', "'A sentence'?", 'A sentence!'])
  normal gg))
  call assert_equal(3, getcurpos()[1])

  %delete _
endfunc

" Test for quote (', " and `) textobjects
func Test_textobj_quote()
  new

  " Test for i" when cursor is in front of a quoted object
  call append(0, 'foo "bar"')
  norm! 1gg0di"
  call assert_equal(['foo ""', ''], getline(1,'$'))

  " Test for visually selecting an inner quote
  %d
  " extend visual selection from one quote to the next
  call setline(1, 'color "red" color "blue"')
  call cursor(1, 7)
  normal v4li"y
  call assert_equal('"red" color "blue', @")

  " try to extend visual selection from one quote to a non-existing quote
  call setline(1, 'color "red" color blue')
  call cursor(1, 7)
  call feedkeys('v4li"y', 'xt')
  call assert_equal('"red"', @")

  " try to extend visual selection from one quote to a next partial quote
  call setline(1, 'color "red" color "blue')
  call cursor(1, 7)
  normal v4li"y
  call assert_equal('"red" color ', @")

  " select a quote backwards in visual mode
  call cursor(1, 12)
  normal vhi"y
  call assert_equal('red" ', @")
  call assert_equal(8, col('.'))

  " select a quote backwards in visual mode from outside the quote
  call cursor(1, 17)
  normal v2hi"y
  call assert_equal('red', @")
  call assert_equal(8, col('.'))

  " visually selecting a quote with 'selection' set to 'exclusive'
  call setline(1, 'He said "How are you?"')
  set selection=exclusive
  normal 012lv2li"y
  call assert_equal('How are you?', @")
  set selection&

  " try copy a quote object with a single quote in the line
  call setline(1, "Smith's car")
  call cursor(1, 6)
  call assert_beeps("normal yi'")
  call assert_beeps("normal 2lyi'")

  " selecting space before and after a quoted string
  call setline(1, "some    'special'    string")
  normal 0ya'
  call assert_equal("'special'    ", @")
  call setline(1, "some    'special'string")
  normal 0ya'
  call assert_equal("    'special'", @")

  " quoted string with odd or even number of backslashes.
  call setline(1, 'char *s = "foo\"bar"')
  normal $hhyi"
  call assert_equal('foo\"bar', @")
  call setline(1, 'char *s = "foo\\"bar"')
  normal $hhyi"
  call assert_equal('bar', @")
  call setline(1, 'char *s = "foo\\\"bar"')
  normal $hhyi"
  call assert_equal('foo\\\"bar', @")
  call setline(1, 'char *s = "foo\\\\"bar"')
  normal $hhyi"
  call assert_equal('bar', @")

  close!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
