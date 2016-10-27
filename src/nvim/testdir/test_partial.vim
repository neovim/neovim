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

  call Cb("zzz")
  call assert_equal("foo/bar/xxx", Cb("xxx"))
  call assert_equal("foo/bar/yyy", call(Cb, ["yyy"]))
  let Cb2 = function(Cb)
  call assert_equal("foo/bar/zzz", Cb2("zzz"))
  let Cb3 = function(Cb, ["www"])
  call assert_equal("foo/bar/www", Cb3())

  let Cb = function('MyFunc', [])
  call assert_equal("a/b/c", Cb("a", "b", "c"))
  let Cb2 = function(Cb, [])
  call assert_equal("a/b/d", Cb2("a", "b", "d"))
  let Cb3 = function(Cb, ["a", "b"])
  call assert_equal("a/b/e", Cb3("e"))

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

  let dict = {"tr": function('tr', ['hello', 'h', 'H'])}
  call assert_equal("Hello", dict.tr())
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

function! s:cache_clear() dict
  return self.name
endfunction

func Test_script_function_in_dict()
  let s:obj = {'name': 'foo'}
  let s:obj2 = {'name': 'bar'}

  let s:obj['clear'] = function('s:cache_clear')

  call assert_equal('foo', s:obj.clear())
  let F = s:obj.clear
  call assert_equal('foo', F())
  call assert_equal('foo', call(s:obj.clear, [], s:obj))
  call assert_equal('bar', call(s:obj.clear, [], s:obj2))

  let s:obj2['clear'] = function('s:cache_clear')
  call assert_equal('bar', s:obj2.clear())
  let B = s:obj2.clear
  call assert_equal('bar', B())
endfunc

func Test_partial_exists()
  let F = function('MyFunc')
  call assert_true(exists('*F'))
  let lF = [F]
  call assert_true(exists('*lF[0]'))

  let F = function('MyFunc', ['arg'])
  call assert_true(exists('*F'))
  let lF = [F]
  call assert_true(exists('*lF[0]'))
endfunc
