" Tests for 'conceal'.

source check.vim
CheckFeature conceal

source screendump.vim
" CheckScreendump

func Test_conceal_two_windows()
  CheckScreendump
  let code =<< trim [CODE]
    let lines = ["one one one one one", "two |hidden| here", "three |hidden| three"]
    call setline(1, lines)
    syntax match test /|hidden|/ conceal
    set conceallevel=2
    set concealcursor=
    exe "normal /here\r"
    new
    call setline(1, lines)
    call setline(4, "Second window")
    syntax match test /|hidden|/ conceal
    set conceallevel=2
    set concealcursor=nc
    exe "normal /here\r"
  [CODE]

  call writefile(code, 'XTest_conceal')
  " Check that cursor line is concealed
  let buf = RunVimInTerminal('-S XTest_conceal', {})
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_01', {})

  " Check that with concealed text vertical cursor movement is correct.
  call term_sendkeys(buf, "k")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_02', {})

  " Check that with cursor line is not concealed
  call term_sendkeys(buf, "j")
  call term_sendkeys(buf, ":set concealcursor=\r")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_03', {})

  " Check that with cursor line is not concealed when moving cursor down
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_04', {})

  " Check that with cursor line is not concealed when switching windows
  call term_sendkeys(buf, "\<C-W>\<C-W>")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_05', {})

  " Check that with cursor line is only concealed in Normal mode
  call term_sendkeys(buf, ":set concealcursor=n\r")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_06n', {})
  call term_sendkeys(buf, "a")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_06i', {})
  call term_sendkeys(buf, "\<Esc>/e")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_06c', {})
  call term_sendkeys(buf, "\<Esc>v")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_06v', {})
  call term_sendkeys(buf, "\<Esc>")

  " Check that with cursor line is only concealed in Insert mode
  call term_sendkeys(buf, ":set concealcursor=i\r")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_07n', {})
  call term_sendkeys(buf, "a")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_07i', {})
  call term_sendkeys(buf, "\<Esc>/e")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_07c', {})
  call term_sendkeys(buf, "\<Esc>v")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_07v', {})
  call term_sendkeys(buf, "\<Esc>")

  " Check that with cursor line is only concealed in Command mode
  call term_sendkeys(buf, ":set concealcursor=c\r")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_08n', {})
  call term_sendkeys(buf, "a")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_08i', {})
  call term_sendkeys(buf, "\<Esc>/e")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_08c', {})
  call term_sendkeys(buf, "\<Esc>v")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_08v', {})
  call term_sendkeys(buf, "\<Esc>")

  " Check that with cursor line is only concealed in Visual mode
  call term_sendkeys(buf, ":set concealcursor=v\r")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_09n', {})
  call term_sendkeys(buf, "a")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_09i', {})
  call term_sendkeys(buf, "\<Esc>/e")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_09c', {})
  call term_sendkeys(buf, "\<Esc>v")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_09v', {})
  call term_sendkeys(buf, "\<Esc>")

  " Check moving the cursor while in insert mode.
  call term_sendkeys(buf, ":set concealcursor=\r")
  call term_sendkeys(buf, "a")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_10', {})
  call term_sendkeys(buf, "\<Down>")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_11', {})
  call term_sendkeys(buf, "\<Esc>")

  " Check the "o" command
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_12', {})
  call term_sendkeys(buf, "o")
  call VerifyScreenDump(buf, 'Test_conceal_two_windows_13', {})
  call term_sendkeys(buf, "\<Esc>")

  " clean up
  call StopVimInTerminal(buf)
  call delete('XTest_conceal')
endfunc

func Test_conceal_with_cursorline()
  CheckScreendump
  " Opens a help window, where 'conceal' is set, switches to the other window
  " where 'cursorline' needs to be updated when the cursor moves.
  let code =<< trim [CODE]
    set cursorline
    normal othis is a test
    new
    call setline(1, ["one", "two", "three", "four", "five"])
    set ft=help
    normal M
  [CODE]

  call writefile(code, 'XTest_conceal_cul')
  let buf = RunVimInTerminal('-S XTest_conceal_cul', {})
  call VerifyScreenDump(buf, 'Test_conceal_cul_01', {})

  call term_sendkeys(buf, ":wincmd w\r")
  call VerifyScreenDump(buf, 'Test_conceal_cul_02', {})

  call term_sendkeys(buf, "k")
  call VerifyScreenDump(buf, 'Test_conceal_cul_03', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XTest_conceal_cul')
endfunc

func Test_conceal_resize_term()
  CheckScreendump
  let code =<< trim [CODE]
    call setline(1, '`one` `two` `three` `four` `five`, the backticks should be concealed')
    setl cocu=n cole=3
    syn region CommentCodeSpan matchgroup=Comment start=/`/ end=/`/ concealends
    normal fb
  [CODE]
  call writefile(code, 'XTest_conceal_resize')
  let buf = RunVimInTerminal('-S XTest_conceal_resize', {'rows': 6})
  call VerifyScreenDump(buf, 'Test_conceal_resize_01', {})

  call win_execute(buf->win_findbuf()[0], 'wincmd +')
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_conceal_resize_02', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XTest_conceal_resize')
endfunc

" Tests for correct display (cursor column position) with +conceal and
" tabulators.  Need to run this test in a separate Vim instance. Otherwise the
" screen is not updated (lazy redraw) and the cursor position is wrong.
func Test_conceal_cursor_pos()
  let code =<< trim [CODE]
    :let l = ['start:', '.concealed.     text', "|concealed|\ttext"]
    :let l += ['', "\t.concealed.\ttext", "\t|concealed|\ttext", '']
    :let l += [".a.\t.b.\t.c.\t.d.", "|a|\t|b|\t|c|\t|d|"]
    :call append(0, l)
    :call cursor(1, 1)
    :" Conceal settings.
    :set conceallevel=2
    :set concealcursor=nc
    :syntax match test /|/ conceal
    :" Save current cursor position. Only works in <expr> mode, can't be used
    :" with :normal because it moves the cursor to the command line. Thanks
    :" to ZyX <zyx.vim@gmail.com> for the idea to use an <expr> mapping.
    :let curpos = []
    :nnoremap <expr> GG ":let curpos += ['".screenrow().":".screencol()."']\n"
    :normal ztj
    GGk
    :" We should end up in the same column when running these commands on the
    :" two lines.
    :normal ft
    GGk
    :normal $
    GGk
    :normal 0j
    GGk
    :normal ft
    GGk
    :normal $
    GGk
    :normal 0j0j
    GGk
    :" Same for next test block.
    :normal ft
    GGk
    :normal $
    GGk
    :normal 0j
    GGk
    :normal ft
    GGk
    :normal $
    GGk
    :normal 0j0j
    GGk
    :" And check W with multiple tabs and conceals in a line.
    :normal W
    GGk
    :normal W
    GGk
    :normal W
    GGk
    :normal $
    GGk
    :normal 0j
    GGk
    :normal W
    GGk
    :normal W
    GGk
    :normal W
    GGk
    :normal $
    GGk
    :set lbr
    :normal $
    GGk
    :set list listchars=tab:>-
    :normal 0
    GGk
    :normal W
    GGk
    :normal W
    GGk
    :normal W
    GGk
    :normal $
    GGk
    :call writefile(curpos, 'Xconceal_curpos.out')
    :q!

  [CODE]
  call writefile(code, 'XTest_conceal_curpos')

  if RunVim([], [], '-s XTest_conceal_curpos')
    call assert_equal([
          \ '2:1', '2:17', '2:20', '3:1', '3:17', '3:20', '5:8', '5:25',
          \ '5:28', '6:8', '6:25', '6:28', '8:1', '8:9', '8:17', '8:25',
          \ '8:27', '9:1', '9:9', '9:17', '9:25', '9:26', '9:26', '9:1',
          \ '9:9', '9:17', '9:25', '9:26'], readfile('Xconceal_curpos.out'))
  endif

  call delete('Xconceal_curpos.out')
  call delete('XTest_conceal_curpos')
endfunc

func Test_conceal_eol()
  new!
  setlocal concealcursor=n conceallevel=1
  call setline(1, ["x", ""])
  call matchaddpos('Conceal', [[2, 1, 1]], 2, -1, {'conceal': 1})
  redraw!

  call assert_notequal(screenchar(1, 1), screenchar(2, 2))
  call assert_equal(screenattr(1, 1), screenattr(1, 2))
  call assert_equal(screenattr(1, 2), screenattr(2, 2))
  call assert_equal(screenattr(2, 1), screenattr(2, 2))

  set list
  redraw!

  call assert_equal(screenattr(1, 1), screenattr(2, 2))
  call assert_notequal(screenattr(1, 1), screenattr(1, 2))
  call assert_notequal(screenattr(1, 2), screenattr(2, 1))

  set nolist
endfunc

" vim: shiftwidth=2 sts=2 expandtab
