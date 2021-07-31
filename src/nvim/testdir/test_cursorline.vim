" Test for cursorline and cursorlineopt
"
source view_util.vim
source check.vim

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
