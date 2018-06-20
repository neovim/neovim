" Test :recover

func Test_recover_root_dir()
  " This used to access invalid memory.
  split Xtest
  set dir=/
  call assert_fails('recover', 'E305:')
  close!
  call assert_fails('split Xtest', 'E303:')
  set dir&
endfunc

" Inserts 10000 lines with text to fill the swap file with two levels of pointer
" blocks.  Then recovers from the swap file and checks all text is restored.
"
" We need about 10000 lines of 100 characters to get two levels of pointer
" blocks.
func Test_swap_file()
  set directory=.
  set fileformat=unix undolevels=-1
  edit! Xtest
  let text = "\tabcdefghijklmnoparstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnoparstuvwxyz0123456789"
  let i = 1
  let linecount = 10000
  while i <= linecount
    call append(i - 1, i . text)
    let i += 1
  endwhile
  $delete
  preserve
  " get the name of the swap file
  let swname = split(execute("swapname"))[0]
  let swname = substitute(swname, '[[:blank:][:cntrl:]]*\(.\{-}\)[[:blank:][:cntrl:]]*$', '\1', '')
  " make a copy of the swap file in Xswap
  set binary
  exe 'sp ' . swname
  w! Xswap
  set nobinary
  new
  only!
  bwipe! Xtest
  call rename('Xswap', swname)
  recover Xtest
  call delete(swname)
  let linedollar = line('$')
  call assert_equal(linecount, linedollar)
  if linedollar < linecount
    let linecount = linedollar
  endif
  let i = 1
  while i <= linecount
    call assert_equal(i . text, getline(i))
    let i += 1
  endwhile

  set undolevels&
  enew! | only
endfunc
