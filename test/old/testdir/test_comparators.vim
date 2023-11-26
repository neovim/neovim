function Test_Comparators()
  try
    let oldisident=&isident
    set isident+=#
    call assert_equal(1, 1 is#1)
  finally
    let &isident=oldisident
  endtry
endfunction
