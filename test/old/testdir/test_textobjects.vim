" Test for textobjects

source check.vim

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

func Test_inner_block_single_char()
  new
  call setline(1, "(a)")

  set selection=inclusive
  let @" = ''
  call assert_nobeep('norm! 0faviby')
  call assert_equal('a', @")

  set selection=exclusive
  let @" = ''
  call assert_nobeep('norm! 0faviby')
  call assert_equal('a', @")

  set selection&
  bwipe!
endfunc

func Test_quote_selection_selection_exclusive()
  new
  call setline(1, "a 'bcde' f")
  set selection=exclusive

  exe "norm! fdvhi'y"
  call assert_equal('bcde', @")

  let @" = 'dummy'
  exe "norm! $gevi'y"
  call assert_equal('bcde', @")

  let @" = 'dummy'
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

    " tag, that includes a > in some attribute
    let t = "<div attr=\"attr >> foo >> bar \">Hello</div>"
    $put =t
    normal! fHyit
    call assert_equal("Hello", @", e)

    " tag, that includes a > in some attribute
    let t = "<div attr='attr >> foo >> bar '>Hello 123</div>"
    $put =t
    normal! fHyit
    call assert_equal("Hello 123", @", e)

    set quoteescape&

    " this was going beyond the end of the line
    %del
    sil! norm i"\
    sil! norm i"\
    sil! norm i"\
    call assert_equal('"\', getline(1))

    bwipe!
  endfor

  set enc=utf-8
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

  " selecting a tag block in a non-empty blank line should fail
  call setline(1, '    ')
  call assert_beeps('normal $vaty')

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

" Test for the paragraph (ap) text object
func Test_paragraph()
  new
  call setline(1, ['First line.', 'Second line.', 'Third line.'])
  call cursor(2, 1)
  normal vapy
  call assert_equal("First line.\nSecond line.\nThird line.\n", @")

  call cursor(2, 1)
  call assert_beeps('normal vapapy')

  call setline(1, ['First line.', 'Second line.', '  ', ''])
  call cursor(1, 1)
  normal vapy
  call assert_equal("First line.\nSecond line.\n  \n\n", @")

  call setline(1, ['', '', '', 'First line.', 'Second line.'])
  call cursor(2, 1)
  normal yap
  call assert_equal("\n\n\nFirst line.\nSecond line.\n", @")
  call assert_beeps('normal 3yap')
  exe "normal \<C-C>"

  %d
  call setline(1, ['  ', '  ', '  '])
  call cursor(2, 1)
  normal Vipy
  call assert_equal("  \n  \n  \n", @")
  call cursor(2, 1)
  call assert_beeps("normal Vipip")
  exe "normal \<C-C>"

  bw!
endfunc

" Tests for text object aw
func Test_textobj_a_word()
  new
  call append(0, ['foobar,eins,foobar', 'foo,zwei,foo    '])
  " diw
  norm! 1gg0diw
  call assert_equal([',eins,foobar', 'foo,zwei,foo    ', ''], getline(1,'$'))
  " daw
  norm! 2ggEdaw
  call assert_equal([',eins,foobar', 'foo,zwei,', ''], getline(1, '$'))
  " daw the last word in a line
  call setline(1, ['foo bar', 'foo bar', ''])
  call cursor(1, 5)
  normal daw
  call assert_equal('foo', getline(1))
  " aw in visual mode
  call cursor(2, 5)
  normal! vawx
  call assert_equal('foo', getline(2))
  %d
  call append(0, ["foo\teins\tfoobar", "foo\tzwei\tfoo   "])
  " diW
  norm! 2ggwd2iW
  call assert_equal(['foo	eins	foobar', 'foo	foo   ', ''], getline(1,'$'))
  " daW
  norm! 1ggd2aW
  call assert_equal(['foobar', 'foo	foo   ', ''], getline(1,'$'))

  %d
  call append(0, ["foo\teins\tfoobar", "foo\tzwei\tfoo   "])
  " aw in visual line mode switches to characterwise mode
  norm! 2gg$Vawd
  call assert_equal(['foo	eins	foobar', 'foo	zwei	foo'], getline(1,'$'))
  norm! 1gg$Viwd
  call assert_equal(['foo	eins	', 'foo	zwei	foo'], getline(1,'$'))

  " visually selecting a tab before a word with 'selection' set to 'exclusive'
  set selection=exclusive
  normal gg3lvlawy
  call assert_equal("\teins", @")
  " visually selecting a tab before a word with 'selection' set to 'inclusive'
  set selection=inclusive
  normal gg3lvlawy
  call assert_equal("\teins\t", @")
  set selection&

  " selecting a word with no non-space characters in a buffer fails
  %d
  call setline(1, '    ')
  call assert_beeps('normal 3lyaw')

  " visually selecting words backwards with no more words to select
  call setline(1, 'one two')
  call assert_beeps('normal 2lvh2aw')
  exe "normal \<C-C>"
  call assert_beeps('normal $vh3aw')
  exe "normal \<C-C>"
  call setline(1, ['', 'one two'])
  call assert_beeps('normal 2G2lvh3aw')
  exe "normal \<C-C>"

  " selecting words forward with no more words to select
  %d
  call setline(1, 'one a')
  call assert_beeps('normal 0y3aw')
  call setline(1, 'one two ')
  call assert_beeps('normal 0y3aw')
  call assert_beeps('normal 03ly2aw')

  " clean up
  bw!
endfunc

" Test for is and as text objects
func Test_textobj_sentence()
  new
  call append(0, ['This is a test. With some sentences!', '',
        \ 'Even with a question? And one more. And no sentence here'])
  " Test for dis - does not remove trailing whitespace
  norm! 1gg0dis
  call assert_equal([' With some sentences!', '',
        \ 'Even with a question? And one more. And no sentence here', ''],
        \ getline(1,'$'))
  " Test for das - removes leading whitespace
  norm! 3ggf?ldas
  call assert_equal([' With some sentences!', '',
        \ 'Even with a question? And no sentence here', ''], getline(1,'$'))
  " when used in visual mode, is made characterwise
  norm! 3gg$Visy
  call assert_equal('v', visualmode())
  " reset visualmode()
  norm! 3ggVy
  norm! 3gg$Vasy
  call assert_equal('v', visualmode())
  " basic testing for textobjects a< and at
  %d
  call setline(1, ['<div> ','<a href="foobar" class="foo">xyz</a>','    </div>', ' '])
  " a<
  norm! 1gg0da<
  call assert_equal([' ', '<a href="foobar" class="foo">xyz</a>', '    </div>', ' '], getline(1,'$'))
  norm! 1pj
  call assert_equal([' <div>', '<a href="foobar" class="foo">xyz</a>', '    </div>', ' '], getline(1,'$'))
  " at
  norm! d2at
  call assert_equal([' '], getline(1,'$'))
  %d
  call setline(1, ['<div> ','<a href="foobar" class="foo">xyz</a>','    </div>', ' '])
  " i<
  norm! 1gg0di<
  call assert_equal(['<> ', '<a href="foobar" class="foo">xyz</a>', '    </div>', ' '], getline(1,'$'))
  norm! 1Pj
  call assert_equal(['<div> ', '<a href="foobar" class="foo">xyz</a>', '    </div>', ' '], getline(1,'$'))
  norm! d2it
  call assert_equal(['<div></div>',' '], getline(1,'$'))
  " basic testing for a[ and i[ text object
  %d
  call setline(1, [' ', '[', 'one [two]', 'thre', ']'])
  norm! 3gg0di[
  call assert_equal([' ', '[', ']'], getline(1,'$'))
  call setline(1, [' ', '[', 'one [two]', 'thre', ']'])
  norm! 3gg0ftd2a[
  call assert_equal([' '], getline(1,'$'))

  " clean up
  bw!
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

  bw!
endfunc

" Test for i(, i<, etc. when cursor is in front of a block
func Test_textobj_find_paren_forward()
  new

  " i< and a> when cursor is in front of a block
  call setline(1, '#include <foo.h>')
  normal 0yi<
  call assert_equal('foo.h', @")
  normal 0ya>
  call assert_equal('<foo.h>', @")

  " 2i(, 3i( in front of a block enters second/third nested '('
  call setline(1, 'foo (bar (baz (quux)))')
  normal 0yi)
  call assert_equal('bar (baz (quux))', @")
  normal 02yi)
  call assert_equal('baz (quux)', @")
  normal 03yi)
  call assert_equal('quux', @")

  " 3i( in front of a block doesn't enter third but un-nested '('
  call setline(1, 'foo (bar (baz) (quux))')
  normal 03di)
  call assert_equal('foo (bar (baz) (quux))', getline(1))
  normal 02di)
  call assert_equal('foo (bar () (quux))', getline(1))
  normal 0di)
  call assert_equal('foo ()', getline(1))

  bw!
endfunc

func Test_inner_block_empty_paren()
  new
  call setline(1, ["(text)()", "", "(text)(", ")", "", "()()", "", "text()"])

  " Example 1
  call cursor(1, 1)
  let @" = ''
  call assert_beeps(':call feedkeys("0f(viby","xt")')
  call assert_equal(7, getpos('.')[2])
  call assert_equal('(', @")

  " Example 2
  call cursor(3, 1)
  let @" = ''
  call assert_beeps('call feedkeys("0f(viby", "xt")')
  call assert_equal(7, getpos('.')[2])
  call assert_equal('(', @")

  " Example 3
  call cursor(6, 1)
  let @" = ''
  call assert_beeps('call feedkeys("0f(viby", "xt")')
  call assert_equal(3, getpos('.')[2])
  call assert_equal('(', @")

  " Change empty inner block
  call cursor(8, 1)
  call feedkeys("0cibtext", "xt")
  call assert_equal("text(text)", getline('.'))

  bwipe!
endfunc

func Test_inner_block_empty_bracket()
  new
  call setline(1, ["[text][]", "", "[text][", "]", "", "[][]", "", "text[]"])

  " Example 1
  call cursor(1, 1)
  let @" = ''
  call assert_beeps(':call feedkeys("0f[viby","xt")')
  call assert_equal(7, getpos('.')[2])
  call assert_equal('[', @")

  " Example 2
  call cursor(3, 1)
  let @" = ''
  call assert_beeps('call feedkeys("0f[viby", "xt")')
  call assert_equal(7, getpos('.')[2])
  call assert_equal('[', @")

  " Example 3
  call cursor(6, 1)
  let @" = ''
  call assert_beeps('call feedkeys("0f[viby", "xt")')
  call assert_equal(3, getpos('.')[2])
  call assert_equal('[', @")

  " Change empty inner block
  call cursor(8, 1)
  call feedkeys("0ci[text", "xt")
  call assert_equal("text[text]", getline('.'))

  bwipe!
endfunc

func Test_inner_block_empty_brace()
  new
  call setline(1, ["{text}{}", "", "{text}{", "}", "", "{}{}", "", "text{}"])

  " Example 1
  call cursor(1, 1)
  let @" = ''
  call assert_beeps(':call feedkeys("0f{viby","xt")')
  call assert_equal(7, getpos('.')[2])
  call assert_equal('{', @")

  " Example 2
  call cursor(3, 1)
  let @" = ''
  call assert_beeps('call feedkeys("0f{viby", "xt")')
  call assert_equal(7, getpos('.')[2])
  call assert_equal('{', @")

  " Example 3
  call cursor(6, 1)
  let @" = ''
  call assert_beeps('call feedkeys("0f{viby", "xt")')
  call assert_equal(3, getpos('.')[2])
  call assert_equal('{', @")

  " Change empty inner block
  call cursor(8, 1)
  call feedkeys("0ciBtext", "xt")
  call assert_equal("text{text}", getline('.'))

  bwipe!
endfunc

func Test_inner_block_empty_lessthan()
  new
  call setline(1, ["<text><>", "", "<text><", ">", "", "<><>"])

  " Example 1
  call cursor(1, 1)
  let @" = ''
  call assert_beeps(':call feedkeys("0f<viby","xt")')
  call assert_equal(7, getpos('.')[2])
  call assert_equal('<', @")

  " Example 2
  call cursor(3, 1)
  let @" = ''
  call assert_beeps('call feedkeys("0f<viby", "xt")')
  call assert_equal(7, getpos('.')[2])
  call assert_equal('<', @")

  " Example 3
  call cursor(6, 1)
  let @" = ''
  call assert_beeps('call feedkeys("0f<viby", "xt")')
  call assert_equal(3, getpos('.')[2])
  call assert_equal('<', @")
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
