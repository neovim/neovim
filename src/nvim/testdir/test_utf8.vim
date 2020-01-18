" Tests for Unicode manipulations
 

" Visual block Insert adjusts for multi-byte char
func Test_visual_block_insert()
  new
  call setline(1, ["aaa", "あああ", "bbb"])
  exe ":norm! gg0l\<C-V>jjIx\<Esc>"
  call assert_equal(['axaa', 'xあああ', 'bxbb'], getline(1, '$'))
  bwipeout!
endfunc

" Test for built-in function strchars()
func Test_strchars()
  let inp = ["a", "あいa", "A\u20dd", "A\u20dd\u20dd", "\u20dd"]
  let exp = [[1, 1, 1], [3, 3, 3], [2, 2, 1], [3, 3, 1], [1, 1, 1]]
  for i in range(len(inp))
    call assert_equal(exp[i][0], strchars(inp[i]))
    call assert_equal(exp[i][1], strchars(inp[i], 0))
    call assert_equal(exp[i][2], strchars(inp[i], 1))
  endfor
endfunc

" Test for customlist completion
function! CustomComplete1(lead, line, pos)
	return ['あ', 'い']
endfunction

function! CustomComplete2(lead, line, pos)
	return ['あたし', 'あたま', 'あたりめ']
endfunction

function! CustomComplete3(lead, line, pos)
	return ['Nこ', 'Nん', 'Nぶ']
endfunction

func Test_customlist_completion()
  command -nargs=1 -complete=customlist,CustomComplete1 Test1 echo
  call feedkeys(":Test1 \<C-L>\<C-B>\"\<CR>", 'itx')
  call assert_equal('"Test1 ', getreg(':'))

  command -nargs=1 -complete=customlist,CustomComplete2 Test2 echo
  call feedkeys(":Test2 \<C-L>\<C-B>\"\<CR>", 'itx')
  call assert_equal('"Test2 あた', getreg(':'))

  command -nargs=1 -complete=customlist,CustomComplete3 Test3 echo
  call feedkeys(":Test3 \<C-L>\<C-B>\"\<CR>", 'itx')
  call assert_equal('"Test3 N', getreg(':'))

  call garbagecollect(1)
endfunc

" Yank one 3 byte character and check the mark columns.
func Test_getvcol()
  new
  call setline(1, "x\u2500x")
  normal 0lvy
  call assert_equal(2, col("'["))
  call assert_equal(4, col("']"))
  call assert_equal(2, virtcol("'["))
  call assert_equal(2, virtcol("']"))
endfunc
