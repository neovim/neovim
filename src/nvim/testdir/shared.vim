" Functions shared by several tests.

" Return time slept in milliseconds.  With the +reltime feature this can be
" more than the actual waiting time.  Without +reltime it can also be less.
func WaitFor(expr)
  " using reltime() is more accurate, but not always available
  if has('reltime')
    let start = reltime()
  else
    let slept = 0
  endif
  for i in range(100)
    try
      if eval(a:expr)
        if has('reltime')
          return float2nr(reltimefloat(reltime(start)) * 1000)
        endif
        return slept
      endif
    catch
    endtry
    if !has('reltime')
      let slept += 10
    endif
    sleep 10m
  endfor
  return 1000
endfunc
