"Tests for nested functions
"
func NestedFunc()
  func! Func1()
    let g:text .= 'Func1 '
  endfunc
  call Func1()
  func! s:func2()
    let g:text .= 's:func2 '
  endfunc
  call s:func2()
  func! s:_func3()
    let g:text .= 's:_func3 '
  endfunc
  call s:_func3()
  let fn = 'Func4'
  func! {fn}()
    let g:text .= 'Func4 '
  endfunc
  call {fn}()
  let fn = 'func5'
  func! s:{fn}()
    let g:text .= 's:func5'
  endfunc
  call s:{fn}()
endfunc

func Test_nested_functions()
  let g:text = ''
  call NestedFunc()
  call assert_equal('Func1 s:func2 s:_func3 Func4 s:func5', g:text)
endfunction

func Test_nested_argument()
  func g:X()
    let g:Y = function('sort')
  endfunc
  let g:Y = function('sort')
  echo g:Y([], g:X())
  delfunc g:X
  unlet g:Y
endfunc

func Recurse(count)
  if a:count > 0
    call Recurse(a:count - 1)
  endif
endfunc

func Test_max_nesting()
  " TODO: why does this fail on Windows?  Runs out of stack perhaps?
  if has('win32')
    return
  endif
  let call_depth_here = 2
  let ex_depth_here = 5
  set mfd&

  call Recurse(99 - call_depth_here)
  call assert_fails('call Recurse(' . (100 - call_depth_here) . ')', 'E132:')

  set mfd=210
  call Recurse(209 - ex_depth_here)
  call assert_fails('call Recurse(' . (210 - ex_depth_here) . ')', 'E169:')

  set mfd&
endfunc
