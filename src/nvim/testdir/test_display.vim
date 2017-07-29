" Test for displaying stuff
if !has('gui_running') && has('unix')
  set term=ansi
endif

function! s:screenline(lnum, nr) abort
  let line = []
  for j in range(a:nr)
    for c in range(1, winwidth(0))
        call add(line, nr2char(screenchar(a:lnum+j, c)))
    endfor
    call add(line, "\n")
  endfor
  return join(line, '')
endfunction

function! Test_display_foldcolumn()
  new
  vnew
  vert resize 25
  call assert_equal(25, winwidth(winnr()))
  set isprint=@

  1put='e more noise blah blah more stuff here'

  let expect = "e more noise blah blah<82\n> more stuff here        \n"

  call cursor(2, 1)
  norm! zt
  redraw!
  call assert_equal(expect, s:screenline(1,2))
  set fdc=2
  redraw!
  let expect = "  e more noise blah blah<\n  82> more stuff here    \n"
  call assert_equal(expect, s:screenline(1,2))

  quit!
  quit!
endfunction
