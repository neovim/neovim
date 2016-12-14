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

func MyMap(sub, index, val)
  return a:val - a:sub
endfunc

func MyFilter(threshold, index, val)
  return a:val > a:threshold
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

  let Map = function('MyMap', [2])
  call assert_equal([-1, 0, 1], map([1, 2, 3], Map))
  let Map = function('MyMap', [3])
  call assert_equal([-2, -1, 0], map([1, 2, 3], Map))

  let Filter = function('MyFilter', [1])
  call assert_equal([2, 3], filter([1, 2, 3], Filter))
  let Filter = function('MyFilter', [2])
  call assert_equal([3], filter([1, 2, 3], Filter))
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

  let Cb = function('MyDictFunc', dict)
  call assert_equal({"foo": "hello/foo/1", "bar": "hello/bar/2"}, map({"foo": 1, "bar": 2}, Cb))

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

function! s:cache_arg(arg) dict
  let s:result = self.name . '/' . a:arg
  return s:result
endfunction

func Test_script_function_in_dict_arg()
  let s:obj = {'name': 'foo'}
  let s:obj['clear'] = function('s:cache_arg')

  call assert_equal('foo/bar', s:obj.clear('bar'))
  let F = s:obj.clear
  let s:result = ''
  call assert_equal('foo/bar', F('bar'))
  call assert_equal('foo/bar', s:result)

  let s:obj['clear'] = function('s:cache_arg', ['bar'])
  call assert_equal('foo/bar', s:obj.clear())
  let s:result = ''
  call s:obj.clear()
  call assert_equal('foo/bar', s:result)

  let F = s:obj.clear
  call assert_equal('foo/bar', F())
  let s:result = ''
  call F()
  call assert_equal('foo/bar', s:result)

  call assert_equal('foo/bar', call(s:obj.clear, [], s:obj))
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

func Test_partial_string()
  let F = function('MyFunc')
  call assert_equal("function('MyFunc')", string(F))
  let F = function('MyFunc', ['foo'])
  call assert_equal("function('MyFunc', ['foo'])", string(F))
  let F = function('MyFunc', ['foo', 'bar'])
  call assert_equal("function('MyFunc', ['foo', 'bar'])", string(F))
  let d = {'one': 1}
  let F = function('MyFunc', d)
  call assert_equal("function('MyFunc', {'one': 1})", string(F))
  let F = function('MyFunc', ['foo'], d)
  call assert_equal("function('MyFunc', ['foo'], {'one': 1})", string(F))
endfunc

func Test_func_unref()
  let obj = {}
  function! obj.func() abort
  endfunction
  let funcnumber = matchstr(string(obj.func), '^function(''\zs.\{-}\ze''')
  call assert_true(exists('*{' . funcnumber . '}'))
  unlet obj
  call assert_false(exists('*{' . funcnumber . '}'))
endfunc

func Test_redefine_dict_func()
  let d = {}
  function d.test4()
  endfunction
  let d.test4 = d.test4
  try
    function! d.test4(name)
    endfunction
  catch
    call assert_true(v:errmsg, v:exception)
  endtry
endfunc

" This caused double free on exit if EXITFREE is defined.
func Test_cyclic_list_arg()
  let l = []
  let Pt = function('string', [l])
  call add(l, Pt)
  unlet l
  unlet Pt
endfunc

" This caused double free on exit if EXITFREE is defined.
func Test_cyclic_dict_arg()
  let d = {}
  let Pt = function('string', [d])
  let d.Pt = Pt
  unlet d
  unlet Pt
endfunc

func Ignored(job1, job2, status)
endfunc

" func Test_cycle_partial_job()
"   let job = job_start('echo')
"   call job_setoptions(job, {'exit_cb': function('Ignored', [job])})
"   unlet job
" endfunc

" func Test_ref_job_partial_dict()
"   let g:ref_job = job_start('echo')
"   let d = {'a': 'b'}
"   call job_setoptions(g:ref_job, {'exit_cb': function('string', [], d)})
" endfunc

func Test_auto_partial_rebind()
  let dict1 = {'name': 'dict1'}
  func! dict1.f1()
    return self.name
  endfunc
  let dict1.f2 = function(dict1.f1, dict1)

  call assert_equal('dict1', dict1.f1())
  call assert_equal('dict1', dict1['f1']())
  call assert_equal('dict1', dict1.f2())
  call assert_equal('dict1', dict1['f2']())

  let dict2 = {'name': 'dict2'}
  let dict2.f1 = dict1.f1
  let dict2.f2 = dict1.f2

  call assert_equal('dict2', dict2.f1())
  call assert_equal('dict2', dict2['f1']())
  call assert_equal('dict1', dict2.f2())
  call assert_equal('dict1', dict2['f2']())
endfunc

func Test_get_partial_items()
  let dict = {'name': 'hello'}
  let args = ["foo", "bar"]
  let Func = function('MyDictFunc')
  let Cb = function('MyDictFunc', args, dict)

  call assert_equal(Func, get(Cb, 'func'))
  call assert_equal('MyDictFunc', get(Cb, 'name'))
  call assert_equal(args, get(Cb, 'args'))
  call assert_equal(dict, get(Cb, 'dict'))
  call assert_fails('call get(Cb, "xxx")', 'E475:')

  call assert_equal(Func, get(Func, 'func'))
  call assert_equal('MyDictFunc', get(Func, 'name'))
  call assert_equal([], get(Func, 'args'))
  call assert_true(empty( get(Func, 'dict')))
endfunc

func Test_compare_partials()
  let d1 = {}
  let d2 = {}

  function d1.f1() dict
  endfunction

  function d1.f2() dict
  endfunction

  let F1 = get(d1, 'f1')
  let F2 = get(d1, 'f2')

  let F1d1 = function(F1, d1)
  let F2d1 = function(F2, d2)
  let F1d1a1 = function(F1d1, [1])
  let F1d1a12 = function(F1d1, [1, 2])
  let F1a1 = function(F1, [1])
  let F1a2 = function(F1, [2])
  let F1d2 = function(F1, d2)
  let d3 = {'f1': F1, 'f2': F2}
  let F1d3 = function(F1, d3)
  let F1ad1 = function(F1, [d1])
  let F1ad3 = function(F1, [d3])

  call assert_match('^function(''\d\+'')$', string(F1))  " Not a partial
  call assert_match('^function(''\d\+'')$', string(F2))  " Not a partial
  call assert_match('^function(''\d\+'', {.*})$', string(F1d1))  " A partial
  call assert_match('^function(''\d\+'', {.*})$', string(F2d1))  " A partial
  call assert_match('^function(''\d\+'', \[.*\])$', string(F1a1))  " No dict

  " !=
  let X = F1
  call assert_false(F1 != X)  " same function
  let X = F1d1
  call assert_false(F1d1 != X)  " same partial
  let X = F1d1a1
  call assert_false(F1d1a1 != X)  " same partial
  let X = F1a1
  call assert_false(F1a1 != X)  " same partial

  call assert_true(F1 != F2)  " Different functions
  call assert_true(F1 != F1d1)  " Partial /= non-partial
  call assert_true(F1d1a1 != F1d1a12)  " Different number of arguments
  call assert_true(F1a1 != F1d1a12)  " One has no dict
  call assert_true(F1a1 != F1a2)  " Different arguments
  call assert_true(F1d2 != F1d1)  " Different dictionaries
  call assert_false(F1d1 != F1d3)  " Equal dictionaries, even though d1 isnot d3

  " isnot, option 1
  call assert_true(F1 isnot# F2)  " Different functions
  call assert_true(F1 isnot# F1d1)  " Partial /= non-partial
  call assert_true(F1d1 isnot# F1d3)  " d1 isnot d3, even though d1 == d3
  call assert_true(F1a1 isnot# F1d1a12)  " One has no dict
  call assert_true(F1a1 isnot# F1a2)  " Different number of arguments
  call assert_true(F1ad1 isnot# F1ad3)  " In arguments d1 isnot d3

  " isnot, option 2
  call assert_true(F1 isnot# F2)  " Different functions
  call assert_true(F1 isnot# F1d1)  " Partial /= non-partial
  call assert_true(d1.f1 isnot# d1.f1)  " handle_subscript creates new partial each time
endfunc
