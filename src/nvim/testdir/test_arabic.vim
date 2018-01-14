" Simplistic testing of Arabic mode.

if !has('arabic')
  finish
endif

set encoding=utf-8
scriptencoding utf-8

" Return list of utf8 sequences of each character at line lnum.
" Combining characters are treated as a single item.
func GetCharsUtf8(lnum)
  call cursor(a:lnum, 1)
  let chars = []
  let numchars = strchars(getline('.'), 1)
  for i in range(1, numchars)
    exe 'norm ' i . '|'
    call add(chars, execute('norm g8'))
  endfor
  return chars
endfunc

func Test_arabic_toggle()
  set arabic
  call assert_equal(1, &rightleft)
  call assert_equal(1, &arabicshape)
  call assert_equal('arabic', &keymap)
  call assert_equal(1, &delcombine)

  set iminsert=1 imsearch=1
  set arabic&
  call assert_equal(0, &rightleft)
  call assert_equal(1, &arabicshape)
  call assert_equal('arabic', &keymap)
  call assert_equal(1, &delcombine)
  call assert_equal(0, &iminsert)
  call assert_equal(-1, &imsearch)

  set arabicshape& keymap= delcombine&
endfunc

func Test_arabic_input()
  new
  set arabic
  " Typing sghl in Arabic insert mode should show the
  " Arabic word 'Salaam' i.e. 'peace'.
  call feedkeys('isghl', 'tx')
  redraw
  call assert_equal([
  \ "\nd8 b3 ",
  \ "\nd9 84 + d8 a7 ",
  \ "\nd9 85 "], GetCharsUtf8(1))

  " Without shaping, it should give individual Arabic letters.
  set noarabicshape
  redraw
  call assert_equal([
  \ "\nd8 b3 ",
  \ "\nd9 84 ",
  \ "\nd8 a7 ",
  \ "\nd9 85 "], GetCharsUtf8(1))

  set arabicshape&
  set arabic&
  bwipe!
endfunc

func Test_arabic_toggle_keymap()
  new
  set arabic
  call feedkeys("i12\<C-^>12\<C-^>12", 'tx')
  redraw
  call assert_equal('١٢12١٢', getline('.'))
  set arabic&
  bwipe!
endfunc

func Test_delcombine()
  new
  set arabic
  call feedkeys("isghl\<BS>\<BS>", 'tx')
  redraw
  call assert_equal(["\nd8 b3 ", "\nd9 84 "], GetCharsUtf8(1))

  " Now the same with nodelcombine
  set nodelcombine
  %d
  call feedkeys("isghl\<BS>\<BS>", 'tx')
  call assert_equal(["\nd8 b3 "], GetCharsUtf8(1)) 
  set arabic&
  bwipe!
endfunc
