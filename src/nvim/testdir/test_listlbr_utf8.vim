" Test for linebreak and list option in utf-8 mode

set encoding=utf-8
scriptencoding utf-8

if !exists("+linebreak") || !has("conceal") || !has("signs")
  finish
endif

source view_util.vim

function s:screen_lines(lnum, width) abort
  return ScreenLines(a:lnum, a:width)
endfunction

function! s:compare_lines(expect, actual)
  call assert_equal(a:expect, a:actual)
endfunction

function s:screen_attr(lnum, chars, ...) abort
  let line = getline(a:lnum)
  let attr = []
  let prefix = get(a:000, 0, 0)
  for i in range(a:chars[0], a:chars[1])
    let scol = strdisplaywidth(strcharpart(line, 0, i-1)) + 1
    let attr += [screenattr(a:lnum, scol + prefix)]
  endfor
  return attr
endfunction

function s:test_windows(...)
  call NewWindow(10, 20)
  setl ts=4 sw=4 sts=4 linebreak sbr=+ wrap
  exe get(a:000, 0, '')
endfunction

function s:close_windows(...)
  call CloseWindow()
  exe get(a:000, 0, '')
endfunction

func Test_linebreak_with_fancy_listchars()
  call s:test_windows("setl list listchars=nbsp:\u2423,tab:\u2595\u2014,trail:\u02d1,eol:\ub6")
  call setline(1, "\tabcdef hijklmn\tpqrstuvwxyz\u00a01060ABCDEFGHIJKLMNOP ")
  redraw!
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "▕———abcdef          ",
\ "+hijklmn▕———        ",
\ "+pqrstuvwxyz␣1060ABC",
\ "+DEFGHIJKLMNOPˑ¶    ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_nolinebreak_with_list()
  call s:test_windows("setl nolinebreak list listchars=nbsp:\u2423,tab:\u2595\u2014,trail:\u02d1,eol:\ub6")
  call setline(1, "\tabcdef hijklmn\tpqrstuvwxyz\u00a01060ABCDEFGHIJKLMNOP ")
  redraw!
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "▕———abcdef hijklmn▕—",
\ "+pqrstuvwxyz␣1060ABC",
\ "+DEFGHIJKLMNOPˑ¶    ",
\ "~                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_linebreak_with_nolist()
  call s:test_windows('setl nolist')
  call setline(1, "\t*mask = nil;")
  redraw!
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "    *mask = nil;    ",
\ "~                   ",
\ "~                   ",
\ "~                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_list_and_concealing1()
  call s:test_windows('setl list listchars=tab:>- cole=1')
  call setline(1, [
\ "#define ABCDE\t\t1",
\ "#define ABCDEF\t\t1",
\ "#define ABCDEFG\t\t1",
\ "#define ABCDEFGH\t1",
\ "#define MSG_MODE_FILE\t\t\t1",
\ "#define MSG_MODE_CONSOLE\t\t2",
\ "#define MSG_MODE_FILE_AND_CONSOLE\t3",
\ "#define MSG_MODE_FILE_THEN_CONSOLE\t4",
\ ])
  vert resize 40
  syn match Conceal conceal cchar=>'AB\|MSG_MODE'
  redraw!
  let lines = s:screen_lines([1, 7], winwidth(0))
  let expect = [
\ "#define ABCDE>-->---1                   ",
\ "#define >CDEF>-->---1                   ",
\ "#define >CDEFG>->---1                   ",
\ "#define >CDEFGH>----1                   ",
\ "#define >_FILE>--------->--->---1       ",
\ "#define >_CONSOLE>---------->---2       ",
\ "#define >_FILE_AND_CONSOLE>---------3   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_list_and_concealing2()
  call s:test_windows('setl nowrap ts=2 list listchars=tab:>- cole=2 concealcursor=n')
  call setline(1, "bbeeeeee\t\t;\tsome text")
  vert resize 40
  syn clear
  syn match meaning    /;\s*\zs.*/
  syn match hasword    /^\x\{8}/    contains=word
  syn match word       /\<\x\{8}\>/ contains=beginword,endword contained
  syn match beginword  /\<\x\x/     contained conceal
  syn match endword    /\x\{6}\>/   contained
  hi meaning   guibg=blue
  hi beginword guibg=green
  hi endword   guibg=red
  redraw!
  let lines = s:screen_lines([1, 1], winwidth(0))
  let expect = [
\ "eeeeee>--->-;>some text                 ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_screenattr_for_comment()
  call s:test_windows("setl ft=c ts=7 list listchars=nbsp:\u2423,tab:\u2595\u2014,trail:\u02d1,eol:\ub6")
  call setline(1, " /*\t\t and some more */")
  norm! gg0
  syntax on
  hi SpecialKey term=underline ctermfg=red guifg=red
  redraw!
  let line = getline(1)
  let attr = s:screen_attr(1, [1, 6])
  call assert_notequal(attr[0], attr[1])
  call assert_notequal(attr[1], attr[3])
  call assert_notequal(attr[3], attr[5])
  call s:close_windows()
endfunc

func Test_visual_block_and_selection_exclusive()
  call s:test_windows('setl selection=exclusive')
  call setline(1, "long line: " . repeat("foobar ", 40) . "TARGETÃ' at end")
  exe "norm! $3B\<C-v>eAx\<Esc>"
  let lines = s:screen_lines([1, 10], winwidth(0))
  let expect = [
\ "+foobar foobar      ",
\ "+foobar foobar      ",
\ "+foobar foobar      ",
\ "+foobar foobar      ",
\ "+foobar foobar      ",
\ "+foobar foobar      ",
\ "+foobar foobar      ",
\ "+foobar foobar      ",
\ "+foobar foobar      ",
\ "+foobar TARGETÃx'   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_multibyte_sign_and_colorcolumn()
  call s:test_windows("setl nolinebreak cc=3 list listchars=nbsp:\u2423,tab:\u2595\u2014,trail:\u02d1,eol:\ub6")
  call setline(1, ["", "a b c", "a b c"])
  exe "sign define foo text=\uff0b"
  exe "sign place 1 name=foo line=2 buffer=" . bufnr('%')
  redraw!
  norm! ggj0
  let signwidth = strdisplaywidth("\uff0b")
  let attr1 = s:screen_attr(2, [1, 3], signwidth)
  let attr2 = s:screen_attr(3, [1, 3], signwidth)
  call assert_equal(attr1[0], attr2[0])
  call assert_equal(attr1[1], attr2[1])
  call assert_equal(attr1[2], attr2[2])
  let lines = s:screen_lines([1, 3], winwidth(0))
  let expect = [
\ "  ¶                 ",
\ "＋a b c¶            ",
\ "  a b c¶            ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc
