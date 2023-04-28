" Helper functions for generating mouse events

let g:Ttymouse_values = ['sgr']
let g:Ttymouse_dec = []
let g:Ttymouse_netterm = []

func MouseLeftClick(row, col)
  call nvim_input_mouse('left', 'press', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseMiddleClick(row, col)
  call nvim_input_mouse('middle', 'press', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseRightClick(row, col)
  call nvim_input_mouse('right', 'press', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseCtrlLeftClick(row, col)
  call nvim_input_mouse('left', 'press', 'C', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseCtrlRightClick(row, col)
  call nvim_input_mouse('right', 'press', 'C', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseAltLeftClick(row, col)
  call nvim_input_mouse('left', 'press', 'A', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseAltRightClick(row, col)
  call nvim_input_mouse('right', 'press', 'A', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseLeftRelease(row, col)
  call nvim_input_mouse('left', 'release', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseMiddleRelease(row, col)
  call nvim_input_mouse('middle', 'release', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseRightRelease(row, col)
  call nvim_input_mouse('right', 'release', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseLeftDrag(row, col)
  call nvim_input_mouse('left', 'drag', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseWheelUp(row, col)
  call nvim_input_mouse('wheel', 'up', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseWheelDown(row, col)
  call nvim_input_mouse('wheel', 'down', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseWheelLeft(row, col)
  call nvim_input_mouse('wheel', 'left', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

func MouseWheelRight(row, col)
  call nvim_input_mouse('wheel', 'right', '', 0, a:row - 1, a:col - 1)
  call getchar(1)
  call feedkeys('', 'x!')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
