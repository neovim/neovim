
" Tests for "r<Tab>" with 'smarttab' and 'expandtab' set/not set.
" Also test that dv_ works correctly
func Test_smarttab()
  enew!
  set smarttab expandtab ts=8 sw=4
  " make sure that backspace works, no matter what termcap is used
  exe "set t_kD=\<C-V>x7f t_kb=\<C-V>x08"
  call append(0, ['start text',
	      \ "\t\tsome test text",
	      \ 'test text',
	      \ "\t\tother test text",
	      \ '    a cde',
	      \ '    f ghi',
	      \ 'test text',
	      \ '  Second line beginning with whitespace'
	      \ ])
  call cursor(1, 1)
  exe "normal /some\<CR>"
  exe "normal r\t"
  call assert_equal("\t\t    ome test text", getline('.'))
  set noexpandtab
  exe "normal /other\<CR>"
  exe "normal r\t"
  call assert_equal("\t\t    ther test text", getline('.'))

  " Test replacing with Tabs and then backspacing to undo it
  exe "normal j0wR\t\t\t\<BS>\<BS>\<BS>"
  call assert_equal("    a cde", getline('.'))
  " Test replacing with Tabs
  exe "normal j0wR\t\t\t"
  call assert_equal("    \t\thi", getline('.'))

  " Test that copyindent works with expandtab set
  set expandtab smartindent copyindent ts=8 sw=8 sts=8
  exe "normal jo{\<CR>x"
  call assert_equal('{', getline(line('.') - 1))
  call assert_equal('        x', getline('.'))
  set nosol
  exe "normal /Second line/\<CR>"
  exe "normal fwdv_"
  call assert_equal('  with whitespace', getline('.'))
  enew!
  set expandtab& smartindent& copyindent& ts& sw& sts&
endfunc
