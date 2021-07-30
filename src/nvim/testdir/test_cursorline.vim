" Test for cursorline and cursorlineopt

source check.vim
source screendump.vim

function! s:screen_attr(lnum) abort
  return map(range(1, 8), 'screenattr(a:lnum, v:val)')
endfunction

function! s:test_windows(h, w) abort
  call NewWindow(a:h, a:w)
endfunction

function! s:close_windows() abort
  call CloseWindow()
endfunction

function! s:new_hi() abort
  redir => save_hi
  silent! hi CursorLineNr
  redir END
  let save_hi = join(split(substitute(save_hi, '\s*xxx\s*', ' ', ''), "\n"), '')
  exe 'hi' save_hi 'ctermbg=0 guibg=Black'
  return save_hi
endfunction

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
    call assert_equal(attr21[0:3], attr31[0:3])
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
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_1', {})
  call term_sendkeys(buf, "fagj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_2', {})
  call term_sendkeys(buf, "gj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_3', {})
  call term_sendkeys(buf, "gj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_4', {})
  call term_sendkeys(buf, "gj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_5', {})
  call term_sendkeys(buf, "gj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_6', {})
  " test with set list and cursorlineopt containing number
  call term_sendkeys(buf, "gg0")
  call term_sendkeys(buf, ":set list cursorlineopt+=number listchars=space:-\<cr>")
  call VerifyScreenDump(buf, 'Test_'. filename. '_7', {})
  call term_sendkeys(buf, "fagj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_8', {})
  call term_sendkeys(buf, "gj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_9', {})
  call term_sendkeys(buf, "gj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_10', {})
  call term_sendkeys(buf, "gj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_11', {})
  call term_sendkeys(buf, "gj")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_'. filename. '_12', {})
  if exists("+foldcolumn") && exists("+signcolumn") && exists("+breakindent")
    " test with set foldcolumn signcoloumn and breakindent
    call term_sendkeys(buf, "gg0")
    call term_sendkeys(buf, ":set breakindent foldcolumn=2 signcolumn=yes\<cr>")
    call VerifyScreenDump(buf, 'Test_'. filename. '_13', {})
    call term_sendkeys(buf, "fagj")
    call term_wait(buf)
    call VerifyScreenDump(buf, 'Test_'. filename. '_14', {})
    call term_sendkeys(buf, "gj")
    call term_wait(buf)
    call VerifyScreenDump(buf, 'Test_'. filename. '_15', {})
    call term_sendkeys(buf, "gj")
    call term_wait(buf)
    call VerifyScreenDump(buf, 'Test_'. filename. '_16', {})
    call term_sendkeys(buf, "gj")
    call term_wait(buf)
    call VerifyScreenDump(buf, 'Test_'. filename. '_17', {})
    call term_sendkeys(buf, "gj")
    call term_wait(buf)
    call VerifyScreenDump(buf, 'Test_'. filename. '_18', {})
  endif

  call StopVimInTerminal(buf)
  call delete(filename)
endfunc
