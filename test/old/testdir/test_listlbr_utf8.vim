" Test for linebreak and list option in utf-8 mode

set encoding=utf-8
scriptencoding utf-8

source check.vim
CheckOption linebreak
CheckFeature conceal
CheckFeature signs

source view_util.vim
source screendump.vim

func s:screen_lines(lnum, width) abort
  return ScreenLines(a:lnum, a:width)
endfunc

func s:compare_lines(expect, actual)
  call assert_equal(a:expect, a:actual)
endfunc

func s:screen_attr(lnum, chars, ...) abort
  let line = getline(a:lnum)
  let attr = []
  let prefix = get(a:000, 0, 0)
  for i in range(a:chars[0], a:chars[1])
    let scol = strdisplaywidth(strcharpart(line, 0, i-1)) + 1
    let attr += [screenattr(a:lnum, scol + prefix)]
  endfor
  return attr
endfunc

func s:test_windows(...)
  call NewWindow(10, 20)
  setl ts=4 sw=4 sts=4 linebreak sbr=+ wrap
  exe get(a:000, 0, '')
endfunc

func s:close_windows(...)
  call CloseWindow()
  exe get(a:000, 0, '')
endfunc

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

" this was causing a crash
func Test_linebreak_with_list_and_tabs()
  set linebreak list listchars=tab:⇤\ ⇥ tabstop=100
  new
  call setline(1, "\t\t\ttext")
  redraw
  bwipe!
  set nolinebreak nolist listchars&vim tabstop=8
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

func Test_colorcolumn_priority()
  call s:test_windows('setl cc=4 cuc hls')
  call setline(1, ["xxyy", ""])
  norm! gg
  exe "normal! /xxyy\<CR>"
  norm! G
  redraw!
  let line_attr = s:screen_attr(1, [1, &cc])
  " Search wins over CursorColumn
  call assert_equal(line_attr[1], line_attr[0])
  " Search wins over Colorcolumn
  call assert_equal(line_attr[2], line_attr[3])
  call s:close_windows('setl hls&vim')
endfunc

func Test_illegal_byte_and_breakat()
  call s:test_windows("setl sbr= brk+=<")
  vert resize 18
  call setline(1, repeat("\x80", 6))
  redraw!
  let lines = s:screen_lines([1, 2], winwidth(0))
  let expect = [
\ "<80><80><80><80><8",
\ "0><80>            ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('setl brk&vim')
endfunc

func Test_multibyte_wrap_and_breakat()
  call s:test_windows("setl sbr= brk+=>")
  call setline(1, repeat('a', 17) . repeat('あ', 2))
  redraw!
  let lines = s:screen_lines([1, 2], winwidth(0))
  let expect = [
\ "aaaaaaaaaaaaaaaaaあ>",
\ "あ                  ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows('setl brk&vim')
endfunc

func Test_chinese_char_on_wrap_column()
  call s:test_windows("setl nolbr wrap sbr=")
  call setline(1, [
\ 'aaaaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaaaaa中'.
\ 'hello'])
  call cursor(1,1)
  norm! $
  redraw!
  let expect=[
\ '<<<aaaaaaaaaaaaaaaa>',
\ '中aaaaaaaaaaaaaaaaa>',
\ '中aaaaaaaaaaaaaaaaa>',
\ '中aaaaaaaaaaaaaaaaa>',
\ '中aaaaaaaaaaaaaaaaa>',
\ '中aaaaaaaaaaaaaaaaa>',
\ '中aaaaaaaaaaaaaaaaa>',
\ '中aaaaaaaaaaaaaaaaa>',
\ '中aaaaaaaaaaaaaaaaa>',
\ '中hello             ']
  let lines = s:screen_lines([1, 10], winwidth(0))
  call s:compare_lines(expect, lines)
  call assert_equal(len(expect), winline())
  call assert_equal(strwidth(trim(expect[-1], ' ', 2)), wincol())
  norm! g0
  call assert_equal(len(expect), winline())
  call assert_equal(1, wincol())
  call s:close_windows()
endfunc

func Test_chinese_char_on_wrap_column_sbr()
  call s:test_windows("setl nolbr wrap sbr=!!!")
  call setline(1, [
\ 'aaaaaaaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaa中'.
\ 'aaaaaaaaaaaaaa中'.
\ 'hello'])
  call cursor(1,1)
  norm! $
  redraw!
  let expect=[
\ '!!!中aaaaaaaaaaaaaa>',
\ '!!!中aaaaaaaaaaaaaa>',
\ '!!!中aaaaaaaaaaaaaa>',
\ '!!!中aaaaaaaaaaaaaa>',
\ '!!!中aaaaaaaaaaaaaa>',
\ '!!!中aaaaaaaaaaaaaa>',
\ '!!!中aaaaaaaaaaaaaa>',
\ '!!!中aaaaaaaaaaaaaa>',
\ '!!!中aaaaaaaaaaaaaa>',
\ '!!!中hello          ']
  let lines = s:screen_lines([1, 10], winwidth(0))
  call s:compare_lines(expect, lines)
  call assert_equal(len(expect), winline())
  call assert_equal(strwidth(trim(expect[-1], ' ', 2)), wincol())
  norm! g0
  call assert_equal(len(expect), winline())
  call assert_equal(4, wincol())
  call s:close_windows()
endfunc

func Test_unprintable_char_on_wrap_column()
  call s:test_windows("setl nolbr wrap sbr=")
  call setline(1, 'aaa' .. repeat("\uFEFF", 50) .. 'bbb')
  call cursor(1,1)
  norm! $
  redraw!
  let expect=[
\ '<<<<feff><feff><feff',
\ '><feff><feff><feff><',
\ 'feff><feff><feff><fe',
\ 'ff><feff><feff><feff',
\ '><feff><feff><feff><',
\ 'feff><feff><feff><fe',
\ 'ff><feff><feff><feff',
\ '><feff><feff><feff><',
\ 'feff><feff><feff><fe',
\ 'ff>bbb              ']
  let lines = s:screen_lines([1, 10], winwidth(0))
  call s:compare_lines(expect, lines)
  call assert_equal(len(expect), winline())
  call assert_equal(strwidth(trim(expect[-1], ' ', 2)), wincol())
  setl sbr=!!
  redraw!
  let expect=[
\ '!!><feff><feff><feff',
\ '!!><feff><feff><feff',
\ '!!><feff><feff><feff',
\ '!!><feff><feff><feff',
\ '!!><feff><feff><feff',
\ '!!><feff><feff><feff',
\ '!!><feff><feff><feff',
\ '!!><feff><feff><feff',
\ '!!><feff><feff><feff',
\ '!!><feff><feff>bbb  ']
  let lines = s:screen_lines([1, 10], winwidth(0))
  call s:compare_lines(expect, lines)
  call assert_equal(len(expect), winline())
  call assert_equal(strwidth(trim(expect[-1], ' ', 2)), wincol())
  call s:close_windows()
endfunc

" Test that Visual selection is drawn correctly when 'linebreak' is set and
" selection ends before multibyte 'showbreak'.
func Test_visual_ends_before_showbreak()
  CheckScreendump

  let lines =<< trim END
      vim9script
      &wrap = true
      &linebreak = true
      &showbreak = '↪ '
      ['xxxxx ' .. 'y'->repeat(&columns - 6) .. ' zzzz']->setline(1)
      normal! wvel
  END
  call writefile(lines, 'XvisualEndsBeforeShowbreak', 'D')
  let buf = RunVimInTerminal('-S XvisualEndsBeforeShowbreak', #{rows: 6})
  call VerifyScreenDump(buf, 'Test_visual_ends_before_showbreak', {})

  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
