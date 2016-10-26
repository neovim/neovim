" Test binding arguments to a Funcref.

func MyFunc(arg1, arg2, arg3)
  return a:arg1 . '/' . a:arg2 . '/' . a:arg3
endfunc

func MySort(up, one, two)
  if a:one == a:two
    return 0
  endif
  if a:up
    return a:one > a:two ? 1 : -1
  endif
  return a:one < a:two ? 1 : -1
endfunc

func Test_partial_args()
  let Cb = function('MyFunc', ["foo", "bar"])
  call assert_equal("foo/bar/xxx", Cb("xxx"))
  call assert_equal("foo/bar/yyy", call(Cb, ["yyy"]))

  let Cb = function('MyFunc', [])
  call assert_equal("a/b/c", Cb("a", "b", "c"))

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

  let Cb = function('MyDictFunc', [], dict)
  call assert_equal("hello/ttt/xxx", Cb("ttt", "xxx"))
  call assert_fails('Cb("yyy")', 'E492:')

  let Cb = function('MyDictFunc', ["foo"], dict)
  call assert_equal("hello/foo/xxx", Cb("xxx"))
  call assert_fails('Cb()', 'E492:')
  let Cb = function('MyDictFunc', dict)
  call assert_equal("hello/xxx/yyy", Cb("xxx", "yyy"))
  call assert_fails('Cb("fff")', 'E492:')
endfunc

func Test_partial_implicit()
  let dict = {'name': 'foo'}
  func dict.MyFunc(arg) dict
    return self.name . '/' . a:arg
  endfunc

  call assert_equal('foo/bar',  dict.MyFunc('bar'))

  call assert_fails('let func = dict.MyFunc', 'E704:')
  let Func = dict.MyFunc
  call assert_equal('foo/aaa', Func('aaa'))

  let Func = function(dict.MyFunc, ['bbb'])
  call assert_equal('foo/bbb', Func())

  call assert_fails('call function(dict.MyFunc, ["bbb"], dict)', 'E924:')
endfunc

fun InnerCall(funcref)
  return a:funcref
endfu

fun OuterCall()
  let opt = { 'func' : function('sin') }
  call InnerCall(opt.func)
endfu

func Test_function_in_dict()
  call OuterCall()
endfunc

