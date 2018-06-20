" Tests for various functions.

func Test_str2nr()
  call assert_equal(0, str2nr(''))
  call assert_equal(1, str2nr('1'))
  call assert_equal(1, str2nr(' 1 '))

  call assert_equal(1, str2nr('+1'))
  call assert_equal(1, str2nr('+ 1'))
  call assert_equal(1, str2nr(' + 1 '))

  call assert_equal(-1, str2nr('-1'))
  call assert_equal(-1, str2nr('- 1'))
  call assert_equal(-1, str2nr(' - 1 '))

  call assert_equal(123456789, str2nr('123456789'))
  call assert_equal(-123456789, str2nr('-123456789'))
endfunc

func Test_setbufvar_options()
  " This tests that aucmd_prepbuf() and aucmd_restbuf() properly restore the
  " window layout.
  call assert_equal(1, winnr('$'))
  split dummy_preview
  resize 2
  set winfixheight winfixwidth
  let prev_id = win_getid()

  wincmd j
  let wh = winheight('.')
  let dummy_buf = bufnr('dummy_buf1', v:true)
  call setbufvar(dummy_buf, '&buftype', 'nofile')
  execute 'belowright vertical split #' . dummy_buf
  call assert_equal(wh, winheight('.'))
  let dum1_id = win_getid()

  wincmd h
  let wh = winheight('.')
  let dummy_buf = bufnr('dummy_buf2', v:true)
  call setbufvar(dummy_buf, '&buftype', 'nofile')
  execute 'belowright vertical split #' . dummy_buf
  call assert_equal(wh, winheight('.'))

  bwipe!
  call win_gotoid(prev_id)
  bwipe!
  call win_gotoid(dum1_id)
  bwipe!
endfunc

func Test_tolower()
  call assert_equal("", tolower(""))

  " Test with all printable ASCII characters.
  call assert_equal(' !"#$%&''()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\]^_`abcdefghijklmnopqrstuvwxyz{|}~',
          \ tolower(' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~'))

  if !has('multi_byte')
    return
  endif

  " Test with a few uppercase diacritics.
  call assert_equal("aàáâãäåāăąǎǟǡả", tolower("AÀÁÂÃÄÅĀĂĄǍǞǠẢ"))
  call assert_equal("bḃḇ", tolower("BḂḆ"))
  call assert_equal("cçćĉċč", tolower("CÇĆĈĊČ"))
  call assert_equal("dďđḋḏḑ", tolower("DĎĐḊḎḐ"))
  call assert_equal("eèéêëēĕėęěẻẽ", tolower("EÈÉÊËĒĔĖĘĚẺẼ"))
  call assert_equal("fḟ ", tolower("FḞ "))
  call assert_equal("gĝğġģǥǧǵḡ", tolower("GĜĞĠĢǤǦǴḠ"))
  call assert_equal("hĥħḣḧḩ", tolower("HĤĦḢḦḨ"))
  call assert_equal("iìíîïĩīĭįiǐỉ", tolower("IÌÍÎÏĨĪĬĮİǏỈ"))
  call assert_equal("jĵ", tolower("JĴ"))
  call assert_equal("kķǩḱḵ", tolower("KĶǨḰḴ"))
  call assert_equal("lĺļľŀłḻ", tolower("LĹĻĽĿŁḺ"))
  call assert_equal("mḿṁ", tolower("MḾṀ"))
  call assert_equal("nñńņňṅṉ", tolower("NÑŃŅŇṄṈ"))
  call assert_equal("oòóôõöøōŏőơǒǫǭỏ", tolower("OÒÓÔÕÖØŌŎŐƠǑǪǬỎ"))
  call assert_equal("pṕṗ", tolower("PṔṖ"))
  call assert_equal("q", tolower("Q"))
  call assert_equal("rŕŗřṙṟ", tolower("RŔŖŘṘṞ"))
  call assert_equal("sśŝşšṡ", tolower("SŚŜŞŠṠ"))
  call assert_equal("tţťŧṫṯ", tolower("TŢŤŦṪṮ"))
  call assert_equal("uùúûüũūŭůűųưǔủ", tolower("UÙÚÛÜŨŪŬŮŰŲƯǓỦ"))
  call assert_equal("vṽ", tolower("VṼ"))
  call assert_equal("wŵẁẃẅẇ", tolower("WŴẀẂẄẆ"))
  call assert_equal("xẋẍ", tolower("XẊẌ"))
  call assert_equal("yýŷÿẏỳỷỹ", tolower("YÝŶŸẎỲỶỸ"))
  call assert_equal("zźżžƶẑẕ", tolower("ZŹŻŽƵẐẔ"))

  " Test with a few lowercase diacritics, which should remain unchanged.
  call assert_equal("aàáâãäåāăąǎǟǡả", tolower("aàáâãäåāăąǎǟǡả"))
  call assert_equal("bḃḇ", tolower("bḃḇ"))
  call assert_equal("cçćĉċč", tolower("cçćĉċč"))
  call assert_equal("dďđḋḏḑ", tolower("dďđḋḏḑ"))
  call assert_equal("eèéêëēĕėęěẻẽ", tolower("eèéêëēĕėęěẻẽ"))
  call assert_equal("fḟ", tolower("fḟ"))
  call assert_equal("gĝğġģǥǧǵḡ", tolower("gĝğġģǥǧǵḡ"))
  call assert_equal("hĥħḣḧḩẖ", tolower("hĥħḣḧḩẖ"))
  call assert_equal("iìíîïĩīĭįǐỉ", tolower("iìíîïĩīĭįǐỉ"))
  call assert_equal("jĵǰ", tolower("jĵǰ"))
  call assert_equal("kķǩḱḵ", tolower("kķǩḱḵ"))
  call assert_equal("lĺļľŀłḻ", tolower("lĺļľŀłḻ"))
  call assert_equal("mḿṁ ", tolower("mḿṁ "))
  call assert_equal("nñńņňŉṅṉ", tolower("nñńņňŉṅṉ"))
  call assert_equal("oòóôõöøōŏőơǒǫǭỏ", tolower("oòóôõöøōŏőơǒǫǭỏ"))
  call assert_equal("pṕṗ", tolower("pṕṗ"))
  call assert_equal("q", tolower("q"))
  call assert_equal("rŕŗřṙṟ", tolower("rŕŗřṙṟ"))
  call assert_equal("sśŝşšṡ", tolower("sśŝşšṡ"))
  call assert_equal("tţťŧṫṯẗ", tolower("tţťŧṫṯẗ"))
  call assert_equal("uùúûüũūŭůűųưǔủ", tolower("uùúûüũūŭůűųưǔủ"))
  call assert_equal("vṽ", tolower("vṽ"))
  call assert_equal("wŵẁẃẅẇẘ", tolower("wŵẁẃẅẇẘ"))
  call assert_equal("ẋẍ", tolower("ẋẍ"))
  call assert_equal("yýÿŷẏẙỳỷỹ", tolower("yýÿŷẏẙỳỷỹ"))
  call assert_equal("zźżžƶẑẕ", tolower("zźżžƶẑẕ"))

  " According to https://twitter.com/jifa/status/625776454479970304
  " Ⱥ (U+023A) and Ⱦ (U+023E) are the *only* code points to increase
  " in length (2 to 3 bytes) when lowercased. So let's test them.
  call assert_equal("ⱥ ⱦ", tolower("Ⱥ Ⱦ"))
endfunc

func Test_toupper()
  call assert_equal("", toupper(""))

  " Test with all printable ASCII characters.
  call assert_equal(' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`ABCDEFGHIJKLMNOPQRSTUVWXYZ{|}~',
          \ toupper(' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~'))

  if !has('multi_byte')
    return
  endif

  " Test with a few lowercase diacritics.
  call assert_equal("AÀÁÂÃÄÅĀĂĄǍǞǠẢ", toupper("aàáâãäåāăąǎǟǡả"))
  call assert_equal("BḂḆ", toupper("bḃḇ"))
  call assert_equal("CÇĆĈĊČ", toupper("cçćĉċč"))
  call assert_equal("DĎĐḊḎḐ", toupper("dďđḋḏḑ"))
  call assert_equal("EÈÉÊËĒĔĖĘĚẺẼ", toupper("eèéêëēĕėęěẻẽ"))
  call assert_equal("FḞ", toupper("fḟ"))
  call assert_equal("GĜĞĠĢǤǦǴḠ", toupper("gĝğġģǥǧǵḡ"))
  call assert_equal("HĤĦḢḦḨẖ", toupper("hĥħḣḧḩẖ"))
  call assert_equal("IÌÍÎÏĨĪĬĮǏỈ", toupper("iìíîïĩīĭįǐỉ"))
  call assert_equal("JĴǰ", toupper("jĵǰ"))
  call assert_equal("KĶǨḰḴ", toupper("kķǩḱḵ"))
  call assert_equal("LĹĻĽĿŁḺ", toupper("lĺļľŀłḻ"))
  call assert_equal("MḾṀ ", toupper("mḿṁ "))
  call assert_equal("NÑŃŅŇŉṄṈ", toupper("nñńņňŉṅṉ"))
  call assert_equal("OÒÓÔÕÖØŌŎŐƠǑǪǬỎ", toupper("oòóôõöøōŏőơǒǫǭỏ"))
  call assert_equal("PṔṖ", toupper("pṕṗ"))
  call assert_equal("Q", toupper("q"))
  call assert_equal("RŔŖŘṘṞ", toupper("rŕŗřṙṟ"))
  call assert_equal("SŚŜŞŠṠ", toupper("sśŝşšṡ"))
  call assert_equal("TŢŤŦṪṮẗ", toupper("tţťŧṫṯẗ"))
  call assert_equal("UÙÚÛÜŨŪŬŮŰŲƯǓỦ", toupper("uùúûüũūŭůűųưǔủ"))
  call assert_equal("VṼ", toupper("vṽ"))
  call assert_equal("WŴẀẂẄẆẘ", toupper("wŵẁẃẅẇẘ"))
  call assert_equal("ẊẌ", toupper("ẋẍ"))
  call assert_equal("YÝŸŶẎẙỲỶỸ", toupper("yýÿŷẏẙỳỷỹ"))
  call assert_equal("ZŹŻŽƵẐẔ", toupper("zźżžƶẑẕ"))

  " Test that uppercase diacritics, which should remain unchanged.
  call assert_equal("AÀÁÂÃÄÅĀĂĄǍǞǠẢ", toupper("AÀÁÂÃÄÅĀĂĄǍǞǠẢ"))
  call assert_equal("BḂḆ", toupper("BḂḆ"))
  call assert_equal("CÇĆĈĊČ", toupper("CÇĆĈĊČ"))
  call assert_equal("DĎĐḊḎḐ", toupper("DĎĐḊḎḐ"))
  call assert_equal("EÈÉÊËĒĔĖĘĚẺẼ", toupper("EÈÉÊËĒĔĖĘĚẺẼ"))
  call assert_equal("FḞ ", toupper("FḞ "))
  call assert_equal("GĜĞĠĢǤǦǴḠ", toupper("GĜĞĠĢǤǦǴḠ"))
  call assert_equal("HĤĦḢḦḨ", toupper("HĤĦḢḦḨ"))
  call assert_equal("IÌÍÎÏĨĪĬĮİǏỈ", toupper("IÌÍÎÏĨĪĬĮİǏỈ"))
  call assert_equal("JĴ", toupper("JĴ"))
  call assert_equal("KĶǨḰḴ", toupper("KĶǨḰḴ"))
  call assert_equal("LĹĻĽĿŁḺ", toupper("LĹĻĽĿŁḺ"))
  call assert_equal("MḾṀ", toupper("MḾṀ"))
  call assert_equal("NÑŃŅŇṄṈ", toupper("NÑŃŅŇṄṈ"))
  call assert_equal("OÒÓÔÕÖØŌŎŐƠǑǪǬỎ", toupper("OÒÓÔÕÖØŌŎŐƠǑǪǬỎ"))
  call assert_equal("PṔṖ", toupper("PṔṖ"))
  call assert_equal("Q", toupper("Q"))
  call assert_equal("RŔŖŘṘṞ", toupper("RŔŖŘṘṞ"))
  call assert_equal("SŚŜŞŠṠ", toupper("SŚŜŞŠṠ"))
  call assert_equal("TŢŤŦṪṮ", toupper("TŢŤŦṪṮ"))
  call assert_equal("UÙÚÛÜŨŪŬŮŰŲƯǓỦ", toupper("UÙÚÛÜŨŪŬŮŰŲƯǓỦ"))
  call assert_equal("VṼ", toupper("VṼ"))
  call assert_equal("WŴẀẂẄẆ", toupper("WŴẀẂẄẆ"))
  call assert_equal("XẊẌ", toupper("XẊẌ"))
  call assert_equal("YÝŶŸẎỲỶỸ", toupper("YÝŶŸẎỲỶỸ"))
  call assert_equal("ZŹŻŽƵẐẔ", toupper("ZŹŻŽƵẐẔ"))

  call assert_equal("ⱥ ⱦ", tolower("Ⱥ Ⱦ"))
endfunc

" Tests for the mode() function
let current_modes = ''
func! Save_mode()
  let g:current_modes = mode(0) . '-' . mode(1)
  return ''
endfunc

func! Test_mode()
  new
  call append(0, ["Blue Ball Black", "Brown Band Bowl", ""])

  inoremap <F2> <C-R>=Save_mode()<CR>

  normal! 3G
  exe "normal i\<F2>\<Esc>"
  call assert_equal('i-i', g:current_modes)
  " i_CTRL-P: Multiple matches
  exe "normal i\<C-G>uBa\<C-P>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)
  " i_CTRL-P: Single match
  exe "normal iBro\<C-P>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)
  " i_CTRL-X
  exe "normal iBa\<C-X>\<F2>\<Esc>u"
  call assert_equal('i-ix', g:current_modes)
  " i_CTRL-X CTRL-P: Multiple matches
  exe "normal iBa\<C-X>\<C-P>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)
  " i_CTRL-X CTRL-P: Single match
  exe "normal iBro\<C-X>\<C-P>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)
  " i_CTRL-X CTRL-P + CTRL-P: Single match
  exe "normal iBro\<C-X>\<C-P>\<C-P>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)
  " i_CTRL-X CTRL-L: Multiple matches
  exe "normal i\<C-X>\<C-L>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)
  " i_CTRL-X CTRL-L: Single match
  exe "normal iBlu\<C-X>\<C-L>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)
  " i_CTRL-P: No match
  exe "normal iCom\<C-P>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)
  " i_CTRL-X CTRL-P: No match
  exe "normal iCom\<C-X>\<C-P>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)
  " i_CTRL-X CTRL-L: No match
  exe "normal iabc\<C-X>\<C-L>\<F2>\<Esc>u"
  call assert_equal('i-ic', g:current_modes)

  " R_CTRL-P: Multiple matches
  exe "normal RBa\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)
  " R_CTRL-P: Single match
  exe "normal RBro\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)
  " R_CTRL-X
  exe "normal RBa\<C-X>\<F2>\<Esc>u"
  call assert_equal('R-Rx', g:current_modes)
  " R_CTRL-X CTRL-P: Multiple matches
  exe "normal RBa\<C-X>\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)
  " R_CTRL-X CTRL-P: Single match
  exe "normal RBro\<C-X>\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)
  " R_CTRL-X CTRL-P + CTRL-P: Single match
  exe "normal RBro\<C-X>\<C-P>\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)
  " R_CTRL-X CTRL-L: Multiple matches
  exe "normal R\<C-X>\<C-L>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)
  " R_CTRL-X CTRL-L: Single match
  exe "normal RBlu\<C-X>\<C-L>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)
  " R_CTRL-P: No match
  exe "normal RCom\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)
  " R_CTRL-X CTRL-P: No match
  exe "normal RCom\<C-X>\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)
  " R_CTRL-X CTRL-L: No match
  exe "normal Rabc\<C-X>\<C-L>\<F2>\<Esc>u"
  call assert_equal('R-Rc', g:current_modes)

  call assert_equal('n', mode(0))
  call assert_equal('n', mode(1))

  " How to test operator-pending mode?

  call feedkeys("v", 'xt')
  call assert_equal('v', mode())
  call assert_equal('v', mode(1))
  call feedkeys("\<Esc>V", 'xt')
  call assert_equal('V', mode())
  call assert_equal('V', mode(1))
  call feedkeys("\<Esc>\<C-V>", 'xt')
  call assert_equal("\<C-V>", mode())
  call assert_equal("\<C-V>", mode(1))
  call feedkeys("\<Esc>", 'xt')

  call feedkeys("gh", 'xt')
  call assert_equal('s', mode())
  call assert_equal('s', mode(1))
  call feedkeys("\<Esc>gH", 'xt')
  call assert_equal('S', mode())
  call assert_equal('S', mode(1))
  call feedkeys("\<Esc>g\<C-H>", 'xt')
  call assert_equal("\<C-S>", mode())
  call assert_equal("\<C-S>", mode(1))
  call feedkeys("\<Esc>", 'xt')

  call feedkeys(":echo \<C-R>=Save_mode()\<C-U>\<CR>", 'xt')
  call assert_equal('c-c', g:current_modes)
  call feedkeys("gQecho \<C-R>=Save_mode()\<CR>\<CR>vi\<CR>", 'xt')
  call assert_equal('c-cv', g:current_modes)
  " How to test Ex mode?

  bwipe!
  iunmap <F2>
endfunc

func Test_getbufvar()
  let bnr = bufnr('%')
  let b:var_num = '1234'
  let def_num = '5678'
  call assert_equal('1234', getbufvar(bnr, 'var_num'))
  call assert_equal('1234', getbufvar(bnr, 'var_num', def_num))

  let bd = getbufvar(bnr, '')
  call assert_equal('1234', bd['var_num'])
  call assert_true(exists("bd['changedtick']"))
  call assert_equal(2, len(bd))

  let bd2 = getbufvar(bnr, '', def_num)
  call assert_equal(bd, bd2)

  unlet b:var_num
  call assert_equal(def_num, getbufvar(bnr, 'var_num', def_num))
  call assert_equal('', getbufvar(bnr, 'var_num'))

  let bd = getbufvar(bnr, '')
  call assert_equal(1, len(bd))
  let bd = getbufvar(bnr, '',def_num)
  call assert_equal(1, len(bd))

  call assert_equal('', getbufvar(9999, ''))
  call assert_equal(def_num, getbufvar(9999, '', def_num))
  unlet def_num

  call assert_equal(0, getbufvar(bnr, '&autoindent'))
  call assert_equal(0, getbufvar(bnr, '&autoindent', 1))

  " Open new window with forced option values
  set fileformats=unix,dos
  new ++ff=dos ++bin ++enc=iso-8859-2
  call assert_equal('dos', getbufvar(bufnr('%'), '&fileformat'))
  call assert_equal(1, getbufvar(bufnr('%'), '&bin'))
  call assert_equal('iso-8859-2', getbufvar(bufnr('%'), '&fenc'))
  close

  set fileformats&
endfunc
