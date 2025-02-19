" Tests for fuzzy matching

source shared.vim
source check.vim
source term_util.vim

" Test for matchfuzzy()
func Test_matchfuzzy()
  call assert_fails('call matchfuzzy(10, "abc")', 'E686:')
  call assert_fails('call matchfuzzy(["abc"], [])', 'E730:')
  call assert_fails("let x = matchfuzzy(v:_null_list, 'foo')", 'E686:')
  call assert_fails('call matchfuzzy(["abc"], v:_null_string)', 'E475:')
  call assert_equal([], matchfuzzy([], 'abc'))
  call assert_equal([], matchfuzzy(['abc'], ''))
  call assert_equal(['abc'], matchfuzzy(['abc', 10], 'ac'))
  call assert_equal([], matchfuzzy([10, 20], 'ac'))
  call assert_equal(['abc'], matchfuzzy(['abc'], 'abc'))
  call assert_equal(['crayon', 'camera'], matchfuzzy(['camera', 'crayon'], 'cra'))
  call assert_equal(['aabbaa', 'aaabbbaaa', 'aaaabbbbaaaa', 'aba'], matchfuzzy(['aba', 'aabbaa', 'aaabbbaaa', 'aaaabbbbaaaa'], 'aa'))
  call assert_equal(['one'], matchfuzzy(['one', 'two'], 'one'))
  call assert_equal(['oneTwo', 'onetwo'], matchfuzzy(['onetwo', 'oneTwo'], 'oneTwo'))
  call assert_equal(['onetwo', 'one_two'], matchfuzzy(['onetwo', 'one_two'], 'oneTwo'))
  call assert_equal(['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'], matchfuzzy(['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'], 'aa'))
  call assert_equal(256, matchfuzzy([repeat('a', 256)], repeat('a', 256))[0]->len())
  call assert_equal([], matchfuzzy([repeat('a', 300)], repeat('a', 257)))
  " full match has highest score
  call assert_equal(['Cursor', 'lCursor'], matchfuzzy(["hello", "lCursor", "Cursor"], "Cursor"))
  " matches with same score should not be reordered
  let l = ['abc1', 'abc2', 'abc3']
  call assert_equal(l, l->matchfuzzy('abc'))

  " Tests for match preferences
  " preference for camel case match
  call assert_equal(['oneTwo', 'onetwo'], ['onetwo', 'oneTwo']->matchfuzzy('onetwo'))
  " preference for match after a separator (_ or space)
  call assert_equal(['onetwo', 'one_two', 'one two'], ['onetwo', 'one_two', 'one two']->matchfuzzy('onetwo'))
  " preference for leading letter match
  call assert_equal(['onetwo', 'xonetwo'], ['xonetwo', 'onetwo']->matchfuzzy('onetwo'))
  " preference for sequential match
  call assert_equal(['onetwo', 'oanbectdweo'], ['oanbectdweo', 'onetwo']->matchfuzzy('onetwo'))
  " non-matching leading letter(s) penalty
  call assert_equal(['xonetwo', 'xxonetwo'], ['xxonetwo', 'xonetwo']->matchfuzzy('onetwo'))
  " total non-matching letter(s) penalty
  call assert_equal(['one', 'onex', 'onexx'], ['onexx', 'one', 'onex']->matchfuzzy('one'))
  " prefer complete matches over separator matches
  call assert_equal(['.vim/vimrc', '.vim/vimrc_colors', '.vim/v_i_m_r_c'], ['.vim/vimrc', '.vim/vimrc_colors', '.vim/v_i_m_r_c']->matchfuzzy('vimrc'))
  " gap penalty
  call assert_equal(['xxayybxxxx', 'xxayyybxxx', 'xxayyyybxx'], ['xxayyyybxx', 'xxayyybxxx', 'xxayybxxxx']->matchfuzzy('ab'))
  " path separator vs word separator
  call assert_equal(['color/setup.vim', 'color\\setup.vim', 'color setup.vim', 'color_setup.vim', 'colorsetup.vim'], matchfuzzy(['colorsetup.vim', 'color setup.vim', 'color/setup.vim', 'color_setup.vim', 'color\\setup.vim'], 'setup.vim'))

  " match multiple words (separated by space)
  call assert_equal(['foo bar baz'], ['foo bar baz', 'foo', 'foo bar', 'baz bar']->matchfuzzy('baz foo'))
  call assert_equal([], ['foo bar baz', 'foo', 'foo bar', 'baz bar']->matchfuzzy('one two'))
  call assert_equal([], ['foo bar']->matchfuzzy(" \t "))

  " test for matching a sequence of words
  call assert_equal(['bar foo'], ['foo bar', 'bar foo', 'foobar', 'barfoo']->matchfuzzy('bar foo', {'matchseq' : 1}))
  call assert_equal([#{text: 'two one'}], [#{text: 'one two'}, #{text: 'two one'}]->matchfuzzy('two one', #{key: 'text', matchseq: v:true}))

  %bw!
  eval ['somebuf', 'anotherone', 'needle', 'yetanotherone']->map({_, v -> bufadd(v) + bufload(v)})
  let l = getbufinfo()->map({_, v -> fnamemodify(v.name, ':t')})->matchfuzzy('ndl')
  call assert_equal(1, len(l))
  call assert_match('needle', l[0])

  " Test for fuzzy matching dicts
  let l = [{'id' : 5, 'val' : 'crayon'}, {'id' : 6, 'val' : 'camera'}]
  call assert_equal([{'id' : 6, 'val' : 'camera'}], matchfuzzy(l, 'cam', {'text_cb' : {v -> v.val}}))
  call assert_equal([{'id' : 6, 'val' : 'camera'}], matchfuzzy(l, 'cam', {'key' : 'val'}))
  call assert_equal([], matchfuzzy(l, 'day', {'text_cb' : {v -> v.val}}))
  call assert_equal([], matchfuzzy(l, 'day', {'key' : 'val'}))
  call assert_fails("let x = matchfuzzy(l, 'cam', 'random')", 'E1206:')
  call assert_equal([], matchfuzzy(l, 'day', {'text_cb' : {v -> []}}))
  call assert_equal([], matchfuzzy(l, 'day', {'text_cb' : {v -> 1}}))
  call assert_fails("let x = matchfuzzy(l, 'day', {'text_cb' : {a, b -> 1}})", 'E119:')
  call assert_equal([], matchfuzzy(l, 'cam'))
  " Nvim's callback implementation is different, so E6000 is expected instead,
  " call assert_fails("let x = matchfuzzy(l, 'cam', {'text_cb' : []})", 'E921:')
  call assert_fails("let x = matchfuzzy(l, 'cam', {'text_cb' : []})", 'E6000:')
  call assert_fails("let x = matchfuzzy(l, 'foo', {'key' : []})", 'E730:')
  call assert_fails("let x = matchfuzzy(l, 'cam', v:_null_dict)", 'E1297:')
  call assert_fails("let x = matchfuzzy(l, 'foo', {'key' : v:_null_string})", 'E475:')
  " Nvim doesn't have null functions
  " call assert_fails("let x = matchfuzzy(l, 'foo', {'text_cb' : test_null_function()})", 'E475:')
  " matches with same score should not be reordered
  let l = [#{text: 'abc', id: 1}, #{text: 'abc', id: 2}, #{text: 'abc', id: 3}]
  call assert_equal(l, l->matchfuzzy('abc', #{key: 'text'}))

  let l = [{'id' : 5, 'name' : 'foo'}, {'id' : 6, 'name' : []}, {'id' : 7}]
  call assert_fails("let x = matchfuzzy(l, 'foo', {'key' : 'name'})", 'E730:')

  " Test in latin1 encoding
  let save_enc = &encoding
  " Nvim supports utf-8 encoding only
  " set encoding=latin1
  call assert_equal(['abc'], matchfuzzy(['abc'], 'abc'))
  let &encoding = save_enc
endfunc

" Test for the matchfuzzypos() function
func Test_matchfuzzypos()
  call assert_equal([['curl', 'world'], [[2,3], [2,3]], [178, 177]], matchfuzzypos(['world', 'curl'], 'rl'))
  call assert_equal([['curl', 'world'], [[2,3], [2,3]], [178, 177]], matchfuzzypos(['world', 'one', 'curl'], 'rl'))
  call assert_equal([['hello', 'hello world hello world'],
        \ [[0, 1, 2, 3, 4], [0, 1, 2, 3, 4]], [500, 382]],
        \ matchfuzzypos(['hello world hello world', 'hello', 'world'], 'hello'))
  call assert_equal([['aaaaaaa'], [[0, 1, 2]], [266]], matchfuzzypos(['aaaaaaa'], 'aaa'))
  call assert_equal([['a  b'], [[0, 3]], [269]], matchfuzzypos(['a  b'], 'a  b'))
  call assert_equal([['a  b'], [[0, 3]], [269]], matchfuzzypos(['a  b'], 'a    b'))
  call assert_equal([['a  b'], [[0]], [137]], matchfuzzypos(['a  b'], '  a  '))
  call assert_equal([[], [], []], matchfuzzypos(['a  b'], '  '))
  call assert_equal([[], [], []], matchfuzzypos(['world', 'curl'], 'ab'))
  let x = matchfuzzypos([repeat('a', 256)], repeat('a', 256))
  call assert_equal(range(256), x[1][0])
  call assert_equal([[], [], []], matchfuzzypos([repeat('a', 300)], repeat('a', 257)))
  call assert_equal([[], [], []], matchfuzzypos([], 'abc'))

  " match in a long string
  call assert_equal([[repeat('x', 300) .. 'abc'], [[300, 301, 302]], [-60]],
        \ matchfuzzypos([repeat('x', 300) .. 'abc'], 'abc'))

  " preference for camel case match
  call assert_equal([['xabcxxaBc'], [[6, 7, 8]], [269]], matchfuzzypos(['xabcxxaBc'], 'abc'))
  " preference for match after a separator (_ or space)
  call assert_equal([['xabx_ab'], [[5, 6]], [195]], matchfuzzypos(['xabx_ab'], 'ab'))
  " preference for leading letter match
  call assert_equal([['abcxabc'], [[0, 1]], [200]], matchfuzzypos(['abcxabc'], 'ab'))
  " preference for sequential match
  call assert_equal([['aobncedone'], [[7, 8, 9]], [233]], matchfuzzypos(['aobncedone'], 'one'))
  " best recursive match
  call assert_equal([['xoone'], [[2, 3, 4]], [243]], matchfuzzypos(['xoone'], 'one'))

  " match multiple words (separated by space)
  call assert_equal([['foo bar baz'], [[8, 9, 10, 0, 1, 2]], [519]], ['foo bar baz', 'foo', 'foo bar', 'baz bar']->matchfuzzypos('baz foo'))
  call assert_equal([[], [], []], ['foo bar baz', 'foo', 'foo bar', 'baz bar']->matchfuzzypos('baz foo', {'matchseq': 1}))
  call assert_equal([['foo bar baz'], [[0, 1, 2, 8, 9, 10]], [519]], ['foo bar baz', 'foo', 'foo bar', 'baz bar']->matchfuzzypos('foo baz'))
  call assert_equal([['foo bar baz'], [[0, 1, 2, 3, 4, 5, 10]], [476]], ['foo bar baz', 'foo', 'foo bar', 'baz bar']->matchfuzzypos('foo baz', {'matchseq': 1}))
  call assert_equal([[], [], []], ['foo bar baz', 'foo', 'foo bar', 'baz bar']->matchfuzzypos('one two'))
  call assert_equal([[], [], []], ['foo bar']->matchfuzzypos(" \t "))
  call assert_equal([['grace'], [[1, 2, 3, 4, 2, 3, 4, 0, 1, 2, 3, 4]], [1057]], ['grace']->matchfuzzypos('race ace grace'))

  let l = [{'id' : 5, 'val' : 'crayon'}, {'id' : 6, 'val' : 'camera'}]
  call assert_equal([[{'id' : 6, 'val' : 'camera'}], [[0, 1, 2]], [267]],
        \ matchfuzzypos(l, 'cam', {'text_cb' : {v -> v.val}}))
  call assert_equal([[{'id' : 6, 'val' : 'camera'}], [[0, 1, 2]], [267]],
        \ matchfuzzypos(l, 'cam', {'key' : 'val'}))
  call assert_equal([[], [], []], matchfuzzypos(l, 'day', {'text_cb' : {v -> v.val}}))
  call assert_equal([[], [], []], matchfuzzypos(l, 'day', {'key' : 'val'}))
  call assert_fails("let x = matchfuzzypos(l, 'cam', 'random')", 'E1206:')
  call assert_equal([[], [], []], matchfuzzypos(l, 'day', {'text_cb' : {v -> []}}))
  call assert_equal([[], [], []], matchfuzzypos(l, 'day', {'text_cb' : {v -> 1}}))
  call assert_fails("let x = matchfuzzypos(l, 'day', {'text_cb' : {a, b -> 1}})", 'E119:')
  call assert_equal([[], [], []], matchfuzzypos(l, 'cam'))
  " Nvim's callback implementation is different, so E6000 is expected instead,
  " call assert_fails("let x = matchfuzzypos(l, 'cam', {'text_cb' : []})", 'E921:')
  call assert_fails("let x = matchfuzzypos(l, 'cam', {'text_cb' : []})", 'E6000:')
  call assert_fails("let x = matchfuzzypos(l, 'foo', {'key' : []})", 'E730:')
  call assert_fails("let x = matchfuzzypos(l, 'cam', v:_null_dict)", 'E1297:')
  call assert_fails("let x = matchfuzzypos(l, 'foo', {'key' : v:_null_string})", 'E475:')
  " Nvim doesn't have null functions
  " call assert_fails("let x = matchfuzzypos(l, 'foo', {'text_cb' : test_null_function()})", 'E475:')

  " case match
  call assert_equal([['Match', 'match'], [[0, 1], [0, 1]], [202, 177]], matchfuzzypos(['match', 'Match'], 'Ma'))
  call assert_equal([['match', 'Match'], [[0, 1], [0, 1]], [202, 177]], matchfuzzypos(['Match', 'match'], 'ma'))
  " CamelCase has high weight even case match
  call assert_equal(['MyTestCase', 'mytestcase'], matchfuzzy(['mytestcase', 'MyTestCase'], 'mtc'))
  call assert_equal(['MyTestCase', 'mytestcase'], matchfuzzy(['MyTestCase', 'mytestcase'], 'mtc'))
  call assert_equal(['MyTest', 'Mytest', 'mytest', ],matchfuzzy(['Mytest', 'mytest', 'MyTest'], 'MyT'))
  call assert_equal(['CamelCaseMatchIngAlg', 'camelCaseMatchingAlg', 'camelcasematchingalg'],
      \ matchfuzzy(['CamelCaseMatchIngAlg', 'camelcasematchingalg', 'camelCaseMatchingAlg'], 'CamelCase'))
  call assert_equal(['CamelCaseMatchIngAlg', 'camelCaseMatchingAlg', 'camelcasematchingalg'],
      \ matchfuzzy(['CamelCaseMatchIngAlg', 'camelcasematchingalg', 'camelCaseMatchingAlg'], 'CamelcaseM'))

  let l = [{'id' : 5, 'name' : 'foo'}, {'id' : 6, 'name' : []}, {'id' : 7}]
  call assert_fails("let x = matchfuzzypos(l, 'foo', {'key' : 'name'})", 'E730:')
endfunc

" Test for matchfuzzy() with multibyte characters
func Test_matchfuzzy_mbyte()
  CheckFeature multi_lang
  call assert_equal(['ンヹㄇヺヴ'], matchfuzzy(['ンヹㄇヺヴ'], 'ヹヺ'))
  " reverse the order of characters
  call assert_equal([], matchfuzzy(['ンヹㄇヺヴ'], 'ヺヹ'))
  call assert_equal(['αβΩxxx', 'xαxβxΩx'],
        \ matchfuzzy(['αβΩxxx', 'xαxβxΩx'], 'αβΩ'))
  call assert_equal(['ππbbππ', 'πππbbbπππ', 'ππππbbbbππππ', 'πbπ'],
        \ matchfuzzy(['πbπ', 'ππbbππ', 'πππbbbπππ', 'ππππbbbbππππ'], 'ππ'))

  " match multiple words (separated by space)
  call assert_equal(['세 마리의 작은 돼지'], ['세 마리의 작은 돼지', '마리의', '마리의 작은', '작은 돼지']->matchfuzzy('돼지 마리의'))
  call assert_equal([], ['세 마리의 작은 돼지', '마리의', '마리의 작은', '작은 돼지']->matchfuzzy('파란 하늘'))

  " preference for camel case match
  call assert_equal(['oneĄwo', 'oneąwo'],
        \ ['oneąwo', 'oneĄwo']->matchfuzzy('oneąwo'))
  " preference for complete match then match after separator (_ or space)
  call assert_equal(['ⅠⅡabㄟㄠ'] + sort(['ⅠⅡa_bㄟㄠ', 'ⅠⅡa bㄟㄠ']),
          \ ['ⅠⅡabㄟㄠ', 'ⅠⅡa bㄟㄠ', 'ⅠⅡa_bㄟㄠ']->matchfuzzy('ⅠⅡabㄟㄠ'))
  " preference for match after a separator (_ or space)
  call assert_equal(['ㄓㄔabㄟㄠ', 'ㄓㄔa_bㄟㄠ', 'ㄓㄔa bㄟㄠ'],
        \ ['ㄓㄔa_bㄟㄠ', 'ㄓㄔa bㄟㄠ', 'ㄓㄔabㄟㄠ']->matchfuzzy('ㄓㄔabㄟㄠ'))
  " preference for leading letter match
  call assert_equal(['ŗŝţũŵż', 'xŗŝţũŵż'],
        \ ['xŗŝţũŵż', 'ŗŝţũŵż']->matchfuzzy('ŗŝţũŵż'))
  " preference for sequential match
  call assert_equal(['ㄞㄡㄤﬀﬁﬂ', 'ㄞaㄡbㄤcﬀdﬁeﬂ'],
        \ ['ㄞaㄡbㄤcﬀdﬁeﬂ', 'ㄞㄡㄤﬀﬁﬂ']->matchfuzzy('ㄞㄡㄤﬀﬁﬂ'))
  " non-matching leading letter(s) penalty
  call assert_equal(['xㄞㄡㄤﬀﬁﬂ', 'xxㄞㄡㄤﬀﬁﬂ'],
        \ ['xxㄞㄡㄤﬀﬁﬂ', 'xㄞㄡㄤﬀﬁﬂ']->matchfuzzy('ㄞㄡㄤﬀﬁﬂ'))
  " total non-matching letter(s) penalty
  call assert_equal(['ŗŝţ', 'ŗŝţx', 'ŗŝţxx'],
        \ ['ŗŝţxx', 'ŗŝţ', 'ŗŝţx']->matchfuzzy('ŗŝţ'))
endfunc

" Test for matchfuzzypos() with multibyte characters
func Test_matchfuzzypos_mbyte()
  CheckFeature multi_lang
  call assert_equal([['こんにちは世界'], [[0, 1, 2, 3, 4]], [273]],
        \ matchfuzzypos(['こんにちは世界'], 'こんにちは'))
  call assert_equal([['ンヹㄇヺヴ'], [[1, 3]], [88]], matchfuzzypos(['ンヹㄇヺヴ'], 'ヹヺ'))
  " reverse the order of characters
  call assert_equal([[], [], []], matchfuzzypos(['ンヹㄇヺヴ'], 'ヺヹ'))
  call assert_equal([['αβΩxxx', 'xαxβxΩx'], [[0, 1, 2], [1, 3, 5]], [252, 143]],
        \ matchfuzzypos(['αβΩxxx', 'xαxβxΩx'], 'αβΩ'))
  call assert_equal([['ππbbππ', 'πππbbbπππ', 'ππππbbbbππππ', 'πbπ'],
        \ [[0, 1], [0, 1], [0, 1], [0, 2]], [176, 173, 170, 135]],
        \ matchfuzzypos(['πbπ', 'ππbbππ', 'πππbbbπππ', 'ππππbbbbππππ'], 'ππ'))
  call assert_equal([['ααααααα'], [[0, 1, 2]], [216]],
        \ matchfuzzypos(['ααααααα'], 'ααα'))

  call assert_equal([[], [], []], matchfuzzypos(['ンヹㄇ', 'ŗŝţ'], 'ﬀﬁﬂ'))
  let x = matchfuzzypos([repeat('Ψ', 256)], repeat('Ψ', 256))
  call assert_equal(range(256), x[1][0])
  call assert_equal([[], [], []], matchfuzzypos([repeat('✓', 300)], repeat('✓', 257)))

  " match multiple words (separated by space)
  call assert_equal([['세 마리의 작은 돼지'], [[9, 10, 2, 3, 4]], [328]], ['세 마리의 작은 돼지', '마리의', '마리의 작은', '작은 돼지']->matchfuzzypos('돼지 마리의'))
  call assert_equal([[], [], []], ['세 마리의 작은 돼지', '마리의', '마리의 작은', '작은 돼지']->matchfuzzypos('파란 하늘'))

  " match in a long string
  call assert_equal([[repeat('ぶ', 300) .. 'ẼẼẼ'], [[300, 301, 302]], [-110]],
        \ matchfuzzypos([repeat('ぶ', 300) .. 'ẼẼẼ'], 'ẼẼẼ'))
  " preference for camel case match
  call assert_equal([['xѳѵҁxxѳѴҁ'], [[6, 7, 8]], [219]], matchfuzzypos(['xѳѵҁxxѳѴҁ'], 'ѳѵҁ'))
  " preference for match after a separator (_ or space)
  call assert_equal([['xちだx_ちだ'], [[5, 6]], [145]], matchfuzzypos(['xちだx_ちだ'], 'ちだ'))
  " preference for leading letter match
  call assert_equal([['ѳѵҁxѳѵҁ'], [[0, 1]], [150]], matchfuzzypos(['ѳѵҁxѳѵҁ'], 'ѳѵ'))
  " preference for sequential match
  call assert_equal([['aンbヹcㄇdンヹㄇ'], [[7, 8, 9]], [158]], matchfuzzypos(['aンbヹcㄇdンヹㄇ'], 'ンヹㄇ'))
  " best recursive match
  call assert_equal([['xффйд'], [[2, 3, 4]], [168]], matchfuzzypos(['xффйд'], 'фйд'))
endfunc

" Test for matchfuzzy() with limit
func Test_matchfuzzy_limit()
  let x = ['1', '2', '3', '2']
  call assert_equal(['2', '2'], x->matchfuzzy('2'))
  call assert_equal(['2', '2'], x->matchfuzzy('2', #{}))
  call assert_equal(['2', '2'], x->matchfuzzy('2', #{limit: 0}))
  call assert_equal(['2'], x->matchfuzzy('2', #{limit: 1}))
  call assert_equal(['2', '2'], x->matchfuzzy('2', #{limit: 2}))
  call assert_equal(['2', '2'], x->matchfuzzy('2', #{limit: 3}))
  call assert_fails("call matchfuzzy(x, '2', #{limit: '2'})", 'E475:')

  let l = [{'id': 5, 'val': 'crayon'}, {'id': 6, 'val': 'camera'}]
  call assert_equal([{'id': 5, 'val': 'crayon'}, {'id': 6, 'val': 'camera'}], l->matchfuzzy('c', #{text_cb: {v -> v.val}}))
  call assert_equal([{'id': 5, 'val': 'crayon'}, {'id': 6, 'val': 'camera'}], l->matchfuzzy('c', #{key: 'val'}))
  call assert_equal([{'id': 5, 'val': 'crayon'}, {'id': 6, 'val': 'camera'}], l->matchfuzzy('c', #{text_cb: {v -> v.val}, limit: 0}))
  call assert_equal([{'id': 5, 'val': 'crayon'}, {'id': 6, 'val': 'camera'}], l->matchfuzzy('c', #{key: 'val', limit: 0}))
  call assert_equal([{'id': 5, 'val': 'crayon'}], l->matchfuzzy('c', #{text_cb: {v -> v.val}, limit: 1}))
  call assert_equal([{'id': 5, 'val': 'crayon'}], l->matchfuzzy('c', #{key: 'val', limit: 1}))
endfunc

" This was using uninitialized memory
func Test_matchfuzzy_initialized()
  CheckRunVimInTerminal

  " This can take a very long time (esp. when using valgrind).  Run in a
  " separate Vim instance and kill it after two seconds.  We only check for
  " memory errors.
  let lines =<< trim END
      lvimgrep [ss [fg*
  END
  call writefile(lines, 'XTest_matchfuzzy', 'D')

  let buf = RunVimInTerminal('-u NONE -X -Z', {})
  call term_sendkeys(buf, ":source XTest_matchfuzzy\n")
  call TermWait(buf, 2000)

  let job = term_getjob(buf)
  if job_status(job) == "run"
    call job_stop(job, "int")
    call TermWait(buf, 50)
  endif

  " clean up
  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
