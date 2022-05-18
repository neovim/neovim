" Tests for cursor() and other functions that get/set the cursor position

func Test_wrong_arguments()
  call assert_fails('call cursor(1. 3)', 'E474:')
endfunc

func Test_move_cursor()
  new
  call setline(1, ['aaa', 'bbb', 'ccc', 'ddd'])

  call cursor([1, 1, 0, 1])
  call assert_equal([1, 1, 0, 1], getcurpos()[1:])
  call cursor([4, 3, 0, 3])
  call assert_equal([4, 3, 0, 3], getcurpos()[1:])

  call cursor(2, 2)
  call assert_equal([2, 2, 0, 2], getcurpos()[1:])
  " line number zero keeps the line number
  call cursor(0, 1)
  call assert_equal([2, 1, 0, 1], getcurpos()[1:])
  " col number zero keeps the column
  call cursor(3, 0)
  call assert_equal([3, 1, 0, 1], getcurpos()[1:])
  " below last line goes to last line
  call cursor(9, 1)
  call assert_equal([4, 1, 0, 1], getcurpos()[1:])
  " pass string arguments
  call cursor('3', '3')
  call assert_equal([3, 3, 0, 3], getcurpos()[1:])

  call setline(1, ["\<TAB>"])
  call cursor(1, 1, 1)
  call assert_equal([1, 1, 1], getcurpos()[1:3])

  call assert_equal(-1, cursor(-1, -1))

  quit!
endfunc

" Very short version of what matchparen does.
function s:Highlight_Matching_Pair()
  let save_cursor = getcurpos()
  eval save_cursor->setpos('.')
endfunc

func Test_curswant_with_autocommand()
  new
  call setline(1, ['func()', '{', '}', '----'])
  autocmd! CursorMovedI * call s:Highlight_Matching_Pair()
  exe "normal! 3Ga\<Down>X\<Esc>"
  call assert_equal('-X---', getline(4))
  autocmd! CursorMovedI *
  quit!
endfunc

" Tests for behavior of curswant with cursorcolumn/line
func Test_curswant_with_cursorcolumn()
  new
  call setline(1, ['01234567', ''])
  exe "normal! ggf6j"
  call assert_equal(6, winsaveview().curswant)
  set cursorcolumn
  call assert_equal(6, winsaveview().curswant)
  quit!
endfunc

func Test_curswant_with_cursorline()
  new
  call setline(1, ['01234567', ''])
  exe "normal! ggf6j"
  call assert_equal(6, winsaveview().curswant)
  set cursorline
  call assert_equal(6, winsaveview().curswant)
  quit!
endfunc

func Test_screenpos()
  rightbelow new
  rightbelow 20vsplit
  call setline(1, ["\tsome text", "long wrapping line here", "next line"])
  redraw
  let winid = win_getid()
  let [winrow, wincol] = win_screenpos(winid)
  call assert_equal({'row': winrow,
    \ 'col': wincol + 0,
    \ 'curscol': wincol + 7,
    \ 'endcol': wincol + 7}, winid->screenpos(1, 1))
  call assert_equal({'row': winrow,
    \ 'col': wincol + 13,
    \ 'curscol': wincol + 13,
    \ 'endcol': wincol + 13}, winid->screenpos(1, 7))
  call assert_equal({'row': winrow + 2,
    \ 'col': wincol + 1,
    \ 'curscol': wincol + 1,
    \ 'endcol': wincol + 1}, screenpos(winid, 2, 22))
  setlocal number
  call assert_equal({'row': winrow + 3,
    \ 'col': wincol + 9,
    \ 'curscol': wincol + 9,
    \ 'endcol': wincol + 9}, screenpos(winid, 2, 22))
  close
  bwipe!

  call assert_equal({'col': 1, 'row': 1, 'endcol': 1, 'curscol': 1}, screenpos(win_getid(), 1, 1))
  " nmenu WinBar.TEST :
  setlocal winbar=TEST
  call assert_equal({'col': 1, 'row': 2, 'endcol': 1, 'curscol': 1}, screenpos(win_getid(), 1, 1))
  " nunmenu WinBar.TEST
  setlocal winbar&
endfunc

func Test_screenpos_number()
  rightbelow new
  rightbelow 73vsplit
  call setline (1, repeat('x', 66))
  setlocal number
  redraw
  let winid = win_getid()
  let [winrow, wincol] = win_screenpos(winid)
  let pos = screenpos(winid, 1, 66)
  call assert_equal(winrow, pos.row)
  call assert_equal(wincol + 66 + 3, pos.col)
  close
  bwipe!
endfunc

" Save the visual start character position
func SaveVisualStartCharPos()
  call add(g:VisualStartPos, getcharpos('v'))
  return ''
endfunc

" Save the current cursor character position in insert mode
func SaveInsertCurrentCharPos()
  call add(g:InsertCurrentPos, getcharpos('.'))
  return ''
endfunc

" Test for the getcharpos() function
func Test_getcharpos()
  call assert_fails('call getcharpos({})', 'E731:')
  call assert_equal([0, 0, 0, 0], getcharpos(0))
  new
  call setline(1, ['', "01\tà4è678", 'Ⅵ', '012345678', ' │  x'])

  " Test for '.' and '$'
  normal 1G
  call assert_equal([0, 1, 1, 0], getcharpos('.'))
  call assert_equal([0, 5, 1, 0], getcharpos('$'))
  normal 2G6l
  call assert_equal([0, 2, 7, 0], getcharpos('.'))
  normal 3G$
  call assert_equal([0, 3, 1, 0], getcharpos('.'))
  normal 4G$
  call assert_equal([0, 4, 9, 0], getcharpos('.'))

  " Test for a mark
  normal 2G7lmmgg
  call assert_equal([0, 2, 8, 0], getcharpos("'m"))
  delmarks m
  call assert_equal([0, 0, 0, 0], getcharpos("'m"))

  " Check mark does not move
  normal 5Gfxma
  call assert_equal([0, 5, 5, 0], getcharpos("'a"))
  call assert_equal([0, 5, 5, 0], getcharpos("'a"))
  call assert_equal([0, 5, 5, 0], getcharpos("'a"))

  " Test for the visual start column
  vnoremap <expr> <F3> SaveVisualStartCharPos()
  let g:VisualStartPos = []
  exe "normal 2G6lv$\<F3>ohh\<F3>o\<F3>"
  call assert_equal([[0, 2, 7, 0], [0, 2, 10, 0], [0, 2, 5, 0]], g:VisualStartPos)
  call assert_equal([0, 2, 9, 0], getcharpos('v'))
  let g:VisualStartPos = []
  exe "normal 3Gv$\<F3>o\<F3>"
  call assert_equal([[0, 3, 1, 0], [0, 3, 2, 0]], g:VisualStartPos)
  let g:VisualStartPos = []
  exe "normal 1Gv$\<F3>o\<F3>"
  call assert_equal([[0, 1, 1, 0], [0, 1, 1, 0]], g:VisualStartPos)
  vunmap <F3>

  " Test for getting the position in insert mode with the cursor after the
  " last character in a line
  inoremap <expr> <F3> SaveInsertCurrentCharPos()
  let g:InsertCurrentPos = []
  exe "normal 1GA\<F3>"
  exe "normal 2GA\<F3>"
  exe "normal 3GA\<F3>"
  exe "normal 4GA\<F3>"
  exe "normal 2G6li\<F3>"
  call assert_equal([[0, 1, 1, 0], [0, 2, 10, 0], [0, 3, 2, 0], [0, 4, 10, 0],
                        \ [0, 2, 7, 0]], g:InsertCurrentPos)
  iunmap <F3>

  %bw!
endfunc

" Test for the setcharpos() function
func Test_setcharpos()
  call assert_equal(-1, setcharpos('.', v:_null_list))
  new
  call setline(1, ['', "01\tà4è678", 'Ⅵ', '012345678'])
  call setcharpos('.', [0, 1, 1, 0])
  call assert_equal([1, 1], [line('.'), col('.')])
  call setcharpos('.', [0, 2, 7, 0])
  call assert_equal([2, 9], [line('.'), col('.')])
  call setcharpos('.', [0, 3, 4, 0])
  call assert_equal([3, 1], [line('.'), col('.')])
  call setcharpos('.', [0, 3, 1, 0])
  call assert_equal([3, 1], [line('.'), col('.')])
  call setcharpos('.', [0, 4, 0, 0])
  call assert_equal([4, 1], [line('.'), col('.')])
  call setcharpos('.', [0, 4, 20, 0])
  call assert_equal([4, 9], [line('.'), col('.')])

  " Test for mark
  delmarks m
  call setcharpos("'m", [0, 2, 9, 0])
  normal `m
  call assert_equal([2, 11], [line('.'), col('.')])
  " unload the buffer and try to set the mark
  let bnr = bufnr()
  enew!
  call assert_equal(-1, setcharpos("'m", [bnr, 2, 2, 0]))

  %bw!
  call assert_equal(-1, setcharpos('.', [10, 3, 1, 0]))
endfunc

func SaveVisualStartCharCol()
  call add(g:VisualStartCol, charcol('v'))
  return ''
endfunc

func SaveInsertCurrentCharCol()
  call add(g:InsertCurrentCol, charcol('.'))
  return ''
endfunc

" Test for the charcol() function
func Test_charcol()
  call assert_fails('call charcol({})', 'E731:')
  call assert_equal(0, charcol(0))
  new
  call setline(1, ['', "01\tà4è678", 'Ⅵ', '012345678'])

  " Test for '.' and '$'
  normal 1G
  call assert_equal(1, charcol('.'))
  call assert_equal(1, charcol('$'))
  normal 2G6l
  call assert_equal(7, charcol('.'))
  call assert_equal(10, charcol('$'))
  normal 3G$
  call assert_equal(1, charcol('.'))
  call assert_equal(2, charcol('$'))
  normal 4G$
  call assert_equal(9, charcol('.'))
  call assert_equal(10, charcol('$'))

  " Test for [lnum, '$']
  call assert_equal(1, charcol([1, '$']))
  call assert_equal(10, charcol([2, '$']))
  call assert_equal(2, charcol([3, '$']))
  call assert_equal(0, charcol([5, '$']))

  " Test for a mark
  normal 2G7lmmgg
  call assert_equal(8, charcol("'m"))
  delmarks m
  call assert_equal(0, charcol("'m"))

  " Test for the visual start column
  vnoremap <expr> <F3> SaveVisualStartCharCol()
  let g:VisualStartCol = []
  exe "normal 2G6lv$\<F3>ohh\<F3>o\<F3>"
  call assert_equal([7, 10, 5], g:VisualStartCol)
  call assert_equal(9, charcol('v'))
  let g:VisualStartCol = []
  exe "normal 3Gv$\<F3>o\<F3>"
  call assert_equal([1, 2], g:VisualStartCol)
  let g:VisualStartCol = []
  exe "normal 1Gv$\<F3>o\<F3>"
  call assert_equal([1, 1], g:VisualStartCol)
  vunmap <F3>

  " Test for getting the column number in insert mode with the cursor after
  " the last character in a line
  inoremap <expr> <F3> SaveInsertCurrentCharCol()
  let g:InsertCurrentCol = []
  exe "normal 1GA\<F3>"
  exe "normal 2GA\<F3>"
  exe "normal 3GA\<F3>"
  exe "normal 4GA\<F3>"
  exe "normal 2G6li\<F3>"
  call assert_equal([1, 10, 2, 10, 7], g:InsertCurrentCol)
  iunmap <F3>

  %bw!
endfunc

func SaveInsertCursorCharPos()
  call add(g:InsertCursorPos, getcursorcharpos('.'))
  return ''
endfunc

" Test for getcursorcharpos()
func Test_getcursorcharpos()
  call assert_equal(getcursorcharpos(), getcursorcharpos(0))
  call assert_equal([0, 0, 0, 0, 0], getcursorcharpos(-1))
  call assert_equal([0, 0, 0, 0, 0], getcursorcharpos(1999))

  new
  call setline(1, ['', "01\tà4è678", 'Ⅵ', '012345678'])
  normal 1G9l
  call assert_equal([0, 1, 1, 0, 1], getcursorcharpos())
  normal 2G9l
  call assert_equal([0, 2, 9, 0, 14], getcursorcharpos())
  normal 3G9l
  call assert_equal([0, 3, 1, 0, 1], getcursorcharpos())
  normal 4G9l
  call assert_equal([0, 4, 9, 0, 9], getcursorcharpos())

  " Test for getting the cursor position in insert mode with the cursor after
  " the last character in a line
  inoremap <expr> <F3> SaveInsertCursorCharPos()
  let g:InsertCursorPos = []
  exe "normal 1GA\<F3>"
  exe "normal 2GA\<F3>"
  exe "normal 3GA\<F3>"
  exe "normal 4GA\<F3>"
  exe "normal 2G6li\<F3>"
  call assert_equal([[0, 1, 1, 0, 1], [0, 2, 10, 0, 15], [0, 3, 2, 0, 2],
                    \ [0, 4, 10, 0, 10], [0, 2, 7, 0, 12]], g:InsertCursorPos)
  iunmap <F3>

  let winid = win_getid()
  normal 2G5l
  wincmd w
  call assert_equal([0, 2, 6, 0, 11], getcursorcharpos(winid))
  %bw!
endfunc

" Test for setcursorcharpos()
func Test_setcursorcharpos()
  call assert_fails('call setcursorcharpos(v:_null_list)', 'E474:')
  call assert_fails('call setcursorcharpos([1])', 'E474:')
  call assert_fails('call setcursorcharpos([1, 1, 1, 1, 1])', 'E474:')
  new
  call setline(1, ['', "01\tà4è678", 'Ⅵ', '012345678'])
  normal G
  call setcursorcharpos([1, 1])
  call assert_equal([1, 1], [line('.'), col('.')])
  call setcursorcharpos([2, 7, 0])
  call assert_equal([2, 9], [line('.'), col('.')])
  call setcursorcharpos(3, 4)
  call assert_equal([3, 1], [line('.'), col('.')])
  call setcursorcharpos([3, 1])
  call assert_equal([3, 1], [line('.'), col('.')])
  call setcursorcharpos([4, 0, 0, 0])
  call assert_equal([4, 1], [line('.'), col('.')])
  call setcursorcharpos([4, 20])
  call assert_equal([4, 9], [line('.'), col('.')])
  normal 1G
  call setcursorcharpos([100, 100, 100, 100])
  call assert_equal([4, 9], [line('.'), col('.')])
  normal 1G
  call setcursorcharpos('$', 1)
  call assert_equal([4, 1], [line('.'), col('.')])

  %bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
