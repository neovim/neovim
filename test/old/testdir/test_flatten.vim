" Test for flatting list.
func Test_flatten()
  call assert_fails('call flatten(1)', 'E686:')
  call assert_fails('call flatten({})', 'E686:')
  call assert_fails('call flatten("string")', 'E686:')
  call assert_fails('call flatten([], [])', 'E745:')
  call assert_fails('call flatten([], -1)', 'E900: maxdepth')

  call assert_equal([], flatten([]))
  call assert_equal([], flatten([[]]))
  call assert_equal([], flatten([[[]]]))

  call assert_equal([1, 2, 3], flatten([1, 2, 3]))
  call assert_equal([1, 2, 3], flatten([[1], 2, 3]))
  call assert_equal([1, 2, 3], flatten([1, [2], 3]))
  call assert_equal([1, 2, 3], flatten([1, 2, [3]]))
  call assert_equal([1, 2, 3], flatten([[1], [2], 3]))
  call assert_equal([1, 2, 3], flatten([1, [2], [3]]))
  call assert_equal([1, 2, 3], flatten([[1], 2, [3]]))
  call assert_equal([1, 2, 3], flatten([[1], [2], [3]]))

  call assert_equal([1, 2, 3], flatten([[1, 2, 3], []]))
  call assert_equal([1, 2, 3], flatten([[], [1, 2, 3]]))
  call assert_equal([1, 2, 3], flatten([[1, 2], [], [3]]))
  call assert_equal([1, 2, 3], flatten([[], [1, 2, 3], []]))
  call assert_equal([1, 2, 3, 4], flatten(range(1, 4)))

  " example in the help
  call assert_equal([1, 2, 3, 4, 5], flatten([1, [2, [3, 4]], 5]))
  call assert_equal([1, 2, [3, 4], 5], flatten([1, [2, [3, 4]], 5], 1))

  call assert_equal([0, [1], 2, [3], 4], flatten([[0, [1]], 2, [[3], 4]], 1))
  call assert_equal([1, 2, 3], flatten([[[[1]]], [2], [3]], 3))
  call assert_equal([[1], [2], [3]], flatten([[[1], [2], [3]]], 1))
  call assert_equal([[1]], flatten([[1]], 0))

  " Make it flatten if the given maxdepth is larger than actual depth.
  call assert_equal([1, 2, 3], flatten([[1, 2, 3]], 1))
  call assert_equal([1, 2, 3], flatten([[1, 2, 3]], 2))

  let l:list = [[1], [2], [3]]
  call assert_equal([1, 2, 3], flatten(l:list))
  call assert_equal([1, 2, 3], l:list)

  " Tests for checking reference counter works well.
  let l:x = {'foo': 'bar'}
  call assert_equal([1, 2, l:x, 3], flatten([1, [2, l:x], 3]))
  call test_garbagecollect_now()
  call assert_equal('bar', l:x.foo)

  let l:list = [[1], [2], [3]]
  call assert_equal([1, 2, 3], flatten(l:list))
  call test_garbagecollect_now()
  call assert_equal([1, 2, 3], l:list)

  " Tests for checking circular reference list can be flattened.
  let l:x = [1]
  let l:y = [x]
  let l:z = flatten(l:y)
  call assert_equal([1], l:z)
  call test_garbagecollect_now()
  let l:x[0] = 2
  call assert_equal([2], l:x)
  call assert_equal([1], l:z) " NOTE: primitive types are copied.
  call assert_equal([1], l:y)

  let l:x = [2]
  let l:y = [1, [l:x], 3] " [1, [[2]], 3]
  let l:z = flatten(l:y, 1)
  call assert_equal([1, [2], 3], l:z)
  let l:x[0] = 9
  call assert_equal([1, [9], 3], l:z) " Reference to l:x is kept.
  call assert_equal([1, [9], 3], l:y)

  let l:x = [1]
  let l:y = [2]
  call add(x, y) " l:x = [1, [2]]
  call add(y, x) " l:y = [2, [1, [...]]]
  call assert_equal([1, 2, 1, 2], flatten(l:x, 2))
  call assert_equal([2, l:x], l:y)

  let l4 = [ 1, [ 11, [ 101, [ 1001 ] ] ] ]
  call assert_equal(l4, flatten(deepcopy(l4), 0))
  call assert_equal([1, 11, [101, [1001]]], flatten(deepcopy(l4), 1))
  call assert_equal([1, 11, 101, [1001]], flatten(deepcopy(l4), 2))
  call assert_equal([1, 11, 101, 1001], flatten(deepcopy(l4), 3))
  call assert_equal([1, 11, 101, 1001], flatten(deepcopy(l4), 4))
  call assert_equal([1, 11, 101, 1001], flatten(deepcopy(l4)))
endfunc

func Test_flattennew()
  let l = [1, [2, [3, 4]], 5]
  call assert_equal([1, 2, 3, 4, 5], flattennew(l))
  call assert_equal([1, [2, [3, 4]], 5], l)

  call assert_equal([1, 2, [3, 4], 5], flattennew(l, 1))
  call assert_equal([1, [2, [3, 4]], 5], l)

  let l4 = [ 1, [ 11, [ 101, [ 1001 ] ] ] ]
  call assert_equal(l4, flatten(deepcopy(l4), 0))
  call assert_equal([1, 11, [101, [1001]]], flattennew(l4, 1))
  call assert_equal([1, 11, 101, [1001]], flattennew(l4, 2))
  call assert_equal([1, 11, 101, 1001], flattennew(l4, 3))
  call assert_equal([1, 11, 101, 1001], flattennew(l4, 4))
  call assert_equal([1, 11, 101, 1001], flattennew(l4))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
