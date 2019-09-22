" Functions about view shared by several tests

" Only load this script once.
if exists('*ScreenLines')
  finish
endif

" ScreenLines(lnum, width) or
" ScreenLines([start, end], width)
function! ScreenLines(lnum, width) abort
  redraw!
  if type(a:lnum) == v:t_list
    let start = a:lnum[0]
    let end = a:lnum[1]
  else
    let start = a:lnum
    let end = a:lnum
  endif
  let lines = []
  for l in range(start, end)
    let lines += [join(map(range(1, a:width), 'nr2char(screenchar(l, v:val))'), '')]
  endfor
  return lines
endfunction

function! ScreenAttrs(lnum, width) abort
  redraw!
  if type(a:lnum) == v:t_list
    let start = a:lnum[0]
    let end = a:lnum[1]
  else
    let start = a:lnum
    let end = a:lnum
  endif
  let attrs = []
  for l in range(start, end)
    let attrs += [map(range(1, a:width), 'screenattr(l, v:val)')]
  endfor
  return attrs
endfunction

function! NewWindow(height, width) abort
  exe a:height . 'new'
  exe a:width . 'vsp'
  set winfixwidth winfixheight
  redraw!
endfunction

function! CloseWindow() abort
  bw!
  redraw!
endfunction
