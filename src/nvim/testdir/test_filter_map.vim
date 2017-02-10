" Test filter() and map()

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
