" Functions shared by several tests.

" Wait for up to a second for "expr" to become true.
" Return time slept in milliseconds.
func WaitFor(expr)
  let slept = 0
  for i in range(100)
    try
      if eval(a:expr)
       return slept
      endif
    catch
    endtry
    let slept += 10
    sleep 10m
  endfor
endfunc
