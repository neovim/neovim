
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

func Test_put_char_block2()
  new
  let a = [ getreg('a'), getregtype('a') ]
  call setreg('a', ' one ', 'v')
  call setline(1, ['Line 1', '', 'Line 3', ''])
  " visually select the first 3 lines and put register a over it
  exe "norm! ggl\<c-v>2j2l\"ap"
  call assert_equal(['L one  1', '', 'L one  3', ''], getline(1,4))
  " clean up
  bw!
  call setreg('a', a[0], a[1])
endfunc

func Test_put_lines()
  new
  let a = [ getreg('a'), getregtype('a') ]
  call setline(1, ['Line 1', 'Line2', 'Line 3', ''])
  exe 'norm! gg"add"AddG""p'
  call assert_equal(['Line 3', '', 'Line 1', 'Line2'], getline(1,'$'))
  " clean up
  bw!
  call setreg('a', a[0], a[1])
endfunc
