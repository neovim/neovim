" Test for breakindent
"
" Note: if you get strange failures when adding new tests, it might be that
" while the test is run, the breakindent cacheing gets in its way.
" It helps to change the tabstop setting and force a redraw (e.g. see
" Test_breakindent08())
if !exists('+breakindent')
  finish
endif

source view_util.vim

let s:input ="\tabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP"

function s:screen_lines(lnum, width) abort
  return ScreenLines([a:lnum, a:lnum + 2], a:width)
endfunction

function! s:compare_lines(expect, actual)
  call assert_equal(join(a:expect, "\n"), join(a:actual, "\n"))
endfunction

function s:test_windows(...)
  call NewWindow(10, 20)
  setl ts=4 sw=4 sts=4 breakindent
  put =s:input
  exe get(a:000, 0, '')
endfunction

function s:close_windows(...)
  call CloseWindow()
  exe get(a:000, 0, '')
endfunction

function Test_breakindent01()
  " simple breakindent test
  call s:test_windows('setl briopt=min:0')
  let lines=s:screen_lines(line('.'),8)
  let expect=[
\ "    abcd",
\ "    qrst",
\ "    GHIJ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunction

function Test_breakindent02()
  " simple breakindent test with showbreak set
  call s:test_windows('setl briopt=min:0 sbr=>>')
  let lines=s:screen_lines(line('.'),8)
  let expect=[
\ "    abcd",
\ "    >>qr",
\ "    >>EF",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent03()
  " simple breakindent test with showbreak set and briopt including sbr
  call s:test_windows('setl briopt=sbr,min:0 sbr=++')
  let lines=s:screen_lines(line('.'),8)
  let expect=[
\ "    abcd",
\ "++  qrst",
\ "++  GHIJ",
\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent04()
  " breakindent set with min width 18
  call s:test_windows('setl sbr= briopt=min:18')
  let lines=s:screen_lines(line('.'),8)
  let expect=[
\ "    abcd",
\ "  qrstuv",
\ "  IJKLMN",
\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent05()
  " breakindent set and shift by 2
  call s:test_windows('setl briopt=shift:2,min:0')
  let lines=s:screen_lines(line('.'),8)
  let expect=[
\ "    abcd",
\ "      qr",
\ "      EF",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunction

function Test_breakindent06()
  " breakindent set and shift by -1
  call s:test_windows('setl briopt=shift:-1,min:0')
  let lines=s:screen_lines(line('.'),8)
  let expect=[
\ "    abcd",
\ "   qrstu",
\ "   HIJKL",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunction

function Test_breakindent07()
  " breakindent set and shift by 1, Number  set sbr=? and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu sbr=? nuw=4 cpo+=n')
  let lines=s:screen_lines(line('.'),10)
  let expect=[
\ "  2     ab",
\ "?        m",
\ "?        x",
\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr= cpo-=n')
endfunction

function Test_breakindent07a()
  " breakindent set and shift by 1, Number  set sbr=? and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu sbr=? nuw=4')
  let lines=s:screen_lines(line('.'),10)
  let expect=[
\ "  2     ab",
\ "    ?    m",
\ "    ?    x",
\ ]
  call s:compare_lines(expect, lines)
  " clean up
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent08()
  " breakindent set and shift by 1, Number and list set sbr=# and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu nuw=4 sbr=# list cpo+=n ts=4')
  " make sure, cache is invalidated!
  set ts=8
  redraw!
  set ts=4
  redraw!
  let lines=s:screen_lines(line('.'),10)
  let expect=[
\ "  2 ^Iabcd",
\ "#      opq",
\ "#      BCD",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr= cpo-=n')
endfunction

function Test_breakindent08a()
  " breakindent set and shift by 1, Number and list set sbr=# and briopt:sbr
  call s:test_windows('setl briopt=shift:1,sbr,min:0 nu nuw=4 sbr=# list')
  let lines=s:screen_lines(line('.'),10)
  let expect=[
\ "  2 ^Iabcd",
\ "    #  opq",
\ "    #  BCD",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent09()
  " breakindent set and shift by 1, Number and list set sbr=#
  call s:test_windows('setl briopt=shift:1,min:0 nu nuw=4 sbr=# list')
  let lines=s:screen_lines(line('.'),10)
  let expect=[
\ "  2 ^Iabcd",
\ "       #op",
\ "       #AB",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent10()
  " breakindent set, Number set sbr=~
  call s:test_windows('setl cpo+=n sbr=~ nu nuw=4 nolist briopt=sbr,min:0')
  " make sure, cache is invalidated!
  set ts=8
  redraw!
  set ts=4
  redraw!
  let lines=s:screen_lines(line('.'),10)
  let expect=[
\ "  2     ab",
\ "~       mn",
\ "~       yz",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set sbr= cpo-=n')
endfunction

function Test_breakindent11()
  " test strdisplaywidth()
  call s:test_windows('setl cpo-=n sbr=>> nu nuw=4 nolist briopt= ts=4')
  let text=getline(2)
  let width = strlen(text[1:])+indent(2)+strlen(&sbr)*3 " text wraps 3 times
  call assert_equal(width, strdisplaywidth(text))
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent12()
  " test breakindent with long indent
  let s:input="\t\t\t\t\t{"
  call s:test_windows('setl breakindent linebreak briopt=min:10 nu numberwidth=3 ts=4 list listchars=tab:>-')
  let lines=s:screen_lines(2,16)
  let expect=[
\ " 2 >--->--->--->",
\ "          ---{  ",
\ "~               ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('set nuw=4 listchars=')
endfunction

function Test_breakindent13()
  let s:input=""
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
endfunction

function Test_breakindent14()
  let s:input=""
  call s:test_windows('setl breakindent briopt= ts=8')
  vert resize 30
  norm! 3a1234567890
  norm! a    abcde
  exec "norm! 0\<C-V>tex"
  let lines=s:screen_lines(line('.'),8)
  let expect=[
\ "e       ",
\ "~       ",
\ "~       ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunction

function Test_breakindent15()
  let s:input=""
  call s:test_windows('setl breakindent briopt= ts=8 sw=8')
  vert resize 30
  norm! 4a1234567890
  exe "normal! >>\<C-V>3f0x"
  let lines=s:screen_lines(line('.'),20)
  let expect=[
\ "        1234567890  ",
\ "~                   ",
\ "~                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunction

function Test_breakindent16()
  " Check that overlong lines are indented correctly.
  let s:input=""
  call s:test_windows('setl breakindent briopt=min:0 ts=4')
  call setline(1, "\t".repeat("1234567890", 10))
  resize 6
  norm! 1gg$
  redraw!
  let lines=s:screen_lines(1,10)
  let expect=[
\ "    789012",
\ "    345678",
\ "    901234",
\ ]
  call s:compare_lines(expect, lines)
  let lines=s:screen_lines(4,10)
  let expect=[
\ "    567890",
\ "    123456",
\ "    7890  ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunction
