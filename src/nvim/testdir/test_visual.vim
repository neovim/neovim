" Tests for various Visual mode.
if !has('visual')
  finish
endif

set belloff=all

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
