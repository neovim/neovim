" Tests for various Visual mode.
if !has('visual')
  finish
endif


func Test_block_shift_multibyte()
  " Uses double-wide character.
  if !has('multi_byte')
    return
  endif
  split
  call setline(1, ['xヹxxx', 'ヹxxx'])
  exe "normal 1G0l\<C-V>jl>"
  call assert_equal('x	 ヹxxx', getline(1))
  call assert_equal('	ヹxxx', getline(2))
  q!
endfunc

func Test_Visual_ctrl_o()
  new
  call setline(1, ['one', 'two', 'three'])
  call cursor(1,2)
  set noshowmode
  set tw=0
  call feedkeys("\<c-v>jjlIa\<c-\>\<c-o>:set tw=88\<cr>\<esc>", 'tx')
  call assert_equal(['oane', 'tawo', 'tahree'], getline(1, 3))
  call assert_equal(88, &tw)
  set tw&
  bw!
endfu

func Test_Visual_vapo()
  new
  normal oxx
  normal vapo
  bwipe!
endfunc

func Test_dotregister_paste()
  new
  exe "norm! ihello world\<esc>"
  norm! 0ve".p
  call assert_equal('hello world world', getline(1))
  q!
endfunc

func Test_Visual_inner_quote()
  new
  normal oxX
  normal vki'
  bwipe!
endfunc

" Test for visual block shift and tab characters.
func Test_block_shift_tab()
  enew!
  call append(0, repeat(['one two three'], 5))
  call cursor(1,1)
  exe "normal i\<C-G>u"
  exe "normal fe\<C-V>4jR\<Esc>ugvr1"
  call assert_equal('on1 two three', getline(1))
  call assert_equal('on1 two three', getline(2))
  call assert_equal('on1 two three', getline(5))

  enew!
  call append(0, repeat(['abcdefghijklmnopqrstuvwxyz'], 5))
  call cursor(1,1)
  exe "normal \<C-V>4jI    \<Esc>j<<11|D"
  exe "normal j7|a\<Tab>\<Tab>"
  exe "normal j7|a\<Tab>\<Tab>   "
  exe "normal j7|a\<Tab>       \<Tab>\<Esc>4k13|\<C-V>4j<"
  call assert_equal('    abcdefghijklmnopqrstuvwxyz', getline(1))
  call assert_equal('abcdefghij', getline(2))
  call assert_equal("    abc\<Tab>    defghijklmnopqrstuvwxyz", getline(3))
  call assert_equal("    abc\<Tab>    defghijklmnopqrstuvwxyz", getline(4))
  call assert_equal("    abc\<Tab>    defghijklmnopqrstuvwxyz", getline(5))

  %s/\s\+//g
  call cursor(1,1)
  exe "normal \<C-V>4jI    \<Esc>j<<"
  exe "normal j7|a\<Tab>\<Tab>"
  exe "normal j7|a\<Tab>\<Tab>\<Tab>\<Tab>\<Tab>"
  exe "normal j7|a\<Tab>       \<Tab>\<Tab>\<Esc>4k13|\<C-V>4j3<"
  call assert_equal('    abcdefghijklmnopqrstuvwxyz', getline(1))
  call assert_equal('abcdefghij', getline(2))
  call assert_equal("    abc\<Tab>    defghijklmnopqrstuvwxyz", getline(3))
  call assert_equal("    abc\<Tab>\<Tab>defghijklmnopqrstuvwxyz", getline(4))
  call assert_equal("    abc\<Tab>    defghijklmnopqrstuvwxyz", getline(5))

  enew!
endfunc

" Tests Blockwise Visual when there are TABs before the text.
func Test_blockwise_visual()
  enew!
  call append(0, ['123456',
	      \ '234567',
	      \ '345678',
	      \ '',
	      \ 'test text test tex start here',
	      \ "\t\tsome text",
	      \ "\t\ttest text",
	      \ 'test text'])
  call cursor(1,1)
  exe "normal /start here$\<CR>"
  exe 'normal "by$' . "\<C-V>jjlld"
  exe "normal /456$\<CR>"
  exe "normal \<C-V>jj" . '"bP'
  call assert_equal(['123start here56',
	      \ '234start here67',
	      \ '345start here78',
	      \ '',
	      \ 'test text test tex rt here',
	      \ "\t\tsomext",
	      \ "\t\ttesext"], getline(1, 7))

  enew!
endfunc

" Test Virtual replace mode.
func Test_virtual_replace()
  throw 'skipped: TODO: '
  exe "set t_kD=\<C-V>x7f t_kb=\<C-V>x08"
  enew!
  exe "normal a\nabcdefghi\njk\tlmn\n    opq	rst\n\<C-D>uvwxyz"
  call cursor(1,1)
  set ai bs=2
  exe "normal gR0\<C-D> 1\nA\nBCDEFGHIJ\n\tKL\nMNO\nPQR"
  call assert_equal([' 1',
	      \ ' A',
	      \ ' BCDEFGHIJ',
	      \ ' 	KL',
	      \ '	MNO',
	      \ '	PQR',
	      \ ], getline(1, 6))
  normal G
  mark a
  inoremap <C-D> <Del>
  exe "normal o0\<C-D>\nabcdefghi\njk\tlmn\n    opq\trst\n\<C-D>uvwxyz\n"
  exe "normal 'ajgR0\<C-D> 1\nA\nBCDEFGHIJ\n\tKL\nMNO\nPQR" . repeat("\<BS>", 29)
  call assert_equal([' 1',
	      \ 'abcdefghi',
	      \ 'jk	lmn',
	      \ '    opq	rst',
	      \ 'uvwxyz'], getline(7, 11))
  normal G
  exe "normal iab\tcdefghi\tjkl"
  exe "normal 0gRAB......CDEFGHI.J\<Esc>o"
  exe "normal iabcdefghijklmnopqrst\<Esc>0gRAB\tIJKLMNO\tQR"
  call assert_equal(['AB......CDEFGHI.Jkl',
	      \ 'AB	IJKLMNO	QRst'], getline(12, 13))
  enew!
endfunc
