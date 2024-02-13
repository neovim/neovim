" Tests for case-insensitive UTF-8 comparisons (utf_strnicmp() in mbyte.c)
" Also test "g~ap".

func Ch(a, op, b, expected)
  call assert_equal(eval(printf('"%s" %s "%s"', a:a, a:op, a:b)), a:expected,
        \ printf('"%s" %s "%s" should return %d', a:a, a:op, a:b, a:expected))
endfunc

func Chk(a, b, result)
  if a:result == 0
    call Ch(a:a, '==?', a:b, 1)
    call Ch(a:a, '!=?', a:b, 0)
    call Ch(a:a, '<=?', a:b, 1)
    call Ch(a:a, '>=?', a:b, 1)
    call Ch(a:a, '<?', a:b, 0)
    call Ch(a:a, '>?', a:b, 0)
  elseif a:result > 0
    call Ch(a:a, '==?', a:b, 0)
    call Ch(a:a, '!=?', a:b, 1)
    call Ch(a:a, '<=?', a:b, 0)
    call Ch(a:a, '>=?', a:b, 1)
    call Ch(a:a, '<?', a:b, 0)
    call Ch(a:a, '>?', a:b, 1)
  else
    call Ch(a:a, '==?', a:b, 0)
    call Ch(a:a, '!=?', a:b, 1)
    call Ch(a:a, '<=?', a:b, 1)
    call Ch(a:a, '>=?', a:b, 0)
    call Ch(a:a, '<?', a:b, 1)
    call Ch(a:a, '>?', a:b, 0)
  endif
endfunc

func Check(a, b, result)
  call Chk(a:a, a:b, a:result)
  call Chk(a:b, a:a, -a:result)
endfunc

func LT(a, b)
  call Check(a:a, a:b, -1)
endfunc

func GT(a, b)
  call Check(a:a, a:b, 1)
endfunc

func EQ(a, b)
  call Check(a:a, a:b, 0)
endfunc

func Test_comparisons()
  call EQ('', '')
  call LT('', 'a')
  call EQ('abc', 'abc')
  call EQ('Abc', 'abC')
  call LT('ab', 'abc')
  call LT('AB', 'abc')
  call LT('ab', 'aBc')
  call EQ('\xd0\xb9\xd1\x86\xd1\x83\xd0\xba\xd0\xb5\xd0\xbd', '\xd0\xb9\xd0\xa6\xd0\xa3\xd0\xba\xd0\x95\xd0\xbd')
  call LT('\xd0\xb9\xd1\x86\xd1\x83\xd0\xba\xd0\xb5\xd0\xbd', '\xd0\xaf\xd1\x86\xd1\x83\xd0\xba\xd0\xb5\xd0\xbd')
  call EQ('\xe2\x84\xaa', 'k')
  call LT('\xe2\x84\xaa', 'kkkkkk')
  call EQ('\xe2\x84\xaa\xe2\x84\xaa\xe2\x84\xaa', 'kkk')
  call LT('kk', '\xe2\x84\xaa\xe2\x84\xaa\xe2\x84\xaa')
  call EQ('\xe2\x84\xaa\xe2\x84\xa6k\xe2\x84\xaak\xcf\x89', 'k\xcf\x89\xe2\x84\xaakk\xe2\x84\xa6')
  call EQ('Abc\x80', 'AbC\x80')
  call LT('Abc\x80', 'AbC\x81')
  call LT('Abc', 'AbC\x80')
  call LT('abc\x80DEF', 'abc\x80def')  " case folding stops at the first bad character
  call LT('\xc3XYZ', '\xc3xyz')
  call EQ('\xef\xbc\xba', '\xef\xbd\x9a')  " FF3A (upper), FF5A (lower)
  call GT('\xef\xbc\xba', '\xef\xbc\xff')  " first string is ok and equals \xef\xbd\x9a after folding, second string is illegal and was left unchanged, then the strings were bytewise compared
  call LT('\xc3', '\xc3\x83')
  call EQ('\xc3\xa3xYz', '\xc3\x83XyZ')
  for n in range(0x60, 0xFF)
    call LT(printf('xYz\x%.2X', n-1), printf('XyZ\x%.2X', n))
  endfor
  for n in range(0x80, 0xBF)
    call EQ(printf('xYz\xc2\x%.2XUvW', n), printf('XyZ\xc2\x%.2XuVw', n))
  endfor
  for n in range(0xC0, 0xFF)
    call LT(printf('xYz\xc2\x%.2XUvW', n), printf('XyZ\xc2\x%.2XuVw', n))
  endfor
endfunc

" test that g~ap changes one paragraph only.
func Test_gap()
  new
  " setup text
  call feedkeys("iabcd\<cr>\<cr>defg", "tx")
  " modify only first line
  call feedkeys("gg0g~ap", "tx")
  call assert_equal(["ABCD", "", "defg"], getline(1,3))
endfunc

" test that g~, ~ and gU correctly upper-cases ß
func Test_uppercase_sharp_ss()
  new
  call setline(1, repeat(['ß'], 4))

  call cursor(1, 1)
  norm! ~
  call assert_equal('ẞ', getline(line('.')))
  norm! ~
  call assert_equal('ß', getline(line('.')))

  call cursor(2, 1)
  norm! g~l
  call assert_equal('ẞ', getline(line('.')))
  norm! g~l
  call assert_equal('ß', getline(line('.')))

  call cursor(3, 1)
  norm! gUl
  call assert_equal('ẞ', getline(line('.')))
  norm! vgU
  call assert_equal('ẞ', getline(line('.')))
  norm! vgu
  call assert_equal('ß', getline(line('.')))
  norm! gul
  call assert_equal('ß', getline(line('.')))

  call cursor(4, 1)
  norm! vgU
  call assert_equal('ẞ', getline(line('.')))
  norm! vgu
  call assert_equal('ß', getline(line('.')))
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
