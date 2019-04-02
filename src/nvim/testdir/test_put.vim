" Tests for put commands, e.g. ":put", "p", "gp", "P", "gP", etc.

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

func Test_put_expr()
  new
  call setline(1, repeat(['A'], 6))
  exec "1norm! \"=line('.')\<cr>p"
  norm! j0.
  norm! j0.
  exec "4norm! \"=\<cr>P"
  norm! j0.
  norm! j0.
  call assert_equal(['A1','A2','A3','4A','5A','6A'], getline(1,'$'))
  bw!
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

func Test_put_fails_when_nomodifiable()
  new
  setlocal nomodifiable

  normal! yy
  call assert_fails(':put', 'E21')
  call assert_fails(':put!', 'E21')
  call assert_fails(':normal! p', 'E21')
  call assert_fails(':normal! gp', 'E21')
  call assert_fails(':normal! P', 'E21')
  call assert_fails(':normal! gP', 'E21')

  if has('mouse')
    set mouse=n
    call assert_fails('execute "normal! \<MiddleMouse>"', 'E21')
    set mouse&
  endif

  bwipeout!
endfunc

" A bug was discovered where the Normal mode put commands (e.g., "p") would
" output duplicate error messages when invoked in a non-modifiable buffer.
func Test_put_p_errmsg_nodup()
  new
  setlocal nomodifiable

  normal! yy

  func Capture_p_error()
    redir => s:p_err
    normal! p
    redir END
  endfunc

  silent! call Capture_p_error()

  " Error message output within a function should be three lines (the function
  " name, the line number, and the error message).
  call assert_equal(3, count(s:p_err, "\n"))

  delfunction Capture_p_error
  bwipeout!
endfunc
