" Tests for 'virtualedit'.

func Test_yank_move_change()
  new
  call setline(1, [
	\ "func foo() error {",
	\ "\tif n, err := bar();",
	\ "\terr != nil {",
	\ "\t\treturn err",
	\ "\t}",
	\ "\tn = n * n",
	\ ])
  set virtualedit=all
  set ts=4
  function! MoveSelectionDown(count) abort
    normal! m`
    silent! exe "'<,'>move'>+".a:count
    norm! ``
  endfunction

  xmap ]e :<C-U>call MoveSelectionDown(v:count1)<CR>
  2
  normal 2gg
  normal J
  normal jVj
  normal ]e
  normal ce
  bwipe!
  set virtualedit=
  set ts=8
endfunc

func Test_paste_end_of_line()
  new
  set virtualedit=all
  call setline(1, ['456', '123'])
  normal! gg0"ay$
  exe "normal! 2G$lllA\<C-O>:normal! \"agP\r"
  call assert_equal('123456', getline(2))

  bwipe!
  set virtualedit=
endfunc
