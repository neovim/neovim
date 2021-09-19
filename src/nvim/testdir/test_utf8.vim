" Tests for Unicode manipulations
 
source view_util.vim

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
func CustomComplete1(lead, line, pos)
	return ['あ', 'い']
endfunc

func CustomComplete2(lead, line, pos)
	return ['あたし', 'あたま', 'あたりめ']
endfunc

func CustomComplete3(lead, line, pos)
	return ['Nこ', 'Nん', 'Nぶ']
endfunc

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

func Test_screenchar_utf8()
  new

  " 1-cell, with composing characters 
  call setline(1, ["ABC\u0308"])
  redraw
  call assert_equal([0x0041], screenchars(1, 1))
  call assert_equal([0x0042], screenchars(1, 2))
  call assert_equal([0x0043, 0x0308], screenchars(1, 3))
  call assert_equal("A", screenstring(1, 1))
  call assert_equal("B", screenstring(1, 2))
  call assert_equal("C\u0308", screenstring(1, 3))

  " 2-cells, with composing characters 
  let text = "\u3042\u3044\u3046\u3099"
  call setline(1, text)
  redraw
  call assert_equal([0x3042], screenchars(1, 1))
  call assert_equal([0], screenchars(1, 2))
  call assert_equal([0x3044], screenchars(1, 3))
  call assert_equal([0], screenchars(1, 4))
  call assert_equal([0x3046, 0x3099], screenchars(1, 5))

  call assert_equal("\u3042", screenstring(1, 1))
  call assert_equal("", screenstring(1, 2))
  call assert_equal("\u3044", screenstring(1, 3))
  call assert_equal("", screenstring(1, 4))
  call assert_equal("\u3046\u3099", screenstring(1, 5))

  call assert_equal([text . '  '], ScreenLines(1, 8))

  bwipe!
endfunc

func Test_list2str_str2list_utf8()
  " One Unicode codepoint
  let s = "\u3042\u3044"
  let l = [0x3042, 0x3044]
  call assert_equal(l, str2list(s, 1))
  call assert_equal(s, list2str(l, 1))
  if &enc ==# 'utf-8'
    call assert_equal(str2list(s), str2list(s, 1))
    call assert_equal(list2str(l), list2str(l, 1))
  endif

  " With composing characters
  let s = "\u304b\u3099\u3044"
  let l = [0x304b, 0x3099, 0x3044]
  call assert_equal(l, str2list(s, 1))
  call assert_equal(s, list2str(l, 1))
  if &enc ==# 'utf-8'
    call assert_equal(str2list(s), str2list(s, 1))
    call assert_equal(list2str(l), list2str(l, 1))
  endif

  " Null list is the same as an empty list
  call assert_equal('', list2str([]))
  call assert_equal('', list2str(v:_null_list))
endfunc

func Test_list2str_str2list_latin1()
  " When 'encoding' is not multi-byte can still get utf-8 string.
  " But we need to create the utf-8 string while 'encoding' is utf-8.
  let s = "\u3042\u3044"
  let l = [0x3042, 0x3044]

  let save_encoding = &encoding
  " set encoding=latin1

  let lres = str2list(s, 1)
  let sres = list2str(l, 1)

  let &encoding = save_encoding
  call assert_equal(l, lres)
  call assert_equal(s, sres)
endfunc

func Test_print_overlong()
  " Text with more composing characters than MB_MAXBYTES.
  new
  call setline(1, 'axxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
  s/x/\=nr2char(1629)/g
  print
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
