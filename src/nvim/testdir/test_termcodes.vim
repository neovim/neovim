" Tests for decoding escape sequences sent by the terminal.

" This only works for Unix in a terminal
if has('gui_running') || !has('unix')
  finish
endif

func Test_xterm_mouse_click()
  throw 'Skipped: Nvim does not support feeding terminal escape sequences'
  new
  let save_mouse = &mouse
  let save_term = &term
  let save_ttymouse = &ttymouse
  set mouse=a
  set term=xterm
  call setline(1, ['line 1', 'line 2', 'line 3 is a bit longer'])
  redraw

  " Xterm mouse click
  set ttymouse=xterm
  let button = 0x20  " left down
  let row = 2 + 32
  let col = 6 + 32
  call feedkeys("\<Esc>[M" .. list2str([button, col, row]), 'Lx!')

  let button = 0x23  " release
  call feedkeys("\<Esc>[M" .. list2str([button, col, row]), 'Lx!')

  call assert_equal([0, 2, 6, 0], getpos('.'))

  " SGR mouse click
  set ttymouse=sgr
  let button = 0  " left down
  let row = 3
  let col = 9
  call feedkeys(printf("\<Esc>[<%d;%d;%dM", button, col, row), 'Lx!')

  let button = 3  " release
  call feedkeys(printf("\<Esc>[<%d;%d;%dm", button, col, row), 'Lx!')

  call assert_equal([0, 3, 9, 0], getpos('.'))

  let &mouse = save_mouse
  let &term = save_term
  let &ttymouse = save_ttymouse
  bwipe!
endfunc

