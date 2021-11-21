" Tests for various functions.

source shared.vim
source check.vim

" Must be done first, since the alternate buffer must be unset.
func Test_00_bufexists()
  call assert_equal(0, bufexists('does_not_exist'))
  call assert_equal(1, bufexists(bufnr('%')))
  call assert_equal(0, bufexists(0))
  new Xfoo
  let bn = bufnr('%')
  call assert_equal(1, bufexists(bn))
  call assert_equal(1, bufexists('Xfoo'))
  call assert_equal(1, bufexists(getcwd() . '/Xfoo'))
  call assert_equal(1, bufexists(0))
  bw
  call assert_equal(0, bufexists(bn))
  call assert_equal(0, bufexists('Xfoo'))
endfunc

func Test_empty()
  call assert_equal(1, empty(''))
  call assert_equal(0, empty('a'))

  call assert_equal(1, empty(0))
  call assert_equal(1, empty(-0))
  call assert_equal(0, empty(1))
  call assert_equal(0, empty(-1))

  if has('float')
    call assert_equal(1, empty(0.0))
    call assert_equal(1, empty(-0.0))
    call assert_equal(0, empty(1.0))
    call assert_equal(0, empty(-1.0))
    call assert_equal(0, empty(1.0/0.0))
    call assert_equal(0, empty(0.0/0.0))
  endif

  call assert_equal(1, empty([]))
  call assert_equal(0, empty(['a']))

  call assert_equal(1, empty({}))
  call assert_equal(0, empty({'a':1}))

  call assert_equal(1, empty(v:null))
  " call assert_equal(1, empty(v:none))
  call assert_equal(1, empty(v:false))
  call assert_equal(0, empty(v:true))

  if has('channel')
    call assert_equal(1, empty(test_null_channel()))
  endif
  if has('job')
    call assert_equal(1, empty(test_null_job()))
  endif

  call assert_equal(0, empty(function('Test_empty')))
  call assert_equal(0, empty(function('Test_empty', [0])))
endfunc

func Test_len()
  call assert_equal(1, len(0))
  call assert_equal(2, len(12))

  call assert_equal(0, len(''))
  call assert_equal(2, len('ab'))

  call assert_equal(0, len([]))
  call assert_equal(2, len([2, 1]))

  call assert_equal(0, len({}))
  call assert_equal(2, len({'a': 1, 'b': 2}))

  " call assert_fails('call len(v:none)', 'E701:')
  call assert_fails('call len({-> 0})', 'E701:')
endfunc

func Test_max()
  call assert_equal(0, max([]))
  call assert_equal(2, max([2]))
  call assert_equal(2, max([1, 2]))
  call assert_equal(2, max([1, 2, v:null]))

  call assert_equal(0, max({}))
  call assert_equal(2, max({'a':1, 'b':2}))

  call assert_fails('call max(1)', 'E712:')
  " call assert_fails('call max(v:none)', 'E712:')
endfunc

func Test_min()
  call assert_equal(0, min([]))
  call assert_equal(2, min([2]))
  call assert_equal(1, min([1, 2]))
  call assert_equal(0, min([1, 2, v:null]))

  call assert_equal(0, min({}))
  call assert_equal(1, min({'a':1, 'b':2}))

  call assert_fails('call min(1)', 'E712:')
  " call assert_fails('call min(v:none)', 'E712:')
endfunc

func Test_strwidth()
  for aw in ['single', 'double']
    exe 'set ambiwidth=' . aw
    call assert_equal(0, strwidth(''))
    call assert_equal(1, strwidth("\t"))
    call assert_equal(3, strwidth('Vim'))
    call assert_equal(4, strwidth(1234))
    call assert_equal(5, strwidth(-1234))

    call assert_equal(2, strwidth('😉'))
    call assert_equal(17, strwidth('Eĥoŝanĝo ĉiuĵaŭde'))
    call assert_equal((aw == 'single') ? 6 : 7, strwidth('Straße'))

    call assert_fails('call strwidth({->0})', 'E729:')
    call assert_fails('call strwidth([])', 'E730:')
    call assert_fails('call strwidth({})', 'E731:')
    if has('float')
      call assert_fails('call strwidth(1.2)', 'E806:')
    endif
  endfor

  set ambiwidth&
endfunc

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

  call assert_equal(5, str2nr('101', 2))
  call assert_equal(5, str2nr('0b101', 2))
  call assert_equal(5, str2nr('0B101', 2))
  call assert_equal(-5, str2nr('-101', 2))
  call assert_equal(-5, str2nr('-0b101', 2))
  call assert_equal(-5, str2nr('-0B101', 2))

  call assert_equal(65, str2nr('101', 8))
  call assert_equal(65, str2nr('0101', 8))
  call assert_equal(-65, str2nr('-101', 8))
  call assert_equal(-65, str2nr('-0101', 8))
  call assert_equal(65, str2nr('0o101', 8))
  call assert_equal(65, str2nr('0O0101', 8))
  call assert_equal(-65, str2nr('-0O101', 8))
  call assert_equal(-65, str2nr('-0o0101', 8))

  call assert_equal(11259375, str2nr('abcdef', 16))
  call assert_equal(11259375, str2nr('ABCDEF', 16))
  call assert_equal(-11259375, str2nr('-ABCDEF', 16))
  call assert_equal(11259375, str2nr('0xabcdef', 16))
  call assert_equal(11259375, str2nr('0Xabcdef', 16))
  call assert_equal(11259375, str2nr('0XABCDEF', 16))
  call assert_equal(-11259375, str2nr('-0xABCDEF', 16))

  call assert_equal(1, str2nr("1'000'000", 10, 0))
  call assert_equal(256, str2nr("1'0000'0000", 2, 1))
  call assert_equal(262144, str2nr("1'000'000", 8, 1))
  call assert_equal(1000000, str2nr("1'000'000", 10, 1))
  call assert_equal(1000, str2nr("1'000''000", 10, 1))
  call assert_equal(65536, str2nr("1'00'00", 16, 1))

  call assert_equal(0, str2nr('0x10'))
  call assert_equal(0, str2nr('0b10'))
  call assert_equal(0, str2nr('0o10'))
  call assert_equal(1, str2nr('12', 2))
  call assert_equal(1, str2nr('18', 8))
  call assert_equal(1, str2nr('1g', 16))

  call assert_equal(0, str2nr(v:null))
  " call assert_equal(0, str2nr(v:none))

  call assert_fails('call str2nr([])', 'E730:')
  call assert_fails('call str2nr({->2})', 'E729:')
  call assert_fails('call str2nr(1.2)', 'E806:')
  call assert_fails('call str2nr(10, [])', 'E474:')
endfunc

func Test_strftime()
  CheckFunction strftime

  " Format of strftime() depends on system. We assume
  " that basic formats tested here are available and
  " identical on all systems which support strftime().
  "
  " The 2nd parameter of strftime() is a local time, so the output day
  " of strftime() can be 17 or 18, depending on timezone.
  call assert_match('^2017-01-1[78]$', strftime('%Y-%m-%d', 1484695512))
  "
  call assert_match('^\d\d\d\d-\(0\d\|1[012]\)-\([012]\d\|3[01]\) \([01]\d\|2[0-3]\):[0-5]\d:\([0-5]\d\|60\)$', strftime('%Y-%m-%d %H:%M:%S'))

  call assert_fails('call strftime([])', 'E730:')
  call assert_fails('call strftime("%Y", [])', 'E745:')

  " Check that the time changes after we change the timezone
  " Save previous timezone value, if any
  if exists('$TZ')
    let tz = $TZ
  endif

  " Force EST and then UTC, save the current hour (24-hour clock) for each
  let $TZ = 'EST' | let est = strftime('%H')
  let $TZ = 'UTC' | let utc = strftime('%H')

  " Those hours should be two bytes long, and should not be the same; if they
  " are, a tzset(3) call may have failed somewhere
  call assert_equal(strlen(est), 2)
  call assert_equal(strlen(utc), 2)
  " TODO: this fails on MS-Windows
  if has('unix')
    call assert_notequal(est, utc)
  endif

  " If we cached a timezone value, put it back, otherwise clear it
  if exists('tz')
    let $TZ = tz
  else
    unlet $TZ
  endif
endfunc

func Test_strptime()
  CheckFunction strptime
  CheckNotMSWindows

  if exists('$TZ')
    let tz = $TZ
  endif
  let $TZ = 'UTC'

  call assert_equal(1484653763, strptime('%Y-%m-%d %T', '2017-01-17 11:49:23'))

  " Force DST and check that it's considered
  let $TZ = 'WINTER0SUMMER,J1,J365'
  call assert_equal(1484653763 - 3600, strptime('%Y-%m-%d %T', '2017-01-17 11:49:23'))

  call assert_fails('call strptime()', 'E119:')
  call assert_fails('call strptime("xxx")', 'E119:')
  call assert_equal(0, strptime("%Y", ''))
  call assert_equal(0, strptime("%Y", "xxx"))

  if exists('tz')
    let $TZ = tz
  else
    unlet $TZ
  endif
endfunc

func Test_resolve_unix()
  if !has('unix')
    return
  endif

  " Xlink1 -> Xlink2
  " Xlink2 -> Xlink3
  silent !ln -s -f Xlink2 Xlink1
  silent !ln -s -f Xlink3 Xlink2
  call assert_equal('Xlink3', resolve('Xlink1'))
  call assert_equal('./Xlink3', resolve('./Xlink1'))
  call assert_equal('Xlink3/', resolve('Xlink2/'))
  " FIXME: these tests result in things like "Xlink2/" instead of "Xlink3/"?!
  "call assert_equal('Xlink3/', resolve('Xlink1/'))
  "call assert_equal('./Xlink3/', resolve('./Xlink1/'))
  "call assert_equal(getcwd() . '/Xlink3/', resolve(getcwd() . '/Xlink1/'))
  call assert_equal(getcwd() . '/Xlink3', resolve(getcwd() . '/Xlink1'))

  " Test resolve() with a symlink cycle.
  " Xlink1 -> Xlink2
  " Xlink2 -> Xlink3
  " Xlink3 -> Xlink1
  silent !ln -s -f Xlink1 Xlink3
  call assert_fails('call resolve("Xlink1")',   'E655:')
  call assert_fails('call resolve("./Xlink1")', 'E655:')
  call assert_fails('call resolve("Xlink2")',   'E655:')
  call assert_fails('call resolve("Xlink3")',   'E655:')
  call delete('Xlink1')
  call delete('Xlink2')
  call delete('Xlink3')

  silent !ln -s -f Xdir//Xfile Xlink
  call assert_equal('Xdir/Xfile', resolve('Xlink'))
  call delete('Xlink')

  silent !ln -s -f Xlink2/ Xlink1
  call assert_equal('Xlink2', 'Xlink1'->resolve())
  call assert_equal('Xlink2/', resolve('Xlink1/'))
  call delete('Xlink1')

  silent !ln -s -f ./Xlink2 Xlink1
  call assert_equal('Xlink2', resolve('Xlink1'))
  call assert_equal('./Xlink2', resolve('./Xlink1'))
  call delete('Xlink1')

  call assert_equal('/', resolve('/'))
endfunc

func Test_simplify()
  call assert_equal('',            simplify(''))
  call assert_equal('/',           simplify('/'))
  call assert_equal('/',           simplify('/.'))
  call assert_equal('/',           simplify('/..'))
  call assert_equal('/...',        simplify('/...'))
  call assert_equal('./dir/file',  simplify('./dir/file'))
  call assert_equal('./dir/file',  simplify('.///dir//file'))
  call assert_equal('./dir/file',  simplify('./dir/./file'))
  call assert_equal('./file',      simplify('./dir/../file'))
  call assert_equal('../dir/file', simplify('dir/../../dir/file'))
  call assert_equal('./file',      simplify('dir/.././file'))

  call assert_fails('call simplify({->0})', 'E729:')
  call assert_fails('call simplify([])', 'E730:')
  call assert_fails('call simplify({})', 'E731:')
  call assert_fails('call simplify(1.2)', 'E806:')
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
  let wh = winheight(0)
  let dummy_buf = bufnr('dummy_buf1', v:true)
  call setbufvar(dummy_buf, '&buftype', 'nofile')
  execute 'belowright vertical split #' . dummy_buf
  call assert_equal(wh, winheight(0))
  let dum1_id = win_getid()

  wincmd h
  let wh = winheight(0)
  let dummy_buf = bufnr('dummy_buf2', v:true)
  call setbufvar(dummy_buf, '&buftype', 'nofile')
  execute 'belowright vertical split #' . dummy_buf
  call assert_equal(wh, winheight(0))

  bwipe!
  call win_gotoid(prev_id)
  bwipe!
  call win_gotoid(dum1_id)
  bwipe!
endfunc

func Test_pathshorten()
  call assert_equal('', pathshorten(''))
  call assert_equal('foo', pathshorten('foo'))
  call assert_equal('/foo', '/foo'->pathshorten())
  call assert_equal('f/', pathshorten('foo/'))
  call assert_equal('f/bar', pathshorten('foo/bar'))
  call assert_equal('f/b/foobar', 'foo/bar/foobar'->pathshorten())
  call assert_equal('/f/b/foobar', pathshorten('/foo/bar/foobar'))
  call assert_equal('.f/bar', pathshorten('.foo/bar'))
  call assert_equal('~f/bar', pathshorten('~foo/bar'))
  call assert_equal('~.f/bar', pathshorten('~.foo/bar'))
  call assert_equal('.~f/bar', pathshorten('.~foo/bar'))
  call assert_equal('~/f/bar', pathshorten('~/foo/bar'))
endfunc

func Test_strpart()
  call assert_equal('de', strpart('abcdefg', 3, 2))
  call assert_equal('ab', strpart('abcdefg', -2, 4))
  call assert_equal('abcdefg', strpart('abcdefg', -2))
  call assert_equal('fg', strpart('abcdefg', 5, 4))
  call assert_equal('defg', strpart('abcdefg', 3))

  call assert_equal('lép', strpart('éléphant', 2, 4))
  call assert_equal('léphant', strpart('éléphant', 2))

  call assert_equal('é', strpart('éléphant', 0, 1, 1))
  call assert_equal('ép', strpart('éléphant', 3, 2, v:true))
  call assert_equal('ó', strpart('cómposed', 1, 1, 1))
endfunc

func Test_tolower()
  call assert_equal("", tolower(""))

  " Test with all printable ASCII characters.
  call assert_equal(' !"#$%&''()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\]^_`abcdefghijklmnopqrstuvwxyz{|}~',
          \ tolower(' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~'))

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

  " This call to tolower with invalid utf8 sequence used to cause access to
  " invalid memory.
  call tolower("\xC0\x80\xC0")
  call tolower("123\xC0\x80\xC0")
endfunc

func Test_toupper()
  call assert_equal("", toupper(""))

  " Test with all printable ASCII characters.
  call assert_equal(' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`ABCDEFGHIJKLMNOPQRSTUVWXYZ{|}~',
          \ toupper(' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~'))

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

  call assert_equal("Ⱥ Ⱦ", toupper("ⱥ ⱦ"))

  " This call to toupper with invalid utf8 sequence used to cause access to
  " invalid memory.
  call toupper("\xC0\x80\xC0")
  call toupper("123\xC0\x80\xC0")
endfunc

" Tests for the mode() function
let current_modes = ''
func Save_mode()
  let g:current_modes = mode(0) . '-' . mode(1)
  return ''
endfunc

func Test_mode()
  new
  call append(0, ["Blue Ball Black", "Brown Band Bowl", ""])

  " Only complete from the current buffer.
  set complete=.

  inoremap <F2> <C-R>=Save_mode()<CR>
  xnoremap <F2> <Cmd>call Save_mode()<CR>

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

  exe "normal R\<F2>\<Esc>"
  call assert_equal('R-R', g:current_modes)
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

  exe "normal gR\<F2>\<Esc>"
  call assert_equal('R-Rv', g:current_modes)
  " gR_CTRL-P: Multiple matches
  exe "normal gRBa\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)
  " gR_CTRL-P: Single match
  exe "normal gRBro\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)
  " gR_CTRL-X
  exe "normal gRBa\<C-X>\<F2>\<Esc>u"
  call assert_equal('R-Rvx', g:current_modes)
  " gR_CTRL-X CTRL-P: Multiple matches
  exe "normal gRBa\<C-X>\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)
  " gR_CTRL-X CTRL-P: Single match
  exe "normal gRBro\<C-X>\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)
  " gR_CTRL-X CTRL-P + CTRL-P: Single match
  exe "normal gRBro\<C-X>\<C-P>\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)
  " gR_CTRL-X CTRL-L: Multiple matches
  exe "normal gR\<C-X>\<C-L>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)
  " gR_CTRL-X CTRL-L: Single match
  exe "normal gRBlu\<C-X>\<C-L>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)
  " gR_CTRL-P: No match
  exe "normal gRCom\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)
  " gR_CTRL-X CTRL-P: No match
  exe "normal gRCom\<C-X>\<C-P>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)
  " gR_CTRL-X CTRL-L: No match
  exe "normal gRabc\<C-X>\<C-L>\<F2>\<Esc>u"
  call assert_equal('R-Rvc', g:current_modes)

  call assert_equal('n', 0->mode())
  call assert_equal('n', 1->mode())

  " i_CTRL-O
  exe "normal i\<C-O>:call Save_mode()\<Cr>\<Esc>"
  call assert_equal("n-niI", g:current_modes)

  " R_CTRL-O
  exe "normal R\<C-O>:call Save_mode()\<Cr>\<Esc>"
  call assert_equal("n-niR", g:current_modes)

  " gR_CTRL-O
  exe "normal gR\<C-O>:call Save_mode()\<Cr>\<Esc>"
  call assert_equal("n-niV", g:current_modes)

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

  " v_CTRL-O
  exe "normal gh\<C-O>\<F2>\<Esc>"
  call assert_equal("v-vs", g:current_modes)
  exe "normal gH\<C-O>\<F2>\<Esc>"
  call assert_equal("V-Vs", g:current_modes)
  exe "normal g\<C-H>\<C-O>\<F2>\<Esc>"
  call assert_equal("\<C-V>-\<C-V>s", g:current_modes)

  call feedkeys(":echo \<C-R>=Save_mode()\<C-U>\<CR>", 'xt')
  call assert_equal('c-c', g:current_modes)
  call feedkeys("gQecho \<C-R>=Save_mode()\<CR>\<CR>vi\<CR>", 'xt')
  call assert_equal('c-cv', g:current_modes)
  " How to test Ex mode?

  " Test mode in operatorfunc (it used to be Operator-pending).
  set operatorfunc=OperatorFunc
  function OperatorFunc(_)
    call Save_mode()
  endfunction
  execute "normal! g@l\<Esc>"
  call assert_equal('n-n', g:current_modes)
  execute "normal! i\<C-o>g@l\<Esc>"
  call assert_equal('n-niI', g:current_modes)
  execute "normal! R\<C-o>g@l\<Esc>"
  call assert_equal('n-niR', g:current_modes)
  execute "normal! gR\<C-o>g@l\<Esc>"
  call assert_equal('n-niV', g:current_modes)

  if has('terminal')
    term
    call feedkeys("\<C-W>N", 'xt')
    call assert_equal('n', mode())
    call assert_equal('nt', mode(1))
    call feedkeys("aexit\<CR>", 'xt')
  endif

  bwipe!
  iunmap <F2>
  xunmap <F2>
  set complete&
  set operatorfunc&
  delfunction OperatorFunc
endfunc

func Test_append()
  enew!
  split
  call append(0, ["foo"])
  split
  only
  undo
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

  " Get the b: dict.
  let b:testvar = 'one'
  new
  let b:testvar = 'two'
  let thebuf = bufnr()
  wincmd w
  call assert_equal('two', getbufvar(thebuf, 'testvar'))
  call assert_equal('two', getbufvar(thebuf, '').testvar)
  bwipe!

  set fileformats&
endfunc

func Test_last_buffer_nr()
  call assert_equal(bufnr('$'), last_buffer_nr())
endfunc

func Test_stridx()
  call assert_equal(-1, stridx('', 'l'))
  call assert_equal(0,  stridx('', ''))
  call assert_equal(0,  stridx('hello', ''))
  call assert_equal(-1, stridx('hello', 'L'))
  call assert_equal(2,  stridx('hello', 'l', -1))
  call assert_equal(2,  stridx('hello', 'l', 0))
  call assert_equal(2,  stridx('hello', 'l', 1))
  call assert_equal(3,  stridx('hello', 'l', 3))
  call assert_equal(-1, stridx('hello', 'l', 4))
  call assert_equal(-1, stridx('hello', 'l', 10))
  call assert_equal(2,  stridx('hello', 'll'))
  call assert_equal(-1, stridx('hello', 'hello world'))
endfunc

func Test_strridx()
  call assert_equal(-1, strridx('', 'l'))
  call assert_equal(0,  strridx('', ''))
  call assert_equal(5,  strridx('hello', ''))
  call assert_equal(-1, strridx('hello', 'L'))
  call assert_equal(3,  strridx('hello', 'l'))
  call assert_equal(3,  strridx('hello', 'l', 10))
  call assert_equal(3,  strridx('hello', 'l', 3))
  call assert_equal(2,  strridx('hello', 'l', 2))
  call assert_equal(-1, strridx('hello', 'l', 1))
  call assert_equal(-1, strridx('hello', 'l', 0))
  call assert_equal(-1, strridx('hello', 'l', -1))
  call assert_equal(2,  strridx('hello', 'll'))
  call assert_equal(-1, strridx('hello', 'hello world'))
endfunc

func Test_match_func()
  call assert_equal(4,  match('testing', 'ing'))
  call assert_equal(4,  'testing'->match('ing', 2))
  call assert_equal(-1, match('testing', 'ing', 5))
  call assert_equal(-1, match('testing', 'ing', 8))
  call assert_equal(1, match(['vim', 'testing', 'execute'], 'ing'))
  call assert_equal(-1, match(['vim', 'testing', 'execute'], 'img'))
endfunc

func Test_matchend()
  call assert_equal(7,  matchend('testing', 'ing'))
  call assert_equal(7,  'testing'->matchend('ing', 2))
  call assert_equal(-1, matchend('testing', 'ing', 5))
  call assert_equal(-1, matchend('testing', 'ing', 8))
  call assert_equal(match(['vim', 'testing', 'execute'], 'ing'), matchend(['vim', 'testing', 'execute'], 'ing'))
  call assert_equal(match(['vim', 'testing', 'execute'], 'img'), matchend(['vim', 'testing', 'execute'], 'img'))
endfunc

func Test_matchlist()
  call assert_equal(['acd', 'a', '', 'c', 'd', '', '', '', '', ''],  matchlist('acd', '\(a\)\?\(b\)\?\(c\)\?\(.*\)'))
  call assert_equal(['d', '', '', '', 'd', '', '', '', '', ''],  'acd'->matchlist('\(a\)\?\(b\)\?\(c\)\?\(.*\)', 2))
  call assert_equal([],  matchlist('acd', '\(a\)\?\(b\)\?\(c\)\?\(.*\)', 4))
endfunc

func Test_matchstr()
  call assert_equal('ing',  matchstr('testing', 'ing'))
  call assert_equal('ing',  'testing'->matchstr('ing', 2))
  call assert_equal('', matchstr('testing', 'ing', 5))
  call assert_equal('', matchstr('testing', 'ing', 8))
  call assert_equal('testing', matchstr(['vim', 'testing', 'execute'], 'ing'))
  call assert_equal('', matchstr(['vim', 'testing', 'execute'], 'img'))
endfunc

func Test_matchstrpos()
  call assert_equal(['ing', 4, 7], matchstrpos('testing', 'ing'))
  call assert_equal(['ing', 4, 7], 'testing'->matchstrpos('ing', 2))
  call assert_equal(['', -1, -1], matchstrpos('testing', 'ing', 5))
  call assert_equal(['', -1, -1], matchstrpos('testing', 'ing', 8))
  call assert_equal(['ing', 1, 4, 7], matchstrpos(['vim', 'testing', 'execute'], 'ing'))
  call assert_equal(['', -1, -1, -1], matchstrpos(['vim', 'testing', 'execute'], 'img'))
endfunc

func Test_nextnonblank_prevnonblank()
  new
insert
This


is

a
Test
.
  call assert_equal(0, nextnonblank(-1))
  call assert_equal(0, nextnonblank(0))
  call assert_equal(1, nextnonblank(1))
  call assert_equal(4, 2->nextnonblank())
  call assert_equal(4, nextnonblank(3))
  call assert_equal(4, nextnonblank(4))
  call assert_equal(6, nextnonblank(5))
  call assert_equal(6, nextnonblank(6))
  call assert_equal(7, nextnonblank(7))
  call assert_equal(0, 8->nextnonblank())

  call assert_equal(0, prevnonblank(-1))
  call assert_equal(0, prevnonblank(0))
  call assert_equal(1, 1->prevnonblank())
  call assert_equal(1, prevnonblank(2))
  call assert_equal(1, prevnonblank(3))
  call assert_equal(4, prevnonblank(4))
  call assert_equal(4, 5->prevnonblank())
  call assert_equal(6, prevnonblank(6))
  call assert_equal(7, prevnonblank(7))
  call assert_equal(0, prevnonblank(8))
  bw!
endfunc

func Test_byte2line_line2byte()
  new
  set endofline
  call setline(1, ['a', 'bc', 'd'])

  set fileformat=unix
  call assert_equal([-1, -1, 1, 1, 2, 2, 2, 3, 3, -1],
  \                 map(range(-1, 8), 'byte2line(v:val)'))
  call assert_equal([-1, -1, 1, 3, 6, 8, -1],
  \                 map(range(-1, 5), 'line2byte(v:val)'))

  set fileformat=mac
  call assert_equal([-1, -1, 1, 1, 2, 2, 2, 3, 3, -1],
  \                 map(range(-1, 8), 'v:val->byte2line()'))
  call assert_equal([-1, -1, 1, 3, 6, 8, -1],
  \                 map(range(-1, 5), 'v:val->line2byte()'))

  set fileformat=dos
  call assert_equal([-1, -1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, -1],
  \                 map(range(-1, 11), 'byte2line(v:val)'))
  call assert_equal([-1, -1, 1, 4, 8, 11, -1],
  \                 map(range(-1, 5), 'line2byte(v:val)'))

  bw!
  set noendofline nofixendofline
  normal a-
  for ff in ["unix", "mac", "dos"]
    let &fileformat = ff
    call assert_equal(1, line2byte(1))
    call assert_equal(2, line2byte(2))  " line2byte(line("$") + 1) is the buffer size plus one (as per :help line2byte).
  endfor

  set endofline& fixendofline& fileformat&
  bw!
endfunc

func Test_byteidx()
  let a = '.é.' " one char of two bytes
  call assert_equal(0, byteidx(a, 0))
  call assert_equal(0, byteidxcomp(a, 0))
  call assert_equal(1, byteidx(a, 1))
  call assert_equal(1, byteidxcomp(a, 1))
  call assert_equal(3, byteidx(a, 2))
  call assert_equal(3, byteidxcomp(a, 2))
  call assert_equal(4, byteidx(a, 3))
  call assert_equal(4, byteidxcomp(a, 3))
  call assert_equal(-1, byteidx(a, 4))
  call assert_equal(-1, byteidxcomp(a, 4))

  let b = '.é.' " normal e with composing char
  call assert_equal(0, b->byteidx(0))
  call assert_equal(1, b->byteidx(1))
  call assert_equal(4, b->byteidx(2))
  call assert_equal(5, b->byteidx(3))
  call assert_equal(-1, b->byteidx(4))

  call assert_equal(0, b->byteidxcomp(0))
  call assert_equal(1, b->byteidxcomp(1))
  call assert_equal(2, b->byteidxcomp(2))
  call assert_equal(4, b->byteidxcomp(3))
  call assert_equal(5, b->byteidxcomp(4))
  call assert_equal(-1, b->byteidxcomp(5))
endfunc

" Test for charidx()
func Test_charidx()
  let a = 'xáb́y'
  call assert_equal(0, charidx(a, 0))
  call assert_equal(1, charidx(a, 3))
  call assert_equal(2, charidx(a, 4))
  call assert_equal(3, charidx(a, 7))
  call assert_equal(-1, charidx(a, 8))
  call assert_equal(-1, charidx('', 0))

  " count composing characters
  call assert_equal(0, charidx(a, 0, 1))
  call assert_equal(2, charidx(a, 2, 1))
  call assert_equal(3, charidx(a, 4, 1))
  call assert_equal(5, charidx(a, 7, 1))
  call assert_equal(-1, charidx(a, 8, 1))
  call assert_equal(-1, charidx('', 0, 1))

  call assert_fails('let x = charidx([], 1)', 'E474:')
  call assert_fails('let x = charidx("abc", [])', 'E474:')
  call assert_fails('let x = charidx("abc", 1, [])', 'E474:')
  call assert_fails('let x = charidx("abc", 1, -1)', 'E474:')
  call assert_fails('let x = charidx("abc", 1, 2)', 'E474:')
endfunc

func Test_count()
  let l = ['a', 'a', 'A', 'b']
  call assert_equal(2, count(l, 'a'))
  call assert_equal(1, count(l, 'A'))
  call assert_equal(1, count(l, 'b'))
  call assert_equal(0, count(l, 'B'))

  call assert_equal(2, count(l, 'a', 0))
  call assert_equal(1, count(l, 'A', 0))
  call assert_equal(1, count(l, 'b', 0))
  call assert_equal(0, count(l, 'B', 0))

  call assert_equal(3, count(l, 'a', 1))
  call assert_equal(3, count(l, 'A', 1))
  call assert_equal(1, count(l, 'b', 1))
  call assert_equal(1, count(l, 'B', 1))
  call assert_equal(0, count(l, 'c', 1))

  call assert_equal(1, count(l, 'a', 0, 1))
  call assert_equal(2, count(l, 'a', 1, 1))
  call assert_fails('call count(l, "a", 0, 10)', 'E684:')
  call assert_fails('call count(l, "a", [])', 'E745:')

  let d = {1: 'a', 2: 'a', 3: 'A', 4: 'b'}
  call assert_equal(2, count(d, 'a'))
  call assert_equal(1, count(d, 'A'))
  call assert_equal(1, count(d, 'b'))
  call assert_equal(0, count(d, 'B'))

  call assert_equal(2, count(d, 'a', 0))
  call assert_equal(1, count(d, 'A', 0))
  call assert_equal(1, count(d, 'b', 0))
  call assert_equal(0, count(d, 'B', 0))

  call assert_equal(3, count(d, 'a', 1))
  call assert_equal(3, count(d, 'A', 1))
  call assert_equal(1, count(d, 'b', 1))
  call assert_equal(1, count(d, 'B', 1))
  call assert_equal(0, count(d, 'c', 1))

  call assert_fails('call count(d, "a", 0, 1)', 'E474:')

  call assert_equal(0, count("foo", "bar"))
  call assert_equal(1, count("foo", "oo"))
  call assert_equal(2, count("foo", "o"))
  call assert_equal(0, count("foo", "O"))
  call assert_equal(2, count("foo", "O", 1))
  call assert_equal(2, count("fooooo", "oo"))
  call assert_equal(0, count("foo", ""))

  call assert_fails('call count(0, 0)', 'E712:')
endfunc

func Test_changenr()
  new Xchangenr
  call assert_equal(0, changenr())
  norm ifoo
  call assert_equal(1, changenr())
  set undolevels=10
  norm Sbar
  call assert_equal(2, changenr())
  undo
  call assert_equal(1, changenr())
  redo
  call assert_equal(2, changenr())
  bw!
  set undolevels&
endfunc

func Test_filewritable()
  new Xfilewritable
  write!
  call assert_equal(1, filewritable('Xfilewritable'))

  call assert_notequal(0, setfperm('Xfilewritable', 'r--r-----'))
  call assert_equal(0, filewritable('Xfilewritable'))

  call assert_notequal(0, setfperm('Xfilewritable', 'rw-r-----'))
  call assert_equal(1, 'Xfilewritable'->filewritable())

  call assert_equal(0, filewritable('doesnotexist'))

  call delete('Xfilewritable')
  bw!
endfunc

func Test_Executable()
  if has('win32')
    call assert_equal(1, executable('notepad'))
    call assert_equal(1, 'notepad.exe'->executable())
    call assert_equal(0, executable('notepad.exe.exe'))
    call assert_equal(0, executable('shell32.dll'))
    call assert_equal(0, executable('win.ini'))
  elseif has('unix')
    call assert_equal(1, 'cat'->executable())
    call assert_equal(0, executable('nodogshere'))

    " get "cat" path and remove the leading /
    let catcmd = exepath('cat')[1:]
    new
    " check that the relative path works in /
    lcd /
    call assert_equal(1, executable(catcmd))
    let result = catcmd->exepath()
    " when using chroot looking for sbin/cat can return bin/cat, that is OK
    if catcmd =~ '\<sbin\>' && result =~ '\<bin\>'
      call assert_equal('/' .. substitute(catcmd, '\<sbin\>', 'bin', ''), result)
    else
      " /bin/cat and /usr/bin/cat may be hard linked, we could get either
      let result = substitute(result, '/usr/bin/cat', '/bin/cat', '')
      let catcmd = substitute(catcmd, 'usr/bin/cat', 'bin/cat', '')
      call assert_equal('/' .. catcmd, result)
    endif
    bwipe
  else
    throw 'Skipped: does not work on this platform'
  endif
endfunc

func Test_executable_longname()
  if !has('win32')
    return
  endif

  let fname = 'X' . repeat('あ', 200) . '.bat'
  call writefile([], fname)
  call assert_equal(1, executable(fname))
  call delete(fname)
endfunc

func Test_hostname()
  let hostname_vim = hostname()
  if has('unix')
    let hostname_system = systemlist('uname -n')[0]
    call assert_equal(hostname_vim, hostname_system)
  endif
endfunc

func Test_getpid()
  " getpid() always returns the same value within a vim instance.
  call assert_equal(getpid(), getpid())
  if has('unix')
    call assert_equal(systemlist('echo $PPID')[0], string(getpid()))
  endif
endfunc

func Test_hlexists()
  call assert_equal(0, hlexists('does_not_exist'))
  " call assert_equal(0, 'Number'->hlexists())
  call assert_equal(0, highlight_exists('does_not_exist'))
  " call assert_equal(0, highlight_exists('Number'))
  syntax on
  call assert_equal(0, hlexists('does_not_exist'))
  " call assert_equal(1, hlexists('Number'))
  call assert_equal(0, highlight_exists('does_not_exist'))
  " call assert_equal(1, highlight_exists('Number'))
  syntax off
endfunc

func Test_col()
  new
  call setline(1, 'abcdef')
  norm gg4|mx6|mY2|
  call assert_equal(2, col('.'))
  call assert_equal(7, col('$'))
  call assert_equal(4, col("'x"))
  call assert_equal(6, col("'Y"))
  call assert_equal(2, [1, 2]->col())
  call assert_equal(7, col([1, '$']))

  call assert_equal(0, col(''))
  call assert_equal(0, col('x'))
  call assert_equal(0, col([2, '$']))
  call assert_equal(0, col([1, 100]))
  call assert_equal(0, col([1]))
  bw!
endfunc

func Test_inputlist()
  call feedkeys(":let c = inputlist(['Select color:', '1. red', '2. green', '3. blue'])\<cr>1\<cr>", 'tx')
  call assert_equal(1, c)
  call feedkeys(":let c = ['Select color:', '1. red', '2. green', '3. blue']->inputlist()\<cr>2\<cr>", 'tx')
  call assert_equal(2, c)
  call feedkeys(":let c = inputlist(['Select color:', '1. red', '2. green', '3. blue'])\<cr>3\<cr>", 'tx')
  call assert_equal(3, c)

  " CR to cancel
  call feedkeys(":let c = inputlist(['Select color:', '1. red', '2. green', '3. blue'])\<cr>\<cr>", 'tx')
  call assert_equal(0, c)

  " Esc to cancel
  call feedkeys(":let c = inputlist(['Select color:', '1. red', '2. green', '3. blue'])\<cr>\<Esc>", 'tx')
  call assert_equal(0, c)

  " q to cancel
  call feedkeys(":let c = inputlist(['Select color:', '1. red', '2. green', '3. blue'])\<cr>q", 'tx')
  call assert_equal(0, c)

  " Cancel after inputting a number
  call feedkeys(":let c = inputlist(['Select color:', '1. red', '2. green', '3. blue'])\<cr>5q", 'tx')
  call assert_equal(0, c)

  call assert_fails('call inputlist("")', 'E686:')
endfunc

func Test_balloon_show()
  CheckFeature balloon_eval

  " This won't do anything but must not crash either.
  call balloon_show('hi!')
endfunc

func Test_shellescape()
  let save_shell = &shell
  set shell=bash
  call assert_equal("'text'", shellescape('text'))
  call assert_equal("'te\"xt'", shellescape('te"xt'))
  call assert_equal("'te'\\''xt'", shellescape("te'xt"))

  call assert_equal("'te%xt'", shellescape("te%xt"))
  call assert_equal("'te\\%xt'", shellescape("te%xt", 1))
  call assert_equal("'te#xt'", shellescape("te#xt"))
  call assert_equal("'te\\#xt'", shellescape("te#xt", 1))
  call assert_equal("'te!xt'", shellescape("te!xt"))
  call assert_equal("'te\\!xt'", shellescape("te!xt", 1))

  call assert_equal("'te\nxt'", shellescape("te\nxt"))
  call assert_equal("'te\\\nxt'", shellescape("te\nxt", 1))
  set shell=tcsh
  call assert_equal("'te\\!xt'", shellescape("te!xt"))
  call assert_equal("'te\\\\!xt'", shellescape("te!xt", 1))
  call assert_equal("'te\\\nxt'", shellescape("te\nxt"))
  call assert_equal("'te\\\\\nxt'", shellescape("te\nxt", 1))

  set shell=fish
  call assert_equal("'text'", shellescape('text'))
  call assert_equal("'te\"xt'", shellescape('te"xt'))
  call assert_equal("'te'\\''xt'", shellescape("te'xt"))

  call assert_equal("'te%xt'", shellescape("te%xt"))
  call assert_equal("'te\\%xt'", shellescape("te%xt", 1))
  call assert_equal("'te#xt'", shellescape("te#xt"))
  call assert_equal("'te\\#xt'", shellescape("te#xt", 1))
  call assert_equal("'te!xt'", shellescape("te!xt"))
  call assert_equal("'te\\!xt'", shellescape("te!xt", 1))

  call assert_equal("'te\\\\xt'", shellescape("te\\xt"))
  call assert_equal("'te\\\\xt'", shellescape("te\\xt", 1))
  call assert_equal("'te\\\\'\\''xt'", shellescape("te\\'xt"))
  call assert_equal("'te\\\\'\\''xt'", shellescape("te\\'xt", 1))
  call assert_equal("'te\\\\!xt'", shellescape("te\\!xt"))
  call assert_equal("'te\\\\\\!xt'", shellescape("te\\!xt", 1))
  call assert_equal("'te\\\\%xt'", shellescape("te\\%xt"))
  call assert_equal("'te\\\\\\%xt'", shellescape("te\\%xt", 1))
  call assert_equal("'te\\\\#xt'", shellescape("te\\#xt"))
  call assert_equal("'te\\\\\\#xt'", shellescape("te\\#xt", 1))

  let &shell = save_shell
endfunc

func Test_redo_in_nested_functions()
  nnoremap g. :set opfunc=Operator<CR>g@
  function Operator( type, ... )
     let @x = 'XXX'
     execute 'normal! g`[' . (a:type ==# 'line' ? 'V' : 'v') . 'g`]' . '"xp'
  endfunction

  function! Apply()
      5,6normal! .
  endfunction

  new
  call setline(1, repeat(['some "quoted" text', 'more "quoted" text'], 3))
  1normal g.i"
  call assert_equal('some "XXX" text', getline(1))
  3,4normal .
  call assert_equal('some "XXX" text', getline(3))
  call assert_equal('more "XXX" text', getline(4))
  call Apply()
  call assert_equal('some "XXX" text', getline(5))
  call assert_equal('more "XXX" text', getline(6))
  bwipe!

  nunmap g.
  delfunc Operator
  delfunc Apply
endfunc

func Test_trim()
  call assert_equal("Testing", trim("  \t\r\r\x0BTesting  \t\n\r\n\t\x0B\x0B"))
  call assert_equal("Testing", trim("  \t  \r\r\n\n\x0BTesting  \t\n\r\n\t\x0B\x0B"))
  call assert_equal("RESERVE", trim("xyz \twwRESERVEzyww \t\t", " wxyz\t"))
  call assert_equal("wRE    \tSERVEzyww", trim("wRE    \tSERVEzyww"))
  call assert_equal("abcd\t     xxxx   tail", trim(" \tabcd\t     xxxx   tail"))
  call assert_equal("\tabcd\t     xxxx   tail", trim(" \tabcd\t     xxxx   tail", " "))
  call assert_equal(" \tabcd\t     xxxx   tail", trim(" \tabcd\t     xxxx   tail", "abx"))
  call assert_equal("RESERVE", trim("你RESERVE好", "你好"))
  call assert_equal("您R E SER V E早", trim("你好您R E SER V E早好你你", "你好"))
  call assert_equal("你好您R E SER V E早好你你", trim(" \n\r\r   你好您R E SER V E早好你你    \t  \x0B", ))
  call assert_equal("您R E SER V E早好你你    \t  \x0B", trim("    你好您R E SER V E早好你你    \t  \x0B", " 你好"))
  call assert_equal("您R E SER V E早好你你    \t  \x0B", trim("    tteesstttt你好您R E SER V E早好你你    \t  \x0B ttestt", " 你好tes"))
  call assert_equal("您R E SER V E早好你你    \t  \x0B", trim("    tteesstttt你好您R E SER V E早好你你    \t  \x0B ttestt", "   你你你好好好tttsses"))
  call assert_equal("留下", trim("这些些不要这些留下这些", "这些不要"))
  call assert_equal("", trim("", ""))
  call assert_equal("a", trim("a", ""))
  call assert_equal("", trim("", "a"))
  call assert_equal("vim", trim("  vim  ", " ", 0))
  call assert_equal("vim  ", trim("  vim  ", " ", 1))
  call assert_equal("  vim", trim("  vim  ", " ", 2))
  call assert_fails('call trim("  vim  ", " ", [])', 'E745:')
  call assert_fails('call trim("  vim  ", " ", -1)', 'E475:')
  call assert_fails('call trim("  vim  ", " ", 3)', 'E475:')

  let chars = join(map(range(1, 0x20) + [0xa0], {n -> n->nr2char()}), '')
  call assert_equal("x", trim(chars . "x" . chars))
endfunc

func EditAnotherFile()
  let word = expand('<cword>')
  edit Xfuncrange2
endfunc

func Test_func_range_with_edit()
  " Define a function that edits another buffer, then call it with a range that
  " is invalid in that buffer.
  call writefile(['just one line'], 'Xfuncrange2')
  new
  call setline(1, 10->range())
  write Xfuncrange1
  call assert_fails('5,8call EditAnotherFile()', 'E16:')

  call delete('Xfuncrange1')
  call delete('Xfuncrange2')
  bwipe!
endfunc

func Test_func_exists_on_reload()
  call writefile(['func ExistingFunction()', 'echo "yes"', 'endfunc'], 'Xfuncexists')
  call assert_equal(0, exists('*ExistingFunction'))
  source Xfuncexists
  call assert_equal(1, '*ExistingFunction'->exists())
  " Redefining a function when reloading a script is OK.
  source Xfuncexists
  call assert_equal(1, exists('*ExistingFunction'))

  " But redefining in another script is not OK.
  call writefile(['func ExistingFunction()', 'echo "yes"', 'endfunc'], 'Xfuncexists2')
  call assert_fails('source Xfuncexists2', 'E122:')

  delfunc ExistingFunction
  call assert_equal(0, exists('*ExistingFunction'))
  call writefile([
	\ 'func ExistingFunction()', 'echo "yes"', 'endfunc',
	\ 'func ExistingFunction()', 'echo "no"', 'endfunc',
	\ ], 'Xfuncexists')
  call assert_fails('source Xfuncexists', 'E122:')
  call assert_equal(1, exists('*ExistingFunction'))

  call delete('Xfuncexists2')
  call delete('Xfuncexists')
  delfunc ExistingFunction
endfunc

sandbox function Fsandbox()
  normal ix
endfunc

func Test_func_sandbox()
  sandbox let F = {-> 'hello'}
  call assert_equal('hello', F())

  sandbox let F = {-> "normal ix\<Esc>"->execute()}
  call assert_fails('call F()', 'E48:')
  unlet F

  call assert_fails('call Fsandbox()', 'E48:')
  delfunc Fsandbox
endfunc

" Test for reg_recording() and reg_executing()
func Test_reg_executing_and_recording()
  let s:reg_stat = ''
  func s:save_reg_stat()
    let s:reg_stat = reg_recording() . ':' . reg_executing()
    return ''
  endfunc

  new
  call s:save_reg_stat()
  call assert_equal(':', s:reg_stat)
  call feedkeys("qa\"=s:save_reg_stat()\<CR>pq", 'xt')
  call assert_equal('a:', s:reg_stat)
  call feedkeys("@a", 'xt')
  call assert_equal(':a', s:reg_stat)
  call feedkeys("qb@aq", 'xt')
  call assert_equal('b:a', s:reg_stat)
  call feedkeys("q\"\"=s:save_reg_stat()\<CR>pq", 'xt')
  call assert_equal('":', s:reg_stat)

  " :normal command saves and restores reg_executing
  let s:reg_stat = ''
  let @q = ":call TestFunc()\<CR>:call s:save_reg_stat()\<CR>"
  func TestFunc() abort
    normal! ia
  endfunc
  call feedkeys("@q", 'xt')
  call assert_equal(':q', s:reg_stat)
  delfunc TestFunc

  " getchar() command saves and restores reg_executing
  map W :call TestFunc()<CR>
  let @q = "W"
  let g:typed = ''
  let g:regs = []
  func TestFunc() abort
    let g:regs += [reg_executing()]
    let g:typed = getchar(0)
    let g:regs += [reg_executing()]
  endfunc
  call feedkeys("@qy", 'xt')
  call assert_equal(char2nr("y"), g:typed)
  call assert_equal(['q', 'q'], g:regs)
  delfunc TestFunc
  unmap W
  unlet g:typed
  unlet g:regs

  " input() command saves and restores reg_executing
  map W :call TestFunc()<CR>
  let @q = "W"
  let g:typed = ''
  let g:regs = []
  func TestFunc() abort
    let g:regs += [reg_executing()]
    let g:typed = '?'->input()
    let g:regs += [reg_executing()]
  endfunc
  call feedkeys("@qy\<CR>", 'xt')
  call assert_equal("y", g:typed)
  call assert_equal(['q', 'q'], g:regs)
  delfunc TestFunc
  unmap W
  unlet g:typed
  unlet g:regs

  bwipe!
  delfunc s:save_reg_stat
  unlet s:reg_stat
endfunc

func Test_inputsecret()
  map W :call TestFunc()<CR>
  let @q = "W"
  let g:typed1 = ''
  let g:typed2 = ''
  let g:regs = []
  func TestFunc() abort
    let g:typed1 = '?'->inputsecret()
    let g:typed2 = inputsecret('password: ')
  endfunc
  call feedkeys("@qsomething\<CR>else\<CR>", 'xt')
  call assert_equal("something", g:typed1)
  call assert_equal("else", g:typed2)
  delfunc TestFunc
  unmap W
  unlet g:typed1
  unlet g:typed2
endfunc

func Test_getchar()
  call feedkeys('a', '')
  call assert_equal(char2nr('a'), getchar())
  call assert_equal(0, getchar(0))
  call assert_equal(0, getchar(1))

  call feedkeys('a', '')
  call assert_equal('a', getcharstr())
  call assert_equal('', getcharstr(0))
  call assert_equal('', getcharstr(1))

  call setline(1, 'xxxx')
  " call test_setmouse(1, 3)
  " let v:mouse_win = 9
  " let v:mouse_winid = 9
  " let v:mouse_lnum = 9
  " let v:mouse_col = 9
  " call feedkeys("\<S-LeftMouse>", '')
  call nvim_input_mouse('left', 'press', 'S', 0, 0, 2)
  call assert_equal("\<S-LeftMouse>", getchar())
  call assert_equal(1, v:mouse_win)
  call assert_equal(win_getid(1), v:mouse_winid)
  call assert_equal(1, v:mouse_lnum)
  call assert_equal(3, v:mouse_col)
  enew!
endfunc

func Test_libcall_libcallnr()
  if !has('libcall')
    return
  endif

  if has('win32')
    let libc = 'msvcrt.dll'
  elseif has('mac')
    let libc = 'libSystem.B.dylib'
  elseif system('uname -s') =~ 'SunOS'
    " Set the path to libc.so according to the architecture.
    let test_bits = system('file ' . GetVimProg())
    let test_arch = system('uname -p')
    if test_bits =~ '64-bit' && test_arch =~ 'sparc'
      let libc = '/usr/lib/sparcv9/libc.so'
    elseif test_bits =~ '64-bit' && test_arch =~ 'i386'
      let libc = '/usr/lib/amd64/libc.so'
    else
      let libc = '/usr/lib/libc.so'
    endif
  elseif system('uname -s') =~ 'OpenBSD'
    let libc = 'libc.so'
  else
    " On Unix, libc.so can be in various places.
    " Interestingly, using an empty string for the 1st argument of libcall
    " allows to call functions from libc which is not documented.
    let libc = ''
  endif

  if has('win32')
    call assert_equal($USERPROFILE, 'USERPROFILE'->libcall(libc, 'getenv'))
  else
    call assert_equal($HOME, 'HOME'->libcall(libc, 'getenv'))
  endif

  " If function returns NULL, libcall() should return an empty string.
  call assert_equal('', libcall(libc, 'getenv', 'X_ENV_DOES_NOT_EXIT'))

  " Test libcallnr() with string and integer argument.
  call assert_equal(4, 'abcd'->libcallnr(libc, 'strlen'))
  call assert_equal(char2nr('A'), char2nr('a')->libcallnr(libc, 'toupper'))

  call assert_fails("call libcall(libc, 'Xdoesnotexist_', '')", 'E364:')
  call assert_fails("call libcallnr(libc, 'Xdoesnotexist_', '')", 'E364:')

  call assert_fails("call libcall('Xdoesnotexist_', 'getenv', 'HOME')", 'E364:')
  call assert_fails("call libcallnr('Xdoesnotexist_', 'strlen', 'abcd')", 'E364:')
endfunc

func Test_bufadd_bufload()
  call assert_equal(0, bufexists('someName'))
  let buf = bufadd('someName')
  call assert_notequal(0, buf)
  call assert_equal(1, bufexists('someName'))
  call assert_equal(0, getbufvar(buf, '&buflisted'))
  call assert_equal(0, bufloaded(buf))
  call bufload(buf)
  call assert_equal(1, bufloaded(buf))
  call assert_equal([''], getbufline(buf, 1, '$'))

  let curbuf = bufnr('')
  call writefile(['some', 'text'], 'XotherName')
  let buf = 'XotherName'->bufadd()
  call assert_notequal(0, buf)
  eval 'XotherName'->bufexists()->assert_equal(1)
  call assert_equal(0, getbufvar(buf, '&buflisted'))
  call assert_equal(0, bufloaded(buf))
  eval buf->bufload()
  call assert_equal(1, bufloaded(buf))
  call assert_equal(['some', 'text'], getbufline(buf, 1, '$'))
  call assert_equal(curbuf, bufnr(''))

  let buf1 = bufadd('')
  let buf2 = bufadd('')
  call assert_notequal(0, buf1)
  call assert_notequal(0, buf2)
  call assert_notequal(buf1, buf2)
  call assert_equal(1, bufexists(buf1))
  call assert_equal(1, bufexists(buf2))
  call assert_equal(0, bufloaded(buf1))
  exe 'bwipe ' .. buf1
  call assert_equal(0, bufexists(buf1))
  call assert_equal(1, bufexists(buf2))
  exe 'bwipe ' .. buf2
  call assert_equal(0, bufexists(buf2))

  bwipe someName
  bwipe XotherName
  call assert_equal(0, bufexists('someName'))
  call delete('XotherName')
endfunc

func Test_readdir()
  if isdirectory('Xdir')
    call delete('Xdir', 'rf')
  endif

  call mkdir('Xdir')
  call writefile([], 'Xdir/foo.txt')
  call writefile([], 'Xdir/bar.txt')
  call mkdir('Xdir/dir')

  " All results
  let files = readdir('Xdir')
  call assert_equal(['bar.txt', 'dir', 'foo.txt'], sort(files))

  " Only results containing "f"
  let files = 'Xdir'->readdir({ x -> stridx(x, 'f') !=- 1 })
  call assert_equal(['foo.txt'], sort(files))

  " Only .txt files
  let files = readdir('Xdir', { x -> x =~ '.txt$' })
  call assert_equal(['bar.txt', 'foo.txt'], sort(files))

  " Only .txt files with string
  let files = readdir('Xdir', 'v:val =~ ".txt$"')
  call assert_equal(['bar.txt', 'foo.txt'], sort(files))

  " Limit to 1 result.
  let l = []
  let files = readdir('Xdir', {x -> len(add(l, x)) == 2 ? -1 : 1})
  call assert_equal(1, len(files))

  call delete('Xdir', 'rf')
endfunc

func Test_call()
  call assert_equal(3, call('len', [123]))
  call assert_equal(3, 'len'->call([123]))
  call assert_fails("call call('len', 123)", 'E714:')
  call assert_equal(0, call('', []))

  function Mylen() dict
     return len(self.data)
  endfunction
  let mydict = {'data': [0, 1, 2, 3], 'len': function("Mylen")}
  eval mydict.len->call([], mydict)->assert_equal(4)
  call assert_fails("call call('Mylen', [], 0)", 'E715:')
endfunc

func Test_char2nr()
  call assert_equal(12354, char2nr('あ', 1))
endfunc

func Test_eventhandler()
  call assert_equal(0, eventhandler())
endfunc

" Test for the eval() function
func Test_eval()
  call assert_fails("call eval('5 a')", 'E488:')
endfunc

" Test for the nr2char() function
func Test_nr2char()
  " set encoding=latin1
  call assert_equal('@', nr2char(64))
  set encoding=utf8
  call assert_equal('a', nr2char(97, 1))
  call assert_equal('a', nr2char(97, 0))

  call assert_equal("\x80\xfc\b\xf4\x80\xfeX\x80\xfeX\x80\xfeX", eval('"\<M-' .. nr2char(0x100000) .. '>"'))
  call assert_equal("\x80\xfc\b\xfd\x80\xfeX\x80\xfeX\x80\xfeX\x80\xfeX\x80\xfeX", eval('"\<M-' .. nr2char(0x40000000) .. '>"'))
endfunc

func HasDefault(msg = 'msg')
  return a:msg
endfunc

func Test_default_arg_value()
  call assert_equal('msg', HasDefault())
endfunc

" vim: shiftwidth=2 sts=2 expandtab
