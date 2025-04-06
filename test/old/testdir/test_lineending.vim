" Tests for saving/loading a file with some lines ending in
" CTRL-M, some not
func Test_lineending()
  let l = ["this line ends in a\<CR>",
	      \ "this one doesn't",
	      \ "this one does\<CR>",
	      \ "and the last one doesn't"]
  set fileformat=dos
  enew!
  call append(0, l)
  $delete
  write Xfile1
  bwipe Xfile1
  edit Xfile1
  let t = getline(1, '$')
  call assert_equal(l, t)
  new | only
  call delete('Xfile1')
endfunc
