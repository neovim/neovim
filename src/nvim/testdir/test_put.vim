
func Test_put_block()
  if !has('multi_byte')
    return
  endif
  new
  call feedkeys("i\<C-V>u2500\<CR>x\<ESC>", 'x')
  call feedkeys("\<C-V>y", 'x')
  call feedkeys("gg0p", 'x')
  call assert_equal("\u2500x", getline(1))
  bwipe!
endfunc

func Test_put_char_block()
  new
  call setline(1, ['Line 1', 'Line 2'])
  f Xfile_put
  " visually select both lines and put the cursor at the top of the visual
  " selection and then put the buffer name over it
  exe "norm! G0\<c-v>ke\"%p"
  call assert_equal(['Xfile_put 1', 'Xfile_put 2'], getline(1,2))
  bw!
endfunc
