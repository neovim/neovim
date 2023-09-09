" Test filter() and map()

source vim9.vim

" list with expression string
func Test_filter_map_list_expr_string()
  " filter()
  call assert_equal([2, 3, 4], filter([1, 2, 3, 4], 'v:val > 1'))
  call assert_equal([3, 4], filter([1, 2, 3, 4], 'v:key > 1'))
  call assert_equal([], filter([1, 2, 3, 4], 0))

  " map()
  call assert_equal([2, 4, 6, 8], map([1, 2, 3, 4], 'v:val * 2'))
  call assert_equal([0, 2, 4, 6], map([1, 2, 3, 4], 'v:key * 2'))
  call assert_equal([9, 9, 9, 9], map([1, 2, 3, 4], 9))
  call assert_equal([7, 7, 7], map([1, 2, 3], ' 7 '))
endfunc

" dict with expression string
func Test_filter_map_dict_expr_string()
  let dict = {"foo": 1, "bar": 2, "baz": 3}

  " filter()
  call assert_equal({"bar": 2, "baz": 3}, filter(copy(dict), 'v:val > 1'))
  call assert_equal({"foo": 1, "baz": 3}, filter(copy(dict), 'v:key > "bar"'))
  call assert_equal({}, filter(copy(dict), 0))

  " map()
  call assert_equal({"foo": 2, "bar": 4, "baz": 6}, map(copy(dict), 'v:val * 2'))
  call assert_equal({"foo": "f", "bar": "b", "baz": "b"}, map(copy(dict), 'v:key[0]'))
  call assert_equal({"foo": 9, "bar": 9, "baz": 9}, map(copy(dict), 9))
endfunc

" list with funcref
func Test_filter_map_list_expr_funcref()
  " filter()
  func! s:filter1(index, val) abort
    return a:val > 1
  endfunc
  call assert_equal([2, 3, 4], filter([1, 2, 3, 4], function('s:filter1')))

  func! s:filter2(index, val) abort
    return a:index > 1
  endfunc
  call assert_equal([3, 4], filter([1, 2, 3, 4], function('s:filter2')))

  " map()
  func! s:filter3(index, val) abort
    return a:val * 2
  endfunc
  call assert_equal([2, 4, 6, 8], map([1, 2, 3, 4], function('s:filter3')))

  func! s:filter4(index, val) abort
    return a:index * 2
  endfunc
  call assert_equal([0, 2, 4, 6], map([1, 2, 3, 4], function('s:filter4')))
endfunc

" dict with funcref
func Test_filter_map_dict_expr_funcref()
  let dict = {"foo": 1, "bar": 2, "baz": 3}

  " filter()
  func! s:filter1(key, val) abort
    return a:val > 1
  endfunc
  call assert_equal({"bar": 2, "baz": 3}, filter(copy(dict), function('s:filter1')))

  func! s:filter2(key, val) abort
    return a:key > "bar"
  endfunc
  call assert_equal({"foo": 1, "baz": 3}, filter(copy(dict), function('s:filter2')))

  " map()
  func! s:filter3(key, val) abort
    return a:val * 2
  endfunc
  call assert_equal({"foo": 2, "bar": 4, "baz": 6}, map(copy(dict), function('s:filter3')))

  func! s:filter4(key, val) abort
    return a:key[0]
  endfunc
  call assert_equal({"foo": "f", "bar": "b", "baz": "b"}, map(copy(dict), function('s:filter4')))
endfunc

func Test_map_filter_fails()
  call assert_fails('call map([1], "42 +")', 'E15:')
  call assert_fails('call filter([1], "42 +")', 'E15:')
  call assert_fails("let l = filter([1, 2, 3], '{}')", 'E728:')
  call assert_fails("let l = filter({'k' : 10}, '{}')", 'E728:')
  call assert_fails("let l = filter([1, 2], {})", 'E731:')
  call assert_equal(v:_null_list, filter(v:_null_list, 0))
  call assert_equal(v:_null_dict, filter(v:_null_dict, 0))
  call assert_equal(v:_null_list, map(v:_null_list, '"> " .. v:val'))
  call assert_equal(v:_null_dict, map(v:_null_dict, '"> " .. v:val'))
  " Nvim doesn't have null functions
  " call assert_equal([1, 2, 3], filter([1, 2, 3], test_null_function()))
  call assert_fails("let l = filter([1, 2], function('min'))", 'E118:')
  " Nvim doesn't have null partials
  " call assert_equal([1, 2, 3], filter([1, 2, 3], test_null_partial()))
  call assert_fails("let l = filter([1, 2], {a, b, c -> 1})", 'E119:')
endfunc

func Test_map_and_modify()
  let l = ["abc"]
  " cannot change the list halfway a map()
  call assert_fails('call map(l, "remove(l, 0)[0]")', 'E741:')

  let d = #{a: 1, b: 2, c: 3}
  call assert_fails('call map(d, "remove(d, v:key)[0]")', 'E741:')
  call assert_fails('echo map(d, {k,v -> remove(d, k)})', 'E741:')

  let b = 0z1234
  call assert_fails('call filter(b, "remove(b, 0)")', 'E741:')
endfunc

func Test_filter_and_modify()
  let l = [0]
  " cannot change the list halfway a map()
  call assert_fails('call filter(l, "remove(l, 0)")', 'E741:')

  let d = #{a: 0, b: 0, c: 0}
  call assert_fails('call filter(d, "remove(d, v:key)")', 'E741:')

  let b = 0z1234
  call assert_fails('call filter(b, "remove(b, 0)")', 'E741:')
endfunc

func Test_mapnew_dict()
  let din = #{one: 1, two: 2}
  let dout = mapnew(din, {k, v -> string(v)})
  call assert_equal(#{one: 1, two: 2}, din)
  call assert_equal(#{one: '1', two: '2'}, dout)

  const dconst = #{one: 1, two: 2, three: 3}
  call assert_equal(#{one: 2, two: 3, three: 4}, mapnew(dconst, {_, v -> v + 1}))
endfunc

func Test_mapnew_list()
  let lin = [1, 2, 3]
  let lout = mapnew(lin, {k, v -> string(v)})
  call assert_equal([1, 2, 3], lin)
  call assert_equal(['1', '2', '3'], lout)

  const lconst = [1, 2, 3]
  call assert_equal([2, 3, 4], mapnew(lconst, {_, v -> v + 1}))
endfunc

func Test_mapnew_blob()
  let bin = 0z123456
  let bout = mapnew(bin, {k, v -> k == 1 ? 0x99 : v})
  call assert_equal(0z123456, bin)
  call assert_equal(0z129956, bout)
endfunc

" Test for using map(), filter() and mapnew() with a string
func Test_filter_map_string()
  " filter()
  let lines =<< trim END
    VAR s = "abc"
    call filter(s, '"b" != v:val')
    call assert_equal('abc', s)
    call assert_equal('ac', filter('abc', '"b" != v:val'))
    call assert_equal('あいうえお', filter('あxいxうxえxお', '"x" != v:val'))
    call assert_equal('あa😊💕💕b💕', filter('あxax😊x💕💕b💕x', '"x" != v:val'))
    call assert_equal('xxxx', filter('あxax😊x💕💕b💕x', '"x" == v:val'))
    VAR t = "%),:;>?]}’”†‡…‰,‱‼⁇⁈⁉℃℉,、。〉》」,』】〕〗〙〛,！），．：,；？,］｝"
    VAR u = "%):;>?]}’”†‡…‰‱‼⁇⁈⁉℃℉、。〉》」』】〕〗〙〛！），．：；？］｝"
    call assert_equal(u, filter(t, '"," != v:val'))
    call assert_equal('', filter('abc', '0'))
    call assert_equal('ac', filter('abc', LSTART i, x LMIDDLE "b" != x LEND))
    call assert_equal('あいうえお', filter('あxいxうxえxお', LSTART i, x LMIDDLE "x" != x LEND))
    call assert_equal('', filter('abc', LSTART i, x LMIDDLE v:false LEND))
    call assert_equal('', filter('', "v:val == 'a'"))
    call assert_equal('', filter(v:_null_string, "v:val == 'a'"))
  END
  call CheckLegacyAndVim9Success(lines)

  " map()
  let lines =<< trim END
    VAR s = "abc"
    call map(s, 'nr2char(char2nr(v:val) + 2)')
    call assert_equal('abc', s)
    call assert_equal('cde', map('abc', 'nr2char(char2nr(v:val) + 2)'))
    call assert_equal('[あ][i][う][え][お]', map('あiうえお', '"[" .. v:val .. "]"'))
    call assert_equal('[あ][a][😊][,][‱][‼][⁇][⁈][⁉][💕][b][💕][c][💕]', map('あa😊,‱‼⁇⁈⁉💕b💕c💕', '"[" .. v:val .. "]"'))
    call assert_equal('', map('abc', '""'))
    call assert_equal('cde', map('abc', LSTART i, x LMIDDLE nr2char(char2nr(x) + 2) LEND))
    call assert_equal('[あ][i][う][え][お]', map('あiうえお', LSTART i, x LMIDDLE '[' .. x .. ']' LEND))
    call assert_equal('', map('abc', LSTART i, x LMIDDLE '' LEND))
    call assert_equal('', map('', "v:val == 'a'"))
    call assert_equal('', map(v:_null_string, "v:val == 'a'"))
    call assert_fails('echo map("abc", "10")', 'E928:')
    call assert_fails('echo map("abc", "a10")', 'E121:')
  END
  call CheckLegacyAndVim9Success(lines)

  " mapnew()
  let lines =<< trim END
    VAR s = "abc"
    call mapnew(s, 'nr2char(char2nr(v:val) + 2)')
    call assert_equal('abc', s)
    call assert_equal('cde', mapnew('abc', 'nr2char(char2nr(v:val) + 2)'))
    call assert_equal('[あ][i][う][え][お]', mapnew('あiうえお', '"[" .. v:val .. "]"'))
    call assert_equal('[あ][a][😊][,][‱][‼][⁇][⁈][⁉][💕][b][💕][c][💕]', mapnew('あa😊,‱‼⁇⁈⁉💕b💕c💕', '"[" .. v:val .. "]"'))
    call assert_equal('', mapnew('abc', '""'))
    call assert_equal('cde', mapnew('abc', LSTART i, x LMIDDLE nr2char(char2nr(x) + 2) LEND))
    call assert_equal('[あ][i][う][え][お]', mapnew('あiうえお', LSTART i, x LMIDDLE '[' .. x .. ']' LEND))
    call assert_equal('', mapnew('abc', LSTART i, x LMIDDLE '' LEND))
    call assert_equal('', mapnew('', "v:val == 'a'"))
    call assert_equal('', mapnew(v:_null_string, "v:val == 'a'"))
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
    #" map() and filter()
    call assert_equal('[あ][⁈][a][😊][⁉][💕][💕][b][💕]', map(filter('あx⁈ax😊x⁉💕💕b💕x', '"x" != v:val'), '"[" .. v:val .. "]"'))

    #" patterns-composing(\Z)
    call assert_equal('ॠॠ', filter('ऊॠॡ,ऊॠॡ', LSTART i, x LMIDDLE x =~ '\Z' .. nr2char(0x0960) LEND))
    call assert_equal('àà', filter('càt,càt', LSTART i, x LMIDDLE x =~ '\Za' LEND))
    call assert_equal('ÅÅ', filter('Åström,Åström', LSTART i, x LMIDDLE x =~ '\Z' .. nr2char(0xc5) LEND))
    call assert_equal('öö', filter('Åström,Åström', LSTART i, x LMIDDLE x =~ '\Z' .. nr2char(0xf6) LEND))
    call assert_equal('ऊ@ॡ', map('ऊॠॡ', LSTART i, x LMIDDLE x =~ '\Z' .. nr2char(0x0960) ? '@' : x LEND))
    call assert_equal('c@t', map('càt', LSTART i, x LMIDDLE x =~ '\Za' ? '@' : x LEND))
    call assert_equal('@ström', map('Åström', LSTART i, x LMIDDLE x =~ '\Z' .. nr2char(0xc5) ? '@' : x LEND))
    call assert_equal('Åstr@m', map('Åström', LSTART i, x LMIDDLE x =~ '\Z' .. nr2char(0xf6) ? '@' : x LEND))

    #" patterns-composing(\%C)
    call assert_equal('ॠॠ', filter('ऊॠॡ,ऊॠॡ', LSTART i, x LMIDDLE x =~ nr2char(0x0960) .. '\%C' LEND))
    call assert_equal('àà', filter('càt,càt', LSTART i, x LMIDDLE x =~ 'a' .. '\%C' LEND))
    call assert_equal('ÅÅ', filter('Åström,Åström', LSTART i, x LMIDDLE x =~ nr2char(0xc5) .. '\%C' LEND))
    call assert_equal('öö', filter('Åström,Åström', LSTART i, x LMIDDLE x =~ nr2char(0xf6) .. '\%C' LEND))
    call assert_equal('ऊ@ॡ', map('ऊॠॡ', LSTART i, x LMIDDLE x =~ nr2char(0x0960) .. '\%C' ? '@' : x LEND))
    call assert_equal('c@t', map('càt', LSTART i, x LMIDDLE x =~ 'a' .. '\%C' ? '@' : x LEND))
    call assert_equal('@ström', map('Åström', LSTART i, x LMIDDLE x =~ nr2char(0xc5) .. '\%C' ? '@' : x LEND))
    call assert_equal('Åstr@m', map('Åström', LSTART i, x LMIDDLE x =~ nr2char(0xf6) .. '\%C' ? '@' : x LEND))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
