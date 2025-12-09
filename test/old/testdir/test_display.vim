" Test for displaying stuff

" Nvim: `:set term` is not supported.
" if !has('gui_running') && has('unix')
"   set term=ansi
" endif

source view_util.vim
source check.vim
source screendump.vim

func Test_display_foldcolumn()
  CheckFeature folding

  new
  vnew
  vert resize 25
  call assert_equal(25, winwidth(winnr()))
  set isprint=@

  1put='e more noise blah blah more stuff here'

  let expect = [
        \ "e more noise blah blah<82",
        \ "> more stuff here        "
        \ ]

  call cursor(2, 1)
  norm! zt
  let lines = ScreenLines([1,2], winwidth(0))
  call assert_equal(expect, lines)
  set fdc=2
  let lines = ScreenLines([1,2], winwidth(0))
  let expect = [
        \ "  e more noise blah blah<",
        \ "  82> more stuff here    "
        \ ]
  call assert_equal(expect, lines)

  quit!
  quit!
endfunc

func Test_display_foldtext_mbyte()
  CheckFeature folding

  call NewWindow(10, 40)
  call append(0, range(1,20))
  exe "set foldmethod=manual foldtext=foldtext() fillchars=fold:\u2500,vert:\u2502 fdc=2"
  call cursor(2, 1)
  norm! zf13G
  let lines=ScreenLines([1,3], winwidth(0)+1)
  let expect=[
        \ "  1                                     \u2502",
        \ "+ +-- 12 lines: 2". repeat("\u2500", 23). "\u2502",
        \ "  14                                    \u2502",
        \ ]
  call assert_equal(expect, lines)

  set fillchars=fold:-,vert:\|
  let lines=ScreenLines([1,3], winwidth(0)+1)
  let expect=[
        \ "  1                                     |",
        \ "+ +-- 12 lines: 2". repeat("-", 23). "|",
        \ "  14                                    |",
        \ ]
  call assert_equal(expect, lines)

  set foldtext& fillchars& foldmethod& fdc&
  bw!
endfunc

" check that win_ins_lines() and win_del_lines() work when t_cs is empty.
func Test_scroll_without_region()
  CheckScreendump

  let lines =<< trim END
    call setline(1, range(1, 20))
    set t_cs=
    set laststatus=2
  END
  call writefile(lines, 'Xtestscroll', 'D')
  let buf = RunVimInTerminal('-S Xtestscroll', #{rows: 10})

  call VerifyScreenDump(buf, 'Test_scroll_no_region_1', {})

  call term_sendkeys(buf, ":3delete\<cr>")
  call VerifyScreenDump(buf, 'Test_scroll_no_region_2', {})

  call term_sendkeys(buf, ":4put\<cr>")
  call VerifyScreenDump(buf, 'Test_scroll_no_region_3', {})

  call term_sendkeys(buf, ":undo\<cr>")
  call term_sendkeys(buf, ":undo\<cr>")
  call term_sendkeys(buf, ":set laststatus=0\<cr>")
  call VerifyScreenDump(buf, 'Test_scroll_no_region_4', {})

  call term_sendkeys(buf, ":3delete\<cr>")
  call VerifyScreenDump(buf, 'Test_scroll_no_region_5', {})

  call term_sendkeys(buf, ":4put\<cr>")
  call VerifyScreenDump(buf, 'Test_scroll_no_region_6', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_display_listchars_precedes()
  call NewWindow(10, 10)
  " Need a physical line that wraps over the complete
  " window size
  call append(0, repeat('aaa aaa aa ', 10))
  call append(1, repeat(['bbb bbb bbb bbb'], 2))
  " remove blank trailing line
  $d
  set list nowrap
  call cursor(1, 1)
  " move to end of line and scroll 2 characters back
  norm! $2zh
  let lines=ScreenLines([1,4], winwidth(0)+1)
  let expect = [
        \ " aaa aa $ |",
        \ "$         |",
        \ "$         |",
        \ "~         |",
        \ ]
  call assert_equal(expect, lines)
  set list listchars+=precedes:< nowrap
  call cursor(1, 1)
  " move to end of line and scroll 2 characters back
  norm! $2zh
  let lines = ScreenLines([1,4], winwidth(0)+1)
  let expect = [
        \ "<aaa aa $ |",
        \ "<         |",
        \ "<         |",
        \ "~         |",
        \ ]
  call assert_equal(expect, lines)
  set wrap
  call cursor(1, 1)
  " the complete line should be displayed in the window
  norm! $

  let lines = ScreenLines([1,10], winwidth(0)+1)
  let expect = [
        \ "<aaa aaa a|",
        \ "a aaa aaa |",
        \ "aa aaa aaa|",
        \ " aa aaa aa|",
        \ "a aa aaa a|",
        \ "aa aa aaa |",
        \ "aaa aa aaa|",
        \ " aaa aa aa|",
        \ "a aaa aa a|",
        \ "aa aaa aa |",
        \ ]
  call assert_equal(expect, lines)
  set list& listchars& wrap&
  bw!
endfunc

" Check that win_lines() works correctly with the number_only parameter=TRUE
" should break early to optimize cost of drawing, but needs to make sure
" that the number column is correctly highlighted.
func Test_scroll_CursorLineNr_update()
  CheckScreendump

  let lines =<< trim END
    hi CursorLineNr ctermfg=73 ctermbg=236
    set nu rnu cursorline cursorlineopt=number
    exe ":norm! o\<esc>110ia\<esc>"
  END
  let filename = 'Xdrawscreen'
  call writefile(lines, filename, 'D')
  let buf = RunVimInTerminal('-S '.filename, #{rows: 5, cols: 50})
  call term_sendkeys(buf, "k")
  call VerifyScreenDump(buf, 'Test_winline_rnu', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

" check a long file name does not result in the hit-enter prompt
func Test_edit_long_file_name()
  CheckScreendump

  let longName = 'x'->repeat(min([&columns, 255]))
  call writefile([], longName, 'D')
  let buf = RunVimInTerminal('-N -u NONE --cmd ":set noshowcmd noruler" ' .. longName, #{rows: 8})

  call VerifyScreenDump(buf, 'Test_long_file_name_1', {})

  call term_sendkeys(buf, ":set showcmd\<cr>:e!\<cr>")
  call VerifyScreenDump(buf, 'Test_long_file_name_2', {})

  " clean up
  call StopVimInTerminal(buf)
  set ruler&vim
endfunc

func Test_edit_long_file_name_with_ruler()
  CheckScreendump

  let longName = 'x'->repeat(min([&columns, 255]))
  call writefile([], longName, 'D')
  let buf = RunVimInTerminal('-N -u NONE --cmd ":set noshowcmd" ' .. longName, #{rows: 8})

  call VerifyScreenDump(buf, 'Test_long_file_name_3', {})

  call term_sendkeys(buf, ":set showcmd\<cr>:e!\<cr>")
  call VerifyScreenDump(buf, 'Test_long_file_name_4', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_unprintable_fileformats()
  CheckScreendump

  call writefile(["unix\r", "two"], 'Xunix.txt', 'D')
  call writefile(["mac\r", "two"], 'Xmac.txt', 'D')
  let lines =<< trim END
    edit Xunix.txt
    split Xmac.txt
    edit ++ff=mac
  END
  let filename = 'Xunprintable'
  call writefile(lines, filename, 'D')
  let buf = RunVimInTerminal('-S '.filename, #{rows: 9, cols: 50})
  call VerifyScreenDump(buf, 'Test_display_unprintable_01', {})
  call term_sendkeys(buf, "\<C-W>\<C-W>\<C-L>")
  call VerifyScreenDump(buf, 'Test_display_unprintable_02', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_display_scroll_at_topline()
  CheckScreendump

  let buf = RunVimInTerminal('', #{cols: 20})
  call term_sendkeys(buf, ":call setline(1, repeat('a', 21))\<CR>")
  call term_wait(buf)
  call term_sendkeys(buf, "O\<Esc>")
  call VerifyScreenDump(buf, 'Test_display_scroll_at_topline', #{rows: 4})

  call StopVimInTerminal(buf)
endfunc

func Test_display_scroll_update_visual()
  CheckScreendump

  let lines =<< trim END
      set scrolloff=0
      call setline(1, repeat(['foo'], 10))
      call sign_define('foo', { 'text': '>' })
      call sign_place(1, 'bar', 'foo', bufnr(), { 'lnum': 2 })
      call sign_place(2, 'bar', 'foo', bufnr(), { 'lnum': 1 })
      autocmd CursorMoved * if getcurpos()[1] == 2 | call sign_unplace('bar', { 'id': 1 }) | endif
  END
  call writefile(lines, 'XupdateVisual.vim', 'D')

  let buf = RunVimInTerminal('-S XupdateVisual.vim', #{rows: 8, cols: 60})
  call term_sendkeys(buf, "VG7kk")
  call VerifyScreenDump(buf, 'Test_display_scroll_update_visual', {})

  call StopVimInTerminal(buf)
endfunc

func Test_display_scroll_setline()
  CheckScreendump

  let lines =<< trim END
    setlocal scrolloff=5 signcolumn=yes
    call setline(1, range(1, 100))
    call sign_define('foo', #{text: '>'})
    call sign_place(1, 'bar', 'foo', bufnr(), #{lnum: 71})
    call sign_place(2, 'bar', 'foo', bufnr(), #{lnum: 72})
    call sign_place(3, 'bar', 'foo', bufnr(), #{lnum: 73})
    call sign_place(4, 'bar', 'foo', bufnr(), #{lnum: 74})
    call sign_place(5, 'bar', 'foo', bufnr(), #{lnum: 75})
    normal! G
    autocmd CursorMoved * if line('.') == 79
                      \ |   call sign_unplace('bar', #{id: 4})
                      \ |   call setline(80, repeat('foo', 15))
                      \ | elseif line('.') == 78
                      \ |   call setline(72, repeat('bar', 10))
                      \ | elseif line('.') == 77
                      \ |   call sign_unplace('bar', #{id: 2})
                      \ | endif
  END
  call writefile(lines, 'XscrollSetline.vim', 'D')

  let buf = RunVimInTerminal('-S XscrollSetline.vim', #{rows: 15, cols: 20})
  call VerifyScreenDump(buf, 'Test_display_scroll_setline_1', {})
  call term_sendkeys(buf, '19k')
  call VerifyScreenDump(buf, 'Test_display_scroll_setline_2', {})
  call term_sendkeys(buf, 'k')
  call VerifyScreenDump(buf, 'Test_display_scroll_setline_3', {})
  call term_sendkeys(buf, 'k')
  call VerifyScreenDump(buf, 'Test_display_scroll_setline_4', {})
  call term_sendkeys(buf, 'k')
  call VerifyScreenDump(buf, 'Test_display_scroll_setline_5', {})
  call term_sendkeys(buf, 'k')
  call VerifyScreenDump(buf, 'Test_display_scroll_setline_6', {})

  call StopVimInTerminal(buf)
endfunc

func Test_display_hit_enter_setline()
  CheckScreendump

  let lines =<< trim END
    call setline(1, range(1, 100))
  END
  call writefile(lines, 'XhitEnterSetline.vim', 'D')

  let buf = RunVimInTerminal('-S XhitEnterSetline.vim', #{rows: 8, cols: 40})
  call VerifyScreenDump(buf, 'Test_display_hit_enter_setline_1', {})
  call term_sendkeys(buf, ':echo "abc\ndef\nghi"')
  call term_sendkeys(buf, "\<CR>")
  call VerifyScreenDump(buf, 'Test_display_hit_enter_setline_2', {})
  call term_sendkeys(buf, ":call setline(2, repeat('foo', 35))\<CR>")
  call VerifyScreenDump(buf, 'Test_display_hit_enter_setline_3', {})

  call StopVimInTerminal(buf)
endfunc

" Test for 'eob' (EndOfBuffer) item in 'fillchars'
func Test_eob_fillchars()
  " default value
  " call assert_match('eob:\~', &fillchars)
  " invalid values
  call assert_fails(':set fillchars=eob:', 'E1511:')
  call assert_fails(':set fillchars=eob:xy', 'E1511:')
  call assert_fails(':set fillchars=eob:\255', 'E1511:')
  call assert_fails(':set fillchars=eob:<ff>', 'E1511:')
  call assert_fails(":set fillchars=eob:\x01", 'E1512:')
  call assert_fails(':set fillchars=eob:\\x01', 'E1512:')
  " default is ~
  new
  redraw
  call assert_equal('~', Screenline(2))
  set fillchars=eob:+
  redraw
  call assert_equal('+', Screenline(2))
  set fillchars=eob:\ 
  redraw
  call assert_equal(' ', nr2char(screenchar(2, 1)))
  set fillchars&
  close
endfunc

" Test for 'foldopen', 'foldclose' and 'foldsep' in 'fillchars'
func Test_fold_fillchars()
  new
  set fdc=2 foldenable foldmethod=manual
  call setline(1, ['one', 'two', 'three', 'four', 'five'])
  2,4fold
  " First check for the default setting for a closed fold
  let lines = ScreenLines([1, 3], 8)
  let expected = [
        \ '  one   ',
        \ '+ +--  3',
        \ '  five  '
        \ ]
  call assert_equal(expected, lines)
  normal 2Gzo
  " check the characters for an open fold
  let lines = ScreenLines([1, 5], 8)
  let expected = [
        \ '  one   ',
        \ '- two   ',
        \ '| three ',
        \ '| four  ',
        \ '  five  '
        \ ]
  call assert_equal(expected, lines)

  " change the setting
  set fillchars=vert:\|,fold:-,eob:~,foldopen:[,foldclose:],foldsep:-

  " check the characters for an open fold
  let lines = ScreenLines([1, 5], 8)
  let expected = [
        \ '  one   ',
        \ '[ two   ',
        \ '- three ',
        \ '- four  ',
        \ '  five  '
        \ ]
  call assert_equal(expected, lines)

  " check the characters for a closed fold
  normal 2Gzc
  let lines = ScreenLines([1, 3], 8)
  let expected = [
        \ '  one   ',
        \ '] +--  3',
        \ '  five  '
        \ ]
  call assert_equal(expected, lines)

  set fdc=1 foldmethod=indent foldlevel=10
  call setline(1, ['one', '	two', '	two', '		three', '		three', 'four'])
  let lines = ScreenLines([1, 6], 22)
  let expected = [
        \ ' one                  ',
        \ '[        two          ',
        \ '-        two          ',
        \ '[                three',
        \ '2                three',
        \ ' four                 ',
        \ ]
  call assert_equal(expected, lines)

  " check setting foldinner
  set fillchars+=foldinner:\ 
  let lines = ScreenLines([1, 6], 22)
  let expected = [
        \ ' one                  ',
        \ '[        two          ',
        \ '-        two          ',
        \ '[                three',
        \ '                 three',
        \ ' four                 ',
        \ ]
  call assert_equal(expected, lines)

  " check Unicode chars
  set fillchars=foldopen:▼,foldclose:▶,fold:⋯,foldsep:‖,foldinner:⋮
  let lines = ScreenLines([1, 6], 22)
  let expected = [
        \ ' one                  ',
        \ '▼        two          ',
        \ '‖        two          ',
        \ '▼                three',
        \ '⋮                three',
        \ ' four                 ',
        \ ]
  call assert_equal(expected, lines)

  set fillchars-=foldinner:⋮
  let lines = ScreenLines([1, 6], 22)
  let expected = [
        \ ' one                  ',
        \ '▼        two          ',
        \ '‖        two          ',
        \ '▼                three',
        \ '2                three',
        \ ' four                 ',
        \ ]
  call assert_equal(expected, lines)

  normal! 5ggzc
  let lines = ScreenLines([1, 5], 24)
  let expected = [
        \ ' one                    ',
        \ '▼        two            ',
        \ '‖        two            ',
        \ '▶+---  2 lines: three⋯⋯⋯',
        \ ' four                   ',
        \ ]
  call assert_equal(expected, lines)

  %bw!
  set fillchars& fdc& foldmethod& foldenable&
endfunc

func Test_local_fillchars()
  CheckScreendump

  let lines =<< trim END
      call setline(1, ['window 1']->repeat(3))
      setlocal fillchars=stl:1,stlnc:a,vert:=,eob:x
      vnew
      call setline(1, ['window 2']->repeat(3))
      setlocal fillchars=stl:2,stlnc:b,vert:+,eob:y
      new
      wincmd J
      call setline(1, ['window 3']->repeat(3))
      setlocal fillchars=stl:3,stlnc:c,vert:<,eob:z
      vnew
      call setline(1, ['window 4']->repeat(3))
      setlocal fillchars=stl:4,stlnc:d,vert:>,eob:o
  END
  call writefile(lines, 'Xdisplayfillchars', 'D')
  let buf = RunVimInTerminal('-S Xdisplayfillchars', #{rows: 12})
  call VerifyScreenDump(buf, 'Test_display_fillchars_1', {})

  call term_sendkeys(buf, ":wincmd k\r")
  call VerifyScreenDump(buf, 'Test_display_fillchars_2', {})

  call StopVimInTerminal(buf)
endfunc

func Test_display_linebreak_breakat()
  new
  vert resize 25
  let _breakat = &breakat
  setl signcolumn=yes linebreak breakat=) showbreak=++
  call setline(1, repeat('x', winwidth(0) - 2) .. ')abc')
  let lines = ScreenLines([1, 2], 25)
  let expected = [
          \ '  xxxxxxxxxxxxxxxxxxxxxxx',
          \ '  ++)abc                 ',
          \ ]
  call assert_equal(expected, lines)
  setl breakindent breakindentopt=shift:2
  let lines = ScreenLines([1, 2], 25)
  let expected = [
          \ '  xxxxxxxxxxxxxxxxxxxxxxx',
          \ '    ++)abc               ',
          \ ]
  call assert_equal(expected, lines)
  %bw!
  let &breakat=_breakat
endfunc

func Run_Test_display_lastline(euro)
  let lines =<< trim END
      call setline(1, ['aaa', 'b'->repeat(200)])
      set display=truncate

      vsplit
      100wincmd <
  END
  if a:euro != ''
    let lines[2] = 'set fillchars=vert:\|,lastline:€'
  endif
  call writefile(lines, 'XdispLastline', 'D')
  let buf = RunVimInTerminal('-S XdispLastline', #{rows: 10})
  call VerifyScreenDump(buf, $'Test_display_lastline_{a:euro}1', {})

  call term_sendkeys(buf, ":set display=lastline\<CR>")
  call VerifyScreenDump(buf, $'Test_display_lastline_{a:euro}2', {})

  call term_sendkeys(buf, ":100wincmd >\<CR>")
  call VerifyScreenDump(buf, $'Test_display_lastline_{a:euro}3', {})

  call term_sendkeys(buf, ":set display=truncate\<CR>")
  call VerifyScreenDump(buf, $'Test_display_lastline_{a:euro}4', {})

  call term_sendkeys(buf, ":close\<CR>")
  call term_sendkeys(buf, ":3split\<CR>")
  call VerifyScreenDump(buf, $'Test_display_lastline_{a:euro}5', {})

  call term_sendkeys(buf, ":close\<CR>")
  call term_sendkeys(buf, ":2vsplit\<CR>")
  call VerifyScreenDump(buf, $'Test_display_lastline_{a:euro}6', {})

  call StopVimInTerminal(buf)
endfunc

func Test_display_lastline_dump()
  CheckScreendump

  call Run_Test_display_lastline('')
  call Run_Test_display_lastline('euro_')
endfunc

func Test_display_lastline_fails()
  call assert_fails(':set fillchars=lastline:', 'E1511:')
  call assert_fails(':set fillchars=lastline:〇', 'E1512:')
endfunc

func Test_display_long_lastline()
  CheckScreendump

  let lines =<< trim END
    set display=lastline smoothscroll scrolloff=0
    call setline(1, [
      \'aaaaa'->repeat(150),
      \'bbbbb '->repeat(7) .. 'ccccc '->repeat(7) .. 'ddddd '->repeat(7)
    \])
  END

  call writefile(lines, 'XdispLongline', 'D')
  let buf = RunVimInTerminal('-S XdispLongline', #{rows: 14, cols: 35})

  call term_sendkeys(buf, "736|")
  call VerifyScreenDump(buf, 'Test_display_long_line_1', {})

  " The correct part of the last line is moved into view.
  call term_sendkeys(buf, "D")
  call VerifyScreenDump(buf, 'Test_display_long_line_2', {})

  " "w_skipcol" does not change because the topline is still long enough
  " to maintain the current skipcol.
  call term_sendkeys(buf, "g04l11gkD")
  call VerifyScreenDump(buf, 'Test_display_long_line_3', {})

  " "w_skipcol" is reset to bring the entire topline into view because
  " the line length is now smaller than the current skipcol + marker.
  call term_sendkeys(buf, "x")
  call VerifyScreenDump(buf, 'Test_display_long_line_4', {})

  call StopVimInTerminal(buf)
endfunc

" Moving the cursor to a line that doesn't fit in the window should show
" correctly.
func Test_display_cursor_long_line()
  CheckScreendump

  let lines =<< trim END
    call setline(1, ['a', 'b ' .. 'bbbbb'->repeat(150), 'c'])
    norm $j
  END

  call writefile(lines, 'XdispCursorLongline', 'D')
  let buf = RunVimInTerminal('-S XdispCursorLongline', #{rows: 8})

  call VerifyScreenDump(buf, 'Test_display_cursor_long_line_1', {})

  " FIXME: moving the cursor above the topline does not set w_skipcol
  " correctly with cpo+=n and zero scrolloff (curs_columns() extra == 1).
  call term_sendkeys(buf, ":set number cpo+=n scrolloff=0\<CR>")
  call term_sendkeys(buf, '$0')
  call VerifyScreenDump(buf, 'Test_display_cursor_long_line_2', {})

  " Going to the start of the line with "b" did not set w_skipcol correctly
  " with 'smoothscroll'.
   call term_sendkeys(buf, ":set smoothscroll\<CR>")
   call term_sendkeys(buf, '$b')
   call VerifyScreenDump(buf, 'Test_display_cursor_long_line_3', {})
  " Same for "ge".
   call term_sendkeys(buf, '$ge')
   call VerifyScreenDump(buf, 'Test_display_cursor_long_line_4', {})

  call StopVimInTerminal(buf)
endfunc

func Test_change_wrapped_line_cpo_dollar()
  CheckScreendump

  let lines =<< trim END
    set cpoptions+=$ laststatus=0
    call setline(1, ['foo', 'bar',
          \ repeat('x', 25) .. '!!()!!' .. repeat('y', 25),
          \ 'FOO', 'BAR'])
    inoremap <F2> <Cmd>call setline(1, repeat('z', 30))<CR>
    inoremap <F3> <Cmd>call setline(1, 'foo')<CR>
    vsplit
    call cursor(3, 1)
  END
  call writefile(lines, 'Xwrapped_cpo_dollar', 'D')
  let buf = RunVimInTerminal('-S Xwrapped_cpo_dollar', #{rows: 10, cols: 45})

  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_01', {})
  call term_sendkeys(buf, 'ct!')
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_02', {})
  call term_sendkeys(buf, "\<F2>")
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_03', {})
  call term_sendkeys(buf, "\<F3>")
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_02', {})
  call term_sendkeys(buf, 'y')
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_04', {})
  call term_sendkeys(buf, 'y')
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_05', {})
  call term_sendkeys(buf, "\<Esc>")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_06', {})

  call term_sendkeys(buf, ":silent undo | echo\<CR>")
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_01', {})
  call term_sendkeys(buf, ":source samples/matchparen.vim\<CR>")
  call term_sendkeys(buf, 'ct(')
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_07', {})
  call term_sendkeys(buf, 'y')
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_08', {})
  call term_sendkeys(buf, 'y')
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_09', {})
  call term_sendkeys(buf, "\<Esc>")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_10', {})

  call term_sendkeys(buf, ":silent undo | echo\<CR>")
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_01', {})
  call term_sendkeys(buf, "f(azz\<CR>zz\<Esc>k0")
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_11', {})
  call term_sendkeys(buf, 'ct(')
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_12', {})
  call term_sendkeys(buf, 'y')
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_13', {})
  call term_sendkeys(buf, 'y')
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_14', {})
  call term_sendkeys(buf, "\<Esc>")
  call TermWait(buf, 50)
  call VerifyScreenDump(buf, 'Test_change_wrapped_line_cpo_dollar_15', {})

  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
