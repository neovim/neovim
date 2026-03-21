
source check.vim
" CheckNotGui
" CheckUnix

source shared.vim
source mouse.vim
source view_util.vim
source term_util.vim

func Test_term_mouse_left_click()
  new
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " set mouse=a term=xterm
  set mouse=a
  call setline(1, ['line 1', 'line 2', 'line 3 is a bit longer'])
  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec + g:Ttymouse_netterm
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    go
    call assert_equal([0, 1, 1, 0], getpos('.'), msg)
    let row = 2
    let col = 6
    call MouseLeftClick(row, col)
    call MouseLeftRelease(row, col)
    call assert_equal([0, 2, 6, 0], getpos('.'), msg)
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
  bwipe!
endfunc

func Test_xterm_mouse_right_click_extends_visual()
  if has('mac')
    " throw "Skipped: test right click in visual mode does not work on macOs (why?)"
  endif
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " set mouse=a term=xterm
  set mouse=a

  for visual_mode in ["v", "V", "\<C-V>"]
    for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
      let msg = 'visual=' .. visual_mode .. ' ttymouse=' .. ttymouse_val
      " exe 'set ttymouse=' .. ttymouse_val

      call setline(1, repeat([repeat('-', 7)], 7))
      call MouseLeftClick(4, 4)
      call MouseLeftRelease(4, 4)
      exe  "norm! " .. visual_mode

      " Right click extends top left of visual area.
      call MouseRightClick(2, 2)
      call MouseRightRelease(2, 2)

      " Right click extends bottom right of visual area.
      call MouseRightClick(6, 6)
      call MouseRightRelease(6, 6)
      norm! r1gv

      " Right click shrinks top left of visual area.
      call MouseRightClick(3, 3)
      call MouseRightRelease(3, 3)

      " Right click shrinks bottom right of visual area.
      call MouseRightClick(5, 5)
      call MouseRightRelease(5, 5)
      norm! r2

      if visual_mode ==# 'v'
        call assert_equal(['-------',
              \            '-111111',
              \            '1122222',
              \            '2222222',
              \            '2222211',
              \            '111111-',
              \            '-------'], getline(1, '$'), msg)
      elseif visual_mode ==# 'V'
        call assert_equal(['-------',
              \            '1111111',
              \            '2222222',
              \            '2222222',
              \            '2222222',
              \            '1111111',
              \            '-------'], getline(1, '$'), msg)
      else
        call assert_equal(['-------',
              \            '-11111-',
              \            '-12221-',
              \            '-12221-',
              \            '-12221-',
              \            '-11111-',
              \            '-------'], getline(1, '$'), msg)
      endif
    endfor
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
  bwipe!
endfunc

" Test that <C-LeftMouse> jumps to help tag and <C-RightMouse> jumps back.
func Test_xterm_mouse_ctrl_click()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " set mouse=a term=xterm
  set mouse=a

  for ttymouse_val in g:Ttymouse_values
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    " help
    help usr_toc.txt
    /usr_02.txt
    norm! zt
    let row = 1
    let col = 1
    call MouseCtrlLeftClick(row, col)
    call MouseLeftRelease(row, col)
    call assert_match('usr_02.txt$', bufname('%'), msg)
    call assert_equal('*usr_02.txt*', expand('<cWORD>'), msg)

    call MouseCtrlRightClick(row, col)
    call MouseRightRelease(row, col)
    " call assert_match('help.txt$', bufname('%'), msg)
    call assert_match('usr_toc.txt$', bufname('%'), msg)
    call assert_equal('|usr_02.txt|', expand('<cWORD>'), msg)

    helpclose
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
endfunc

func Test_term_mouse_middle_click()
  CheckFeature clipboard_working

  new
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  let save_quotestar = @*
  let @* = 'abc'
  " set mouse=a term=xterm
  set mouse=a

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    call setline(1, ['123456789', '123456789'])

    " Middle-click in the middle of the line pastes text where clicked.
    let row = 1
    let col = 6
    call MouseMiddleClick(row, col)
    call MouseMiddleRelease(row, col)
    call assert_equal(['12345abc6789', '123456789'], getline(1, '$'), msg)

    " Middle-click beyond end of the line pastes text at the end of the line.
    let col = 20
    call MouseMiddleClick(row, col)
    call MouseMiddleRelease(row, col)
    call assert_equal(['12345abc6789abc', '123456789'], getline(1, '$'), msg)

    " Middle-click beyond the last line pastes in the last line.
    let row = 5
    let col = 3
    call MouseMiddleClick(row, col)
    call MouseMiddleRelease(row, col)
    call assert_equal(['12345abc6789abc', '12abc3456789'], getline(1, '$'), msg)
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
  let @* = save_quotestar
  bwipe!
endfunc

" TODO: for unclear reasons this test fails if it comes after
" Test_xterm_mouse_ctrl_click()
func Test_1xterm_mouse_wheel()
  new
  let save_mouse = &mouse
  let save_term = &term
  let save_wrap = &wrap
  " let save_ttymouse = &ttymouse
  " set mouse=a term=xterm nowrap
  set mouse=a nowrap
  call setline(1, range(100000000000000, 100000000000100))

  for ttymouse_val in g:Ttymouse_values
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    go
    call assert_equal(1, line('w0'), msg)
    call assert_equal([0, 1, 1, 0], getpos('.'), msg)

    call MouseWheelDown(1, 1)
    call assert_equal(4, line('w0'), msg)
    call assert_equal([0, 4, 1, 0], getpos('.'), msg)

    call MouseWheelDown(1, 1)
    call assert_equal(7, line('w0'), msg)
    call assert_equal([0, 7, 1, 0], getpos('.'), msg)

    call MouseWheelUp(1, 1)
    call assert_equal(4, line('w0'), msg)
    call assert_equal([0, 7, 1, 0], getpos('.'), msg)

    call MouseWheelUp(1, 1)
    call assert_equal(1, line('w0'), msg)
    call assert_equal([0, 7, 1, 0], getpos('.'), msg)

    call MouseWheelRight(1, 1)
    call assert_equal(7, 1 + virtcol(".") - wincol(), msg)
    call assert_equal([0, 7, 7, 0], getpos('.'), msg)

    call MouseWheelRight(1, 1)
    call assert_equal(13, 1 + virtcol(".") - wincol(), msg)
    call assert_equal([0, 7, 13, 0], getpos('.'), msg)

    call MouseWheelLeft(1, 1)
    call assert_equal(7, 1 + virtcol(".") - wincol(), msg)
    call assert_equal([0, 7, 13, 0], getpos('.'), msg)

    call MouseWheelLeft(1, 1)
    call assert_equal(1, 1 + virtcol(".") - wincol(), msg)
    call assert_equal([0, 7, 13, 0], getpos('.'), msg)

  endfor

  let &mouse = save_mouse
  " let &term = save_term
  let &wrap = save_wrap
  " let &ttymouse = save_ttymouse
  bwipe!
endfunc

" Test that dragging beyond the window (at the bottom and at the top)
" scrolls window content by the number of lines beyond the window.
func Test_term_mouse_drag_beyond_window()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " set mouse=a term=xterm
  set mouse=a
  let col = 1
  call setline(1, range(1, 100))

  " Split into 3 windows, and go into the middle window
  " so we test dragging mouse below and above the window.
  2split
  wincmd j
  2split

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val

    " Line #10 at the top.
    norm! 10zt
    redraw
    call assert_equal(10, winsaveview().topline, msg)
    call assert_equal(2, winheight(0), msg)

    let row = 4
    call MouseLeftClick(row, col)
    call assert_equal(10, winsaveview().topline, msg)

    " Drag downwards. We're still in the window so topline should
    " not change yet.
    let row += 1
    call MouseLeftDrag(row, col)
    call assert_equal(10, winsaveview().topline, msg)

    " We now leave the window at the bottom, so the window content should
    " scroll by 1 line, then 2 lines (etc) as we drag further away.
    let row += 1
    call MouseLeftDrag(row, col)
    call assert_equal(11, winsaveview().topline, msg)

    let row += 1
    call MouseLeftDrag(row, col)
    call assert_equal(13, winsaveview().topline, msg)

    " Now drag upwards.
    let row -= 1
    call MouseLeftDrag(row, col)
    call assert_equal(14, winsaveview().topline, msg)

    " We're now back in the window so the topline should not change.
    let row -= 1
    call MouseLeftDrag(row, col)
    call assert_equal(14, winsaveview().topline, msg)

    let row -= 1
    call MouseLeftDrag(row, col)
    call assert_equal(14, winsaveview().topline, msg)

    " We now leave the window at the top so the window content should
    " scroll by 1 line, then 2, then 3 (etc) in the opposite direction.
    let row -= 1
    call MouseLeftDrag(row, col)
    call assert_equal(13, winsaveview().topline, msg)

    let row -= 1
    call MouseLeftDrag(row, col)
    call assert_equal(11, winsaveview().topline, msg)

    let row -= 1
    call MouseLeftDrag(row, col)
    call assert_equal(8, winsaveview().topline, msg)

    call MouseLeftRelease(row, col)
    call assert_equal(8, winsaveview().topline, msg)
    call assert_equal(2, winheight(0), msg)
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
  bwipe!
endfunc

func Test_term_mouse_drag_window_separator()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " set mouse=a term=xterm
  set mouse=a

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val

    " Split horizontally and test dragging the horizontal window separator.
    split
    let rowseparator = winheight(0) + 1
    let row = rowseparator
    let col = 1

    " When 'ttymouse' is 'xterm2', row/col bigger than 223 are not supported.
    if ttymouse_val !=# 'xterm2' || row <= 223
      call MouseLeftClick(row, col)
      let row -= 1
      call MouseLeftDrag(row, col)
      call assert_equal(rowseparator - 1, winheight(0) + 1, msg)
      let row += 1
      call MouseLeftDrag(row, col)
      call assert_equal(rowseparator, winheight(0) + 1, msg)
      call MouseLeftRelease(row, col)
      call assert_equal(rowseparator, winheight(0) + 1, msg)
    endif
    bwipe!

    " Split vertically and test dragging the vertical window separator.
    vsplit
    let colseparator = winwidth(0) + 1
    let row = 1
    let col = colseparator

    " When 'ttymouse' is 'xterm2', row/col bigger than 223 are not supported.
    if ttymouse_val !=# 'xterm2' || col <= 223
      call MouseLeftClick(row, col)
      let col -= 1
      call MouseLeftDrag(row, col)
      call assert_equal(colseparator - 1, winwidth(0) + 1, msg)
      let col += 1
      call MouseLeftDrag(row, col)
      call assert_equal(colseparator, winwidth(0) + 1, msg)
      call MouseLeftRelease(row, col)
      call assert_equal(colseparator, winwidth(0) + 1, msg)
    endif
    bwipe!
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
endfunc

func Test_term_mouse_drag_statusline()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  let save_laststatus = &laststatus
  " set mouse=a term=xterm laststatus=2
  set mouse=a laststatus=2

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val

    call assert_equal(1, &cmdheight, msg)
    let rowstatusline = winheight(0) + 1
    let row = rowstatusline
    let col = 1

    if ttymouse_val ==# 'xterm2' && row > 223
      " When 'ttymouse' is 'xterm2', row/col bigger than 223 are not supported.
      continue
    endif

    call MouseLeftClick(row, col)
    let row -= 1
    call MouseLeftDrag(row, col)
    call assert_equal(2, &cmdheight, msg)
    call assert_equal(rowstatusline - 1, winheight(0) + 1, msg)
    let row += 1
    call MouseLeftDrag(row, col)
    call assert_equal(1, &cmdheight, msg)
    call assert_equal(rowstatusline, winheight(0) + 1, msg)
    call MouseLeftRelease(row, col)
    call assert_equal(1, &cmdheight, msg)
    call assert_equal(rowstatusline, winheight(0) + 1, msg)
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
  let &laststatus = save_laststatus
endfunc

func Test_term_mouse_click_tab()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " set mouse=a term=xterm
  set mouse=a
  let row = 1

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec + g:Ttymouse_netterm
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    e Xfoo
    tabnew Xbar

    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '#   Xfoo',
        \              'Tab page 2',
        \              '>   Xbar'], a, msg)

    " Test clicking on tab names in the tabline at the top.
    let col = 2
    redraw
    call MouseLeftClick(row, col)
    call MouseLeftRelease(row, col)
    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '>   Xfoo',
        \              'Tab page 2',
        \              '#   Xbar'], a, msg)

    let col = 9
    call MouseLeftClick(row, col)
    call MouseLeftRelease(row, col)
    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '#   Xfoo',
        \              'Tab page 2',
        \              '>   Xbar'], a, msg)

    %bwipe!
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
endfunc

func Test_term_mouse_click_X_to_close_tab()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " set mouse=a term=xterm
  set mouse=a
  let row = 1
  let col = &columns

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec + g:Ttymouse_netterm
    if ttymouse_val ==# 'xterm2' && col > 223
      " When 'ttymouse' is 'xterm2', row/col bigger than 223 are not supported.
      continue
    endif
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    e Xtab1
    tabnew Xtab2
    tabnew Xtab3
    tabn 2

    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '    Xtab1',
        \              'Tab page 2',
        \              '>   Xtab2',
        \              'Tab page 3',
        \              '#   Xtab3'], a, msg)

    " Click on "X" in tabline to close current tab i.e. Xtab2.
    redraw
    call MouseLeftClick(row, col)
    call MouseLeftRelease(row, col)
    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '    Xtab1',
        \              'Tab page 2',
        \              '>   Xtab3'], a, msg)

    %bwipe!
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
endfunc

func Test_term_mouse_drag_to_move_tab()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " Set 'mousetime' to 1 to avoid recognizing a double-click in the loop
  " set mouse=a term=xterm mousetime=1
  set mouse=a mousetime=0
  let row = 1

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    e Xtab1
    tabnew Xtab2

    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '#   Xtab1',
        \              'Tab page 2',
        \              '>   Xtab2'], a, msg)
    redraw

    " Click in tab2 and drag it to tab1.
    " Check getcharmod() to verify that click is not
    " interpreted as a spurious double-click.
    call MouseLeftClick(row, 10)
    call assert_equal(0, getcharmod(), msg)
    for col in [9, 8, 7, 6]
      call MouseLeftDrag(row, col)
    endfor
    call MouseLeftRelease(row, col)
    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '>   Xtab2',
        \              'Tab page 2',
        \              '#   Xtab1'], a, msg)

    " Switch to tab1
    tabnext
    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '#   Xtab2',
        \              'Tab page 2',
        \              '>   Xtab1'], a, msg)

    " Click in tab2 and drag it to tab1.
    " This time it is non-current tab.
    call MouseLeftClick(row, 6)
    call assert_equal(0, getcharmod(), msg)
    for col in [7, 8, 9, 10]
      call MouseLeftDrag(row, col)
    endfor
    call MouseLeftRelease(row, col)
    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '#   Xtab1',
        \              'Tab page 2',
        \              '>   Xtab2'], a, msg)

    " Click elsewhere so that click in next iteration is not
    " interpreted as unwanted double-click.
    call MouseLeftClick(row, 11)
    call MouseLeftRelease(row, 11)

    %bwipe!
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
  set mousetime&
endfunc

func Test_term_mouse_double_click_to_create_tab()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " Set 'mousetime' to a small value, so that double-click works but we don't
  " have to wait long to avoid a triple-click.
  " set mouse=a term=xterm mousetime=200
  set mouse=a mousetime=200
  let row = 1
  let col = 10

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    e Xtab1
    tabnew Xtab2

    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '#   Xtab1',
        \              'Tab page 2',
        \              '>   Xtab2'], a, msg)

    redraw
    call MouseLeftClick(row, col)
    " Check getcharmod() to verify that first click is not
    " interpreted as a spurious double-click.
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftRelease(row, col)
    call MouseLeftClick(row, col)
    call assert_equal(32, getcharmod(), msg) " double-click
    call MouseLeftRelease(row, col)
    let a = split(execute(':tabs'), "\n")
    call assert_equal(['Tab page 1',
        \              '    Xtab1',
        \              'Tab page 2',
        \              '>   [No Name]',
        \              'Tab page 3',
        \              '#   Xtab2'], a, msg)

    " Click elsewhere so that click in next iteration is not
    " interpreted as unwanted double click.
    call MouseLeftClick(row, col + 1)
    call MouseLeftRelease(row, col + 1)

    %bwipe!
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  " call test_override('no_query_mouse', 0)
  set mousetime&
endfunc

" Test double/triple/quadruple click in normal mode to visually select.
func Test_term_mouse_multiple_clicks_to_visually_select()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)

  " 'mousetime' must be sufficiently large, or else the test is flaky when
  " using a ssh connection with X forwarding; i.e. ssh -X (issue #7563).
  " set mouse=a term=xterm mousetime=600
  set mouse=a mousetime=600
  new

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    call setline(1, ['foo [foo bar] foo', 'foo'])

    " Double-click on word should visually select the word.
    call MouseLeftClick(1, 2)
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftRelease(1, 2)
    call MouseLeftClick(1, 2)
    call assert_equal(32, getcharmod(), msg) " double-click
    call MouseLeftRelease(1, 2)
    call assert_equal('v', mode(), msg)
    norm! r1
    call assert_equal(['111 [foo bar] foo', 'foo'], getline(1, '$'), msg)

    " Double-click on opening square bracket should visually
    " select the whole [foo bar].
    call MouseLeftClick(1, 5)
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftRelease(1, 5)
    call MouseLeftClick(1, 5)
    call assert_equal(32, getcharmod(), msg) " double-click
    call MouseLeftRelease(1, 5)
    call assert_equal('v', mode(), msg)
    norm! r2
    call assert_equal(['111 222222222 foo', 'foo'], getline(1, '$'), msg)

    " Triple-click should visually select the whole line.
    call MouseLeftClick(1, 3)
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftRelease(1, 3)
    call MouseLeftClick(1, 3)
    call assert_equal(32, getcharmod(), msg) " double-click
    call MouseLeftRelease(1, 3)
    call MouseLeftClick(1, 3)
    call assert_equal(64, getcharmod(), msg) " triple-click
    call MouseLeftRelease(1, 3)
    call assert_equal('V', mode(), msg)
    norm! r3
    call assert_equal(['33333333333333333', 'foo'], getline(1, '$'), msg)

    " Quadruple-click should start visual block select.
    call MouseLeftClick(1, 2)
    call assert_equal(0, getcharmod(), msg)
    call MouseLeftRelease(1, 2)
    call MouseLeftClick(1, 2)
    call assert_equal(32, getcharmod(), msg) " double-click
    call MouseLeftRelease(1, 2)
    call MouseLeftClick(1, 2)
    call assert_equal(64, getcharmod(), msg) " triple-click
    call MouseLeftRelease(1, 2)
    call MouseLeftClick(1, 2)
    call assert_equal(96, getcharmod(), msg) " quadruple-click
    call MouseLeftRelease(1, 2)
    call assert_equal("\<c-v>", mode(), msg)
    norm! r4
    call assert_equal(['34333333333333333', 'foo'], getline(1, '$'), msg)

    " Double-click on a space character should visually select all the
    " consecutive space characters.
    %d
    call setline(1, '    one two')
    call MouseLeftClick(1, 2)
    call MouseLeftRelease(1, 2)
    call MouseLeftClick(1, 2)
    call MouseLeftRelease(1, 2)
    call assert_equal('v', mode(), msg)
    norm! r1
    call assert_equal(['1111one two'], getline(1, '$'), msg)

    " Double-click on a word with exclusive selection
    set selection=exclusive
    let @" = ''
    call MouseLeftClick(1, 10)
    call MouseLeftRelease(1, 10)
    call MouseLeftClick(1, 10)
    call MouseLeftRelease(1, 10)
    norm! y
    call assert_equal('two', @", msg)

    " Double click to select a block of text with exclusive selection
    %d
    call setline(1, 'one (two) three')
    call MouseLeftClick(1, 5)
    call MouseLeftRelease(1, 5)
    call MouseLeftClick(1, 5)
    call MouseLeftRelease(1, 5)
    norm! y
    call assert_equal(5, col("'<"), msg)
    call assert_equal(10, col("'>"), msg)

    call MouseLeftClick(1, 9)
    call MouseLeftRelease(1, 9)
    call MouseLeftClick(1, 9)
    call MouseLeftRelease(1, 9)
    norm! y
    call assert_equal(5, col("'<"), msg)
    call assert_equal(10, col("'>"), msg)
    set selection&

    " Click somewhere else so that the clicks above is not combined with the
    " clicks in the next iteration.
    call MouseRightClick(3, 10)
    call MouseRightRelease(3, 10)
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  set mousetime&
  " call test_override('no_query_mouse', 0)
  bwipe!
endfunc

" Test for selecting text in visual blockwise mode using Alt-LeftClick
func Test_mouse_alt_leftclick()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " set mouse=a term=xterm mousetime=200
  set mouse=a mousetime=200
  set mousemodel=popup
  new
  call setline(1, 'one (two) three')

  for ttymouse_val in g:Ttymouse_values
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val

    " Left click with the Alt modifier key should extend the selection in
    " blockwise visual mode.
    let @" = ''
    call MouseLeftClick(1, 3)
    call MouseLeftRelease(1, 3)
    call MouseAltLeftClick(1, 11)
    call MouseLeftRelease(1, 11)
    call assert_equal("\<C-V>", mode(), msg)
    normal! y
    call assert_equal('e (two) t', @")
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  set mousetime& mousemodel&
  " call test_override('no_query_mouse', 0)
  bw!
endfunc

func Run_test_xterm_mouse_click_in_fold_columns()
  new
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  let save_foldcolumn = &foldcolumn
  " set mouse=a term=xterm foldcolumn=3 ttymouse=xterm2
  set mouse=a foldcolumn=3

  " Create 2 nested folds.
  call setline(1, range(1, 7))
  2,6fold
  norm! zR
  4,5fold
  call assert_equal([-1, -1, -1, 4, 4, -1, -1],
        \           map(range(1, 7), 'foldclosed(v:val)'))

  " Click in "+" of inner fold in foldcolumn should open it.
  redraw
  let row = 4
  let col = 2
  call MouseLeftClick(row, col)
  call MouseLeftRelease(row, col)
  call assert_equal([-1, -1, -1, -1, -1, -1, -1],
        \           map(range(1, 7), 'foldclosed(v:val)'))

  " Click in "-" of outer fold in foldcolumn should close it.
  redraw
  let row = 2
  let col = 1
  call MouseLeftClick(row, col)
  call MouseLeftRelease(row, col)
  call assert_equal([-1, 2, 2, 2, 2, 2, -1],
        \           map(range(1, 7), 'foldclosed(v:val)'))
  norm! zR

  " Click in "|" of inner fold in foldcolumn should close it.
  redraw
  let row = 5
  let col = 2
  call MouseLeftClick(row, col)
  call MouseLeftRelease(row, col)
  call assert_equal([-1, -1, -1, 4, 4, -1, -1],
        \           map(range(1, 7), 'foldclosed(v:val)'))

  let &foldcolumn = save_foldcolumn
  " Redraw at the end of the test to avoid interfering with other tests.
  defer execute('redraw')
  " let &ttymouse = save_ttymouse
  " let &term = save_term
  let &mouse = save_mouse
  bwipe!
endfunc

func Test_xterm_mouse_click_in_fold_columns()
  call Run_test_xterm_mouse_click_in_fold_columns()
  set fillchars+=foldclose:▶
  call Run_test_xterm_mouse_click_in_fold_columns()
  set fillchars-=foldclose:▶ fillchars+=foldclose:!
  call Run_test_xterm_mouse_click_in_fold_columns()
  set fillchars&
endfunc

" Test for the 'h' flag in the 'mouse' option. Using mouse in the help window.
func Test_term_mouse_help_window()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " set mouse=h term=xterm mousetime=200
  set mouse=h mousetime=200

  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val
    help
    let @" = ''
    call MouseLeftClick(2, 5)
    call MouseLeftRelease(2, 5)
    call MouseLeftClick(1, 1)
    call MouseLeftDrag(1, 10)
    call MouseLeftRelease(1, 10)
    norm! y
    call assert_equal('*help.txt*', @", msg)
    helpclose

    " Click somewhere else to make sure the left click above is not combined
    " with the next left click and treated as a double click
    call MouseRightClick(5, 10)
    call MouseRightRelease(5, 10)
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  set mousetime&
  " call test_override('no_query_mouse', 0)
  %bw!
endfunc

" Test for the translation of various mouse terminal codes
func Test_mouse_termcodes()
  let save_mouse = &mouse
  let save_term = &term
  " let save_ttymouse = &ttymouse
  " call test_override('no_query_mouse', 1)
  " set mouse=a term=xterm mousetime=200

  new
  for ttymouse_val in g:Ttymouse_values + g:Ttymouse_dec + g:Ttymouse_netterm
    let msg = 'ttymouse=' .. ttymouse_val
    " exe 'set ttymouse=' .. ttymouse_val

    let mouse_codes = [
          \ ["\<LeftMouse>", "<LeftMouse>"],
          \ ["\<MiddleMouse>", "<MiddleMouse>"],
          \ ["\<RightMouse>", "<RightMouse>"],
          \ ["\<S-LeftMouse>", "<S-LeftMouse>"],
          \ ["\<S-MiddleMouse>", "<S-MiddleMouse>"],
          \ ["\<S-RightMouse>", "<S-RightMouse>"],
          \ ["\<C-LeftMouse>", "<C-LeftMouse>"],
          \ ["\<C-MiddleMouse>", "<C-MiddleMouse>"],
          \ ["\<C-RightMouse>", "<C-RightMouse>"],
          \ ["\<M-LeftMouse>", "<M-LeftMouse>"],
          \ ["\<M-MiddleMouse>", "<M-MiddleMouse>"],
          \ ["\<M-RightMouse>", "<M-RightMouse>"],
          \ ["\<2-LeftMouse>", "<2-LeftMouse>"],
          \ ["\<2-MiddleMouse>", "<2-MiddleMouse>"],
          \ ["\<2-RightMouse>", "<2-RightMouse>"],
          \ ["\<3-LeftMouse>", "<3-LeftMouse>"],
          \ ["\<3-MiddleMouse>", "<3-MiddleMouse>"],
          \ ["\<3-RightMouse>", "<3-RightMouse>"],
          \ ["\<4-LeftMouse>", "<4-LeftMouse>"],
          \ ["\<4-MiddleMouse>", "<4-MiddleMouse>"],
          \ ["\<4-RightMouse>", "<4-RightMouse>"],
          \ ["\<LeftDrag>", "<LeftDrag>"],
          \ ["\<MiddleDrag>", "<MiddleDrag>"],
          \ ["\<RightDrag>", "<RightDrag>"],
          \ ["\<LeftRelease>", "<LeftRelease>"],
          \ ["\<MiddleRelease>", "<MiddleRelease>"],
          \ ["\<RightRelease>", "<RightRelease>"],
          \ ["\<ScrollWheelUp>", "<ScrollWheelUp>"],
          \ ["\<S-ScrollWheelUp>", "<S-ScrollWheelUp>"],
          \ ["\<C-ScrollWheelUp>", "<C-ScrollWheelUp>"],
          \ ["\<ScrollWheelDown>", "<ScrollWheelDown>"],
          \ ["\<S-ScrollWheelDown>", "<S-ScrollWheelDown>"],
          \ ["\<C-ScrollWheelDown>", "<C-ScrollWheelDown>"],
          \ ["\<ScrollWheelLeft>", "<ScrollWheelLeft>"],
          \ ["\<S-ScrollWheelLeft>", "<S-ScrollWheelLeft>"],
          \ ["\<C-ScrollWheelLeft>", "<C-ScrollWheelLeft>"],
          \ ["\<ScrollWheelRight>", "<ScrollWheelRight>"],
          \ ["\<S-ScrollWheelRight>", "<S-ScrollWheelRight>"],
          \ ["\<C-ScrollWheelRight>", "<C-ScrollWheelRight>"]
          \ ]

    for [code, outstr] in mouse_codes
      exe "normal ggC\<C-K>" . code
      call assert_equal(outstr, getline(1), msg)
    endfor
  endfor

  let &mouse = save_mouse
  " let &term = save_term
  " let &ttymouse = save_ttymouse
  set mousetime&
  " call test_override('no_query_mouse', 0)
  %bw!
endfunc

" Test for translation of special key codes (<xF1>, <xF2>, etc.)
func Test_Keycode_Translation()
  let keycodes = [
        \ ["<xUp>", "<Up>"],
        \ ["<xDown>", "<Down>"],
        \ ["<xLeft>", "<Left>"],
        \ ["<xRight>", "<Right>"],
        \ ["<xHome>", "<Home>"],
        \ ["<xEnd>", "<End>"],
        \ ["<zHome>", "<Home>"],
        \ ["<zEnd>", "<End>"],
        \ ["<xF1>", "<F1>"],
        \ ["<xF2>", "<F2>"],
        \ ["<xF3>", "<F3>"],
        \ ["<xF4>", "<F4>"],
        \ ["<S-xF1>", "<S-F1>"],
        \ ["<S-xF2>", "<S-F2>"],
        \ ["<S-xF3>", "<S-F3>"],
        \ ["<S-xF4>", "<S-F4>"]]
  for [k1, k2] in keycodes
    exe "nnoremap " .. k1 .. " 2wx"
    call assert_true(maparg(k1, 'n', 0, 1).lhs == k2)
    exe "nunmap " .. k1
  endfor
endfunc

" Test for terminal keycodes that doesn't have termcap entries
func Test_special_term_keycodes()
  new
  " Test for <xHome>, <S-xHome> and <C-xHome>
  " send <K_SPECIAL> <KS_EXTRA> keycode
  call feedkeys("i\<C-K>\x80\xfd\x3f\n", 'xt')
  " send <K_SPECIAL> <KS_MODIFIER> bitmap <K_SPECIAL> <KS_EXTRA> keycode
  call feedkeys("i\<C-K>\x80\xfc\x2\x80\xfd\x3f\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x4\x80\xfd\x3f\n", 'xt')
  " Test for <xEnd>, <S-xEnd> and <C-xEnd>
  call feedkeys("i\<C-K>\x80\xfd\x3d\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x2\x80\xfd\x3d\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x4\x80\xfd\x3d\n", 'xt')
  " Test for <zHome>, <S-zHome> and <C-zHome>
  call feedkeys("i\<C-K>\x80\xfd\x40\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x2\x80\xfd\x40\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x4\x80\xfd\x40\n", 'xt')
  " Test for <zEnd>, <S-zEnd> and <C-zEnd>
  call feedkeys("i\<C-K>\x80\xfd\x3e\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x2\x80\xfd\x3e\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x4\x80\xfd\x3e\n", 'xt')
  " Test for <xUp>, <xDown>, <xLeft> and <xRight>
  call feedkeys("i\<C-K>\x80\xfd\x41\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfd\x42\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfd\x43\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfd\x44\n", 'xt')
  call assert_equal(['<Home>', '<S-Home>', '<C-Home>',
        \ '<End>', '<S-End>', '<C-End>',
        \ '<Home>', '<S-Home>', '<C-Home>',
        \ '<End>', '<S-End>', '<C-End>',
        \ '<Up>', '<Down>', '<Left>', '<Right>', ''], getline(1, '$'))
  bw!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
