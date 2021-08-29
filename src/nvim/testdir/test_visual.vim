" Tests for various Visual modes.

source shared.vim
source check.vim
source screendump.vim

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

func Test_visual_put_in_block()
  new
  call setline(1, ['xxxx', 'y∞yy', 'zzzz'])
  normal 1G2yl
  exe "normal 1G2l\<C-V>jjlp"
  call assert_equal(['xxxx', 'y∞xx', 'zzxx'], getline(1, 3))
  bwipe!
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

  bwipe!
endfunc

func Test_characterwise_select_mode()
  new

  " Select mode maps
  snoremap <lt>End> <End>
  snoremap <lt>Down> <Down>
  snoremap <lt>Del> <Del>

  " characterwise select mode: delete middle line
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal Gkkgh\<End>\<Del>"
  call assert_equal(['', 'b', 'c'], getline(1, '$'))

  " characterwise select mode: delete middle two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal Gkkgh\<Down>\<End>\<Del>"
  call assert_equal(['', 'c'], getline(1, '$'))

  " characterwise select mode: delete last line
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal Ggh\<End>\<Del>"
  call assert_equal(['', 'a', 'b', ''], getline(1, '$'))

  " characterwise select mode: delete last two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal Gkgh\<Down>\<End>\<Del>"
  call assert_equal(['', 'a', ''], getline(1, '$'))

  sunmap <lt>End>
  sunmap <lt>Down>
  sunmap <lt>Del>
  bwipe!
endfunc

func Test_linewise_select_mode()
  new

  " linewise select mode: delete middle line
  call append('$', ['a', 'b', 'c'])
  exe "normal GkkgH\<Del>"
  call assert_equal(['', 'b', 'c'], getline(1, '$'))


  " linewise select mode: delete middle two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal GkkgH\<Down>\<Del>"
  call assert_equal(['', 'c'], getline(1, '$'))

  " linewise select mode: delete last line
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal GgH\<Del>"
  call assert_equal(['', 'a', 'b'], getline(1, '$'))

  " linewise select mode: delete last two lines
  call deletebufline('', 1, '$')
  call append('$', ['a', 'b', 'c'])
  exe "normal GkgH\<Down>\<Del>"
  call assert_equal(['', 'a'], getline(1, '$'))

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

func Test_select_mode_gv()
  new

  " gv in exclusive select mode after operation
  call append('$', ['zzz ', 'Ã¤Ã '])
  set selection=exclusive
  normal Gkv3lyjv3lpgvcxxx
  call assert_equal(['', 'zzz ', 'xxx '], getline(1, '$'))

  " gv in exclusive select mode without operation
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
  call setline(1, ['abcdefghijklm', 'abcdefghijklm', 'abcdefghijklm',
        \ 'abcdefghijklm', 'abcdefghijklm'])
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
    onoremap <expr> i- execute('let g:mode = mode(1)')
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
  " gUe must uppercase a whole word, also when ß changes to SS
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
  call assert_equal(['the YOUTUSSEUU end', '- yOUSSTUSSEXu -',
        \ 'THE YOUTUSSEUU END', '111THE YOUTUSSEUU END', 'BLAH DI', 'DOH DUT',
        \ '222the yoUTUSSEUU END', '333THE YOUTUßeuu end'], getline(2, '$'))
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

  " clean up
  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
  call delete('XTest_beval')
endfunc


" vim: shiftwidth=2 sts=2 expandtab
