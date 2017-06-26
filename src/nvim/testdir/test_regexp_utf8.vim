" Tests for regexp in utf8 encoding

func s:equivalence_test()
  let str = "AÀÁÂÃÄÅĀĂĄǍǞǠẢ BḂḆ CÇĆĈĊČ DĎĐḊḎḐ EÈÉÊËĒĔĖĘĚẺẼ FḞ GĜĞĠĢǤǦǴḠ HĤĦḢḦḨ IÌÍÎÏĨĪĬĮİǏỈ JĴ KĶǨḰḴ LĹĻĽĿŁḺ MḾṀ NÑŃŅŇṄṈ OÒÓÔÕÖØŌŎŐƠǑǪǬỎ PṔṖ Q RŔŖŘṘṞ SŚŜŞŠṠ TŢŤŦṪṮ UÙÚÛÜŨŪŬŮŰŲƯǓỦ VṼ WŴẀẂẄẆ XẊẌ YÝŶŸẎỲỶỸ ZŹŻŽƵẐẔ aàáâãäåāăąǎǟǡả bḃḇ cçćĉċč dďđḋḏḑ eèéêëēĕėęěẻẽ fḟ gĝğġģǥǧǵḡ hĥħḣḧḩẖ iìíîïĩīĭįǐỉ jĵǰ kķǩḱḵ lĺļľŀłḻ mḿṁ nñńņňŉṅṉ oòóôõöøōŏőơǒǫǭỏ pṕṗ q rŕŗřṙṟ sśŝşšṡ tţťŧṫṯẗ uùúûüũūŭůűųưǔủ vṽ wŵẁẃẅẇẘ xẋẍ yýÿŷẏẙỳỷỹ zźżžƶẑẕ"
  let groups = split(str)
  for group1 in groups
    for c in split(group1, '\zs')
      " next statement confirms that equivalence class matches every
      " character in group
      call assert_match('^[[=' . c . '=]]*$', group1)
      for group2 in groups
        if group2 != group1
          " next statement converts that equivalence class doesn't match
          " character in any other group
          call assert_equal(-1, match(group2, '[[=' . c . '=]]'))
        endif
      endfor
    endfor
  endfor
endfunc

func Test_equivalence_re1()
  set re=1
  call s:equivalence_test()
  set re=0
endfunc

func Test_equivalence_re2()
  set re=2
  call s:equivalence_test()
  set re=0
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
  set re=0
endfunc

func Test_classes_re2()
  set re=2
  call s:classes_test()
  set re=0
endfunc

func Test_recursive_substitute()
  new
  s/^/\=execute("s#^##gn")
  " check we are now not in the sandbox
  call setwinvar(1, 'myvar', 1)
  bwipe!
endfunc

func Test_eow_with_optional()
  let expected = ['abc def', 'abc', 'def', '', '', '', '', '', '', '']
  for re in range(0, 2)
    exe 'set re=' . re
    let actual = matchlist('abc def', '\(abc\>\)\?\s*\(def\)')
    call assert_equal(expected, actual)
  endfor
endfunc
