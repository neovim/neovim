" Test for breakindent
"
" Note: if you get strange failures when adding new tests, it might be that
" while the test is run, the breakindent cacheing gets in its way.
" It helps to change the tabastop setting and force a redraw (e.g. see
" Test_breakindent08())
if !exists('+breakindent')
  finish
endif

let s:input ="\tabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP"

function s:screenline(lnum, width) abort
  " always get 4 screen lines
  redraw!
  let line = []
  for j in range(3)
    for c in range(1, a:width)
  call add(line, nr2char(screenchar(a:lnum+j, c)))
    endfor
    call add(line, "\n")
  endfor
  return join(line, '')
endfunction

function s:testwindows(...)
  10new
  vsp
  vert resize 20
  setl ts=4 sw=4 sts=4 breakindent 
  put =s:input
  if a:0
    exe a:1
  endif
endfunction

function s:close_windows(...)
  bw!
  if a:0
    exe a:1
  endif
  unlet! g:line g:expect
endfunction

function Test_breakindent01()
  " simple breakindent test
  call s:testwindows('setl briopt=min:0')
  let g:line=s:screenline(line('.'),8)
  let g:expect="    abcd\n    qrst\n    GHIJ\n"
  call assert_equal(g:expect, g:line)
  call s:close_windows()
endfunction

function Test_breakindent02()
  " simple breakindent test with showbreak set
  call s:testwindows('setl briopt=min:0 sbr=>>')
  let g:line=s:screenline(line('.'),8)
  let g:expect="    abcd\n    >>qr\n    >>EF\n"
  call assert_equal(g:expect, g:line)
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent03()
  " simple breakindent test with showbreak set and briopt including sbr
  call s:testwindows('setl briopt=sbr,min:0 sbr=++')
  let g:line=s:screenline(line('.'),8)
  let g:expect="    abcd\n++  qrst\n++  GHIJ\n"
  call assert_equal(g:expect, g:line)
  " clean up
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent04()
  " breakindent set with min width 18
  call s:testwindows('setl sbr= briopt=min:18')
  let g:line=s:screenline(line('.'),8)
  let g:expect="    abcd\n  qrstuv\n  IJKLMN\n"
  call assert_equal(g:expect, g:line)
  " clean up
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent05()
  " breakindent set and shift by 2
  call s:testwindows('setl briopt=shift:2,min:0')
  let g:line=s:screenline(line('.'),8)
  let g:expect="    abcd\n      qr\n      EF\n"
  call assert_equal(g:expect, g:line)
  call s:close_windows()
endfunction

function Test_breakindent06()
  " breakindent set and shift by -1
  call s:testwindows('setl briopt=shift:-1,min:0')
  let g:line=s:screenline(line('.'),8)
  let g:expect="    abcd\n   qrstu\n   HIJKL\n"
  call assert_equal(g:expect, g:line)
  call s:close_windows()
endfunction

function Test_breakindent07()
  " breakindent set and shift by 1, Number  set sbr=? and briopt:sbr
  call s:testwindows('setl briopt=shift:1,sbr,min:0 nu sbr=? nuw=4 cpo+=n')
  let g:line=s:screenline(line('.'),10)
  let g:expect="  2     ab\n?        m\n?        x\n"
  call assert_equal(g:expect, g:line)
  " clean up
  call s:close_windows('set sbr= cpo-=n')
endfunction

function Test_breakindent07a()
  " breakindent set and shift by 1, Number  set sbr=? and briopt:sbr
  call s:testwindows('setl briopt=shift:1,sbr,min:0 nu sbr=? nuw=4')
  let g:line=s:screenline(line('.'),10)
  let g:expect="  2     ab\n    ?    m\n    ?    x\n"
  call assert_equal(g:expect, g:line)
  " clean up
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent08()
  " breakindent set and shift by 1, Number and list set sbr=# and briopt:sbr
  call s:testwindows('setl briopt=shift:1,sbr,min:0 nu nuw=4 sbr=# list cpo+=n ts=4')
  " make sure, cache is invalidated!
  set ts=8
  redraw!
  set ts=4
  redraw!
  let g:line=s:screenline(line('.'),10)
  let g:expect="  2 ^Iabcd\n#      opq\n#      BCD\n"
  call assert_equal(g:expect, g:line)
  call s:close_windows('set sbr= cpo-=n')
endfunction

function Test_breakindent08a()
  " breakindent set and shift by 1, Number and list set sbr=# and briopt:sbr
  call s:testwindows('setl briopt=shift:1,sbr,min:0 nu nuw=4 sbr=# list')
  let g:line=s:screenline(line('.'),10)
  let g:expect="  2 ^Iabcd\n    #  opq\n    #  BCD\n"
  call assert_equal(g:expect, g:line)
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent09()
  " breakindent set and shift by 1, Number and list set sbr=#
  call s:testwindows('setl briopt=shift:1,min:0 nu nuw=4 sbr=# list')
  let g:line=s:screenline(line('.'),10)
  let g:expect="  2 ^Iabcd\n       #op\n       #AB\n"
  call assert_equal(g:expect, g:line)
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent10()
  " breakindent set, Number set sbr=~
  call s:testwindows('setl cpo+=n sbr=~ nu nuw=4 nolist briopt=sbr,min:0')
  " make sure, cache is invalidated!
  set ts=8
  redraw!
  set ts=4
  redraw!
  let g:line=s:screenline(line('.'),10)
  let g:expect="  2     ab\n~       mn\n~       yz\n"
  call assert_equal(g:expect, g:line)
  call s:close_windows('set sbr= cpo-=n')
endfunction

function Test_breakindent11()
  " test strdisplaywidth()
  call s:testwindows('setl cpo-=n sbr=>> nu nuw=4 nolist briopt= ts=4')
  let text=getline(2)
  let width = strlen(text[1:])+indent(2)+strlen(&sbr)*3 " text wraps 3 times
  call assert_equal(width, strdisplaywidth(text))
  call s:close_windows('set sbr=')
endfunction

function Test_breakindent12()
  " test breakindent with long indent
  let s:input="\t\t\t\t\t{"
  call s:testwindows('setl breakindent linebreak briopt=min:10 nu numberwidth=3 ts=4 list listchars=tab:>-')
  let g:line=s:screenline(2,16)
  let g:expect=" 2 >--->--->--->\n          ---{  \n~               \n"
  call assert_equal(g:expect, g:line)
  call s:close_windows('set nuw=4 listchars=')
endfunction

function Test_breakindent13()
  let s:input=""
  call s:testwindows('setl breakindent briopt=min:10 ts=8')
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
  call s:testwindows('setl breakindent briopt= ts=8')
  vert resize 30
  norm! 3a1234567890
  norm! a    abcde
  exec "norm! 0\<C-V>tex"
  let g:line=s:screenline(line('.'),8)
  let g:expect="e       \n~       \n~       \n"
  call assert_equal(g:expect, g:line)
  call s:close_windows()
endfunction

function Test_breakindent15()
  let s:input=""
  call s:testwindows('setl breakindent briopt= ts=8 sw=8')
  vert resize 30
  norm! 4a1234567890
  exe "normal! >>\<C-V>3f0x"
  let g:line=s:screenline(line('.'),20)
  let g:expect="        1234567890  \n~                   \n~                   \n"
  call assert_equal(g:expect, g:line)
  call s:close_windows()
endfunction

function Test_breakindent16()
  " Check that overlong lines are indented correctly.
  " TODO: currently it does not fail even when the bug is not fixed.
  let s:input=""
  call s:testwindows('setl breakindent briopt=min:0 ts=4')
  call setline(1, "\t".repeat("1234567890", 10))
  resize 6
  norm! 1gg$
  redraw!
  let g:line=s:screenline(1,10)
  let g:expect="    123456\n    789012\n    345678\n"
  call assert_equal(g:expect, g:line)
  let g:line=s:screenline(4,10)
  let g:expect="    901234\n    567890\n    123456\n"
  call assert_equal(g:expect, g:line)
  call s:close_windows()
endfunction
