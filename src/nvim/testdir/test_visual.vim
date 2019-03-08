" Tests for various Visual mode.

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

func Test_block_shift_overflow()
  " This used to cause a multiplication overflow followed by a crash.
  new
  normal ii
  exe "normal \<C-V>876543210>"
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

" Test swapping corners in blockwise visual mode with o and O
func Test_blockwise_visual_o_O()
  enew!

  exe "norm! 10i.\<Esc>Y4P3lj\<C-V>4l2jr "
  exe "norm! gvO\<Esc>ra"
  exe "norm! gvO\<Esc>rb"
  exe "norm! gvo\<C-c>rc"
  exe "norm! gvO\<C-c>rd"

  call assert_equal(['..........',
        \            '...c   d..',
        \            '...     ..',
        \            '...a   b..',
        \            '..........'], getline(1, '$'))

  enew!
endfun

" Test Virtual replace mode.
func Test_virtual_replace()
  throw 'skipped: TODO: '
  if exists('&t_kD')
    let save_t_kD = &t_kD
  endif
  if exists('&t_kb')
    let save_t_kb = &t_kb
  endif
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
  set noai bs&vim
  if exists('save_t_kD')
    let &t_kD = save_t_kD
  endif
  if exists('save_t_kb')
    let &t_kb = save_t_kb
  endif
endfunc

" Test Virtual replace mode.
func Test_virtual_replace2()
  enew!
  set bs=2
  exe "normal a\nabcdefghi\njk\tlmn\n    opq	rst\n\<C-D>uvwxyz"
  call cursor(1,1)
  " Test 1: Test that del deletes the newline
  exe "normal gR0\<del> 1\nA\nBCDEFGHIJ\n\tKL\nMNO\nPQR"
  call assert_equal(['0 1',
	      \ 'A',
	      \ 'BCDEFGHIJ',
	      \ '	KL',
	      \ 'MNO',
	      \ 'PQR',
	      \ ], getline(1, 6))
  " Test 2:
  " a newline is not deleted, if no newline has been added in virtual replace mode
  %d_
  call setline(1, ['abcd', 'efgh', 'ijkl'])
  call cursor(2,1)
  exe "norm! gR1234\<cr>5\<bs>\<bs>\<bs>"
  call assert_equal(['abcd',
        \ '123h',
        \ 'ijkl'], getline(1, '$'))
  " Test 3:
  " a newline is deleted, if a newline has been inserted before in virtual replace mode
  %d_
  call setline(1, ['abcd', 'efgh', 'ijkl'])
  call cursor(2,1)
  exe "norm! gR1234\<cr>\<cr>56\<bs>\<bs>\<bs>"
  call assert_equal(['abcd',
        \ '1234',
        \ 'ijkl'], getline(1, '$'))
  " Test 4:
  " delete add a newline, delete it, add it again and check undo
  %d_
  call setline(1, ['abcd', 'efgh', 'ijkl'])
  call cursor(2,1)
  " break undo sequence explicitly
  let &ul = &ul
  exe "norm! gR1234\<cr>\<bs>\<del>56\<cr>"
  let &ul = &ul
  call assert_equal(['abcd',
        \ '123456',
        \ ''], getline(1, '$'))
  norm! u
  call assert_equal(['abcd',
        \ 'efgh',
        \ 'ijkl'], getline(1, '$'))
  " clean up
  %d_
  set bs&vim
endfunc

" Test for Visual mode not being reset causing E315 error.
func TriggerTheProblem()
  " At this point there is no visual selection because :call reset it.
  " Let's restore the selection:
  normal gv
  '<,'>del _
  try
      exe "normal \<Esc>"
  catch /^Vim\%((\a\+)\)\=:E315/
      echom 'Snap! E315 error!'
      let g:msg = 'Snap! E315 error!'
  endtry
endfunc

func Test_visual_mode_reset()
  set belloff=all
  enew
  let g:msg = "Everything's fine."
  enew
  setl buftype=nofile
  call append(line('$'), 'Delete this line.')

  " NOTE: this has to be done by a call to a function because executing :del
  " the ex-way will require the colon operator which resets the visual mode
  " thus preventing the problem:
  exe "normal! GV:call TriggerTheProblem()\<CR>"
  call assert_equal("Everything's fine.", g:msg)

  set belloff&
endfunc

func Test_Visual_word_textobject()
  new
  call setline(1, ['First sentence. Second sentence.'])

  " When start and end of visual area are identical, 'aw' or 'iw' select
  " the whole word.
  norm! 1go2fcvawy
  call assert_equal('Second ', @")
  norm! 1go2fcviwy
  call assert_equal('Second', @")

  " When start and end of visual area are not identical, 'aw' or 'iw'
  " extend the word in direction of the end of the visual area.
  norm! 1go2fcvlawy
  call assert_equal('cond ', @")
  norm! gv2awy
  call assert_equal('cond sentence.', @")

  norm! 1go2fcvliwy
  call assert_equal('cond', @")
  norm! gv2iwy
  call assert_equal('cond sentence', @")

  " Extend visual area in opposite direction.
  norm! 1go2fcvhawy
  call assert_equal(' Sec', @")
  norm! gv2awy
  call assert_equal(' sentence. Sec', @")

  norm! 1go2fcvhiwy
  call assert_equal('Sec', @")
  norm! gv2iwy
  call assert_equal('. Sec', @")

  bwipe!
endfunc

func Test_Visual_sentence_textobject()
  new
  call setline(1, ['First sentence. Second sentence. Third', 'sentence. Fourth sentence'])

  " When start and end of visual area are identical, 'as' or 'is' select
  " the whole sentence.
  norm! 1gofdvasy
  call assert_equal('Second sentence. ', @")
  norm! 1gofdvisy
  call assert_equal('Second sentence.', @")

  " When start and end of visual area are not identical, 'as' or 'is'
  " extend the sentence in direction of the end of the visual area.
  norm! 1gofdvlasy
  call assert_equal('d sentence. ', @")
  norm! gvasy
  call assert_equal("d sentence. Third\nsentence. ", @")

  norm! 1gofdvlisy
  call assert_equal('d sentence.', @")
  norm! gvisy
  call assert_equal('d sentence. ', @")
  norm! gvisy
  call assert_equal("d sentence. Third\nsentence.", @")

  " Extend visual area in opposite direction.
  norm! 1gofdvhasy
  call assert_equal(' Second', @")
  norm! gvasy
  call assert_equal("First sentence. Second", @")

  norm! 1gofdvhisy
  call assert_equal('Second', @")
  norm! gvisy
  call assert_equal(' Second', @")
  norm! gvisy
  call assert_equal('First sentence. Second', @")

  bwipe!
endfunc

func Test_curswant_not_changed()
  new
  call setline(1, ['one', 'two'])
  au InsertLeave * call getcurpos()
  call feedkeys("gg0\<C-V>jI123 \<Esc>j", 'xt')
  call assert_equal([0, 2, 1, 0, 1], getcurpos())

  bwipe!
  au! InsertLeave
endfunc

func Test_Visual_paragraph_textobject()
  new
  call setline(1, ['First line.',
  \                '',
  \                'Second line.',
  \                'Third line.',
  \                'Fourth line.',
  \                'Fifth line.',
  \                '',
  \                'Sixth line.'])

  " When start and end of visual area are identical, 'ap' or 'ip' select
  " the whole paragraph.
  norm! 4ggvapy
  call assert_equal("Second line.\nThird line.\nFourth line.\nFifth line.\n\n", @")
  norm! 4ggvipy
  call assert_equal("Second line.\nThird line.\nFourth line.\nFifth line.\n", @")

  " When start and end of visual area are not identical, 'ap' or 'ip'
  " extend the sentence in direction of the end of the visual area.
  " FIXME: actually, it is not sufficient to have different start and
  " end of visual selection, the start line and end line have to differ,
  " which is not consistent with the documentation.
  norm! 4ggVjapy
  call assert_equal("Third line.\nFourth line.\nFifth line.\n\n", @")
  norm! gvapy
  call assert_equal("Third line.\nFourth line.\nFifth line.\n\nSixth line.\n", @")
  norm! 4ggVjipy
  call assert_equal("Third line.\nFourth line.\nFifth line.\n", @")
  norm! gvipy
  call assert_equal("Third line.\nFourth line.\nFifth line.\n\n", @")
  norm! gvipy
  call assert_equal("Third line.\nFourth line.\nFifth line.\n\nSixth line.\n", @")

  " Extend visual area in opposite direction.
  norm! 5ggVkapy
  call assert_equal("\nSecond line.\nThird line.\nFourth line.\n", @")
  norm! gvapy
  call assert_equal("First line.\n\nSecond line.\nThird line.\nFourth line.\n", @")
  norm! 5ggVkipy
  call assert_equal("Second line.\nThird line.\nFourth line.\n", @")
  norma gvipy
  call assert_equal("\nSecond line.\nThird line.\nFourth line.\n", @")
  norm! gvipy
  call assert_equal("First line.\n\nSecond line.\nThird line.\nFourth line.\n", @")

  bwipe!
endfunc
