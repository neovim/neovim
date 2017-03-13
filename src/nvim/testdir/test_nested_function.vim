"Tests for nested functions
"
function! NestedFunc()
  fu! Func1()
    let g:text .= 'Func1 '
  endfunction
  call Func1()
  fu! s:func2()
    let g:text .= 's:func2 '
  endfunction
  call s:func2()
  fu! s:_func3()
    let g:text .= 's:_func3 '
  endfunction
  call s:_func3()
  let fn = 'Func4'
  fu! {fn}()
    let g:text .= 'Func4 '
  endfunction
  call {fn}()
  let fn = 'func5'
  fu! s:{fn}()
    let g:text .= 's:func5'
  endfunction
  call s:{fn}()
endfunction

function! Test_nested_functions()
  let g:text = ''
  call NestedFunc()
  call assert_equal('Func1 s:func2 s:_func3 Func4 s:func5', g:text)
endfunction
