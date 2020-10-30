" Tests for fuzzy matching

source shared.vim
source check.vim

" Test for matchfuzzy()
func Test_matchfuzzy()
  call assert_fails('call matchfuzzy(10, "abc")', 'E686:')
  call assert_fails('call matchfuzzy(["abc"], [])', 'E730:')
  call assert_fails("let x = matchfuzzy(test_null_list(), 'foo')", 'E686:')
  call assert_fails('call matchfuzzy(["abc"], test_null_string())', 'E475:')
  call assert_equal([], matchfuzzy([], 'abc'))
  call assert_equal([], matchfuzzy(['abc'], ''))
  call assert_equal(['abc'], matchfuzzy(['abc', 10], 'ac'))
  call assert_equal([], matchfuzzy([10, 20], 'ac'))
  call assert_equal(['abc'], matchfuzzy(['abc'], 'abc'))
  call assert_equal(['crayon', 'camera'], matchfuzzy(['camera', 'crayon'], 'cra'))
  call assert_equal(['aabbaa', 'aaabbbaaa', 'aaaabbbbaaaa', 'aba'], matchfuzzy(['aba', 'aabbaa', 'aaabbbaaa', 'aaaabbbbaaaa'], 'aa'))
  call assert_equal(['one'], matchfuzzy(['one', 'two'], 'one'))
  call assert_equal(['oneTwo', 'onetwo'], matchfuzzy(['onetwo', 'oneTwo'], 'oneTwo'))
  call assert_equal(['one_two', 'onetwo'], matchfuzzy(['onetwo', 'one_two'], 'oneTwo'))
  call assert_equal(['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'], matchfuzzy(['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'], 'aa'))
  call assert_equal(256, matchfuzzy([repeat('a', 256)], len(repeat('a', 256))[0]))
  call assert_equal([], matchfuzzy([repeat('a', 300)], repeat('a', 257)))

  " Tests for match preferences
  " preference for camel case match
  call assert_equal(['oneTwo', 'onetwo'], matchfuzzy(['onetwo', 'oneTwo'], 'onetwo'))
  " preference for match after a separator (_ or space)
  call assert_equal(['one_two', 'one two', 'onetwo'], matchfuzzy(['onetwo', 'one_two', 'one two'], 'onetwo'))
  " preference for leading letter match
  call assert_equal(['onetwo', 'xonetwo'], matchfuzzy(['xonetwo', 'onetwo'], 'onetwo'))
  " preference for sequential match
  call assert_equal(['onetwo', 'oanbectdweo'], matchfuzzy(['oanbectdweo', 'onetwo'], 'onetwo'))
  " non-matching leading letter(s) penalty
  call assert_equal(['xonetwo', 'xxonetwo'], matchfuzzy(['xxonetwo', 'xonetwo'], 'onetwo'))
  " total non-matching letter(s) penalty
  call assert_equal(['one', 'onex', 'onexx'], matchfuzzy(['onexx', 'one', 'onex'], 'one'))

  %bw!
  eval map(['somebuf', 'anotherone', 'needle', 'yetanotherone'], {_, v -> bufadd(v) + bufload(v)})
  let l = matchfuzzy(map(getbufinfo(), {_, v -> v.name}), 'ndl')
  call assert_equal(1, len(l))
  call assert_match('needle', l[0])

  let l = [{'id' : 5, 'val' : 'crayon'}, {'id' : 6, 'val' : 'camera'}]
  call assert_equal([{'id' : 6, 'val' : 'camera'}], matchfuzzy(l, 'cam', {'text_cb' : {v -> v.val}}))
  call assert_equal([{'id' : 6, 'val' : 'camera'}], matchfuzzy(l, 'cam', {'key' : 'val'}))
  call assert_equal([], matchfuzzy(l, 'day', {'text_cb' : {v -> v.val}}))
  call assert_equal([], matchfuzzy(l, 'day', {'key' : 'val'}))
  call assert_fails("let x = matchfuzzy(l, 'cam', 'random')", 'E715:')
  call assert_equal([], matchfuzzy(l, 'day', {'text_cb' : {v -> []}}))
  call assert_equal([], matchfuzzy(l, 'day', {'text_cb' : {v -> 1}}))
  call assert_fails("let x = matchfuzzy(l, 'day', {'text_cb' : {a, b -> 1}})", 'E119:')
  call assert_equal([], matchfuzzy(l, 'cam'))
  call assert_fails("let x = matchfuzzy(l, 'cam', {'text_cb' : []})", 'E921:')
  call assert_fails("let x = matchfuzzy(l, 'foo', {'key' : []})", 'E730:')
  call assert_fails("let x = matchfuzzy(l, 'cam', test_null_dict())", 'E715:')
  call assert_fails("let x = matchfuzzy(l, 'foo', {'key' : test_null_string()})", 'E475:')
  call assert_fails("let x = matchfuzzy(l, 'foo', {'text_cb' : test_null_function()})", 'E475:')

  let l = [{'id' : 5, 'name' : 'foo'}, {'id' : 6, 'name' : []}, {'id' : 7}]
  call assert_fails("let x = matchfuzzy(l, 'foo', {'key' : 'name'})", 'E730:')

  " Test in latin1 encoding
  let save_enc = &encoding
  set encoding=latin1
  call assert_equal(['abc'], matchfuzzy(['abc'], 'abc'))
  let &encoding = save_enc
endfunc

" Test for the fuzzymatchpos() function
func Test_matchfuzzypos()
  call assert_equal([['curl', 'world'], [[2,3], [2,3]]], matchfuzzypos(['world', 'curl'], 'rl'))
  call assert_equal([['curl', 'world'], [[2,3], [2,3]]], matchfuzzypos(['world', 'one', 'curl'], 'rl'))
  call assert_equal([['hello', 'hello world hello world'],
        \ [[0, 1, 2, 3, 4], [0, 1, 2, 3, 4]]],
        \ matchfuzzypos(['hello world hello world', 'hello', 'world'], 'hello'))
  call assert_equal([['aaaaaaa'], [[0, 1, 2]]], matchfuzzypos(['aaaaaaa'], 'aaa'))
  call assert_equal([[], []], matchfuzzypos(['world', 'curl'], 'ab'))
  let x = matchfuzzypos([repeat('a', 256)], repeat('a', 256))
  call assert_equal(range(256), x[1][0])
  call assert_equal([[], []], matchfuzzypos([repeat('a', 300)], repeat('a', 257)))
  call assert_equal([[], []], matchfuzzypos([], 'abc'))

  " match in a long string
  call assert_equal([[repeat('x', 300) .. 'abc'], [[300, 301, 302]]],
        \ matchfuzzypos([repeat('x', 300) .. 'abc'], 'abc'))

  " preference for camel case match
  call assert_equal([['xabcxxaBc'], [[6, 7, 8]]], matchfuzzypos(['xabcxxaBc'], 'abc'))
  " preference for match after a separator (_ or space)
  call assert_equal([['xabx_ab'], [[5, 6]]], matchfuzzypos(['xabx_ab'], 'ab'))
  " preference for leading letter match
  call assert_equal([['abcxabc'], [[0, 1]]], matchfuzzypos(['abcxabc'], 'ab'))
  " preference for sequential match
  call assert_equal([['aobncedone'], [[7, 8, 9]]], matchfuzzypos(['aobncedone'], 'one'))
  " best recursive match
  call assert_equal([['xoone'], [[2, 3, 4]]], matchfuzzypos(['xoone'], 'one'))

  let l = [{'id' : 5, 'val' : 'crayon'}, {'id' : 6, 'val' : 'camera'}]
  call assert_equal([[{'id' : 6, 'val' : 'camera'}], [[0, 1, 2]]],
        \ matchfuzzypos(l, 'cam', {'text_cb' : {v -> v.val}}))
  call assert_equal([[{'id' : 6, 'val' : 'camera'}], [[0, 1, 2]]],
        \ matchfuzzypos(l, 'cam', {'key' : 'val'}))
  call assert_equal([[], []], matchfuzzypos(l, 'day', {'text_cb' : {v -> v.val}}))
  call assert_equal([[], []], matchfuzzypos(l, 'day', {'key' : 'val'}))
  call assert_fails("let x = matchfuzzypos(l, 'cam', 'random')", 'E715:')
  call assert_equal([[], []], matchfuzzypos(l, 'day', {'text_cb' : {v -> []}}))
  call assert_equal([[], []], matchfuzzypos(l, 'day', {'text_cb' : {v -> 1}}))
  call assert_fails("let x = matchfuzzypos(l, 'day', {'text_cb' : {a, b -> 1}})", 'E119:')
  call assert_equal([[], []], matchfuzzypos(l, 'cam'))
  call assert_fails("let x = matchfuzzypos(l, 'cam', {'text_cb' : []})", 'E921:')
  call assert_fails("let x = matchfuzzypos(l, 'foo', {'key' : []})", 'E730:')
  call assert_fails("let x = matchfuzzypos(l, 'cam', test_null_dict())", 'E715:')
  call assert_fails("let x = matchfuzzypos(l, 'foo', {'key' : test_null_string()})", 'E475:')
  call assert_fails("let x = matchfuzzypos(l, 'foo', {'text_cb' : test_null_function()})", 'E475:')

  let l = [{'id' : 5, 'name' : 'foo'}, {'id' : 6, 'name' : []}, {'id' : 7}]
  call assert_fails("let x = matchfuzzypos(l, 'foo', {'key' : 'name'})", 'E730:')
endfunc

func Test_matchfuzzy_mbyte()
  CheckFeature multi_lang
  call assert_equal(['ンヹㄇヺヴ'], matchfuzzy(['ンヹㄇヺヴ'], 'ヹヺ'))
  " reverse the order of characters
  call assert_equal([], matchfuzzy(['ンヹㄇヺヴ'], 'ヺヹ'))
  call assert_equal(['αβΩxxx', 'xαxβxΩx'],
        \ matchfuzzy(['αβΩxxx', 'xαxβxΩx'], 'αβΩ'))
  call assert_equal(['ππbbππ', 'πππbbbπππ', 'ππππbbbbππππ', 'πbπ'],
        \ matchfuzzy(['πbπ', 'ππbbππ', 'πππbbbπππ', 'ππππbbbbππππ'], 'ππ'))

  " preference for camel case match
  call assert_equal(['oneĄwo', 'oneąwo'],
        \ ['oneąwo', 'oneĄwo']->matchfuzzy('oneąwo'))
  " preference for match after a separator (_ or space)
  call assert_equal(['ⅠⅡa_bㄟㄠ', 'ⅠⅡa bㄟㄠ', 'ⅠⅡabㄟㄠ'],
        \ ['ⅠⅡabㄟㄠ', 'ⅠⅡa_bㄟㄠ', 'ⅠⅡa bㄟㄠ']->matchfuzzy('ⅠⅡabㄟㄠ'))
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

func Test_matchfuzzypos_mbyte()
  CheckFeature multi_lang
  call assert_equal([['こんにちは世界'], [[0, 1, 2, 3, 4]]],
        \ matchfuzzypos(['こんにちは世界'], 'こんにちは'))
  call assert_equal([['ンヹㄇヺヴ'], [[1, 3]]], matchfuzzypos(['ンヹㄇヺヴ'], 'ヹヺ'))
  " reverse the order of characters
  call assert_equal([[], []], matchfuzzypos(['ンヹㄇヺヴ'], 'ヺヹ'))
  call assert_equal([['αβΩxxx', 'xαxβxΩx'], [[0, 1, 2], [1, 3, 5]]],
        \ matchfuzzypos(['αβΩxxx', 'xαxβxΩx'], 'αβΩ'))
  call assert_equal([['ππbbππ', 'πππbbbπππ', 'ππππbbbbππππ', 'πbπ'],
        \ [[0, 1], [0, 1], [0, 1], [0, 2]]],
        \ matchfuzzypos(['πbπ', 'ππbbππ', 'πππbbbπππ', 'ππππbbbbππππ'], 'ππ'))
  call assert_equal([['ααααααα'], [[0, 1, 2]]],
        \ matchfuzzypos(['ααααααα'], 'ααα'))

  call assert_equal([[], []], matchfuzzypos(['ンヹㄇ', 'ŗŝţ'], 'ﬀﬁﬂ'))
  let x = matchfuzzypos([repeat('Ψ', 256)], repeat('Ψ', 256))
  call assert_equal(range(256), x[1][0])
  call assert_equal([[], []], matchfuzzypos([repeat('✓', 300)], repeat('✓', 257)))

  " match in a long string
  call assert_equal([[repeat('♪', 300) .. '✗✗✗'], [[300, 301, 302]]],
        \ matchfuzzypos([repeat('♪', 300) .. '✗✗✗'], '✗✗✗'))
  " preference for camel case match
  call assert_equal([['xѳѵҁxxѳѴҁ'], [[6, 7, 8]]], matchfuzzypos(['xѳѵҁxxѳѴҁ'], 'ѳѵҁ'))
  " preference for match after a separator (_ or space)
  call assert_equal([['xちだx_ちだ'], [[5, 6]]], matchfuzzypos(['xちだx_ちだ'], 'ちだ'))
  " preference for leading letter match
  call assert_equal([['ѳѵҁxѳѵҁ'], [[0, 1]]], matchfuzzypos(['ѳѵҁxѳѵҁ'], 'ѳѵ'))
  " preference for sequential match
  call assert_equal([['aンbヹcㄇdンヹㄇ'], [[7, 8, 9]]], matchfuzzypos(['aンbヹcㄇdンヹㄇ'], 'ンヹㄇ'))
  " best recursive match
  call assert_equal([['xффйд'], [[2, 3, 4]]], matchfuzzypos(['xффйд'], 'фйд'))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
