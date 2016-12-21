" Tests for expressions using utf-8.
if !has('multi_byte')
  finish
endif

func Test_strgetchar_utf8()
  call assert_equal(char2nr('á'), strgetchar('áxb', 0))
  call assert_equal(char2nr('x'), strgetchar('áxb', 1))

  call assert_equal(char2nr('a'), strgetchar('àxb', 0))
  call assert_equal(char2nr('̀'), strgetchar('àxb', 1))
  call assert_equal(char2nr('x'), strgetchar('àxb', 2))

  call assert_equal(char2nr('あ'), strgetchar('あaい', 0))
  call assert_equal(char2nr('a'), strgetchar('あaい', 1))
  call assert_equal(char2nr('い'), strgetchar('あaい', 2))
endfunc

func Test_strcharpart_utf8()
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

func s:classes_test()
  set isprint=@,161-255
  call assert_equal('Motörhead', matchstr('Motörhead', '[[:print:]]\+'))

  let alphachars = ''
  let lowerchars = ''
  let upperchars = ''
  let alnumchars = ''
  let printchars = ''
  let punctchars = ''
  let xdigitchars = ''
  let i = 1
  while i <= 255
    let c = nr2char(i)
    if c =~ '[[:alpha:]]'
      let alphachars .= c
    endif
    if c =~ '[[:lower:]]'
      let lowerchars .= c
    endif
    if c =~ '[[:upper:]]'
      let upperchars .= c
    endif
    if c =~ '[[:alnum:]]'
      let alnumchars .= c
    endif
    if c =~ '[[:print:]]'
      let printchars .= c
    endif
    if c =~ '[[:punct:]]'
      let punctchars .= c
    endif
    if c =~ '[[:xdigit:]]'
      let xdigitchars .= c
    endif
    let i += 1
  endwhile

  call assert_equal('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz', alphachars)
  call assert_equal('abcdefghijklmnopqrstuvwxyzµßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ', lowerchars)
  call assert_equal('ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ', upperchars)
  call assert_equal('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz', alnumchars)
  call assert_equal(' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~ ¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ', printchars)
  call assert_equal('!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~', punctchars)
  call assert_equal('0123456789ABCDEFabcdef', xdigitchars)
endfunc

func Test_classes_re1()
  set re=1
  call s:classes_test()
endfunc

func Test_classes_re2()
  set re=2
  call s:classes_test()
endfunc
