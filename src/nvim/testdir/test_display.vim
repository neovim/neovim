" Test for displaying stuff

" Nvim: `:set term` is not supported.
" if !has('gui_running') && has('unix')
"   set term=ansi
" endif

source view_util.vim

func! Test_display_foldcolumn()
  if !has("folding")
    return
  endif
  new
  vnew
  vert resize 25
  call assert_equal(25, winwidth(winnr()))
  set isprint=@

  1put='e more noise blah blah more stuff here'

  let expect = [
        \ "e more noise blah blah<82",
        \ "> more stuff here        "
        \ ]

  call cursor(2, 1)
  norm! zt
  let lines=ScreenLines([1,2], winwidth(0))
  call assert_equal(expect, lines)
  set fdc=2
  let lines=ScreenLines([1,2], winwidth(0))
  let expect = [
        \ "  e more noise blah blah<",
        \ "  82> more stuff here    "
        \ ]
  call assert_equal(expect, lines)

  quit!
  quit!
endfunc

func! Test_display_foldtext_mbyte()
  if !has("folding") || !has("multi_byte")
    return
  endif
  call NewWindow(10, 40)
  call append(0, range(1,20))
  exe "set foldmethod=manual foldtext=foldtext() fillchars=fold:\u2500,vert:\u2502 fdc=2"
  call cursor(2, 1)
  norm! zf13G
  let lines=ScreenLines([1,3], winwidth(0)+1)
  let expect=[
        \ "  1                                     \u2502",
        \ "+ +-- 12 lines: 2". repeat("\u2500", 23). "\u2502",
        \ "  14                                    \u2502",
        \ ]
  call assert_equal(expect, lines)

  set fillchars=fold:-,vert:\|
  let lines=ScreenLines([1,3], winwidth(0)+1)
  let expect=[
        \ "  1                                     |",
        \ "+ +-- 12 lines: 2". repeat("-", 23). "|",
        \ "  14                                    |",
        \ ]
  call assert_equal(expect, lines)

  set foldtext& fillchars& foldmethod& fdc&
  bw!
endfunc
