" Test for cursorline and cursorlineopt

source check.vim
source screendump.vim

func s:screen_attr(lnum) abort
  return map(range(1, 8), 'screenattr(a:lnum, v:val)')
endfunc

func s:test_windows(h, w) abort
  call NewWindow(a:h, a:w)
endfunc

func s:close_windows() abort
  call CloseWindow()
endfunc

func s:new_hi() abort
  redir => save_hi
  silent! hi CursorLineNr
  redir END
  let save_hi = join(split(substitute(save_hi, '\s*xxx\s*', ' ', ''), "\n"), '')
  exe 'hi' save_hi 'ctermbg=0 guibg=Black'
  return save_hi
endfunc

func Test_cursorline_highlight1()
  let save_hi = s:new_hi()
  try
    call s:test_windows(10, 20)
    call setline(1, repeat(['aaaa'], 10))
    redraw
    let attr01 = s:screen_attr(1)
    call assert_equal(repeat([attr01[0]], 8), attr01)

    setl number numberwidth=4
    redraw
    let attr11 = s:screen_attr(1)
    call assert_equal(repeat([attr11[0]], 4), attr11[0:3])
    call assert_equal(repeat([attr11[4]], 4), attr11[4:7])
    call assert_notequal(attr11[0], attr11[4])

    setl cursorline
    redraw
    let attr21 = s:screen_attr(1)
    let attr22 = s:screen_attr(2)
    call assert_equal(repeat([attr21[0]], 4), attr21[0:3])
    call assert_equal(repeat([attr21[4]], 4), attr21[4:7])
    call assert_equal(attr11, attr22)
    call assert_notequal(attr22, attr21)

    setl nocursorline relativenumber
    redraw
    let attr31 = s:screen_attr(1)
    call assert_equal(attr22[0:3], attr31[0:3])
    call assert_equal(attr11[4:7], attr31[4:7])

    call s:close_windows()
  finally
    exe 'hi' save_hi
  endtry
endfunc

func Test_cursorline_highlight2()
  CheckOption cursorlineopt

  let save_hi = s:new_hi()
  try
    call s:test_windows(10, 20)
    call setline(1, repeat(['aaaa'], 10))
    redraw
    let attr0 = s:screen_attr(1)
    call assert_equal(repeat([attr0[0]], 8), attr0)

    setl number
    redraw
    let attr1 = s:screen_attr(1)
    call assert_notequal(attr0[0:3], attr1[0:3])
    call assert_equal(attr0[0:3], attr1[4:7])

    setl cursorline cursorlineopt=both
    redraw
    let attr2 = s:screen_attr(1)
    call assert_notequal(attr1[0:3], attr2[0:3])
    call assert_notequal(attr1[4:7], attr2[4:7])

    setl cursorlineopt=line
    redraw
    let attr3 = s:screen_attr(1)
    call assert_equal(attr1[0:3], attr3[0:3])
    call assert_equal(attr2[4:7], attr3[4:7])

    setl cursorlineopt=number
    redraw
    let attr4 = s:screen_attr(1)
    call assert_equal(attr2[0:3], attr4[0:3])
    call assert_equal(attr1[4:7], attr4[4:7])

    setl nonumber
    redraw
    let attr5 = s:screen_attr(1)
    call assert_equal(attr0, attr5)

    call s:close_windows()
  finally
    exe 'hi' save_hi
  endtry
endfunc

func Test_cursorline_screenline()
  CheckScreendump
  CheckOption cursorlineopt

  let filename='Xcursorline'
  let lines = []

  let file_content =<< trim END
    1 foooooooo ar eins‍zwei drei vier fünf sechs sieben acht un zehn elf zwöfl dreizehn	v ierzehn	fünfzehn
    2 foooooooo bar eins zwei drei vier fünf sechs sieben
    3 foooooooo bar eins zwei drei vier fünf sechs sieben
    4 foooooooo bar eins zwei drei vier fünf sechs sieben
  END
  let lines1 =<< trim END1
    set nocp
    set display=lastline
    set cursorlineopt=screenline cursorline nu wrap sbr=>
    hi CursorLineNr ctermfg=blue
    25vsp
  END1
  let lines2 =<< trim END2
    call cursor(1,1)
  END2
  call extend(lines, lines1)
  call extend(lines,  ["call append(0, ".. string(file_content).. ')'])
  call extend(lines, lines2)
  call writefile(lines, filename)
  " basic test
  let buf = RunVimInTerminal('-S '. filename, #{rows: 20})
  call VerifyScreenDump(buf, 'Test_'. filename. '_1', {})
  call term_sendkeys(buf, "fagj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_2', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_3', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_4', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_5', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_6', {})
  " test with set list and cursorlineopt containing number
  call term_sendkeys(buf, "gg0")
  call term_sendkeys(buf, ":set list cursorlineopt+=number listchars=space:-\<cr>")
  call VerifyScreenDump(buf, 'Test_'. filename. '_7', {})
  call term_sendkeys(buf, "fagj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_8', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_9', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_10', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_11', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_12', {})
  if exists("+foldcolumn") && exists("+signcolumn") && exists("+breakindent")
    " test with set foldcolumn signcolumn and breakindent
    call term_sendkeys(buf, "gg0")
    call term_sendkeys(buf, ":set breakindent foldcolumn=2 signcolumn=yes\<cr>")
    call VerifyScreenDump(buf, 'Test_'. filename. '_13', {})
    call term_sendkeys(buf, "fagj")
    call VerifyScreenDump(buf, 'Test_'. filename. '_14', {})
    call term_sendkeys(buf, "gj")
    call VerifyScreenDump(buf, 'Test_'. filename. '_15', {})
    call term_sendkeys(buf, "gj")
    call VerifyScreenDump(buf, 'Test_'. filename. '_16', {})
    call term_sendkeys(buf, "gj")
    call VerifyScreenDump(buf, 'Test_'. filename. '_17', {})
    call term_sendkeys(buf, "gj")
    call VerifyScreenDump(buf, 'Test_'. filename. '_18', {})
    call term_sendkeys(buf, ":set breakindent& foldcolumn& signcolumn&\<cr>")
  endif
  " showbreak should not be highlighted with CursorLine when 'number' is off
  call term_sendkeys(buf, "gg0")
  call term_sendkeys(buf, ":set list cursorlineopt=screenline listchars=space:-\<cr>")
  call term_sendkeys(buf, ":set nonumber\<cr>")
  call VerifyScreenDump(buf, 'Test_'. filename. '_19', {})
  call term_sendkeys(buf, "fagj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_20', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_21', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_22', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_23', {})
  call term_sendkeys(buf, "gj")
  call VerifyScreenDump(buf, 'Test_'. filename. '_24', {})
  call term_sendkeys(buf, ":set list& cursorlineopt& listchars&\<cr>")

  call StopVimInTerminal(buf)
  call delete(filename)
endfunc

func Test_cursorline_redraw()
  CheckScreendump
  CheckOption cursorlineopt

  let textlines =<< END
			When the option is a list of flags, {value} must be
			exactly as they appear in the option.  Remove flags
			one by one to avoid problems.
			Also see |:set-args| above.

The {option} arguments to ":set" may be repeated.  For example: >
	:set ai nosi sw=3 ts=3
If you make an error in one of the arguments, an error message will be given
and the following arguments will be ignored.

							*:set-verbose*
When 'verbose' is non-zero, displaying an option value will also tell where it
was last set.  Example: >
	:verbose set shiftwidth cindent?
<  shiftwidth=4 ~
	  Last set from modeline line 1 ~
  cindent ~
	  Last set from /usr/local/share/vim/vim60/ftplugin/c.vim line 30 ~
This is only done when specific option values are requested, not for ":verbose
set all" or ":verbose set" without an argument.
When the option was set by hand there is no "Last set" message.
When the option was set while executing a function, user command or
END
  call writefile(textlines, 'Xtextfile')

  let script =<< trim END
      set cursorline scrolloff=2
      normal 12G
  END
  call writefile(script, 'Xscript')

  let buf = RunVimInTerminal('-S Xscript Xtextfile', #{rows: 20, cols: 40})
  call VerifyScreenDump(buf, 'Test_cursorline_redraw_1', {})
  call term_sendkeys(buf, "zt")
  call TermWait(buf)
  call term_sendkeys(buf, "\<C-U>")
  call VerifyScreenDump(buf, 'Test_cursorline_redraw_2', {})

  call StopVimInTerminal(buf)
  call delete('Xscript')
  call delete('Xtextfile')
endfunc

func Test_cursorline_callback()
  CheckScreendump
  CheckFeature timers

  let lines =<< trim END
      call setline(1, ['aaaaa', 'bbbbb', 'ccccc', 'ddddd'])
      set cursorline
      call cursor(4, 1)

      func Func(timer)
        call cursor(2, 1)
      endfunc

      call timer_start(300, 'Func')
  END
  call writefile(lines, 'Xcul_timer', 'D')

  let buf = RunVimInTerminal('-S Xcul_timer', #{rows: 8})
  call TermWait(buf, 310)
  call VerifyScreenDump(buf, 'Test_cursorline_callback_1', {})

  call StopVimInTerminal(buf)
endfunc

func Test_cursorline_screenline_resize()
  CheckScreendump

  let lines =<< trim END
      50vnew
      call setline(1, repeat('xyz ', 30))
      setlocal number cursorline cursorlineopt=screenline
      normal! $
  END
  call writefile(lines, 'Xcul_screenline_resize', 'D')

  let buf = RunVimInTerminal('-S Xcul_screenline_resize', #{rows: 8})
  call VerifyScreenDump(buf, 'Test_cursorline_screenline_resize_1', {})
  call term_sendkeys(buf, ":vertical resize -4\<CR>")
  call VerifyScreenDump(buf, 'Test_cursorline_screenline_resize_2', {})
  call term_sendkeys(buf, ":set cpoptions+=n\<CR>")
  call VerifyScreenDump(buf, 'Test_cursorline_screenline_resize_3', {})

  call StopVimInTerminal(buf)
endfunc

func Test_cursorline_screenline_update()
  CheckScreendump

  let lines =<< trim END
      call setline(1, repeat('xyz ', 30))
      set cursorline cursorlineopt=screenline
      inoremap <F2> <Cmd>call cursor(1, 1)<CR>
  END
  call writefile(lines, 'Xcul_screenline', 'D')

  let buf = RunVimInTerminal('-S Xcul_screenline', #{rows: 8})
  call term_sendkeys(buf, "A")
  call VerifyScreenDump(buf, 'Test_cursorline_screenline_1', {})
  call term_sendkeys(buf, "\<F2>")
  call VerifyScreenDump(buf, 'Test_cursorline_screenline_2', {})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
endfunc

func Test_cursorline_screenline_zero_width()
  CheckOption foldcolumn

  set cursorline culopt=screenline winminwidth=1 foldcolumn=1
  " This used to crash Vim
  1vnew | redraw

  bwipe!
  set cursorline& culopt& winminwidth& foldcolumn&
endfunc

func Test_cursorline_cursorbind_horizontal_scroll()
  CheckScreendump

  let lines =<< trim END
      call setline(1, 'aa bb cc dd ee ff gg hh ii jj kk ll mm' ..
                    \ ' nn oo pp qq rr ss tt uu vv ww xx yy zz')
      set nowrap
      " The following makes the cursor apparent on the screen dump
      set sidescroll=1 cursorcolumn
      " add empty lines, required for cursorcolumn
      call append(1, ['','','',''])
      20vsp
      windo :set cursorbind
  END
  call writefile(lines, 'Xhor_scroll')

  let buf = RunVimInTerminal('-S Xhor_scroll', #{rows: 8})
  call term_sendkeys(buf, "20l")
  call VerifyScreenDump(buf, 'Test_hor_scroll_1', {})
  call term_sendkeys(buf, "10l")
  call VerifyScreenDump(buf, 'Test_hor_scroll_2', {})
  call term_sendkeys(buf, ":windo :set cursorline\<cr>")
  call term_sendkeys(buf, "0")
  call term_sendkeys(buf, "20l")
  call VerifyScreenDump(buf, 'Test_hor_scroll_3', {})
  call term_sendkeys(buf, "10l")
  call VerifyScreenDump(buf, 'Test_hor_scroll_4', {})
  call term_sendkeys(buf, ":windo :set nocursorline nocursorcolumn\<cr>")
  call term_sendkeys(buf, "0")
  call term_sendkeys(buf, "40l")
  call VerifyScreenDump(buf, 'Test_hor_scroll_5', {})

  call StopVimInTerminal(buf)
  call delete('Xhor_scroll')
endfunc


" vim: shiftwidth=2 sts=2 expandtab
