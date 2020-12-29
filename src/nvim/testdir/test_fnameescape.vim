
" Test if fnameescape is correct for special chars like !
func Test_fnameescape()
  let fname = 'Xspa ce'
  let status = v:false
  try
    exe "w! " . fnameescape(fname)
    let status = v:true
  endtry
  call assert_true(status, "Space")
  call delete(fname)

  let fname = 'Xemark!'
  let status = v:false
  try
    exe "w! " . fnameescape(fname)
    let status = v:true
  endtry
  call assert_true(status, "ExclamationMark")
  call delete(fname)
endfunc
