" Tests for regexp in utf8 encoding
scriptencoding utf-8

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

func Test_recursive_substitute()
  new
  s/^/\=execute("s#^##gn")
  " check we are now not in the sandbox
  call setwinvar(1, 'myvar', 1)
  bwipe!
endfunc
