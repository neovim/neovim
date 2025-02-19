" Test for lambda and closure

func Test_lambda_feature()
  call assert_equal(1, has('lambda'))
endfunc

func Test_lambda_with_filter()
  let s:x = 2
  call assert_equal([2, 3], filter([1, 2, 3], {i, v -> v >= s:x}))
endfunc

func Test_lambda_with_map()
  let s:x = 1
  call assert_equal([2, 3, 4], map([1, 2, 3], {i, v -> v + s:x}))
endfunc

func Test_lambda_with_sort()
  call assert_equal([1, 2, 3, 4, 7], sort([3,7,2,1,4], {a, b -> a - b}))
endfunc

func Test_lambda_with_timer()
  if !has('timers')
    return
  endif

  let s:n = 0
  let s:timer_id = 0
  func! s:Foo()
    let s:timer_id = timer_start(10, {-> execute("let s:n += 1 | echo s:n", "")}, {"repeat": -1})
  endfunc

  call s:Foo()
  " check timer works
  for i in range(0, 10)
    if s:n > 0
      break
    endif
    sleep 10m
  endfor

  " do not collect lambda
  call test_garbagecollect_now()

  " check timer still works
  let m = s:n
  for i in range(0, 10)
    if s:n > m
      break
    endif
    sleep 10m
  endfor

  call timer_stop(s:timer_id)
  call assert_true(s:n > m)
endfunc

func Test_lambda_with_partial()
  let l:Cb = function({... -> ['zero', a:1, a:2, a:3]}, ['one', 'two'])
  call assert_equal(['zero', 'one', 'two', 'three'], l:Cb('three'))
endfunc

function Test_lambda_fails()
  call assert_equal(3, {a, b -> a + b}(1, 2))
  call assert_fails('echo {a, a -> a + a}(1, 2)', 'E853:')
  call assert_fails('echo {a, b -> a + b)}(1, 2)', 'E451:')
  echo assert_fails('echo 10->{a -> a + 2}', 'E107:')
endfunc

func Test_not_lambda()
  let x = {'>' : 'foo'}
  call assert_equal('foo', x['>'])
endfunc

func Test_lambda_capture_by_reference()
  let v = 1
  let l:F = {x -> x + v}
  let v = 2
  call assert_equal(12, l:F(10))
endfunc

func Test_lambda_side_effect()
  func! s:update_and_return(arr)
    let a:arr[1] = 5
    return a:arr
  endfunc

  func! s:foo(arr)
    return {-> s:update_and_return(a:arr)}
  endfunc

  let arr = [3,2,1]
  call assert_equal([3, 5, 1], s:foo(arr)())
endfunc

func Test_lambda_refer_local_variable_from_other_scope()
  func! s:foo(X)
    return a:X() " refer l:x in s:bar()
  endfunc

  func! s:bar()
    let x = 123
    return s:foo({-> x})
  endfunc

  call assert_equal(123, s:bar())
endfunc

func Test_lambda_do_not_share_local_variable()
  func! s:define_funcs()
    let l:One = {-> split(execute("let a = 'abc' | echo a"))[0]}
    let l:Two = {-> exists("a") ? a : "no"}
    return [l:One, l:Two]
  endfunc

  let l:F = s:define_funcs()

  call assert_equal('no', l:F[1]())
  call assert_equal('abc', l:F[0]())
  call assert_equal('no', l:F[1]())
endfunc

func Test_lambda_closure_counter()
  func! s:foo()
    let x = 0
    return {-> [execute("let x += 1"), x][-1]}
  endfunc

  let l:F = s:foo()
  call test_garbagecollect_now()
  call assert_equal(1, l:F())
  call assert_equal(2, l:F())
  call assert_equal(3, l:F())
  call assert_equal(4, l:F())
endfunc

func Test_lambda_with_a_var()
  func! s:foo()
    let x = 2
    return {... -> a:000 + [x]}
  endfunc
  func! s:bar()
    return s:foo()(1)
  endfunc

  call assert_equal([1, 2], s:bar())
endfunc

func Test_lambda_call_lambda_from_lambda()
  func! s:foo(x)
    let l:F1 = {-> {-> a:x}}
    return {-> l:F1()}
  endfunc

  let l:F = s:foo(1)
  call assert_equal(1, l:F()())
endfunc

func Test_lambda_delfunc()
  func! s:gen()
    let pl = l:
    let l:Foo = {-> get(pl, "Foo", get(pl, "Bar", {-> 0}))}
    let l:Bar = l:Foo
    delfunction l:Foo
    return l:Bar
  endfunc

  let l:F = s:gen()
  call assert_fails(':call l:F()', 'E933:')
endfunc

func Test_lambda_scope()
  func! s:NewCounter()
    let c = 0
    return {-> [execute('let c += 1'), c][-1]}
  endfunc

  func! s:NewCounter2()
    return {-> [execute('let c += 100'), c][-1]}
  endfunc

  let l:C = s:NewCounter()
  let l:D = s:NewCounter2()

  call assert_equal(1, l:C())
  call assert_fails(':call l:D()', 'E121:')
  call assert_equal(2, l:C())
endfunc

func Test_lambda_share_scope()
  func! s:New()
    let c = 0
    let l:Inc0 = {-> [execute('let c += 1'), c][-1]}
    let l:Dec0 = {-> [execute('let c -= 1'), c][-1]}
    return [l:Inc0, l:Dec0]
  endfunc

  let [l:Inc, l:Dec] = s:New()

  call assert_equal(1, l:Inc())
  call assert_equal(2, l:Inc())
  call assert_equal(1, l:Dec())
endfunc

func Test_lambda_circular_reference()
  func! s:Foo()
    let d = {}
    let d.f = {-> d}
    return d.f
  endfunc

  call s:Foo()
  call test_garbagecollect_now()
  let i = 0 | while i < 10000 | call s:Foo() | let i+= 1 | endwhile
  call test_garbagecollect_now()
endfunc

func Test_lambda_combination()
  call assert_equal(2, {x -> {x -> x}}(1)(2))
  call assert_equal(10, {y -> {x -> x(y)(10)}({y -> y})}({z -> z}))
  if has('float')
    call assert_equal(5.0, {x -> {y -> x / y}}(10)(2.0))
  endif
  call assert_equal(6, {x -> {y -> {z -> x + y + z}}}(1)(2)(3))

  call assert_equal(6, {x -> {f -> f(x)}}(3)({x -> x * 2}))
  call assert_equal(6, {f -> {x -> f(x)}}({x -> x * 2})(3))

  " Z combinator
  let Z = {f -> {x -> f({y -> x(x)(y)})}({x -> f({y -> x(x)(y)})})}
  let Fact = {f -> {x -> x == 0 ? 1 : x * f(x - 1)}}
  call assert_equal(120, Z(Fact)(5))
endfunc

func Test_closure_counter()
  func! s:foo()
    let x = 0
    func! s:bar() closure
      let x += 1
      return x
    endfunc
    return function('s:bar')
  endfunc

  let l:F = s:foo()
  call test_garbagecollect_now()
  call assert_equal(1, l:F())
  call assert_equal(2, l:F())
  call assert_equal(3, l:F())
  call assert_equal(4, l:F())

  call assert_match("^\n   function <SNR>\\d\\+_bar() closure"
  \              .. "\n1        let x += 1"
  \              .. "\n2        return x"
  \              .. "\n   endfunction$", execute('func s:bar'))
endfunc

func Test_closure_unlet()
  func! s:foo()
    let x = 1
    func! s:bar() closure
      unlet x
    endfunc
    call s:bar()
    return l:
  endfunc

  call assert_false(has_key(s:foo(), 'x'))
  call test_garbagecollect_now()
endfunc

func LambdaFoo()
  let x = 0
  func! LambdaBar() closure
    let x += 1
    return x
  endfunc
  return function('LambdaBar')
endfunc

func Test_closure_refcount()
  let g:Count = LambdaFoo()
  call test_garbagecollect_now()
  call assert_equal(1, g:Count())
  let g:Count2 = LambdaFoo()
  call test_garbagecollect_now()
  call assert_equal(1, g:Count2())
  call assert_equal(2, g:Count())
  call assert_equal(3, g:Count2())

  delfunc LambdaFoo
  delfunc LambdaBar
endfunc

" This test is causing a use-after-free on shutdown.
func Test_named_function_closure()
  func! Afoo()
    let x = 14
    func! s:Abar() closure
      return x
    endfunc
    call assert_equal(14, s:Abar())
  endfunc
  call Afoo()
  call assert_equal(14, s:Abar())
  call test_garbagecollect_now()
  call assert_equal(14, s:Abar())
endfunc

func Test_lambda_with_index()
  let List = {x -> [x]}
  let Extract = {-> function(List, ['foobar'])()[0]}
  call assert_equal('foobar', Extract())
endfunc

func Test_lambda_error()
  " This was causing a crash
  call assert_fails('ec{@{->{d->()()', 'E15')
endfunc

func Test_closure_error()
  let l =<< trim END
    func F1() closure
      return 1
    endfunc
  END
  call writefile(l, 'Xscript')
  let caught_932 = 0
  try
    source Xscript
  catch /E932:/
    let caught_932 = 1
  endtry
  call assert_equal(1, caught_932)
  call delete('Xscript')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
