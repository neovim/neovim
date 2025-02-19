" Test behavior of interrupt()

let s:bufwritepre_called = 0
let s:bufwritepost_called = 0

func s:bufwritepre()
  let s:bufwritepre_called = 1
  call interrupt()
endfunction

func s:bufwritepost()
  let s:bufwritepost_called = 1
endfunction

func Test_interrupt()
  new Xinterrupt
  let n = 0
  try
    au BufWritePre Xinterrupt call s:bufwritepre()
    au BufWritePost Xinterrupt call s:bufwritepost()
    w!
  catch /^Vim:Interrupt$/
  endtry
  call assert_equal(1, s:bufwritepre_called)
  call assert_equal(0, s:bufwritepost_called)
  call assert_equal(0, filereadable('Xinterrupt'))

  au! BufWritePre
  au! BufWritePost
endfunc

" vim: shiftwidth=2 sts=2 expandtab
