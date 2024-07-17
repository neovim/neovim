" Test 'statusline'
"
" Not tested yet:
"   %N

source view_util.vim
source check.vim
source term_util.vim

func SetUp()
  set laststatus=2
endfunc

func TearDown()
  set laststatus&
endfunc

func s:get_statusline()
  return ScreenLines(&lines - 1, &columns)[0]
endfunc

func StatuslineWithCaughtError()
  let s:func_in_statusline_called = 1
  try
    call eval('unknown expression')
  catch
  endtry
  return ''
endfunc

func StatuslineWithError()
  let s:func_in_statusline_called = 1
  call eval('unknown expression')
  return ''
endfunc

" Function used to display syntax group.
func SyntaxItem()
  call assert_equal(s:expected_curbuf, g:actual_curbuf)
  call assert_equal(s:expected_curwin, g:actual_curwin)
  return synIDattr(synID(line("."), col("."),1), "name")
endfunc

func Test_caught_error_in_statusline()
  let s:func_in_statusline_called = 0
  let statusline = '%{StatuslineWithCaughtError()}'
  let &statusline = statusline
  redrawstatus
  call assert_true(s:func_in_statusline_called)
  call assert_equal(statusline, &statusline)
  set statusline=
endfunc

func Test_statusline_will_be_disabled_with_error()
  let s:func_in_statusline_called = 0
  let statusline = '%{StatuslineWithError()}'
  try
    let &statusline = statusline
    redrawstatus
  catch
  endtry
  call assert_true(s:func_in_statusline_called)
  call assert_equal('', &statusline)
  set statusline=
endfunc

func Test_statusline()
  CheckFeature quickfix

  " %a: Argument list ({current} of {max})
  set statusline=%a
  call assert_match('^\s*$', s:get_statusline())
  arglocal a1 a2
  rewind
  call assert_match('^ (1 of 2)\s*$', s:get_statusline())
  next
  call assert_match('^ (2 of 2)\s*$', s:get_statusline())
  e Xstatusline
  call assert_match('^ ((2) of 2)\s*$', s:get_statusline())

  only
  set splitbelow
  call setline(1, range(1, 10000))

  " %b: Value of character under cursor.
  " %B: As above, in hexadecimal.
  call cursor(9000, 1)
  set statusline=%b,%B
  call assert_match('^57,39\s*$', s:get_statusline())

  " %o: Byte number in file of byte under cursor, first byte is 1.
  " %O: As above, in hexadecimal.
  set statusline=%o,%O
  set fileformat=dos
  call assert_match('^52888,CE98\s*$', s:get_statusline())
  set fileformat=mac
  call assert_match('^43889,AB71\s*$', s:get_statusline())
  set fileformat=unix
  call assert_match('^43889,AB71\s*$', s:get_statusline())
  set fileformat&

  " %f: Path to the file in the buffer, as typed or relative to current dir.
  set statusline=%f
  call assert_match('^Xstatusline\s*$', s:get_statusline())

  " %F: Full path to the file in the buffer.
  set statusline=%F
  call assert_match('/testdir/Xstatusline\s*$', s:get_statusline())

  " Test for min and max width with %(. For some reason, if this test is moved
  " after the below test for the help buffer flag, then the code to truncate
  " the string is not executed.
  set statusline=%015(%f%)
  call assert_match('^    Xstatusline\s*$', s:get_statusline())
  set statusline=%.6(%f%)
  call assert_match('^<sline\s*$', s:get_statusline())
  set statusline=%14f
  call assert_match('^   Xstatusline\s*$', s:get_statusline())
  set statusline=%.4L
  call assert_match('^10>3\s*$', s:get_statusline())

  " %h: Help buffer flag, text is "[help]".
  " %H: Help buffer flag, text is ",HLP".
  set statusline=%h,%H
  call assert_match('^,\s*$', s:get_statusline())
  help
  call assert_match('^\[Help\],HLP\s*$', s:get_statusline())
  helpclose

  " %k: Value of "b:keymap_name" or 'keymap'
  "     when :lmap mappings are being used: <keymap>"
  set statusline=%k
  if has('keymap')
    set keymap=esperanto
    call assert_match('^<Eo>\s*$', s:get_statusline())
    set keymap&
  else
    call assert_match('^\s*$', s:get_statusline())
  endif

  " %l: Line number.
  " %L: Number of line in buffer.
  " %c: Column number.
  set statusline=%l/%L,%c
  call assert_match('^9000/10000,1\s*$', s:get_statusline())

  " %m: Modified flag, text is "[+]", "[-]" if 'modifiable' is off.
  " %M: Modified flag, text is ",+" or ",-".
  set statusline=%m%M
  call assert_match('^\[+\],+\s*$', s:get_statusline())
  set nomodifiable
  call assert_match('^\[+-\],+-\s*$', s:get_statusline())
  write
  call assert_match('^\[-\],-\s*$', s:get_statusline())
  set modifiable&
  call assert_match('^\s*$', s:get_statusline())

  " %n: Buffer number.
  set statusline=%n
  call assert_match('^'.bufnr('%').'\s*$', s:get_statusline())

  " %p: Percentage through file in lines as in CTRL-G.
  " %P: Percentage through file of displayed window.
  set statusline=%p,%P
  0
  call assert_match('^0,Top\s*$', s:get_statusline())
  norm G
  call assert_match('^100,Bot\s*$', s:get_statusline())
  9000
  " Don't check the exact percentage as it depends on the window size
  call assert_match('^90,\(Top\|Bot\|\d\+%\)\s*$', s:get_statusline())

  " %q: "[Quickfix List]", "[Location List]" or empty.
  set statusline=%q
  call assert_match('^\s*$', s:get_statusline())
  copen
  call assert_match('^\[Quickfix List\]\s*$', s:get_statusline())
  cclose
  lexpr getline(1, 2)
  lopen
  call assert_match('^\[Location List\]\s*$', s:get_statusline())
  lclose

  " %r: Readonly flag, text is "[RO]".
  " %R: Readonly flag, text is ",RO".
  set statusline=%r,%R
  call assert_match('^,\s*$', s:get_statusline())
  help
  call assert_match('^\[RO\],RO\s*$', s:get_statusline())
  helpclose

  " %t: File name (tail) of file in the buffer.
  set statusline=%t
  call assert_match('^Xstatusline\s*$', s:get_statusline())

  " %v: Virtual column number.
  " %V: Virtual column number as -{num}. Not displayed if equal to 'c'.
  call cursor(9000, 2)
  set statusline=%v,%V
  call assert_match('^2,\s*$', s:get_statusline())
  set virtualedit=all
  norm 10|
  call assert_match('^10,-10\s*$', s:get_statusline())
  set list
  call assert_match('^10,-10\s*$', s:get_statusline())
  set virtualedit&
  exe "norm A\<Tab>\<Tab>a\<Esc>"
  " In list mode a <Tab> is shown as "^I", which is 2-wide.
  call assert_match('^9,-9\s*$', s:get_statusline())
  set list&
  " Now the second <Tab> ends at the 16th screen column.
  call assert_match('^17,-17\s*$', s:get_statusline())
  undo

  " %w: Preview window flag, text is "[Preview]".
  " %W: Preview window flag, text is ",PRV".
  set statusline=%w%W
  call assert_match('^\s*$', s:get_statusline())
  pedit
  wincmd j
  call assert_match('^\[Preview\],PRV\s*$', s:get_statusline())
  pclose

  " %y: Type of file in the buffer, e.g., "[vim]". See 'filetype'.
  " %Y: Type of file in the buffer, e.g., ",VIM". See 'filetype'.
  set statusline=%y\ %Y
  call assert_match('^\s*$', s:get_statusline())
  setfiletype vim
  call assert_match('^\[vim\] VIM\s*$', s:get_statusline())

  " %=: Separation point between left and right aligned items.
  set statusline=foo%=bar
  call assert_match('^foo\s\+bar\s*$', s:get_statusline())
  set statusline=foo%=bar%=baz
  call assert_match('^foo\s\+bar\s\+baz\s*$', s:get_statusline())
  set statusline=foo%=bar%=baz%=qux
  call assert_match('^foo\s\+bar\s\+baz\s\+qux\s*$', s:get_statusline())

  " Test min/max width, leading zeroes, left/right justify.
  set statusline=%04B
  call cursor(9000, 1)
  call assert_match('^0039\s*$', s:get_statusline())
  set statusline=#%4B#
  call assert_match('^#  39#\s*$', s:get_statusline())
  set statusline=#%-4B#
  call assert_match('^#39  #\s*$', s:get_statusline())
  set statusline=%.6f
  call assert_match('^<sline\s*$', s:get_statusline())

  " %<: Where to truncate.
  " First check with when %< should not truncate with many columns
  exe 'set statusline=a%<b' . repeat('c', &columns - 3) . 'd'
  call assert_match('^abc\+d$', s:get_statusline())
  exe 'set statusline=a' . repeat('b', &columns - 2) . '%<c'
  call assert_match('^ab\+c$', s:get_statusline())
  " Then check when %< should truncate when there with too few columns.
  exe 'set statusline=a%<b' . repeat('c', &columns - 2) . 'd'
  call assert_match('^a<c\+d$', s:get_statusline())
  exe 'set statusline=a' . repeat('b', &columns - 1) . '%<c'
  call assert_match('^ab\+>$', s:get_statusline())

  "%{: Evaluate expression between '%{' and '}' and substitute result.
  syntax on
  let s:expected_curbuf = string(bufnr(''))
  let s:expected_curwin = string(win_getid())
  set statusline=%{SyntaxItem()}
  call assert_match('^vimNumber\s*$', s:get_statusline())
  s/^/"/
  call assert_match('^vimLineComment\s*$', s:get_statusline())
  syntax off

  "%{%expr%}: evaluates expressions present in result of expr
  func! Inner_eval()
    return '%n some other text'
  endfunc
  func! Outer_eval()
    return 'some text %{%Inner_eval()%}'
  endfunc
  set statusline=%{%Outer_eval()%}
  call assert_match('^some text ' . bufnr() . ' some other text\s*$', s:get_statusline())
  delfunc Inner_eval
  delfunc Outer_eval

  "%{%expr%}: Doesn't get stuck in recursion
  func! Recurse_eval()
    return '%{%Recurse_eval()%}'
  endfunc
  set statusline=%{%Recurse_eval()%}
  call assert_match('^%{%Recurse_eval()%}\s*$', s:get_statusline())
  delfunc Recurse_eval

  "%(: Start of item group.
  set statusline=ab%(cd%q%)de
  call assert_match('^abde\s*$', s:get_statusline())
  copen
  call assert_match('^abcd\[Quickfix List]de\s*$', s:get_statusline())
  cclose

  " %#: Set highlight group. The name must follow and then a # again.
  set statusline=ab%#Todo#cd%#Error#ef
  call assert_match('^abcdef\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 3)
  let sa3=screenattr(&lines - 1, 5)
  call assert_notequal(sa1, sa2)
  call assert_notequal(sa1, sa3)
  call assert_notequal(sa2, sa3)
  call assert_equal(sa1, screenattr(&lines - 1, 2))
  call assert_equal(sa2, screenattr(&lines - 1, 4))
  call assert_equal(sa3, screenattr(&lines - 1, 6))
  call assert_equal(sa3, screenattr(&lines - 1, 7))

  " %*: Set highlight group to User{N}
  set statusline=a%1*b%0*c
  call assert_match('^abc\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 2)
  let sa3=screenattr(&lines - 1, 3)
  call assert_equal(sa1, sa3)
  call assert_notequal(sa1, sa2)

  " An empty group that contains highlight changes
  let g:a = ''
  set statusline=ab%(cd%1*%{g:a}%*%)de
  call assert_match('^abde\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 4)
  call assert_equal(sa1, sa2)
  let g:a = 'X'
  call assert_match('^abcdXde\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 5)
  let sa3=screenattr(&lines - 1, 7)
  call assert_equal(sa1, sa3)
  call assert_notequal(sa1, sa2)

  let g:a = ''
  set statusline=ab%1*%(cd%*%{g:a}%1*%)de
  call assert_match('^abde\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 4)
  call assert_notequal(sa1, sa2)
  let g:a = 'X'
  call assert_match('^abcdXde\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 3)
  let sa3=screenattr(&lines - 1, 5)
  let sa4=screenattr(&lines - 1, 7)
  call assert_notequal(sa1, sa2)
  call assert_equal(sa1, sa3)
  call assert_equal(sa2, sa4)

  " An empty group that contains highlight changes and doesn't reset them
  let g:a = ''
  set statusline=ab%(cd%1*%{g:a}%)de
  call assert_match('^abcdde\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 5)
  call assert_notequal(sa1, sa2)
  let g:a = 'X'
  call assert_match('^abcdXde\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 5)
  let sa3=screenattr(&lines - 1, 7)
  call assert_notequal(sa1, sa2)
  call assert_equal(sa2, sa3)

  let g:a = ''
  set statusline=ab%1*%(cd%*%{g:a}%)de
  call assert_match('^abcdde\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 3)
  let sa3=screenattr(&lines - 1, 5)
  call assert_notequal(sa1, sa2)
  call assert_equal(sa1, sa3)
  let g:a = 'X'
  call assert_match('^abcdXde\s*$', s:get_statusline())
  let sa1=screenattr(&lines - 1, 1)
  let sa2=screenattr(&lines - 1, 3)
  let sa3=screenattr(&lines - 1, 5)
  let sa4=screenattr(&lines - 1, 7)
  call assert_notequal(sa1, sa2)
  call assert_equal(sa1, sa3)
  call assert_equal(sa1, sa4)

  let g:a = ''
  set statusline=%#Error#{%(\ %{g:a}\ %)}
  call assert_match('^{}\s*$', s:get_statusline())
  let g:a = 'X'
  call assert_match('^{ X }\s*$', s:get_statusline())

  " %%: a percent sign.
  set statusline=10%%
  call assert_match('^10%\s*$', s:get_statusline())

  " %!: evaluated expression is used as the option value
  set statusline=%!2*3+1
  call assert_match('7\s*$', s:get_statusline())

  func GetNested()
    call assert_equal(string(win_getid()), g:actual_curwin)
    call assert_equal(string(bufnr('')), g:actual_curbuf)
    return 'nested'
  endfunc
  func GetStatusLine()
    call assert_equal(win_getid(), g:statusline_winid)
    return 'the %{GetNested()} line'
  endfunc
  set statusline=%!GetStatusLine()
  call assert_match('the nested line', s:get_statusline())
  call assert_false(exists('g:actual_curwin'))
  call assert_false(exists('g:actual_curbuf'))
  call assert_false(exists('g:statusline_winid'))
  delfunc GetNested
  delfunc GetStatusLine

  " Test statusline works with 80+ items
  function! StatusLabel()
    redrawstatus
    return '[label]'
  endfunc
  let statusline = '%{StatusLabel()}'
  for i in range(150)
    let statusline .= '%#TabLine' . (i % 2 == 0 ? 'Fill' : 'Sel') . '#' . string(i)[0]
  endfor
  let &statusline = statusline
  redrawstatus
  set statusline&
  delfunc StatusLabel


  " Check statusline in current and non-current window
  " with the 'fillchars' option.
  set fillchars=stl:^,stlnc:=,vert:\|,fold:-,diff:-
  vsplit
  set statusline=x%=y
  call assert_match('^x^\+y^x=\+y$', s:get_statusline())
  set fillchars&
  close

  %bw!
  call delete('Xstatusline')
  set statusline&
  set splitbelow&
endfunc

func Test_statusline_trailing_percent_zero()
  " this was causing illegal memory access
  set laststatus=2 stl=%!%0
  call assert_fails('redraw', 'E15: Invalid expression: "%0"')
  set laststatus& stl&
endfunc

func Test_statusline_visual()
  func CallWordcount()
    call wordcount()
  endfunc
  new x1
  setl statusline=count=%{CallWordcount()}
  " buffer must not be empty
  call setline(1, 'hello')

  " window with more lines than x1
  new x2
  call setline(1, range(10))
  $
  " Visual mode in line below liast line in x1 should not give ml_get error
  call feedkeys("\<C-V>", "xt")
  redraw

  delfunc CallWordcount
  bwipe! x1
  bwipe! x2
endfunc

func Test_statusline_removed_group()
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps'
  endif

  let lines =<< trim END
    scriptencoding utf-8
    set laststatus=2
    let &statusline = '%#StatColorHi2#%(✓%#StatColorHi2#%) Q≡'
  END
  call writefile(lines, 'XTest_statusline', 'D')

  let buf = RunVimInTerminal('-S XTest_statusline', {'rows': 10, 'cols': 50})
  call VerifyScreenDump(buf, 'Test_statusline_1', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_statusline_using_mode()
  CheckScreendump

  let lines =<< trim END
    setlocal statusline=-%{mode()}-
    split
    setlocal statusline=+%{mode()}+
  END
  call writefile(lines, 'XTest_statusline', 'D')

  let buf = RunVimInTerminal('-S XTest_statusline', {'rows': 7, 'cols': 50})
  call VerifyScreenDump(buf, 'Test_statusline_mode_1', {})

  call term_sendkeys(buf, ":")
  call VerifyScreenDump(buf, 'Test_statusline_mode_2', {})

  " clean up
  call term_sendkeys(buf, "close\<CR>")
  call StopVimInTerminal(buf)
endfunc

func Test_statusline_after_split_vsplit()
  only

  " Make the status line of each window show the window number.
  set ls=2 stl=%{winnr()}

  split | redraw
  vsplit | redraw

  " The status line of the third window should read '3' here.
  call assert_equal('3', nr2char(screenchar(&lines - 1, 1)))

  only
  set ls& stl&
endfunc

" Test using a multibyte character for 'stl' and 'stlnc' items in 'fillchars'
" with a custom 'statusline'
func Test_statusline_mbyte_fillchar()
  only
  set fillchars=vert:\|,fold:-,stl:━,stlnc:═
  set statusline=a%=b
  call assert_match('^a\+━\+b$', s:get_statusline())
  vnew
  call assert_match('^a\+━\+b━a\+═\+b$', s:get_statusline())
  wincmd w
  call assert_match('^a\+═\+b═a\+━\+b$', s:get_statusline())
  set statusline& fillchars&
  %bw!
endfunc

" Used to write beyond allocated memory.  This assumes MAXPATHL is 4096 bytes.
func Test_statusline_verylong_filename()
  let fname = repeat('x', 4090)
  " Nvim's swap file creation fails on Windows (E303) due to fname's length
  " exe "new " .. fname
  exe "noswapfile new " .. fname
  set buftype=help
  set previewwindow
  redraw
  bwipe!
endfunc

func Test_statusline_highlight_truncate()
  CheckScreendump

  let lines =<< trim END
    set laststatus=2
    hi! link User1 Directory
    hi! link User2 ErrorMsg
    set statusline=%.5(%1*ABC%2*DEF%1*GHI%)
  END
  call writefile(lines, 'XTest_statusline', 'D')

  let buf = RunVimInTerminal('-S XTest_statusline', {'rows': 6})
  call VerifyScreenDump(buf, 'Test_statusline_hl', {})

  call StopVimInTerminal(buf)
endfunc

func Test_statusline_showcmd()
  CheckScreendump

  let lines =<< trim END
    func MyStatusLine()
      return '%S'
    endfunc

    set laststatus=2
    set statusline=%!MyStatusLine()
    set showcmdloc=statusline
    call setline(1, ['a', 'b', 'c'])
    set foldopen+=jump
    1,2fold
    3
  END
  call writefile(lines, 'XTest_statusline', 'D')

  let buf = RunVimInTerminal('-S XTest_statusline', {'rows': 6})

  call term_sendkeys(buf, "g")
  call VerifyScreenDump(buf, 'Test_statusline_showcmd_1', {})

  " typing "gg" should open the fold
  call term_sendkeys(buf, "g")
  call VerifyScreenDump(buf, 'Test_statusline_showcmd_2', {})

  call term_sendkeys(buf, "\<C-V>Gl")
  call VerifyScreenDump(buf, 'Test_statusline_showcmd_3', {})

  call term_sendkeys(buf, "\<Esc>1234")
  call VerifyScreenDump(buf, 'Test_statusline_showcmd_4', {})

  call term_sendkeys(buf, "\<Esc>:set statusline=\<CR>")
  call term_sendkeys(buf, ":\<CR>")
  call term_sendkeys(buf, "1234")
  call VerifyScreenDump(buf, 'Test_statusline_showcmd_5', {})

  call StopVimInTerminal(buf)
endfunc

func Test_statusline_highlight_group_cleared()
  CheckScreendump

  " the laststatus option is there to prevent
  " the code-style test from complaining about
  " trailing whitespace
  let lines =<< trim END
    set fillchars=stl:\ ,stlnc:\  laststatus=2
    split
    hi clear StatusLine
    hi clear StatusLineNC
  END
  call writefile(lines, 'XTest_statusline_stl', 'D')

  let buf = RunVimInTerminal('-S XTest_statusline_stl', {})

  call VerifyScreenDump(buf, 'Test_statusline_stl_1', {})

  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
