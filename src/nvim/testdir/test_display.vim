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

func! Test_display_foldtext_mbyte()
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
  call writefile(lines, 'Xtestscroll')
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
  call delete('Xtestscroll')
endfunc

func Test_display_listchars_precedes()
  set fillchars+=vert:\|
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
  call writefile(lines, filename)
  let buf = RunVimInTerminal('-S '.filename, #{rows: 5, cols: 50})
  call term_sendkeys(buf, "k")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_winline_rnu', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete(filename)
endfunc

" check a long file name does not result in the hit-enter prompt
func Test_edit_long_file_name()
  CheckScreendump

  let longName = 'x'->repeat(min([&columns, 255]))
  call writefile([], longName)
  let buf = RunVimInTerminal('-N -u NONE ' .. longName, #{rows: 8})

  call VerifyScreenDump(buf, 'Test_long_file_name_1', {})

  call term_sendkeys(buf, ":q\<cr>")

  " clean up
  call StopVimInTerminal(buf)
  call delete(longName)
endfunc

func Test_unprintable_fileformats()
  CheckScreendump

  call writefile(["unix\r", "two"], 'Xunix.txt')
  call writefile(["mac\r", "two"], 'Xmac.txt')
  let lines =<< trim END
    edit Xunix.txt
    split Xmac.txt
    edit ++ff=mac
  END
  let filename = 'Xunprintable'
  call writefile(lines, filename)
  let buf = RunVimInTerminal('-S '.filename, #{rows: 9, cols: 50})
  call VerifyScreenDump(buf, 'Test_display_unprintable_01', {})
  call term_sendkeys(buf, "\<C-W>\<C-W>\<C-L>")
  call VerifyScreenDump(buf, 'Test_display_unprintable_02', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xunix.txt')
  call delete('Xmac.txt')
  call delete(filename)
endfunc

" Test for scrolling that modifies buffer during visual block
func Test_visual_block_scroll()
  " See test/functional/legacy/visual_mode_spec.lua
  CheckScreendump

  let lines =<< trim END
    source $VIMRUNTIME/plugin/matchparen.vim
    set scrolloff=1
    call setline(1, ['a', 'b', 'c', 'd', 'e', '', '{', '}', '{', 'f', 'g', '}'])
    call cursor(5, 1)
  END

  let filename = 'Xvisualblockmodifiedscroll'
  call writefile(lines, filename)

  let buf = RunVimInTerminal('-S '.filename, #{rows: 7})
  call term_sendkeys(buf, "V\<C-D>\<C-D>")

  call VerifyScreenDump(buf, 'Test_display_visual_block_scroll', {})

  call StopVimInTerminal(buf)
  call delete(filename)
endfunc

func Test_display_scroll_at_topline()
  " See test/functional/legacy/display_spec.lua
  CheckScreendump

  let buf = RunVimInTerminal('', #{cols: 20})
  call term_sendkeys(buf, ":call setline(1, repeat('a', 21))\<CR>")
  call term_wait(buf)
  call term_sendkeys(buf, "O\<Esc>")
  call VerifyScreenDump(buf, 'Test_display_scroll_at_topline', #{rows: 4})

  call StopVimInTerminal(buf)
endfunc

func Test_display_linebreak_breakat()
  new
  vert resize 25
  let _breakat = &breakat
  setl signcolumn=yes linebreak breakat=) showbreak=+\ 
  call setline(1, repeat('x', winwidth(0) - 2) .. ')abc')
  let lines = ScreenLines([1, 2], 25)
  let expected = [
          \ '  xxxxxxxxxxxxxxxxxxxxxxx',
          \ '  + )abc                 '
          \ ]
  call assert_equal(expected, lines)
  %bw!
  let &breakat=_breakat
endfunc

" vim: shiftwidth=2 sts=2 expandtab
