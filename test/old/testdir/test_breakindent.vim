" Test for breakindent
"
" Note: if you get strange failures when adding new tests, it might be that
" while the test is run, the breakindent caching gets in its way.
" It helps to change the tabstop setting and force a redraw (e.g. see
" Test_breakindent08())
source check.vim
CheckOption breakindent

source view_util.vim
source screendump.vim

func SetUp()
  let s:input ="\tabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP"
endfunc

func s:screen_lines(lnum, width) abort
  return ScreenLines([a:lnum, a:lnum + 2], a:width)
endfunc

func s:screen_lines2(lnums, lnume, width) abort
  return ScreenLines([a:lnums, a:lnume], a:width)
endfunc

func s:compare_lines(expect, actual)
  call assert_equal(join(a:expect, "\n"), join(a:actual, "\n"))
endfunc

func s:test_windows(...)
  call NewWindow(10, 20)
  setl ts=4 sw=4 sts=4 breakindent
  put =s:input
  exe get(a:000, 0, '')
endfunc

func s:close_windows(...)
  call CloseWindow()
  exe get(a:000, 0, '')
endfunc

func Test_breakindent01()
  " simple breakindent test
  call s:test_windows('setl briopt=min:0')
  let lines = s:screen_lines(line('.'),8)
  let expect = [
	\ "    abcd",
	\ "    qrst",
	\ "    GHIJ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_breakindent01_vartabs()
  " like 01 but with vartabs feature
  if !has("vartabs")
    return
  endif
  call s:test_windows('setl briopt=min:0 vts=4')
  let lines = s:screen_lines(line('.'),8)
  let expect = [
	\ "    abcd",
	\ "    qrst",
	\ "    GHIJ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set vts&')
endfunc

func Test_breakindent02()
  " simple breakindent test with showbreak set
  set sbr=>>
  call s:test_windows('setl briopt=min:0 sbr=')
  let lines = s:screen_lines(line('.'),8)
  let expect = [
	\ "    abcd",
	\ "    >>qr",
	\ "    >>EF",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr=')
endfunc

func Test_breakindent02_vartabs()
  if !has("vartabs")
    return
  endif
  " simple breakindent test with showbreak set
  call s:test_windows('setl briopt=min:0 sbr=>> vts=4')
  let lines = s:screen_lines(line('.'), 8)
  let expect = [
	\ "    abcd",
	\ "    >>qr",
	\ "    >>EF",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr= vts&')
endfunc

func Test_breakindent03()
  " simple breakindent test with showbreak set and briopt including sbr
  call s:test_windows('setl briopt=sbr,min:0 sbr=++')
  let lines = s:screen_lines(line('.'), 8)
  let expect=[
\ "    abcd",
\ "++  qrst",
\ "++  GHIJ",
\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr=')
endfunc

func Test_breakindent03_vartabs()
  " simple breakindent test with showbreak set and briopt including sbr
  if !has("vartabs")
    return
  endif
  call s:test_windows('setl briopt=sbr,min:0 sbr=++ vts=4')
  let lines = s:screen_lines(line('.'), 8)
  let expect = [
	\ "    abcd",
	\ "++  qrst",
	\ "++  GHIJ",
	\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr= vts&')
endfunc

func Test_breakindent04()
  " breakindent set with min width 18
  set sbr=<<<
  call s:test_windows('setl sbr=NONE briopt=min:18')
  let lines = s:screen_lines(line('.'), 8)
  let expect = [
	\ "    abcd",
	\ "  qrstuv",
	\ "  IJKLMN",
	\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr=')
  set sbr=
endfunc

func Test_breakindent04_vartabs()
  " breakindent set with min width 18
  if !has("vartabs")
    return
  endif
  call s:test_windows('setl sbr= briopt=min:18 vts=4')
  let lines = s:screen_lines(line('.'), 8)
  let expect = [
	\ "    abcd",
	\ "  qrstuv",
	\ "  IJKLMN",
	\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr= vts&')
endfunc

func Test_breakindent05()
  " breakindent set and shift by 2
  call s:test_windows('setl briopt=shift:2,min:0')
  let lines = s:screen_lines(line('.'),8)
  let expect = [
	\ "    abcd",
	\ "      qr",
	\ "      EF",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_breakindent05_vartabs()
  " breakindent set and shift by 2
  if !has("vartabs")
    return
  endif
  call s:test_windows('setl briopt=shift:2,min:0 vts=4')
  let lines = s:screen_lines(line('.'),8)
  let expect = [
	\ "    abcd",
	\ "      qr",
	\ "      EF",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set vts&')
endfunc

func Test_breakindent06()
  " breakindent set and shift by -1
  call s:test_windows('setl briopt=shift:-1,min:0')
  let lines = s:screen_lines(line('.'),8)
  let expect = [
	\ "    abcd",
	\ "   qrstu",
	\ "   HIJKL",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_breakindent06_vartabs()
  " breakindent set and shift by -1
  if !has("vartabs")
    return
  endif
  call s:test_windows('setl briopt=shift:-1,min:0 vts=4')
  let lines = s:screen_lines(line('.'),8)
  let expect = [
	\ "    abcd",
	\ "   qrstu",
	\ "   HIJKL",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set vts&')
endfunc

func Test_breakindent07()
  " breakindent set and shift by 1, Number  set sbr=? and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu sbr=? nuw=4 cpo+=n')
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2     ab",
	\ "?        m",
	\ "?        x",
	\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr= cpo-=n')
endfunc

func Test_breakindent07_vartabs()
  if !has("vartabs")
    return
  endif
  " breakindent set and shift by 1, Number  set sbr=? and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu sbr=? nuw=4 cpo+=n vts=4')
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2     ab",
	\ "?        m",
	\ "?        x",
	\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr= cpo-=n vts&')
endfunc

func Test_breakindent07a()
  " breakindent set and shift by 1, Number  set sbr=? and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu sbr=? nuw=4')
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2     ab",
	\ "    ?    m",
	\ "    ?    x",
	\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr=')
endfunc

func Test_breakindent07a_vartabs()
  if !has("vartabs")
    return
  endif
  " breakindent set and shift by 1, Number  set sbr=? and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu sbr=? nuw=4 vts=4')
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2     ab",
	\ "    ?    m",
	\ "    ?    x",
	\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr= vts&')
endfunc

func Test_breakindent08()
  " breakindent set and shift by 1, Number and list set sbr=# and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu nuw=4 sbr=# list cpo+=n ts=4')
  " make sure, cache is invalidated!
  set ts=8
  redraw!
  set ts=4
  redraw!
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2 ^Iabcd",
	\ "#      opq",
	\ "#      BCD",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr= cpo-=n')
endfunc

func Test_breakindent08_vartabs()
  if !has("vartabs")
    return
  endif
  " breakindent set and shift by 1, Number and list set sbr=# and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu nuw=4 sbr=# list cpo+=n ts=4 vts=4')
  " make sure, cache is invalidated!
  set ts=8
  redraw!
  set ts=4
  redraw!
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2 ^Iabcd",
	\ "#      opq",
	\ "#      BCD",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr= cpo-=n vts&')
endfunc

func Test_breakindent08a()
  " breakindent set and shift by 1, Number and list set sbr=# and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu nuw=4 sbr=# list')
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2 ^Iabcd",
	\ "    #  opq",
	\ "    #  BCD",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr=')
endfunc

func Test_breakindent08a_vartabs()
  if !has("vartabs")
    return
  endif
  " breakindent set and shift by 1, Number and list set sbr=# and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu nuw=4 sbr=# list vts=4')
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2 ^Iabcd",
	\ "    #  opq",
	\ "    #  BCD",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr= vts&')
endfunc

func Test_breakindent09()
  " breakindent set and shift by 1, Number and list set sbr=#
  call s:test_windows('setl briopt=shift:1,min:0 nu nuw=4 sbr=# list')
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2 ^Iabcd",
	\ "       #op",
	\ "       #AB",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr=')
endfunc

func Test_breakindent09_vartabs()
  if !has("vartabs")
    return
  endif
  " breakindent set and shift by 1, Number and list set sbr=#
  call s:test_windows('setl briopt=shift:1,min:0 nu nuw=4 sbr=# list vts=4')
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2 ^Iabcd",
	\ "       #op",
	\ "       #AB",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr= vts&')
endfunc

func Test_breakindent10()
  " breakindent set, Number set sbr=~
  call s:test_windows('setl cpo+=n sbr=~ nu nuw=4 nolist briopt=sbr,min:0')
  " make sure, cache is invalidated!
  set ts=8
  redraw!
  set ts=4
  redraw!
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2     ab",
	\ "~       mn",
	\ "~       yz",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr= cpo-=n')
endfunc

func Test_breakindent10_vartabs()
  if !has("vartabs")
    return
  endif
  " breakindent set, Number set sbr=~
  call s:test_windows('setl cpo+=n sbr=~ nu nuw=4 nolist briopt=sbr,min:0 vts=4')
  " make sure, cache is invalidated!
  set ts=8
  redraw!
  set ts=4
  redraw!
  let lines = s:screen_lines(line('.'),10)
  let expect = [
	\ "  2     ab",
	\ "~       mn",
	\ "~       yz",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr= cpo-=n vts&')
endfunc

func Test_breakindent11()
  " test strdisplaywidth()
  call s:test_windows('setl cpo-=n sbr=>> nu nuw=4 nolist briopt= ts=4')
  let text = getline(2)
  let width = strlen(text[1:]) + indent(2) + strlen(&sbr) * 3 " text wraps 3 times
  call assert_equal(width, strdisplaywidth(text))
  call s:close_windows('set sbr=')
  call assert_equal(4, strdisplaywidth("\t", 4))
endfunc

func Test_breakindent11_vartabs()
  if !has("vartabs")
    return
  endif
  " test strdisplaywidth()
  call s:test_windows('setl cpo-=n sbr=>> nu nuw=4 nolist briopt= ts=4 vts=4')
  let text = getline(2)
  let width = strlen(text[1:]) + 2->indent() + strlen(&sbr) * 3 " text wraps 3 times
  call assert_equal(width, text->strdisplaywidth())
  call s:close_windows('set sbr= vts&')
endfunc

func Test_breakindent12()
  " test breakindent with long indent
  let s:input="\t\t\t\t\t{"
  call s:test_windows('setl breakindent linebreak briopt=min:10 nu numberwidth=3 ts=4 list listchars=tab:>-')
  let lines = s:screen_lines(2,16)
  let expect = [
	\ " 2 >--->--->--->",
	\ "          ---{  ",
	\ "~               ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set nuw=4 listchars&')
endfunc

func Test_breakindent12_vartabs()
  if !has("vartabs")
    return
  endif
  " test breakindent with long indent
  let s:input = "\t\t\t\t\t{"
  call s:test_windows('setl breakindent linebreak briopt=min:10 nu numberwidth=3 ts=4 list listchars=tab:>- vts=4')
  let lines = s:screen_lines(2,16)
  let expect = [
	\ " 2 >--->--->--->",
	\ "          ---{  ",
	\ "~               ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set nuw=4 listchars& vts&')
endfunc

func Test_breakindent13()
  let s:input = ""
  call s:test_windows('setl breakindent briopt=min:10 ts=8')
  vert resize 20
  call setline(1, ["    a\tb\tc\td\te", "    z   y       x       w       v"])
  1
  norm! fbgj"ayl
  2
  norm! fygj"byl
  call assert_equal('d', @a)
  call assert_equal('w', @b)
  call s:close_windows()
endfunc

func Test_breakindent13_vartabs()
  if !has("vartabs")
    return
  endif
  let s:input = ""
  call s:test_windows('setl breakindent briopt=min:10 ts=8 vts=8')
  vert resize 20
  call setline(1, ["    a\tb\tc\td\te", "    z   y       x       w       v"])
  1
  norm! fbgj"ayl
  2
  norm! fygj"byl
  call assert_equal('d', @a)
  call assert_equal('w', @b)
  call s:close_windows('set vts&')
endfunc

func Test_breakindent14()
  let s:input = ""
  call s:test_windows('setl breakindent briopt= ts=8')
  vert resize 30
  norm! 3a1234567890
  norm! a    abcde
  exec "norm! 0\<C-V>tex"
  let lines = s:screen_lines(line('.'),8)
  let expect = [
	\ "e       ",
	\ "~       ",
	\ "~       ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_breakindent14_vartabs()
  if !has("vartabs")
    return
  endif
  let s:input = ""
  call s:test_windows('setl breakindent briopt= ts=8 vts=8')
  vert resize 30
  norm! 3a1234567890
  norm! a    abcde
  exec "norm! 0\<C-V>tex"
  let lines = s:screen_lines(line('.'),8)
  let expect = [
	\ "e       ",
	\ "~       ",
	\ "~       ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set vts&')
endfunc

func Test_breakindent15()
  let s:input = ""
  call s:test_windows('setl breakindent briopt= ts=8 sw=8')
  vert resize 30
  norm! 4a1234567890
  exe "normal! >>\<C-V>3f0x"
  let lines = s:screen_lines(line('.'),20)
  let expect = [
	\ "        1234567890  ",
	\ "~                   ",
	\ "~                   ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_breakindent15_vartabs()
  if !has("vartabs")
    return
  endif
  let s:input = ""
  call s:test_windows('setl breakindent briopt= ts=8 sw=8 vts=8')
  vert resize 30
  norm! 4a1234567890
  exe "normal! >>\<C-V>3f0x"
  let lines = s:screen_lines(line('.'),20)
  let expect = [
	\ "        1234567890  ",
	\ "~                   ",
	\ "~                   ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set vts&')
endfunc

func Test_breakindent16()
  " Check that overlong lines are indented correctly.
  let s:input = ""
  call s:test_windows('setl breakindent briopt=min:0 ts=4')
  call setline(1, "\t".repeat("1234567890", 10))
  resize 6
  norm! 1gg$
  redraw!
  let lines = s:screen_lines(1,10)
  let expect = [
	\ "<<< 789012",
	\ "    345678",
	\ "    901234",
	\ ]
  call s:compare_lines(expect, lines)
  let lines = s:screen_lines(4,10)
  let expect = [
	\ "    567890",
	\ "    123456",
	\ "    7890  ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_breakindent16_vartabs()
  if !has("vartabs")
    return
  endif
  " Check that overlong lines are indented correctly.
  let s:input = ""
  call s:test_windows('setl breakindent briopt=min:0 ts=4 vts=4')
  call setline(1, "\t".repeat("1234567890", 10))
  resize 6
  norm! 1gg$
  redraw!
  let lines = s:screen_lines(1,10)
  let expect = [
	\ "<<< 789012",
	\ "    345678",
	\ "    901234",
	\ ]
  call s:compare_lines(expect, lines)
  let lines = s:screen_lines(4,10)
  let expect = [
	\ "    567890",
	\ "    123456",
	\ "    7890  ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set vts&')
endfunc

func Test_breakindent17_vartabs()
  if !has("vartabs")
    return
  endif
  let s:input = ""
  call s:test_windows('setl breakindent list listchars=tab:<-> showbreak=+++')
  call setline(1, "\t" . repeat('a', 63))
  vert resize 30
  norm! 1gg$
  redraw!
  let lines = s:screen_lines(1, 30)
  let expect = [
	\ "<-->aaaaaaaaaaaaaaaaaaaaaaaaaa",
	\ "    +++aaaaaaaaaaaaaaaaaaaaaaa",
	\ "    +++aaaaaaaaaaaaaa         ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set breakindent& list& listchars& showbreak&')
endfunc

func Test_breakindent18_vartabs()
  if !has("vartabs")
    return
  endif
  let s:input = ""
  call s:test_windows('setl breakindent list listchars=tab:<->')
  call setline(1, "\t" . repeat('a', 63))
  vert resize 30
  norm! 1gg$
  redraw!
  let lines = s:screen_lines(1, 30)
  let expect = [
	\ "<-->aaaaaaaaaaaaaaaaaaaaaaaaaa",
	\ "    aaaaaaaaaaaaaaaaaaaaaaaaaa",
	\ "    aaaaaaaaaaa               ",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set breakindent& list& listchars&')
endfunc

func Test_breakindent19_sbr_nextpage()
  let s:input = ""
  call s:test_windows('setl breakindent briopt=shift:2,sbr,min:18 sbr=>')
  call setline(1, repeat('a', 200))
  norm! 1gg
  redraw!
  let lines = s:screen_lines(1, 20)
  let expect = [
	\ "aaaaaaaaaaaaaaaaaaaa",
	\ "> aaaaaaaaaaaaaaaaaa",
	\ "> aaaaaaaaaaaaaaaaaa",
	\ ]
  call s:compare_lines(expect, lines)
  " Scroll down one screen line
  setl scrolloff=5
  norm! 5gj
  let lines = s:screen_lines(1, 20)
  let expect = [
	\ "aaaaaaaaaaaaaaaaaaaa",
	\ "> aaaaaaaaaaaaaaaaaa",
	\ "> aaaaaaaaaaaaaaaaaa",
	\ ]
  call s:compare_lines(expect, lines)
  redraw!
  " moving the cursor doesn't change the text offset
  norm! l
  redraw!
  let lines = s:screen_lines(1, 20)
  call s:compare_lines(expect, lines)

  setl breakindent briopt=min:18 sbr=>
  norm! 5gj
  let lines = s:screen_lines(1, 20)
  let expect = [
	\ ">aaaaaaaaaaaaaaaaaaa",
	\ ">aaaaaaaaaaaaaaaaaaa",
	\ ">aaaaaaaaaaaaaaaaaaa",
	\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set breakindent& briopt& sbr&')
endfunc

func Test_breakindent20_cpo_n_nextpage()
  let s:input = ""
  call s:test_windows('setl breakindent briopt=min:14 cpo+=n number')
  call setline(1, repeat('abcdefghijklmnopqrst', 10))
  norm! 1gg
  redraw!
  let lines = s:screen_lines(1, 20)
  let expect = [
	\ "  1 abcdefghijklmnop",
	\ "    qrstabcdefghijkl",
	\ "    mnopqrstabcdefgh",
	\ ]
  call s:compare_lines(expect, lines)
  " Scroll down one screen line
  setl scrolloff=5
  norm! 6gj
  redraw!
  let lines = s:screen_lines(1, 20)
  let expect = [
	\ "<<< qrstabcdefghijkl",
	\ "    mnopqrstabcdefgh",
	\ "    ijklmnopqrstabcd",
	\ ]
  call s:compare_lines(expect, lines)

  setl briopt+=shift:2
  norm! 1gg
  let lines = s:screen_lines(1, 20)
  let expect = [
	\ "  1 abcdefghijklmnop",
	\ "      qrstabcdefghij",
	\ "      klmnopqrstabcd",
	\ ]
  call s:compare_lines(expect, lines)
  " Scroll down one screen line
  norm! 6gj
  let lines = s:screen_lines(1, 20)
  let expect = [
	\ "<<<   qrstabcdefghij",
	\ "      klmnopqrstabcd",
	\ "      efghijklmnopqr",
	\ ]
  call s:compare_lines(expect, lines)

  call s:close_windows('set breakindent& briopt& cpo& number&')
endfunc

func Test_breakindent20_list()
  call s:test_windows('setl breakindent breakindentopt= linebreak')
  " default:
  call setline(1, ['  1.  Congress shall make no law',
        \ '  2.) Congress shall make no law',
        \ '  3.] Congress shall make no law'])
  norm! 1gg
  redraw!
  let lines = s:screen_lines2(1, 6, 20)
  let expect = [
	\ "  1.  Congress      ",
	\ "shall make no law   ",
	\ "  2.) Congress      ",
	\ "shall make no law   ",
	\ "  3.] Congress      ",
	\ "shall make no law   ",
	\ ]
  call s:compare_lines(expect, lines)
  " set minimum text width
  setl briopt=min:5
  redraw!
  let lines = s:screen_lines2(1, 6, 20)
  let expect = [
	\ "  1.  Congress      ",
	\ "  shall make no law ",
	\ "  2.) Congress      ",
	\ "  shall make no law ",
	\ "  3.] Congress      ",
	\ "  shall make no law ",
	\ ]
  call s:compare_lines(expect, lines)
  " set additional handing indent
  setl briopt+=list:4
  redraw!
  let expect = [
	\ "  1.  Congress      ",
	\ "      shall make no ",
	\ "      law           ",
	\ "  2.) Congress      ",
	\ "      shall make no ",
	\ "      law           ",
	\ "  3.] Congress      ",
	\ "      shall make no ",
	\ "      law           ",
	\ ]
  let lines = s:screen_lines2(1, 9, 20)
  call s:compare_lines(expect, lines)

  " reset linebreak option
  " Note: it indents by one additional
  " space, because of the leading space.
  setl linebreak&vim list listchars=eol:$,space:_
  redraw!
  let expect = [
	\ "__1.__Congress_shall",
	\ "      _make_no_law$ ",
	\ "__2.)_Congress_shall",
	\ "      _make_no_law$ ",
	\ "__3.]_Congress_shall",
	\ "      _make_no_law$ ",
	\ ]
  let lines = s:screen_lines2(1, 6, 20)
  call s:compare_lines(expect, lines)

  " check formatlistpat indent
  setl briopt=min:5,list:-1
  setl linebreak list&vim listchars&vim
  let &l:flp = '^\s*\d\+\.\?[\]:)}\t ]\s*'
  redraw!
  let expect = [
	\ "  1.  Congress      ",
	\ "      shall make no ",
	\ "      law           ",
	\ "  2.) Congress      ",
	\ "      shall make no ",
	\ "      law           ",
	\ "  3.] Congress      ",
	\ "      shall make no ",
	\ "      law           ",
	\ ]
  let lines = s:screen_lines2(1, 9, 20)
  call s:compare_lines(expect, lines)

  " check with TABs
  call setline(1, ["\t1.\tCongress shall make no law",
        \ "\t2.) Congress shall make no law",
        \ "\t3.] Congress shall make no law"])
  setl tabstop=4 list listchars=tab:<->
  norm! 1gg
  redraw!
  let expect = [
	\ "<-->1.<>Congress    ",
	\ "        shall make  ",
	\ "        no law      ",
	\ "<-->2.) Congress    ",
	\ "        shall make  ",
	\ "        no law      ",
	\ "<-->3.] Congress    ",
	\ "        shall make  ",
	\ "        no law      ",
	\ ]
  let lines = s:screen_lines2(1, 9, 20)
  call s:compare_lines(expect, lines)

  setl tabstop=2 nolist
  redraw!
  let expect = [
	\ "  1.  Congress      ",
	\ "      shall make no ",
	\ "      law           ",
	\ "  2.) Congress      ",
	\ "      shall make no ",
	\ "      law           ",
	\ "  3.] Congress      ",
	\ "      shall make no ",
	\ "      law           ",
	\ ]
  let lines = s:screen_lines2(1, 9, 20)
  call s:compare_lines(expect, lines)

  setl tabstop& list listchars=space:_
  redraw!
  let expect = [
	\ "^I1.^ICongress_     ",
	\ "      shall_make_no_",
	\ "      law           ",
	\ "^I2.)_Congress_     ",
	\ "      shall_make_no_",
	\ "      law           ",
	\ "^I3.]_Congress_     ",
	\ "      shall_make_no_",
	\ "      law           ",
	\ ]
  let lines = s:screen_lines2(1, 9, 20)
  call s:compare_lines(expect, lines)

  " check formatlistpat indent with different list levels
  let &l:flp = '^\s*\(\*\|•\)\+\s\+'
  setl list&vim listchars&vim
  %delete _
  call setline(1, ['* Congress shall make no law',
        \ '••• Congress shall make no law',
        \ '**** Congress shall make no law'])
  norm! 1gg
  redraw!
  let expect = [
	\ "* Congress shall    ",
	\ "  make no law       ",
	\ "••• Congress shall  ",
	\ "    make no law     ",
	\ "**** Congress shall ",
	\ "     make no law    ",
	\ ]
  let lines = s:screen_lines2(1, 6, 20)
  call s:compare_lines(expect, lines)

  " check formatlistpat indent with different list level
  " showbreak and sbr
  setl briopt=min:5,sbr,list:-1
  setl showbreak=>
  redraw!
  let expect = [
	\ "* Congress shall    ",
	\ "> make no law       ",
	\ "••• Congress shall  ",
	\ ">   make no law     ",
	\ "**** Congress shall ",
	\ ">    make no law    ",
	\ ]
  let lines = s:screen_lines2(1, 6, 20)
  call s:compare_lines(expect, lines)

  " check formatlistpat indent with different list level
  " showbreak sbr and shift
  setl briopt=min:5,sbr,list:-1,shift:2
  setl showbreak=>
  redraw!
  let expect = [
	\ "* Congress shall    ",
	\ ">   make no law     ",
	\ "••• Congress shall  ",
	\ ">     make no law   ",
	\ "**** Congress shall ",
	\ ">      make no law  ",
	\ ]
  let lines = s:screen_lines2(1, 6, 20)
  call s:compare_lines(expect, lines)

  " check breakindent works if breakindentopt=list:-1
  " for a non list content
  %delete _
  call setline(1, ['  Congress shall make no law',
        \ '    Congress shall make no law',
        \ '     Congress shall make no law'])
  norm! 1gg
  setl briopt=min:5,list:-1
  setl showbreak=
  redraw!
  let expect = [
	\ "  Congress shall    ",
	\ "  make no law       ",
	\ "    Congress shall  ",
	\ "    make no law     ",
	\ "     Congress shall ",
	\ "     make no law    ",
	\ ]
  let lines = s:screen_lines2(1, 6, 20)
  call s:compare_lines(expect, lines)

  call s:close_windows('set breakindent& briopt& linebreak& list& listchars& showbreak&')
endfunc

" The following used to crash Vim. This is fixed by 8.2.3391.
" This is a regression introduced by 8.2.2903.
func Test_window_resize_with_linebreak()
  new
  53vnew
  setl linebreak
  setl showbreak=>>
  setl breakindent
  setl breakindentopt=shift:4
  call setline(1, "\naaaaaaaaa\n\na\naaaaa\n¯aaaaaaaaaa\naaaaaaaaaaaa\naaa\n\"a:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa - aaaaaaaa\"\naaaaaaaa\n\"a")
  redraw!
  call assert_equal(["    >>aa^@\"a: "], ScreenLines(2, 14))
  vertical resize 52
  redraw!
  call assert_equal(["    >>aaa^@\"a:"], ScreenLines(2, 14))
  set linebreak& showbreak& breakindent& breakindentopt&
  %bw!
endfunc

func Test_cursor_position_with_showbreak()
  CheckScreendump

  let lines =<< trim END
      vim9script
      &signcolumn = 'yes'
      &showbreak = '++'
      &breakindentopt = 'shift:2'
      var leftcol: number = win_getid()->getwininfo()->get(0, {})->get('textoff')
      repeat('x', &columns - leftcol - 1)->setline(1)
      'second line'->setline(2)
  END
  call writefile(lines, 'XscriptShowbreak', 'D')
  let buf = RunVimInTerminal('-S XscriptShowbreak', #{rows: 6})

  call term_sendkeys(buf, "AX")
  call VerifyScreenDump(buf, 'Test_cursor_position_with_showbreak_1', {})
  " No line wraps, so changing 'showbreak' should lead to the same screen.
  call term_sendkeys(buf, "\<C-\>\<C-O>:setlocal showbreak=+\<CR>")
  call VerifyScreenDump(buf, 'Test_cursor_position_with_showbreak_1', {})
  " No line wraps, so setting 'breakindent' should lead to the same screen.
  call term_sendkeys(buf, "\<C-\>\<C-O>:setlocal breakindent\<CR>")
  call VerifyScreenDump(buf, 'Test_cursor_position_with_showbreak_1', {})
  " The first line now wraps because of "eol" in 'listchars'.
  call term_sendkeys(buf, "\<C-\>\<C-O>:setlocal list\<CR>")
  call VerifyScreenDump(buf, 'Test_cursor_position_with_showbreak_2', {})
  call term_sendkeys(buf, "\<C-\>\<C-O>:setlocal nobreakindent\<CR>")
  call VerifyScreenDump(buf, 'Test_cursor_position_with_showbreak_3', {})

  call StopVimInTerminal(buf)
endfunc

func Test_visual_starts_before_skipcol()
  CheckScreendump

  let lines =<< trim END
    1new
    setlocal breakindent
    call setline(1, "\t" .. join(range(100)))
  END
  call writefile(lines, 'XvisualStartsBeforeSkipcol', 'D')
  let buf = RunVimInTerminal('-S XvisualStartsBeforeSkipcol', #{rows: 6})

  call term_sendkeys(buf, "v$")
  call VerifyScreenDump(buf, 'Test_visual_starts_before_skipcol_1', {})
  call term_sendkeys(buf, "\<Esc>:setlocal showbreak=+++\<CR>gv")
  call VerifyScreenDump(buf, 'Test_visual_starts_before_skipcol_2', {})
  call term_sendkeys(buf, "\<Esc>:setlocal breakindentopt+=sbr\<CR>gv")
  call VerifyScreenDump(buf, 'Test_visual_starts_before_skipcol_3', {})
  call term_sendkeys(buf, "\<Esc>:setlocal nobreakindent\<CR>gv")
  call VerifyScreenDump(buf, 'Test_visual_starts_before_skipcol_4', {})

  call StopVimInTerminal(buf)
endfunc

func Test_no_spurious_match()
  let s:input = printf('- y %s y %s', repeat('x', 50), repeat('x', 50))
  call s:test_windows('setl breakindent breakindentopt=list:-1 formatlistpat=^- hls')
  let @/ = '\%>3v[y]'
  redraw!
  call searchcount().total->assert_equal(1)

  " cleanup
  set hls&vim
  bwipeout!
endfunc

func Test_no_extra_indent()
  call s:test_windows('setl breakindent breakindentopt=list:-1,min:10')
  %d
  let &l:formatlistpat='^\s*\d\+\.\s\+'
  let text = 'word '
  let len = text->strcharlen()
  let line1 = text->repeat((winwidth(0) / len) * 2)
  let line2 = repeat(' ', 2) .. '1. ' .. line1
  call setline(1, [line2])
  redraw!
  " 1) matches formatlist pattern, so indent
  let expect = [
  \ "  1. word word word ",
  \ "     word word word ",
  \ "     word word      ",
  \ "~                   ",
  \ ]
  let lines = s:screen_lines2(1, 4, 20)
  call s:compare_lines(expect, lines)
  " 2) change formatlist pattern
  " -> indent adjusted
  let &l:formatlistpat='^\s*\d\+\.'
  let expect = [
  \ "  1. word word word ",
  \ "    word word word  ",
  \ "    word word       ",
  \ "~                   ",
  \ ]
  let lines = s:screen_lines2(1, 4, 20)
  " 3) no local formatlist pattern,
  " so use global one -> indent
  let g_flp = &g:flp
  let &g:formatlistpat='^\s*\d\+\.\s\+'
  let &l:formatlistpat=''
  let expect = [
  \ "  1. word word word ",
  \ "     word word word ",
  \ "     word word      ",
  \ "~                   ",
  \ ]
  let lines = s:screen_lines2(1, 4, 20)
  call s:compare_lines(expect, lines)
  let &g:flp = g_flp
  let &l:formatlistpat='^\s*\d\+\.'
  " 4) add something in front, no additional indent
  norm! gg0
  exe ":norm! 5iword \<esc>"
  redraw!
  let expect = [
  \ "word word word word ",
  \ "word   1. word word ",
  \ "word word word word ",
  \ "word word           ",
  \ "~                   ",
  \ ]
  let lines = s:screen_lines2(1, 5, 20)
  call s:compare_lines(expect, lines)
  bwipeout!
endfunc

func Test_breakindent_column()
  call s:test_windows('setl breakindent breakindentopt=column:10')
  redraw!
  " 1) default: does not indent, too wide :(
  let expect = [
  \ "                    ",
  \ "    abcdefghijklmnop",
  \ "qrstuvwxyzABCDEFGHIJ",
  \ "KLMNOP              "
  \ ]
  let lines = s:screen_lines2(1, 4, 20)
  call s:compare_lines(expect, lines)
  " 2) lower min value, so that breakindent works
  setl breakindentopt+=min:5
  redraw!
  let expect = [
  \ "                    ",
  \ "    abcdefghijklmnop",
  \ "          qrstuvwxyz",
  \ "          ABCDEFGHIJ",
  \ "          KLMNOP    "
  \ ]
  let lines = s:screen_lines2(1, 5, 20)
  " 3) set shift option -> no influence
  setl breakindentopt+=shift:5
  redraw!
  let expect = [
  \ "                    ",
  \ "    abcdefghijklmnop",
  \ "          qrstuvwxyz",
  \ "          ABCDEFGHIJ",
  \ "          KLMNOP    "
  \ ]
  let lines = s:screen_lines2(1, 5, 20)
  call s:compare_lines(expect, lines)
  " 4) add showbreak value
  setl showbreak=++
  redraw!
  let expect = [
  \ "                    ",
  \ "    abcdefghijklmnop",
  \ "          ++qrstuvwx",
  \ "          ++yzABCDEF",
  \ "          ++GHIJKLMN",
  \ "          ++OP      "
  \ ]
  let lines = s:screen_lines2(1, 6, 20)
  call s:compare_lines(expect, lines)
  bwipeout!
endfunc

func Test_linebreak_list()
  " This was setting wlv.c_extra to NUL while wlv.p_extra is NULL
  filetype plugin on
  syntax enable
  edit! $VIMRUNTIME/doc/index.txt
  /v_P

  setlocal list
  setlocal listchars=tab:>-
  setlocal linebreak
  setlocal nowrap
  setlocal filetype=help
  redraw!

  bwipe!
endfunc

func Test_breakindent_change_display_uhex()
  call s:test_windows('setl briopt=min:0 list listchars=eol:$')
  redraw!
  let lines = s:screen_lines(line('.'), 20)
  let expect = [
        \ "^Iabcdefghijklmnopqr",
        \ "  stuvwxyzABCDEFGHIJ",
        \ "  KLMNOP$           "
        \ ]
  call s:compare_lines(expect, lines)
  set display+=uhex
  redraw!
  let lines = s:screen_lines(line('.'), 20)
  let expect = [
        \ "<09>abcdefghijklmnop",
        \ "    qrstuvwxyzABCDEF",
        \ "    GHIJKLMNOP$     "
        \ ]
  call s:compare_lines(expect, lines)
  set display&

  call s:close_windows()
endfunc

func Test_breakindent_list_split()
  10new
  61vsplit
  setlocal tabstop=8 breakindent list listchars=tab:<->,eol:$
  put =s:input
  30vsplit
  setlocal listchars=eol:$
  let expect = [
      \ "^IabcdefghijklmnopqrstuvwxyzAB|<------>abcdefghijklmnopqrstuv",
      \ "  CDEFGHIJKLMNOP$             |        wxyzABCDEFGHIJKLMNOP$ ",
      \ "~                             |~                             "
      \ ]
  redraw!
  let lines = s:screen_lines(line('.'), 61)
  call s:compare_lines(expect, lines)
  wincmd p
  redraw!
  let lines = s:screen_lines(line('.'), 61)
  call s:compare_lines(expect, lines)

  bwipe!
endfunc

func Test_breakindent_min_with_signcol()
  call s:test_windows('setl briopt=min:15 signcolumn=yes')
  redraw!
  let expect = [
        \ "      abcdefghijklmn",
        \ "     opqrstuvwxyzABC",
        \ "     DEFGHIJKLMNOP  "
        \ ]
  let lines = s:screen_lines(line('.'), 20)
  call s:compare_lines(expect, lines)
  setl briopt=min:17
  redraw!
  let expect = [
        \ "      abcdefghijklmn",
        \ "   opqrstuvwxyzABCDE",
        \ "   FGHIJKLMNOP      "
        \ ]
  let lines = s:screen_lines(line('.'), 20)
  call s:compare_lines(expect, lines)
  setl briopt=min:19
  redraw!
  let expect = [
        \ "      abcdefghijklmn",
        \ "  opqrstuvwxyzABCDEF",
        \ "  GHIJKLMNOP        "
        \ ]
  let lines = s:screen_lines(line('.'), 20)
  call s:compare_lines(expect, lines)

  call s:close_windows()
endfunc

func Test_breakindent_with_double_width_wrap()
  50vnew
  setlocal tabstop=8 breakindent nolist
  call setline(1, "\t" .. repeat('a', winwidth(0) - 9) .. '口口口')
  normal! $g0
  call assert_equal(2, winline())
  call assert_equal(9, wincol())

  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
