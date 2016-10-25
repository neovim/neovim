" Test binding arguments to a Funcref.

func MyFunc(arg1, arg2, arg3)
  return a:arg1 . '/' . a:arg2 . '/' . a:arg3
endfunc

func MySort(up, one, two)
  if a:one == a:two
    return 0
  endif
  if a:up
    return a:one > a:two
  endif
  return a:one < a:two
endfunc

func Test_partial_args()
  let Cb = function('MyFunc', ["foo", "bar"])
  call assert_equal("foo/bar/xxx", Cb("xxx"))
  call assert_equal("foo/bar/yyy", call(Cb, ["yyy"]))

  let Sort = function('MySort', [1])
  call assert_equal([1, 2, 3], sort([3, 1, 2], Sort))
  let Sort = function('MySort', [0])
  call assert_equal([3, 2, 1], sort([3, 1, 2], Sort))
endfunc

func MyDictFunc(arg1, arg2) dict
  return self.name . '/' . a:arg1 . '/' . a:arg2
endfunc

func Test_partial_dict()
  let dict = {'name': 'hello'}
  let Cb = function('MyDictFunc', ["foo", "bar"], dict)
  call assert_equal("hello/foo/bar", Cb())
  call assert_fails('Cb("xxx")', 'E492:')
  let Cb = function('MyDictFunc', ["foo"], dict)
  call assert_equal("hello/foo/xxx", Cb("xxx"))
  call assert_fails('Cb()', 'E492:')
  let Cb = function('MyDictFunc', dict)
  call assert_equal("hello/xxx/yyy", Cb("xxx", "yyy"))
  call assert_fails('Cb()', 'E492:')
endfunc
