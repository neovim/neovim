" Test for lambda and closure

function! Test_lambda_feature()
  call assert_equal(1, has('lambda'))
endfunction

function! Test_lambda_with_filter()
  let s:x = 2
  call assert_equal([2, 3], filter([1, 2, 3], {i, v -> v >= s:x}))
endfunction

function! Test_lambda_with_map()
  let s:x = 1
  call assert_equal([2, 3, 4], map([1, 2, 3], {i, v -> v + s:x}))
endfunction

function! Test_lambda_with_sort()
  call assert_equal([1, 2, 3, 4, 7], sort([3,7,2,1,4], {a, b -> a - b}))
endfunction

function! Test_lambda_with_timer()
  if !has('timers')
    return
  endif

  let s:n = 0
  let s:timer_id = 0
  function! s:Foo()
    "let n = 0
    let s:timer_id = timer_start(50, {-> execute("let s:n += 1 | echo s:n", "")}, {"repeat": -1})
  endfunction

  call s:Foo()
  sleep 210ms
  " do not collect lambda
  call garbagecollect()
  let m = s:n
  sleep 210ms
  call timer_stop(s:timer_id)
  call assert_true(m > 1)
  call assert_true(s:n > m + 1)
  call assert_true(s:n < 9)
endfunction

function! Test_lambda_with_partial()
  let l:Cb = function({... -> ['zero', a:1, a:2, a:3]}, ['one', 'two'])
  call assert_equal(['zero', 'one', 'two', 'three'], l:Cb('three'))
endfunction

function Test_lambda_fails()
  call assert_equal(3, {a, b -> a + b}(1, 2))
  call assert_fails('echo {a, a -> a + a}(1, 2)', 'E15:')
  call assert_fails('echo {a, b -> a + b)}(1, 2)', 'E15:')
endfunc

func Test_not_lambda()
  let x = {'>' : 'foo'}
  call assert_equal('foo', x['>'])
endfunc

function! Test_lambda_capture_by_reference()
  let v = 1
  let l:F = {x -> x + v}
  let v = 2
  call assert_equal(12, l:F(10))
endfunction

function! Test_lambda_side_effect()
  function! s:update_and_return(arr)
    let a:arr[1] = 5
    return a:arr
  endfunction

  function! s:foo(arr)
    return {-> s:update_and_return(a:arr)}
  endfunction

  let arr = [3,2,1]
  call assert_equal([3, 5, 1], s:foo(arr)())
endfunction

function! Test_lambda_refer_local_variable_from_other_scope()
  function! s:foo(X)
    return a:X() " refer l:x in s:bar()
  endfunction

  function! s:bar()
    let x = 123
    return s:foo({-> x})
  endfunction

  call assert_equal(123, s:bar())
endfunction

function! Test_lambda_do_not_share_local_variable()
  function! s:define_funcs()
    let l:One = {-> split(execute("let a = 'abc' | echo a"))[0]}
    let l:Two = {-> exists("a") ? a : "no"}
    return [l:One, l:Two]
  endfunction

  let l:F = s:define_funcs()

  call assert_equal('no', l:F[1]())
  call assert_equal('abc', l:F[0]())
  call assert_equal('no', l:F[1]())
endfunction

function! Test_lambda_closure_counter()
  function! s:foo()
    let x = 0
    return {-> [execute("let x += 1"), x][-1]}
  endfunction

  let l:F = s:foo()
  call garbagecollect()
  call assert_equal(1, l:F())
  call assert_equal(2, l:F())
  call assert_equal(3, l:F())
  call assert_equal(4, l:F())
endfunction

function! Test_lambda_with_a_var()
  function! s:foo()
    let x = 2
    return {... -> a:000 + [x]}
  endfunction
  function! s:bar()
    return s:foo()(1)
  endfunction

  call assert_equal([1, 2], s:bar())
endfunction

function! Test_lambda_call_lambda_from_lambda()
  function! s:foo(x)
    let l:F1 = {-> {-> a:x}}
    return {-> l:F1()}
  endfunction

  let l:F = s:foo(1)
  call assert_equal(1, l:F()())
endfunction

function! Test_lambda_delfunc()
  function! s:gen()
    let pl = l:
    let l:Foo = {-> get(pl, "Foo", get(pl, "Bar", {-> 0}))}
    let l:Bar = l:Foo
    delfunction l:Foo
    return l:Bar
  endfunction

  let l:F = s:gen()
  call assert_fails(':call l:F()', 'E933:')
endfunction

function! Test_lambda_scope()
  function! s:NewCounter()
    let c = 0
    return {-> [execute('let c += 1'), c][-1]}
  endfunction

  function! s:NewCounter2()
    return {-> [execute('let c += 100'), c][-1]}
  endfunction

  let l:C = s:NewCounter()
  let l:D = s:NewCounter2()

  call assert_equal(1, l:C())
  call assert_fails(':call l:D()', 'E15:') " E121: then E15:
  call assert_equal(2, l:C())
endfunction

function! Test_lambda_share_scope()
  function! s:New()
    let c = 0
    let l:Inc0 = {-> [execute('let c += 1'), c][-1]}
    let l:Dec0 = {-> [execute('let c -= 1'), c][-1]}
    return [l:Inc0, l:Dec0]
  endfunction

  let [l:Inc, l:Dec] = s:New()

  call assert_equal(1, l:Inc())
  call assert_equal(2, l:Inc())
  call assert_equal(1, l:Dec())
endfunction

function! Test_lambda_circular_reference()
  function! s:Foo()
    let d = {}
    let d.f = {-> d}
    return d.f
  endfunction

  call s:Foo()
  call garbagecollect()
  let i = 0 | while i < 10000 | call s:Foo() | let i+= 1 | endwhile
  call garbagecollect()
endfunction

function! Test_lambda_combination()
  call assert_equal(2, {x -> {x -> x}}(1)(2))
  call assert_equal(10, {y -> {x -> x(y)(10)}({y -> y})}({z -> z}))
  call assert_equal(5.0, {x -> {y -> x / y}}(10)(2.0))
  call assert_equal(6, {x -> {y -> {z -> x + y + z}}}(1)(2)(3))

  call assert_equal(6, {x -> {f -> f(x)}}(3)({x -> x * 2}))
  call assert_equal(6, {f -> {x -> f(x)}}({x -> x * 2})(3))

  " Z combinator
  let Z = {f -> {x -> f({y -> x(x)(y)})}({x -> f({y -> x(x)(y)})})}
  let Fact = {f -> {x -> x == 0 ? 1 : x * f(x - 1)}}
  call assert_equal(120, Z(Fact)(5))
endfunction

function! Test_closure_counter()
  function! s:foo()
    let x = 0
    function! s:bar() closure
      let x += 1
      return x
    endfunction
    return function('s:bar')
  endfunction

  let l:F = s:foo()
  call garbagecollect()
  call assert_equal(1, l:F())
  call assert_equal(2, l:F())
  call assert_equal(3, l:F())
  call assert_equal(4, l:F())
endfunction

function! Test_closure_unlet()
  function! s:foo()
    let x = 1
    function! s:bar() closure
      unlet x
    endfunction
    call s:bar()
    return l:
  endfunction

  call assert_false(has_key(s:foo(), 'x'))
  call garbagecollect()
endfunction

function! LambdaFoo()
  let x = 0
  function! LambdaBar() closure
    let x += 1
    return x
  endfunction
  return function('LambdaBar')
endfunction

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
  call garbagecollect()
  call assert_equal(14, s:Abar())
endfunc
