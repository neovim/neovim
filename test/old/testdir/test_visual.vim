" Tests for various Visual modes.

source shared.vim
source check.vim
source screendump.vim
source vim9.vim

func Test_block_shift_multibyte()
  " Uses double-wide character.
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

func Test_dotregister_paste()
  new
  exe "norm! ihello world\<esc>"
  norm! 0ve".p
  call assert_equal('hello world world', getline(1))
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

func Test_Visual_inner_quote()
  new
  normal oxX
  normal vki'
  bwipe!
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
endfunc

" Test for visual block shift and tab characters.
func Test_block_shift_tab()
  new
  call append(0, repeat(['one two three'], 5))
  call cursor(1,1)
  exe "normal i\<C-G>u"
  exe "normal fe\<C-V>4jR\<Esc>ugvr1"
  call assert_equal('on1 two three', getline(1))
  call assert_equal('on1 two three', getline(2))
  call assert_equal('on1 two three', getline(5))

  %d _
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

  " Test for block shift with space characters at the beginning and with
  " 'noexpandtab' and 'expandtab'
  %d _
  call setline(1, ["      1", "      2", "      3"])
  setlocal shiftwidth=2 noexpandtab
  exe "normal gg\<C-V>3j>"
  call assert_equal(["\t1", "\t2", "\t3"], getline(1, '$'))
  %d _
  call setline(1, ["      1", "      2", "      3"])
  setlocal shiftwidth=2 expandtab
  exe "normal gg\<C-V>3j>"
  call assert_equal(["        1", "        2", "        3"], getline(1, '$'))
  setlocal shiftwidth&

  bw!
endfunc

" Tests Blockwise Visual when there are TABs before the text.
func Test_blockwise_visual()
  new
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

  bw!
endfunc

" Test swapping corners in blockwise visual mode with o and O
func Test_blockwise_visual_o_O()
  new

  exe "norm! 10i.\<Esc>Y4P3lj\<C-V>4l2jr "
  exe "norm! gvO\<Esc>ra"
  exe "norm! gvO\<Esc>rb"
  exe "norm! gvo\<C-c>rc"
  exe "norm! gvO\<C-c>rd"
  set selection=exclusive
  exe "norm! gvOo\<C-c>re"
  call assert_equal('...a   be.', getline(4))
  exe "norm! gvOO\<C-c>rf"
  set selection&

  call assert_equal(['..........',
        \            '...c   d..',
        \            '...     ..',
        \            '...a   bf.',
        \            '..........'], getline(1, '$'))

  bw!
endfun

" Test Virtual replace mode.
func Test_virtual_replace()
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

  " Test inserting Tab with 'noexpandtab' and 'softabstop' set to 4
  %d
  call setline(1, 'aaaaaaaaaaaaa')
  set softtabstop=4
  exe "normal gggR\<Tab>\<Tab>x"
  call assert_equal("\txaaaa", getline(1))
  set softtabstop&

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

  " Test for truncating spaces in a newly added line using 'autoindent' if
  " characters are not added to that line.
  %d_
  call setline(1, ['    app', '    bee', '    cat'])
  setlocal autoindent
  exe "normal gg$gRt\n\nr"
  call assert_equal(['    apt', '', '    rat'], getline(1, '$'))

  " clean up
  %d_
  set bs&vim
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

func Test_Visual_paragraph_textobject()
  new
  let lines =<< trim [END]
    First line.

    Second line.
    Third line.
    Fourth line.
    Fifth line.

    Sixth line.
  [END]
  call setline(1, lines)

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

func Test_curswant_not_changed()
  new
  call setline(1, ['one', 'two'])
  au InsertLeave * call getcurpos()
  call feedkeys("gg0\<C-V>jI123 \<Esc>j", 'xt')
  call assert_equal([0, 2, 1, 0, 1], getcurpos())

  bwipe!
  au! InsertLeave
endfunc

" Tests for "vaBiB", end could be wrong.
func Test_Visual_Block()
  new
  a
- Bug in "vPPPP" on this text:
	{
		cmd;
		{
			cmd;\t/* <-- Start cursor here */
			{
			}
		}
	}
.
  normal gg
  call search('Start cursor here')
  normal vaBiBD
  call assert_equal(['- Bug in "vPPPP" on this text:',
	      \ "\t{",
	      \ "\t}"], getline(1, '$'))

  close!
endfunc

" Test for 'p'ut in visual block mode
func Test_visual_block_put()
  new
  call append(0, ['One', 'Two', 'Three'])
  normal gg
  yank
  call feedkeys("jl\<C-V>ljp", 'xt')
  call assert_equal(['One', 'T', 'Tee', 'One', ''], getline(1, '$'))
  bw!
endfunc

func Test_visual_block_put_invalid()
  enew!
  " behave mswin
  set selection=exclusive
  norm yy
  norm v)Ps/^/	
  " this was causing the column to become negative
  silent norm ggv)P

  bwipe!
  " behave xterm
  set selection&
endfunc

" Visual modes (v V CTRL-V) followed by an operator; count; repeating
func Test_visual_mode_op()
  new
  call append(0, '')

  call setline(1, 'apple banana cherry')
  call cursor(1, 1)
  normal lvld.l3vd.
  call assert_equal('a y', getline(1))

  call setline(1, ['line 1 line 1', 'line 2 line 2', 'line 3 line 3',
        \ 'line 4 line 4', 'line 5 line 5', 'line 6 line 6'])
  call cursor(1, 1)
  exe "normal Vcnewline\<Esc>j.j2Vd."
  call assert_equal(['newline', 'newline'], getline(1, '$'))

  call deletebufline('', 1, '$')
  call setline(1, ['xxxxxxxxxxxxx', 'xxxxxxxxxxxxx', 'xxxxxxxxxxxxx',
        \ 'xxxxxxxxxxxxx'])
  exe "normal \<C-V>jlc  \<Esc>l.l2\<C-V>c----\<Esc>l."
  call assert_equal(['    --------x',
        \ '    --------x',
        \ 'xxxx--------x',
        \ 'xxxx--------x'], getline(1, '$'))

  bwipe!
endfunc

" Visual mode maps (movement and text object)
" Visual mode maps; count; repeating
"   - Simple
"   - With an Ex command (custom text object)
func Test_visual_mode_maps()
  new
  call append(0, '')

  func SelectInCaps()
    let [line1, col1] = searchpos('\u', 'bcnW')
    let [line2, col2] = searchpos('.\u', 'nW')
    call setpos("'<", [0, line1, col1, 0])
    call setpos("'>", [0, line2, col2, 0])
    normal! gv
  endfunction

  vnoremap W /\u/s-1<CR>
  vnoremap iW :<C-U>call SelectInCaps()<CR>

  call setline(1, 'KiwiRaspberryDateWatermelonPeach')
  call cursor(1, 1)
  exe "normal vWcNo\<Esc>l.fD2vd."
  call assert_equal('NoNoberryach', getline(1))

  call setline(1, 'JambuRambutanBananaTangerineMango')
  call cursor(1, 1)
  exe "normal llviWc-\<Esc>l.l2vdl."
  call assert_equal('--ago', getline(1))

  vunmap W
  vunmap iW
  bwipe!
  delfunc SelectInCaps
endfunc

" Operator-pending mode maps (movement and text object)
"   - Simple
"   - With Ex command moving the cursor
"   - With Ex command and Visual selection (custom text object)
func Test_visual_oper_pending_mode_maps()
  new
  call append(0, '')

  func MoveToCap()
    call search('\u', 'W')
  endfunction

  func SelectInCaps()
    let [line1, col1] = searchpos('\u', 'bcnW')
    let [line2, col2] = searchpos('.\u', 'nW')
    call setpos("'<", [0, line1, col1, 0])
    call setpos("'>", [0, line2, col2, 0])
    normal! gv
  endfunction

  onoremap W /\u/<CR>
  onoremap <Leader>W :<C-U>call MoveToCap()<CR>
  onoremap iW :<C-U>call SelectInCaps()<CR>

  call setline(1, 'PineappleQuinceLoganberryOrangeGrapefruitKiwiZ')
  call cursor(1, 1)
  exe "normal cW-\<Esc>l.l2.l."
  call assert_equal('----Z', getline(1))

  call setline(1, 'JuniperDurianZ')
  call cursor(1, 1)
  exe "normal g?\WfD."
  call assert_equal('WhavcreQhevnaZ', getline(1))

  call setline(1, 'LemonNectarineZ')
  call cursor(1, 1)
  exe "normal yiWPlciWNew\<Esc>fr."
  call assert_equal('LemonNewNewZ', getline(1))

  ounmap W
  ounmap <Leader>W
  ounmap iW
  bwipe!
  delfunc MoveToCap
  delfunc SelectInCaps
endfunc

" Patch 7.3.879: Properly abort Operator-pending mode for "dv:<Esc>" etc.
func Test_op_pend_mode_abort()
  new
  call append(0, '')

  call setline(1, ['zzzz', 'zzzz'])
  call cursor(1, 1)

  exe "normal dV:\<CR>dv:\<CR>"
  call assert_equal(['zzz'], getline(1, 2))
  set nomodifiable
  call assert_fails('exe "normal d:\<CR>"', 'E21:')
  set modifiable
  call feedkeys("dv:\<Esc>dV:\<Esc>", 'xt')
  call assert_equal(['zzz'], getline(1, 2))
  set nomodifiable
  let v:errmsg = ''
  call feedkeys("d:\<Esc>", 'xt')
  call assert_true(v:errmsg !~# '^E21:')
  set modifiable

  bwipe!
endfunc

func Test_characterwise_visual_mode()
  new

  " characterwise visual mode: replace last line
  $put ='a'
  let @" = 'x'
  normal v$p
  call assert_equal('x', getline('$'))

  " characterwise visual mode: delete middle line
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  normal G
  normal kkv$d
  call assert_equal(['', 'b', 'c'], getline(1, '$'))

  " characterwise visual mode: delete middle two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  normal Gkkvj$d
  call assert_equal(['', 'c'], getline(1, '$'))

  " characterwise visual mode: delete last line
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  normal Gv$d
  call assert_equal(['', 'a', 'b', ''], getline(1, '$'))

  " characterwise visual mode: delete last two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  normal Gkvj$d
  call assert_equal(['', 'a', ''], getline(1, '$'))

  " characterwise visual mode: use a count with the visual mode from the last
  " line in the buffer
  %d _
  call setline(1, ['one', 'two', 'three', 'four'])
  norm! vj$y
  norm! G1vy
  call assert_equal('four', @")

  " characterwise visual mode: replace a single character line and the eol
  %d _
  call setline(1, "a")
  normal v$rx
  call assert_equal(['x'], getline(1, '$'))

  " replace a character with composing characters
  call setline(1, "xã̳x")
  normal gg0lvrb
  call assert_equal("xbx", getline(1))

  bwipe!
endfunc

func Test_visual_mode_put()
  new

  " v_p: replace last character with line register at middle line
  call append('$', ['aaa', 'bbb', 'ccc'])
  normal G
  -2yank
  normal k$vp
  call assert_equal(['', 'aaa', 'bb', 'aaa', '', 'ccc'], getline(1, '$'))

  " v_p: replace last character with line register at middle line selecting
  " newline
  call deletebufline('', 1, '$')
  call append('$', ['aaa', 'bbb', 'ccc'])
  normal G
  -2yank
  normal k$v$p
  call assert_equal(['', 'aaa', 'bb', 'aaa', 'ccc'], getline(1, '$'))

  " v_p: replace last character with line register at last line
  call deletebufline('', 1, '$')
  call append('$', ['aaa', 'bbb', 'ccc'])
  normal G
  -2yank
  normal $vp
  call assert_equal(['', 'aaa', 'bbb', 'cc', 'aaa', ''], getline(1, '$'))

  " v_p: replace last character with line register at last line selecting
  " newline
  call deletebufline('', 1, '$')
  call append('$', ['aaa', 'bbb', 'ccc'])
  normal G
  -2yank
  normal $v$p
  call assert_equal(['', 'aaa', 'bbb', 'cc', 'aaa', ''], getline(1, '$'))

  bwipe!
endfunc

func Test_gv_with_exclusive_selection()
  new

  " gv with exclusive selection after an operation
  call append('$', ['zzz ', 'Ã¤Ã '])
  set selection=exclusive
  normal Gkv3lyjv3lpgvcxxx
  call assert_equal(['', 'zzz ', 'xxx '], getline(1, '$'))

  " gv with exclusive selection without an operation
  call deletebufline('', 1, '$')
  call append('$', 'zzz ')
  set selection=exclusive
  exe "normal G0v3l\<Esc>gvcxxx"
  call assert_equal(['', 'xxx '], getline(1, '$'))

  set selection&vim
  bwipe!
endfunc

" Tests for the visual block mode commands
func Test_visual_block_mode()
  new
  call append(0, '')
  call setline(1, repeat(['abcdefghijklm'], 5))
  call cursor(1, 1)

  " Test shift-right of a block
  exe "normal jllll\<C-V>jj>wll\<C-V>jlll>"
  " Test shift-left of a block
  exe "normal G$hhhh\<C-V>kk<"
  " Test block-insert
  exe "normal Gkl\<C-V>kkkIxyz"
  " Test block-replace
  exe "normal Gllll\<C-V>kkklllrq"
  " Test block-change
  exe "normal G$khhh\<C-V>hhkkcmno"
  call assert_equal(['axyzbcdefghijklm',
        \ 'axyzqqqq   mno	      ghijklm',
        \ 'axyzqqqqef mno        ghijklm',
        \ 'axyzqqqqefgmnoklm',
        \ 'abcdqqqqijklm'], getline(1, 5))

  " Test 'C' to change till the end of the line
  call cursor(3, 4)
  exe "normal! \<C-V>j3lCooo"
  call assert_equal(['axyooo', 'axyooo'], getline(3, 4))

  " Test 'D' to delete till the end of the line
  call cursor(3, 3)
  exe "normal! \<C-V>j2lD"
  call assert_equal(['ax', 'ax'], getline(3, 4))

  " Test block insert with a short line that ends before the block
  %d _
  call setline(1, ["  one", "a", "  two"])
  exe "normal gg\<C-V>2jIx"
  call assert_equal(["  xone", "a", "  xtwo"], getline(1, '$'))

  " Test block append at EOL with '$' and without '$'
  %d _
  call setline(1, ["one", "a", "two"])
  exe "normal gg$\<C-V>2jAx"
  call assert_equal(["onex", "ax", "twox"], getline(1, '$'))
  %d _
  call setline(1, ["one", "a", "two"])
  exe "normal gg3l\<C-V>2jAx"
  call assert_equal(["onex", "a  x", "twox"], getline(1, '$'))

  " Test block replace with an empty line in the middle and use $ to jump to
  " the end of the line.
  %d _
  call setline(1, ['one', '', 'two'])
  exe "normal gg$\<C-V>2jrx"
  call assert_equal(["onx", "", "twx"], getline(1, '$'))

  " Test block replace with an empty line in the middle and move cursor to the
  " end of the line
  %d _
  call setline(1, ['one', '', 'two'])
  exe "normal gg2l\<C-V>2jrx"
  call assert_equal(["onx", "", "twx"], getline(1, '$'))

  " Replace odd number of characters with a multibyte character
  %d _
  call setline(1, ['abcd', 'efgh'])
  exe "normal ggl\<C-V>2ljr\u1100"
  call assert_equal(["a\u1100 ", "e\u1100 "], getline(1, '$'))

  " During visual block append, if the cursor moved outside of the selected
  " range, then the edit should not be applied to the block.
  %d _
  call setline(1, ['aaa', 'bbb', 'ccc'])
  exe "normal 2G\<C-V>jAx\<Up>"
  call assert_equal(['aaa', 'bxbb', 'ccc'], getline(1, '$'))

  " During visual block append, if the cursor is moved before the start of the
  " block, then the new text should be appended there.
  %d _
  call setline(1, ['aaa', 'bbb', 'ccc'])
  exe "normal $\<C-V>2jA\<Left>x"
  call assert_equal(['aaxa', 'bbxb', 'ccxc'], getline(1, '$'))
  " Repeat the previous test but use 'l' to move the cursor instead of '$'
  call setline(1, ['aaa', 'bbb', 'ccc'])
  exe "normal! gg2l\<C-V>2jA\<Left>x"
  call assert_equal(['aaxa', 'bbxb', 'ccxc'], getline(1, '$'))

  " Change a characterwise motion to a blockwise motion using CTRL-V
  %d _
  call setline(1, ['123', '456', '789'])
  exe "normal ld\<C-V>j"
  call assert_equal(['13', '46', '789'], getline(1, '$'))

  " Test from ':help v_b_I_example'
  %d _
  setlocal tabstop=8 shiftwidth=4
  let lines =<< trim END
    abcdefghijklmnopqrstuvwxyz
    abc		defghijklmnopqrstuvwxyz
    abcdef  ghi		jklmnopqrstuvwxyz
    abcdefghijklmnopqrstuvwxyz
  END
  call setline(1, lines)
  exe "normal ggfo\<C-V>3jISTRING"
  let expected =<< trim END
    abcdefghijklmnSTRINGopqrstuvwxyz
    abc	      STRING  defghijklmnopqrstuvwxyz
    abcdef  ghi   STRING  	jklmnopqrstuvwxyz
    abcdefghijklmnSTRINGopqrstuvwxyz
  END
  call assert_equal(expected, getline(1, '$'))

  " Test from ':help v_b_A_example'
  %d _
  let lines =<< trim END
    abcdefghijklmnopqrstuvwxyz
    abc		defghijklmnopqrstuvwxyz
    abcdef  ghi		jklmnopqrstuvwxyz
    abcdefghijklmnopqrstuvwxyz
  END
  call setline(1, lines)
  exe "normal ggfo\<C-V>3j$ASTRING"
  let expected =<< trim END
    abcdefghijklmnopqrstuvwxyzSTRING
    abc		defghijklmnopqrstuvwxyzSTRING
    abcdef  ghi		jklmnopqrstuvwxyzSTRING
    abcdefghijklmnopqrstuvwxyzSTRING
  END
  call assert_equal(expected, getline(1, '$'))

  " Test from ':help v_b_<_example'
  %d _
  let lines =<< trim END
    abcdefghijklmnopqrstuvwxyz
    abc		defghijklmnopqrstuvwxyz
    abcdef  ghi		jklmnopqrstuvwxyz
    abcdefghijklmnopqrstuvwxyz
  END
  call setline(1, lines)
  exe "normal ggfo\<C-V>3j3l<.."
  let expected =<< trim END
    abcdefghijklmnopqrstuvwxyz
    abc	      defghijklmnopqrstuvwxyz
    abcdef  ghi   jklmnopqrstuvwxyz
    abcdefghijklmnopqrstuvwxyz
  END
  call assert_equal(expected, getline(1, '$'))

  " Test from ':help v_b_>_example'
  %d _
  let lines =<< trim END
    abcdefghijklmnopqrstuvwxyz
    abc		defghijklmnopqrstuvwxyz
    abcdef  ghi		jklmnopqrstuvwxyz
    abcdefghijklmnopqrstuvwxyz
  END
  call setline(1, lines)
  exe "normal ggfo\<C-V>3j>.."
  let expected =<< trim END
    abcdefghijklmn		  opqrstuvwxyz
    abc			    defghijklmnopqrstuvwxyz
    abcdef  ghi			    jklmnopqrstuvwxyz
    abcdefghijklmn		  opqrstuvwxyz
  END
  call assert_equal(expected, getline(1, '$'))

  " Test from ':help v_b_r_example'
  %d _
  let lines =<< trim END
    abcdefghijklmnopqrstuvwxyz
    abc		defghijklmnopqrstuvwxyz
    abcdef  ghi		jklmnopqrstuvwxyz
    abcdefghijklmnopqrstuvwxyz
  END
  call setline(1, lines)
  exe "normal ggfo\<C-V>5l3jrX"
  let expected =<< trim END
    abcdefghijklmnXXXXXXuvwxyz
    abc	      XXXXXXhijklmnopqrstuvwxyz
    abcdef  ghi   XXXXXX    jklmnopqrstuvwxyz
    abcdefghijklmnXXXXXXuvwxyz
  END
  call assert_equal(expected, getline(1, '$'))

  bwipe!
  set tabstop& shiftwidth&
endfunc

func Test_visual_force_motion_feedkeys()
    onoremap <expr> i- execute('let g:mode = mode(1)')->slice(0, 0)
    call feedkeys('dvi-', 'x')
    call assert_equal('nov', g:mode)
    call feedkeys('di-', 'x')
    call assert_equal('no', g:mode)
    ounmap i-
endfunc

" Test block-insert using cursor keys for movement
func Test_visual_block_insert_cursor_keys()
  new
  call append(0, ['aaaaaa', 'bbbbbb', 'cccccc', 'dddddd'])
  call cursor(1, 1)

  exe "norm! l\<C-V>jjjlllI\<Right>\<Right>  \<Esc>"
  call assert_equal(['aaa  aaa', 'bbb  bbb', 'ccc  ccc', 'ddd  ddd'],
        \ getline(1, 4))

  call deletebufline('', 1, '$')
  call setline(1, ['xaaa', 'bbbb', 'cccc', 'dddd'])
  call cursor(1, 1)
  exe "norm! \<C-V>jjjI<>\<Left>p\<Esc>"
  call assert_equal(['<p>xaaa', '<p>bbbb', '<p>cccc', '<p>dddd'],
        \ getline(1, 4))
  bwipe!
endfunc

func Test_visual_block_create()
  new
  call append(0, '')
  " Test for Visual block was created with the last <C-v>$
  call setline(1, ['A23', '4567'])
  call cursor(1, 1)
  exe "norm! l\<C-V>j$Aab\<Esc>"
  call assert_equal(['A23ab', '4567ab'], getline(1, 2))

  " Test for Visual block was created with the middle <C-v>$ (1)
  call deletebufline('', 1, '$')
  call setline(1, ['B23', '4567'])
  call cursor(1, 1)
  exe "norm! l\<C-V>j$hAab\<Esc>"
  call assert_equal(['B23 ab', '4567ab'], getline(1, 2))

  " Test for Visual block was created with the middle <C-v>$ (2)
  call deletebufline('', 1, '$')
  call setline(1, ['C23', '4567'])
  call cursor(1, 1)
  exe "norm! l\<C-V>j$hhAab\<Esc>"
  call assert_equal(['C23ab', '456ab7'], getline(1, 2))
  bwipe!
endfunc

" Test for Visual block insert when virtualedit=all
func Test_virtualedit_visual_block()
  set ve=all
  new
  call append(0, ["\t\tline1", "\t\tline2", "\t\tline3"])
  call cursor(1, 1)
  exe "norm! 07l\<C-V>jjIx\<Esc>"
  call assert_equal(["       x \tline1",
        \ "       x \tline2",
        \ "       x \tline3"], getline(1, 3))

  " Test for Visual block append when virtualedit=all
  exe "norm! 012l\<C-v>jjAx\<Esc>"
  call assert_equal(['       x     x   line1',
        \ '       x     x   line2',
        \ '       x     x   line3'], getline(1, 3))
  set ve=
  bwipe!
endfunc

" Test for changing case
func Test_visual_change_case()
  new
  " gUe must uppercase a whole word, also when ß changes to ẞ
  exe "normal Gothe youtußeuu end\<Esc>Ypk0wgUe\r"
  " gUfx must uppercase until x, inclusive.
  exe "normal O- youßtußexu -\<Esc>0fogUfx\r"
  " VU must uppercase a whole line
  exe "normal YpkVU\r"
  " same, when it's the last line in the buffer
  exe "normal YPGi111\<Esc>VUddP\r"
  " Uppercase two lines
  exe "normal Oblah di\rdoh dut\<Esc>VkUj\r"
  " Uppercase part of two lines
  exe "normal ddppi333\<Esc>k0i222\<Esc>fyllvjfuUk"
  call assert_equal(['the YOUTUẞEUU end', '- yOUẞTUẞEXu -',
        \ 'THE YOUTUẞEUU END', '111THE YOUTUẞEUU END', 'BLAH DI', 'DOH DUT',
        \ '222the yoUTUẞEUU END', '333THE YOUTUßeuu end'], getline(2, '$'))
  bwipe!
endfunc

" Test for Visual replace using Enter or NL
func Test_visual_replace_crnl()
  new
  exe "normal G3o123456789\e2k05l\<C-V>2jr\r"
  exe "normal G3o98765\e2k02l\<C-V>2jr\<C-V>\r\n"
  exe "normal G3o123456789\e2k05l\<C-V>2jr\n"
  exe "normal G3o98765\e2k02l\<C-V>2jr\<C-V>\n"
  call assert_equal(['12345', '789', '12345', '789', '12345', '789', "98\r65",
        \ "98\r65", "98\r65", '12345', '789', '12345', '789', '12345', '789',
        \ "98\n65", "98\n65", "98\n65"], getline(2, '$'))
  bwipe!
endfunc

func Test_ve_block_curpos()
  new
  " Test cursor position. When ve=block and Visual block mode and $gj
  call append(0, ['12345', '789'])
  call cursor(1, 3)
  set virtualedit=block
  exe "norm! \<C-V>$gj\<Esc>"
  call assert_equal([0, 2, 4, 0], getpos("'>"))
  set virtualedit=
  bwipe!
endfunc

" Test for block_insert when replacing spaces in front of the a with tabs
func Test_block_insert_replace_tabs()
  new
  set ts=8 sts=4 sw=4
  call append(0, ["#define BO_ALL\t    0x0001",
        \ "#define BO_BS\t    0x0002",
        \ "#define BO_CRSR\t    0x0004"])
  call cursor(1, 1)
  exe "norm! f0\<C-V>2jI\<tab>\<esc>"
  call assert_equal([
        \ "#define BO_ALL\t\t0x0001",
        \ "#define BO_BS\t    \t0x0002",
        \ "#define BO_CRSR\t    \t0x0004", ''], getline(1, '$'))
  set ts& sts& sw&
  bwipe!
endfunc

" Test for * register in :
func Test_star_register()
  call assert_fails('*bfirst', 'E16:')
  new
  call setline(1, ['foo', 'bar', 'baz', 'qux'])
  exe "normal jVj\<ESC>"
  *yank r
  call assert_equal("bar\nbaz\n", @r)

  delmarks < >
  call assert_fails('*yank', 'E20:')
  close!
endfunc

" Test for changing text in visual mode with 'exclusive' selection
func Test_exclusive_selection()
  new
  call setline(1, ['one', 'two'])
  set selection=exclusive
  call feedkeys("vwcabc", 'xt')
  call assert_equal('abctwo', getline(1))
  call setline(1, ["\tone"])
  set virtualedit=all
  call feedkeys('0v2lcl', 'xt')
  call assert_equal('l      one', getline(1))
  set virtualedit&
  set selection&
  close!
endfunc

" Test for starting linewise visual with a count.
" This test needs to be run without any previous visual mode. Otherwise the
" count will use the count from the previous visual mode.
func Test_linewise_visual_with_count()
  let after =<< trim [CODE]
    call setline(1, ['one', 'two', 'three', 'four'])
    norm! 3Vy
    call assert_equal("one\ntwo\nthree\n", @")
    call writefile(v:errors, 'Xtestout')
    qall!
  [CODE]
  if RunVim([], after, '')
    call assert_equal([], readfile('Xtestout'))
    call delete('Xtestout')
  endif
endfunc

" Test for starting characterwise visual with a count.
" This test needs to be run without any previous visual mode. Otherwise the
" count will use the count from the previous visual mode.
func Test_characterwise_visual_with_count()
  let after =<< trim [CODE]
    call setline(1, ['one two', 'three'])
    norm! l5vy
    call assert_equal("ne tw", @")
    call writefile(v:errors, 'Xtestout')
    qall!
  [CODE]
  if RunVim([], after, '')
    call assert_equal([], readfile('Xtestout'))
    call delete('Xtestout')
  endif
endfunc

" Test for visually selecting an inner block (iB)
func Test_visual_inner_block()
  new
  call setline(1, ['one', '{', 'two', '{', 'three', '}', 'four', '}', 'five'])
  call cursor(5, 1)
  " visually select all the lines in the block and then execute iB
  call feedkeys("ViB\<C-C>", 'xt')
  call assert_equal([0, 5, 1, 0], getpos("'<"))
  call assert_equal([0, 5, 6, 0], getpos("'>"))
  " visually select two inner blocks
  call feedkeys("ViBiB\<C-C>", 'xt')
  call assert_equal([0, 3, 1, 0], getpos("'<"))
  call assert_equal([0, 7, 5, 0], getpos("'>"))
  " try to select non-existing inner block
  call cursor(5, 1)
  call assert_beeps('normal ViBiBiB')
  " try to select a unclosed inner block
  8,9d
  call cursor(5, 1)
  call assert_beeps('normal ViBiB')
  close!
endfunc

func Test_visual_put_in_block()
  new
  call setline(1, ['xxxx', 'y∞yy', 'zzzz'])
  normal 1G2yl
  exe "normal 1G2l\<C-V>jjlp"
  call assert_equal(['xxxx', 'y∞xx', 'zzxx'], getline(1, 3))
  bwipe!
endfunc

func Test_visual_put_in_block_using_zp()
  new
  " paste using zP
  call setline(1, ['/path;text', '/path;text', '/path;text', '', 
    \ '/subdir', 
    \ '/longsubdir',
    \ '/longlongsubdir'])
  exe "normal! 5G\<c-v>2j$y"
  norm! 1Gf;zP
  call assert_equal(['/path/subdir;text', '/path/longsubdir;text', '/path/longlongsubdir;text'], getline(1, 3))
  %d
  " paste using zP
  call setline(1, ['/path;text', '/path;text', '/path;text', '', 
    \ '/subdir', 
    \ '/longsubdir',
    \ '/longlongsubdir'])
  exe "normal! 5G\<c-v>2j$y"
  norm! 1Gf;hzp
  call assert_equal(['/path/subdir;text', '/path/longsubdir;text', '/path/longlongsubdir;text'], getline(1, 3))
  bwipe!
endfunc

func Test_visual_put_in_block_using_zy_and_zp()
  new

  " Test 1) Paste using zp - after the cursor without trailing spaces
  call setline(1, ['/path;text', '/path;text', '/path;text', '', 
    \ 'texttext  /subdir           columntext',
		\ 'texttext  /longsubdir       columntext',
    \ 'texttext  /longlongsubdir   columntext'])
  exe "normal! 5G0f/\<c-v>2jezy"
  norm! 1G0f;hzp
  call assert_equal(['/path/subdir;text', '/path/longsubdir;text', '/path/longlongsubdir;text'], getline(1, 3))

  " Test 2) Paste using zP - in front of the cursor without trailing spaces
  %d
  call setline(1, ['/path;text', '/path;text', '/path;text', '', 
    \ 'texttext  /subdir           columntext',
		\ 'texttext  /longsubdir       columntext',
    \ 'texttext  /longlongsubdir   columntext'])
  exe "normal! 5G0f/\<c-v>2jezy"
  norm! 1G0f;zP
  call assert_equal(['/path/subdir;text', '/path/longsubdir;text', '/path/longlongsubdir;text'], getline(1, 3))

  " Test 3) Paste using p - with trailing spaces
  %d
  call setline(1, ['/path;text', '/path;text', '/path;text', '', 
    \ 'texttext  /subdir           columntext',
		\ 'texttext  /longsubdir       columntext',
    \ 'texttext  /longlongsubdir   columntext'])
  exe "normal! 5G0f/\<c-v>2jezy"
  norm! 1G0f;hp
  call assert_equal(['/path/subdir        ;text', '/path/longsubdir    ;text', '/path/longlongsubdir;text'], getline(1, 3))

  " Test 4) Paste using P - with trailing spaces
  %d
  call setline(1, ['/path;text', '/path;text', '/path;text', '', 
    \ 'texttext  /subdir           columntext',
		\ 'texttext  /longsubdir       columntext',
    \ 'texttext  /longlongsubdir   columntext'])
  exe "normal! 5G0f/\<c-v>2jezy"
  norm! 1G0f;P
  call assert_equal(['/path/subdir        ;text', '/path/longsubdir    ;text', '/path/longlongsubdir;text'], getline(1, 3))

  " Test 5) Yank with spaces inside the block
  %d
  call setline(1, ['/path;text', '/path;text', '/path;text', '', 
    \ 'texttext  /sub    dir/           columntext',
    \ 'texttext  /lon    gsubdir/       columntext',
    \ 'texttext  /lon    glongsubdir/   columntext'])
  exe "normal! 5G0f/\<c-v>2jf/zy"
  norm! 1G0f;zP
  call assert_equal(['/path/sub    dir/;text', '/path/lon    gsubdir/;text', '/path/lon    glongsubdir/;text'], getline(1, 3))
  bwipe!
endfunc

func Test_visual_put_blockedit_zy_and_zp()
  new

  call setline(1, ['aa', 'bbbbb', 'ccc', '', 'XX', 'GGHHJ', 'RTZU'])
  exe "normal! gg0\<c-v>2j$zy"
  norm! 5gg0zP
  call assert_equal(['aa', 'bbbbb', 'ccc', '', 'aaXX', 'bbbbbGGHHJ', 'cccRTZU'], getline(1, 7))
  "
  " now with blockmode editing
  sil %d
  :set ve=block
  call setline(1, ['aa', 'bbbbb', 'ccc', '', 'XX', 'GGHHJ', 'RTZU'])
  exe "normal! gg0\<c-v>2j$zy"
  norm! 5gg0zP
  call assert_equal(['aa', 'bbbbb', 'ccc', '', 'aaXX', 'bbbbbGGHHJ', 'cccRTZU'], getline(1, 7))
  set ve&vim
  bw!
endfunc

func Test_visual_block_yank_zy()
  new
  " this was reading before the start of the line
  exe "norm o\<C-T>\<Esc>\<C-V>zy"
  bwipe!
endfunc

func Test_visual_block_with_virtualedit()
  CheckScreendump

  let lines =<< trim END
    call setline(1, ['aaaaaa', 'bbbb', 'cc'])
    set virtualedit=block
    normal G
  END
  call writefile(lines, 'XTest_block')

  let buf = RunVimInTerminal('-S XTest_block', {'rows': 8, 'cols': 50})
  call term_sendkeys(buf, "\<C-V>gg$")
  call VerifyScreenDump(buf, 'Test_visual_block_with_virtualedit', {})

  call term_sendkeys(buf, "\<Esc>gg\<C-V>G$")
  call VerifyScreenDump(buf, 'Test_visual_block_with_virtualedit2', {})

  " clean up
  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
  call delete('XTest_block')
endfunc

func Test_visual_block_ctrl_w_f()
  " Empty block selected in new buffer should not result in an error.
  au! BufNew foo sil norm f
  edit foo

  au! BufNew
endfunc

func Test_visual_block_append_invalid_char()
  " this was going over the end of the line
  set isprint=@,161-255
  new
  call setline(1, ['	   let xxx', 'xxxxx', 'xxxxxxxxxxx'])
  exe "normal 0\<C-V>jjA-\<Esc>"
  call assert_equal(['	-   let xxx', 'xxxxx   -', 'xxxxxxxx-xxx'], getline(1, 3))
  bwipe!
  set isprint&
endfunc

func Test_visual_block_with_substitute()
  " this was reading beyond the end of the line
  new
  norm a0)
  sil! norm  O
  s/)
  sil! norm 
  bwipe!
endfunc

func Test_visual_reselect_with_count()
  enew
  call setline(1, ['aaaaaa', '✗ bbbb', '✗ bbbb'])
  exe "normal! 2Gw\<C-V>jed"
  exe "normal! gg0lP"
  call assert_equal(['abbbbaaaaa', '✗bbbb ', '✗ '], getline(1, '$'))

  exe "normal! 1vr."
  call assert_equal(['a....aaaaa', '✗.... ', '✗ '], getline(1, '$'))

  bwipe!

  " this was causing an illegal memory access
  let lines =<< trim END



      :
      r<sfile>
      exe "%norm e3\<c-v>kr\t"
      :

      :
  END
  call writefile(lines, 'XvisualReselect')
  source XvisualReselect

  bwipe!
  call delete('XvisualReselect')
endfunc

func Test_visual_reselect_exclusive()
  new
  call setline(1, ['abcde', 'abcde'])
  set selection=exclusive
  normal 1G0viwd
  normal 2G01vd
  call assert_equal(['', ''], getline(1, 2))

  set selection&
  bwipe!
endfunc

func Test_visual_block_insert_round_off()
  new
  " The number of characters are tuned to fill a 4096 byte allocated block,
  " so that valgrind reports going over the end.
  call setline(1, ['xxxxx', repeat('0', 1350), "\t", repeat('x', 60)])
  exe "normal gg0\<C-V>GI" .. repeat('0', 1320) .. "\<Esc>"
  bwipe!
endfunc

" this was causing an ml_get error
func Test_visual_exchange_windows()
  enew!
  new
  call setline(1, ['foo', 'bar'])
  exe "normal G\<C-V>gg\<C-W>\<C-X>OO\<Esc>"
  bwipe!
  bwipe!
endfunc

" this was leaving the end of the Visual area beyond the end of a line
func Test_visual_ex_copy_line()
  new
  call setline(1, ["aaa", "bbbbbbbbbxbb"])
  /x
  exe "normal ggvjfxO"
  t0
  normal gNU
  bwipe!
endfunc

" This was leaving the end of the Visual area beyond the end of a line.
" Set 'undolevels' to start a new undo block.
func Test_visual_undo_deletes_last_line()
  new
  call setline(1, ["aaa", "ccc", "dyd"])
  set undolevels=100
  exe "normal obbbbbbbbbxbb\<Esc>"
  set undolevels=100
  /y
  exe "normal ggvjfxO"
  undo
  normal gNU

  bwipe!
endfunc

func Test_visual_paste()
  new

  " v_p overwrites unnamed register.
  call setline(1, ['xxxx'])
  call setreg('"', 'foo')
  call setreg('-', 'bar')
  normal gg0vp
  call assert_equal('x', @")
  call assert_equal('x', @-)
  call assert_equal('fooxxx', getline(1))
  normal $vp
  call assert_equal('x', @")
  call assert_equal('x', @-)
  call assert_equal('fooxxx', getline(1))
  " Test with a different register as unnamed register.
  call setline(2, ['baz'])
  normal 2gg0"rD
  call assert_equal('baz', @")
  normal gg0vp
  call assert_equal('f', @")
  call assert_equal('f', @-)
  call assert_equal('bazooxxx', getline(1))
  normal $vp
  call assert_equal('x', @")
  call assert_equal('x', @-)
  call assert_equal('bazooxxf', getline(1))

  bwipe!
endfunc

func Test_visual_paste_clipboard()
  CheckFeature clipboard_working

  if has('gui')
    " auto select feature breaks tests
    set guioptions-=a
  endif

  " v_P does not overwrite unnamed register.
  call setline(1, ['xxxx'])
  call setreg('"', 'foo')
  call setreg('-', 'bar')
  normal gg0vP
  call assert_equal('foo', @")
  call assert_equal('bar', @-)
  call assert_equal('fooxxx', getline(1))
  normal $vP
  call assert_equal('foo', @")
  call assert_equal('bar', @-)
  call assert_equal('fooxxfoo', getline(1))
  " Test with a different register as unnamed register.
  call setline(2, ['baz'])
  normal 2gg0"rD
  call assert_equal('baz', @")
  normal gg0vP
  call assert_equal('baz', @")
  call assert_equal('bar', @-)
  call assert_equal('bazooxxfoo', getline(1))
  normal $vP
  call assert_equal('baz', @")
  call assert_equal('bar', @-)
  call assert_equal('bazooxxfobaz', getline(1))

  " Test for unnamed clipboard
  set clipboard=unnamed
  call setline(1, ['xxxx'])
  call setreg('"', 'foo')
  call setreg('-', 'bar')
  call setreg('*', 'baz')
  normal gg0vP
  call assert_equal('foo', @")
  call assert_equal('bar', @-)
  call assert_equal('baz', @*)
  call assert_equal('bazxxx', getline(1))

  " Test for unnamedplus clipboard
  if has('unnamedplus')
    set clipboard=unnamedplus
    call setline(1, ['xxxx'])
    call setreg('"', 'foo')
    call setreg('-', 'bar')
    call setreg('+', 'baz')
    normal gg0vP
    call assert_equal('foo', @")
    call assert_equal('bar', @-)
    call assert_equal('baz', @+)
    call assert_equal('bazxxx', getline(1))
  endif

  set clipboard&
  if has('gui')
    set guioptions&
  endif
  bwipe!
endfunc

func Test_visual_area_adjusted_when_hiding()
  " The Visual area ended after the end of the line after :hide
  call setline(1, 'xxx')
  vsplit Xfile
  call setline(1, 'xxxxxxxx')
  norm! $o
  hid
  norm! zW
  bwipe!
  bwipe!
endfunc

func Test_switch_buffer_ends_visual_mode()
  enew
  call setline(1, 'foo')
  set hidden
  set virtualedit=all
  let buf1 = bufnr()
  enew
  let buf2 = bufnr()
  call setline(1, ['', '', '', ''])
  call cursor(4, 5)
  call feedkeys("\<C-V>3k4h", 'xt')
  exe 'buffer' buf1
  call assert_equal('n', mode())

  set nohidden
  set virtualedit=
  bwipe!
  exe 'bwipe!' buf2
endfunc

" Check fix for the heap-based buffer overflow bug found in the function
" utfc_ptr2len and reported at
" https://huntr.dev/bounties/ae933869-a1ec-402a-bbea-d51764c6618e
func Test_heap_buffer_overflow()
  enew
  set updatecount=0

  norm R0
  split other
  norm R000
  exe "norm \<C-V>l"
  ball
  call assert_equal(getpos("."), getpos("v"))
  call assert_equal('n', mode())
  norm zW

  %bwipe!
  set updatecount&
endfunc

" Test Visual highlight with cursor at end of screen line and 'showbreak'
func Test_visual_hl_with_showbreak()
  CheckScreendump

  let lines =<< trim END
    setlocal showbreak=+
    call setline(1, repeat('a', &columns + 10))
    normal g$v4lo
  END
  call writefile(lines, 'XTest_visual_sbr', 'D')

  let buf = RunVimInTerminal('-S XTest_visual_sbr', {'rows': 6, 'cols': 50})
  call VerifyScreenDump(buf, 'Test_visual_hl_with_showbreak', {})

  " clean up
  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
endfunc

func Test_Visual_r_CTRL_C()
  new
  " visual r_cmd
  call setline(1, ['   '])
  call feedkeys("\<c-v>$r\<c-c>", 'tx')
  call assert_equal([''], getline(1, 1))

  " visual gr_cmd
  call setline(1, ['   '])
  call feedkeys("\<c-v>$gr\<c-c>", 'tx')
  call assert_equal([''], getline(1, 1))
  bw!
endfunc

func Test_visual_drag_out_of_window()
  rightbelow vnew
  call setline(1, '123456789')
  set mouse=a
  func ClickExpr(off)
    call Ntest_setmouse(1, getwininfo(win_getid())[0].wincol + a:off)
    return "\<LeftMouse>"
  endfunc
  func DragExpr(off)
    call Ntest_setmouse(1, getwininfo(win_getid())[0].wincol + a:off)
    return "\<LeftDrag>"
  endfunc

  nnoremap <expr> <F2> ClickExpr(5)
  nnoremap <expr> <F3> DragExpr(-1)
  redraw
  call feedkeys("\<F2>\<F3>\<LeftRelease>", 'tx')
  call assert_equal([1, 6], [col('.'), col('v')])
  call feedkeys("\<Esc>", 'tx')

  nnoremap <expr> <F2> ClickExpr(6)
  nnoremap <expr> <F3> DragExpr(-2)
  redraw
  call feedkeys("\<F2>\<F3>\<LeftRelease>", 'tx')
  call assert_equal([1, 7], [col('.'), col('v')])
  call feedkeys("\<Esc>", 'tx')

  nunmap <F2>
  nunmap <F3>
  delfunc ClickExpr
  delfunc DragExpr
  set mouse&
  bwipe!
endfunc

func Test_visual_substitute_visual()
  new
  call setline(1, ['one', 'two', 'three'])
  call feedkeys("Gk\<C-V>j$:s/\\%V\\_.*\\%V/foobar\<CR>", 'tx')
  call assert_equal(['one', 'foobar'], getline(1, '$'))
  bwipe!
endfunc

func Test_visual_getregion()
  let lines =<< trim END
    new

    call setline(1, ['one', 'two', 'three'])

    #" Visual mode
    call cursor(1, 1)
    call feedkeys("\<ESC>vjl", 'tx')
    call assert_equal(['one', 'tw'],
          \ 'v'->getpos()->getregion(getpos('.')))
    call assert_equal(['one', 'tw'],
          \ '.'->getpos()->getregion(getpos('v')))
    call assert_equal(['o'],
          \ 'v'->getpos()->getregion(getpos('v')))
    call assert_equal(['w'],
          \ '.'->getpos()->getregion(getpos('.'), {'type': 'v' }))
    call assert_equal(['one', 'two'],
          \ getpos('.')->getregion(getpos('v'), {'type': 'V' }))
    call assert_equal(['on', 'tw'],
          \ getpos('.')->getregion(getpos('v'), {'type': "\<C-v>" }))

    #" Line visual mode
    call cursor(1, 1)
    call feedkeys("\<ESC>Vl", 'tx')
    call assert_equal(['one'],
          \ getregion(getpos('v'), getpos('.'), {'type': 'V' }))
    call assert_equal(['one'],
          \ getregion(getpos('.'), getpos('v'), {'type': 'V' }))
    call assert_equal(['one'],
          \ getregion(getpos('v'), getpos('v'), {'type': 'V' }))
    call assert_equal(['one'],
          \ getregion(getpos('.'), getpos('.'), {'type': 'V' }))
    call assert_equal(['on'],
          \ getpos('.')->getregion(getpos('v'), {'type': 'v' }))
    call assert_equal(['on'],
          \ getpos('.')->getregion(getpos('v'), {'type': "\<C-v>" }))

    #" Block visual mode
    call cursor(1, 1)
    call feedkeys("\<ESC>\<C-v>ll", 'tx')
    call assert_equal(['one'],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))
    call assert_equal(['one'],
          \ getregion(getpos('.'), getpos('v'), {'type': "\<C-v>" }))
    call assert_equal(['o'],
          \ getregion(getpos('v'), getpos('v'), {'type': "\<C-v>" }))
    call assert_equal(['e'],
          \ getregion(getpos('.'), getpos('.'), {'type': "\<C-v>" }))
    call assert_equal(['one'],
          \ '.'->getpos()->getregion(getpos('v'), {'type': 'V' }))
    call assert_equal(['one'],
          \ '.'->getpos()->getregion(getpos('v'), {'type': 'v' }))

    #" Using Marks
    call setpos("'a", [0, 2, 3, 0])
    call cursor(1, 1)
    call assert_equal(['one', 'two'],
          \ "'a"->getpos()->getregion(getpos('.'), {'type': 'v' }))
    call assert_equal(['one', 'two'],
          \ "."->getpos()->getregion(getpos("'a"), {'type': 'v' }))
    call assert_equal(['one', 'two'],
          \ "."->getpos()->getregion(getpos("'a"), {'type': 'V' }))
    call assert_equal(['two'],
          \ "'a"->getpos()->getregion(getpos("'a"), {'type': 'V' }))
    call assert_equal(['one', 'two'],
          \ "."->getpos()->getregion(getpos("'a"), {'type': "\<c-v>" }))

    #" Using List
    call cursor(1, 1)
    call assert_equal(['one', 'two'],
          \ [0, 2, 3, 0]->getregion(getpos('.'), {'type': 'v' }))
    call assert_equal(['one', 'two'],
          \ '.'->getpos()->getregion([0, 2, 3, 0], {'type': 'v' }))
    call assert_equal(['one', 'two'],
          \ '.'->getpos()->getregion([0, 2, 3, 0], {'type': 'V' }))
    call assert_equal(['two'],
          \ [0, 2, 3, 0]->getregion([0, 2, 3, 0], {'type': 'V' }))
    call assert_equal(['one', 'two'],
          \ '.'->getpos()->getregion([0, 2, 3, 0], {'type': "\<c-v>" }))

    #" Multiline with line visual mode
    call cursor(1, 1)
    call feedkeys("\<ESC>Vjj", 'tx')
    call assert_equal(['one', 'two', 'three'],
          \ getregion(getpos('v'), getpos('.'), {'type': 'V' }))

    #" Multiline with block visual mode
    call cursor(1, 1)
    call feedkeys("\<ESC>\<C-v>jj", 'tx')
    call assert_equal(['o', 't', 't'],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))

    call cursor(1, 1)
    call feedkeys("\<ESC>\<C-v>jj$", 'tx')
    call assert_equal(['one', 'two', 'three'],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))

    #" 'virtualedit'
    set virtualedit=all
    call cursor(1, 1)
    call feedkeys("\<ESC>\<C-v>10ljj$", 'tx')
    call assert_equal(['one   ', 'two   ', 'three '],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))
    set virtualedit&

    #" Invalid position
    call cursor(1, 1)
    call feedkeys("\<ESC>vjj$", 'tx')
    call assert_fails("call getregion(1, 2)", 'E1211:')
    call assert_fails("call getregion(getpos('.'), {})", 'E1211:')
    call assert_equal([], getregion(getpos('.'), getpos('.'), {'type': '' }))

    #" using the wrong type
    call assert_fails(':echo "."->getpos()->getregion("$", [])', 'E1211:')

    #" using a mark from another buffer to current buffer
    new
    VAR newbuf = bufnr()
    call setline(1, range(10))
    normal! GmA
    wincmd p
    call assert_equal([newbuf, 10, 1, 0], getpos("'A"))
    call assert_equal([], getregion(getpos('.'), getpos("'A"), {'type': 'v' }))
    call assert_equal([], getregion(getpos("'A"), getpos('.'), {'type': 'v' }))
    exe $':{newbuf}bwipe!'

    #" using a mark from another buffer to another buffer
    new
    VAR anotherbuf = bufnr()
    call setline(1, range(10))
    normal! GmA
    normal! GmB
    wincmd p
    call assert_equal([anotherbuf, 10, 1, 0], getpos("'A"))
    call assert_equal(['9'], getregion(getpos("'B"), getpos("'A"), {'type': 'v' }))
    exe $':{anotherbuf}bwipe!'

    #" using invalid buffer
    call assert_equal([], getregion([10000, 10, 1, 0], [10000, 10, 1, 0]))
  END
  call CheckLegacyAndVim9Success(lines)

  bwipe!

  let lines =<< trim END
    #" Selection in starts or ends in the middle of a multibyte character
    new
    call setline(1, [
          \   "abcdefghijk\u00ab",
          \   "\U0001f1e6\u00ab\U0001f1e7\u00ab\U0001f1e8\u00ab\U0001f1e9",
          \   "1234567890"
          \ ])
    call cursor(1, 3)
    call feedkeys("\<Esc>\<C-v>ljj", 'xt')
    call assert_equal(['cd', "\u00ab ", '34'],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))
    call cursor(1, 4)
    call feedkeys("\<Esc>\<C-v>ljj", 'xt')
    call assert_equal(['de', "\U0001f1e7", '45'],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))
    call cursor(1, 5)
    call feedkeys("\<Esc>\<C-v>jj", 'xt')
    call assert_equal(['e', ' ', '5'],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))
    call cursor(1, 1)
    call feedkeys("\<Esc>vj", 'xt')
    call assert_equal(['abcdefghijk«', "\U0001f1e6"],
          \ getregion(getpos('v'), getpos('.'), {'type': 'v' }))

    #" marks on multibyte chars
    :set selection=exclusive
    call setpos("'a", [0, 1, 11, 0])
    call setpos("'b", [0, 2, 16, 0])
    call setpos("'c", [0, 2, 0, 0])
    call cursor(1, 1)
    call assert_equal(['ghijk', '🇨«🇩'],
          \ getregion(getpos("'a"), getpos("'b"), {'type': "\<c-v>" }))
    call assert_equal(['k«', '🇦«🇧«🇨'],
          \ getregion(getpos("'a"), getpos("'b"), {'type': 'v' }))
    call assert_equal(['k«'],
          \ getregion(getpos("'a"), getpos("'c"), {'type': 'v' }))

    #" use inclusive selection, although 'selection' is exclusive
    call setpos("'a", [0, 1, 11, 0])
    call setpos("'b", [0, 1, 1, 0])
    call assert_equal(['abcdefghijk'],
          \ getregion(getpos("'a"), getpos("'b"),
          \ {'type': "\<c-v>", 'exclusive': v:false }))
    call assert_equal(['abcdefghij'],
          \ getregion(getpos("'a"), getpos("'b"),
          \ {'type': "\<c-v>", 'exclusive': v:true }))
    call assert_equal(['abcdefghijk'],
          \ getregion(getpos("'a"), getpos("'b"),
          \ {'type': 'v', 'exclusive': 0 }))
    call assert_equal(['abcdefghij'],
          \ getregion(getpos("'a"), getpos("'b"),
          \ {'type': 'v', 'exclusive': 1 }))
    call assert_equal(['abcdefghijk«'],
          \ getregion(getpos("'a"), getpos("'b"),
          \ {'type': 'V', 'exclusive': 0 }))
    call assert_equal(['abcdefghijk«'],
          \ getregion(getpos("'a"), getpos("'b"),
          \ {'type': 'V', 'exclusive': 1 }))
    :set selection&
  END
  call CheckLegacyAndVim9Success(lines)

  bwipe!

  let lines =<< trim END
    #" Exclusive selection
    new
    set selection=exclusive
    call setline(1, ["a\tc", "x\tz", '', ''])
    call cursor(1, 1)
    call feedkeys("\<Esc>v2l", 'xt')
    call assert_equal(["a\t"],
          \ getregion(getpos('v'), getpos('.'), {'type': 'v' }))
    call cursor(1, 1)
    call feedkeys("\<Esc>v$G", 'xt')
    call assert_equal(["a\tc", "x\tz", ''],
          \ getregion(getpos('v'), getpos('.'), {'type': 'v' }))
    call cursor(1, 1)
    call feedkeys("\<Esc>v$j", 'xt')
    call assert_equal(["a\tc", "x\tz"],
          \ getregion(getpos('v'), getpos('.'), {'type': 'v' }))
    call cursor(1, 1)
    call feedkeys("\<Esc>\<C-v>$j", 'xt')
    call assert_equal(["a\tc", "x\tz"],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))
    call cursor(1, 1)
    call feedkeys("\<Esc>\<C-v>$G", 'xt')
    call assert_equal(["a", "x", '', ''],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))
    call cursor(1, 1)
    call feedkeys("\<Esc>wv2j", 'xt')
    call assert_equal(["c", "x\tz"],
          \ getregion(getpos('v'), getpos('.'), {'type': 'v' }))
    set selection&

    #" Exclusive selection 2
    new
    call setline(1, ["a\tc", "x\tz", '', ''])
    call cursor(1, 1)
    call feedkeys("\<Esc>v2l", 'xt')
    call assert_equal(["a\t"],
          \ getregion(getpos('v'), getpos('.'), {'exclusive': v:true }))
    call cursor(1, 1)
    call feedkeys("\<Esc>v$G", 'xt')
    call assert_equal(["a\tc", "x\tz", ''],
          \ getregion(getpos('v'), getpos('.'), {'exclusive': v:true }))
    call cursor(1, 1)
    call feedkeys("\<Esc>v$j", 'xt')
    call assert_equal(["a\tc", "x\tz"],
          \ getregion(getpos('v'), getpos('.'), {'exclusive': v:true }))
    call cursor(1, 1)
    call feedkeys("\<Esc>\<C-v>$j", 'xt')
    call assert_equal(["a\tc", "x\tz"],
          \ getregion(getpos('v'), getpos('.'),
          \           {'exclusive': v:true, 'type': "\<C-v>" }))
    call cursor(1, 1)
    call feedkeys("\<Esc>\<C-v>$G", 'xt')
    call assert_equal(["a", "x", '', ''],
          \ getregion(getpos('v'), getpos('.'),
          \           {'exclusive': v:true, 'type': "\<C-v>" }))
    call cursor(1, 1)
    call feedkeys("\<Esc>wv2j", 'xt')
    call assert_equal(["c", "x\tz"],
          \ getregion(getpos('v'), getpos('.'), {'exclusive': v:true }))

    #" virtualedit
    set selection=exclusive
    set virtualedit=all
    call cursor(1, 1)
    call feedkeys("\<Esc>2lv2lj", 'xt')
    call assert_equal(['      c', 'x   '],
          \ getregion(getpos('v'), getpos('.'), {'type': 'v' }))
    call cursor(1, 1)
    call feedkeys("\<Esc>2l\<C-v>2l2j", 'xt')
    call assert_equal(['  ', '  ', '  '],
          \ getregion(getpos('v'), getpos('.'), {'type': "\<C-v>" }))
    set virtualedit&
    set selection&

    bwipe!
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_getregion_invalid_buf()
  new
  help
  call cursor(5, 7)
  norm! mA
  call cursor(5, 18)
  norm! mB
  call assert_equal(['Move around:'], getregion(getpos("'A"), getpos("'B")))
  " close the help window
  q
  call assert_equal([], getregion(getpos("'A"), getpos("'B")))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
