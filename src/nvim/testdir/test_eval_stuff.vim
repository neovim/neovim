" Tests for various eval things.

function s:foo() abort
  try
    return [] == 0
  catch
    return 1
  endtry
endfunction

func Test_catch_return_with_error()
  call assert_equal(1, s:foo())
endfunc
