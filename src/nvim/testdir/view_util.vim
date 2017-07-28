" Functions about view shared by several tests

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

function! NewWindow(height, width) abort
  exe a:height . 'new'
  exe a:width . 'vsp'
  redraw!
endfunction

function! CloseWindow() abort
  bw!
  redraw!
endfunction
