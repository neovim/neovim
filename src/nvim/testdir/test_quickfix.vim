" Test for the quickfix commands.

if !has('quickfix')
  finish
endif

set encoding=utf-8

function! s:setup_commands(cchar)
  if a:cchar == 'c'
    command! -nargs=* -bang Xlist <mods>clist<bang> <args>
    command! -nargs=* Xgetexpr <mods>cgetexpr <args>
    command! -nargs=* Xolder <mods>colder <args>
    command! -nargs=* Xnewer <mods>cnewer <args>
    command! -nargs=* Xopen <mods>copen <args>
    command! -nargs=* Xwindow <mods>cwindow <args>
    command! -nargs=* Xclose <mods>cclose <args>
    command! -nargs=* -bang Xfile <mods>cfile<bang> <args>
    command! -nargs=* Xgetfile <mods>cgetfile <args>
    command! -nargs=* Xaddfile <mods>caddfile <args>
    command! -nargs=* -bang Xbuffer <mods>cbuffer<bang> <args>
    command! -nargs=* Xgetbuffer <mods>cgetbuffer <args>
    command! -nargs=* Xaddbuffer <mods>caddbuffer <args>
    command! -nargs=* Xrewind <mods>crewind <args>
    command! -nargs=* -bang Xnext <mods>cnext<bang> <args>
    command! -nargs=* Xexpr <mods>cexpr <args>
    command! -nargs=* Xvimgrep <mods>vimgrep <args>
    let g:Xgetlist = function('getqflist')
    let g:Xsetlist = function('setqflist')
  else
    command! -nargs=* -bang Xlist <mods>llist<bang> <args>
    command! -nargs=* Xgetexpr <mods>lgetexpr <args>
    command! -nargs=* Xolder <mods>lolder <args>
    command! -nargs=* Xnewer <mods>lnewer <args>
    command! -nargs=* Xopen <mods>lopen <args>
    command! -nargs=* Xwindow <mods>lwindow <args>
    command! -nargs=* Xclose <mods>lclose <args>
    command! -nargs=* -bang Xfile <mods>lfile<bang> <args>
    command! -nargs=* Xgetfile <mods>lgetfile <args>
    command! -nargs=* Xaddfile <mods>laddfile <args>
    command! -nargs=* -bang Xbuffer <mods>lbuffer<bang> <args>
    command! -nargs=* Xgetbuffer <mods>lgetbuffer <args>
    command! -nargs=* Xaddbuffer <mods>laddbuffer <args>
    command! -nargs=* Xrewind <mods>lrewind <args>
    command! -nargs=* -bang Xnext <mods>lnext<bang> <args>
    command! -nargs=* Xexpr <mods>lexpr <args>
    command! -nargs=* Xvimgrep <mods>lvimgrep <args>
    let g:Xgetlist = function('getloclist', [0])
    let g:Xsetlist = function('setloclist', [0])
  endif
endfunction

" Tests for the :clist and :llist commands
function XlistTests(cchar)
  call s:setup_commands(a:cchar)

  " With an empty list, command should return error
  Xgetexpr []
  silent! Xlist
  call assert_true(v:errmsg ==# 'E42: No Errors')

  " Populate the list and then try
  Xgetexpr ['non-error 1', 'Xtestfile1:1:3:Line1',
		  \ 'non-error 2', 'Xtestfile2:2:2:Line2',
		  \ 'non-error 3', 'Xtestfile3:3:1:Line3']

  " List only valid entries
  redir => result
  Xlist
  redir END
  let l = split(result, "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 6 Xtestfile3:3 col 1: Line3'], l)

  " List all the entries
  redir => result
  Xlist!
  redir END
  let l = split(result, "\n")
  call assert_equal([' 1: non-error 1', ' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 5: non-error 3', ' 6 Xtestfile3:3 col 1: Line3'], l)

  " List a range of errors
  redir => result
  Xlist 3,6
  redir END
  let l = split(result, "\n")
  call assert_equal([' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 6 Xtestfile3:3 col 1: Line3'], l)

  redir => result
  Xlist! 3,4
  redir END
  let l = split(result, "\n")
  call assert_equal([' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2'], l)

  redir => result
  Xlist -6,-4
  redir END
  let l = split(result, "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1'], l)

  redir => result
  Xlist! -5,-3
  redir END
  let l = split(result, "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2'], l)
endfunction

function Test_clist()
  call XlistTests('c')
  call XlistTests('l')
endfunction

" Tests for the :colder, :cnewer, :lolder and :lnewer commands
" Note that this test assumes that a quickfix/location list is
" already set by the caller.
function XageTests(cchar)
  call s:setup_commands(a:cchar)

  " Jumping to a non existent list should return error
  silent! Xolder 99
  call assert_true(v:errmsg ==# 'E380: At bottom of quickfix stack')

  silent! Xnewer 99
  call assert_true(v:errmsg ==# 'E381: At top of quickfix stack')

  " Add three quickfix/location lists
  Xgetexpr ['Xtestfile1:1:3:Line1']
  Xgetexpr ['Xtestfile2:2:2:Line2']
  Xgetexpr ['Xtestfile3:3:1:Line3']

  " Go back two lists
  Xolder
  let l = g:Xgetlist()
  call assert_equal('Line2', l[0].text)

  " Go forward two lists
  Xnewer
  let l = g:Xgetlist()
  call assert_equal('Line3', l[0].text)

  " Test for the optional count argument
  Xolder 2
  let l = g:Xgetlist()
  call assert_equal('Line1', l[0].text)

  Xnewer 2
  let l = g:Xgetlist()
  call assert_equal('Line3', l[0].text)
endfunction

function Test_cage()
  let list = [{'bufnr': 1, 'lnum': 1}]
  call setqflist(list)
  call XageTests('c')

  call setloclist(0, list)
  call XageTests('l')
endfunction

" Tests for the :cwindow, :lwindow :cclose, :lclose, :copen and :lopen
" commands
function XwindowTests(cchar)
  call s:setup_commands(a:cchar)

  " Create a list with no valid entries
  Xgetexpr ['non-error 1', 'non-error 2', 'non-error 3']

  " Quickfix/Location window should not open with no valid errors
  Xwindow
  call assert_true(winnr('$') == 1)

  " Create a list with valid entries
  Xgetexpr ['Xtestfile1:1:3:Line1', 'Xtestfile2:2:2:Line2',
		  \ 'Xtestfile3:3:1:Line3']

  " Open the window
  Xwindow
  call assert_true(winnr('$') == 2 && winnr() == 2 &&
	\ getline('.') ==# 'Xtestfile1|1 col 3| Line1')

  " Close the window
  Xclose
  call assert_true(winnr('$') == 1)

  " Create a list with no valid entries
  Xgetexpr ['non-error 1', 'non-error 2', 'non-error 3']

  " Open the window
  Xopen 5
  call assert_true(winnr('$') == 2 && getline('.') ==# '|| non-error 1'
		      \  && winheight('.') == 5)

  " Opening the window again, should move the cursor to that window
  wincmd t
  Xopen 7
  call assert_true(winnr('$') == 2 && winnr() == 2 &&
	\ winheight('.') == 7 &&
	\ getline('.') ==# '|| non-error 1')


  " Calling cwindow should close the quickfix window with no valid errors
  Xwindow
  call assert_true(winnr('$') == 1)
endfunction

function Test_cwindow()
  call XwindowTests('c')
  call XwindowTests('l')
endfunction

" Tests for the :cfile, :lfile, :caddfile, :laddfile, :cgetfile and :lgetfile
" commands.
function XfileTests(cchar)
  call s:setup_commands(a:cchar)

  call writefile(['Xtestfile1:700:10:Line 700',
	\ 'Xtestfile2:800:15:Line 800'], 'Xqftestfile1')

  enew!
  Xfile Xqftestfile1
  let l = g:Xgetlist()
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 700 && l[0].col == 10 && l[0].text ==# 'Line 700' &&
	\ l[1].lnum == 800 && l[1].col == 15 && l[1].text ==# 'Line 800')

  " Run cfile/lfile from a modified buffer
  enew!
  silent! put ='Quickfix'
  silent! Xfile Xqftestfile1
  call assert_true(v:errmsg ==# 'E37: No write since last change (add ! to override)')

  call writefile(['Xtestfile3:900:30:Line 900'], 'Xqftestfile1')
  Xaddfile Xqftestfile1
  let l = g:Xgetlist()
  call assert_true(len(l) == 3 &&
	\ l[2].lnum == 900 && l[2].col == 30 && l[2].text ==# 'Line 900')

  call writefile(['Xtestfile1:222:77:Line 222',
	\ 'Xtestfile2:333:88:Line 333'], 'Xqftestfile1')

  enew!
  Xgetfile Xqftestfile1
  let l = g:Xgetlist()
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 222 && l[0].col == 77 && l[0].text ==# 'Line 222' &&
	\ l[1].lnum == 333 && l[1].col == 88 && l[1].text ==# 'Line 333')

  call delete('Xqftestfile1')
endfunction

function Test_cfile()
  call XfileTests('c')
  call XfileTests('l')
endfunction

" Tests for the :cbuffer, :lbuffer, :caddbuffer, :laddbuffer, :cgetbuffer and
" :lgetbuffer commands.
function XbufferTests(cchar)
  call s:setup_commands(a:cchar)

  enew!
  silent! call setline(1, ['Xtestfile7:700:10:Line 700',
	\ 'Xtestfile8:800:15:Line 800'])
  Xbuffer!
  let l = g:Xgetlist()
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 700 && l[0].col == 10 && l[0].text ==# 'Line 700' &&
	\ l[1].lnum == 800 && l[1].col == 15 && l[1].text ==# 'Line 800')

  enew!
  silent! call setline(1, ['Xtestfile9:900:55:Line 900',
	\ 'Xtestfile10:950:66:Line 950'])
  Xgetbuffer
  let l = g:Xgetlist()
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 900 && l[0].col == 55 && l[0].text ==# 'Line 900' &&
	\ l[1].lnum == 950 && l[1].col == 66 && l[1].text ==# 'Line 950')

  enew!
  silent! call setline(1, ['Xtestfile11:700:20:Line 700',
	\ 'Xtestfile12:750:25:Line 750'])
  Xaddbuffer
  let l = g:Xgetlist()
  call assert_true(len(l) == 4 &&
	\ l[1].lnum == 950 && l[1].col == 66 && l[1].text ==# 'Line 950' &&
	\ l[2].lnum == 700 && l[2].col == 20 && l[2].text ==# 'Line 700' &&
	\ l[3].lnum == 750 && l[3].col == 25 && l[3].text ==# 'Line 750')
  enew!

endfunction

function Test_cbuffer()
  call XbufferTests('c')
  call XbufferTests('l')
endfunction

function Test_helpgrep()
  helpgrep quickfix
  copen
  " This wipes out the buffer, make sure that doesn't cause trouble.
  cclose
endfunc

func Test_errortitle()
  augroup QfBufWinEnter
    au!
    au BufWinEnter * :let g:a=get(w:, 'quickfix_title', 'NONE')
  augroup END
  copen
  let a=[{'lnum': 308, 'bufnr': bufnr(''), 'col': 58, 'valid': 1, 'vcol': 0, 'nr': 0, 'type': '', 'pattern': '', 'text': '    au BufWinEnter * :let g:a=get(w:, ''quickfix_title'', ''NONE'')'}]
  call setqflist(a)
  call assert_equal(':setqflist()', g:a)
  augroup QfBufWinEnter
    au!
  augroup END
  augroup! QfBufWinEnter
endfunc

func Test_vimgreptitle()
  augroup QfBufWinEnter
    au!
    au BufWinEnter * :let g:a=get(w:, 'quickfix_title', 'NONE')
  augroup END
  try
    vimgrep /pattern/j file
  catch /E480/
  endtry
  copen
  call assert_equal(':    vimgrep /pattern/j file', g:a)
  augroup QfBufWinEnter
    au!
  augroup END
  augroup! QfBufWinEnter
endfunc

function XqfTitleTests(cchar)
  call s:setup_commands(a:cchar)

  Xgetexpr ['file:1:1:message']
  let l = g:Xgetlist()
  if a:cchar == 'c'
    call setqflist(l, 'r')
  else
    call setloclist(0, l, 'r')
  endif

  Xopen
  if a:cchar == 'c'
    let title = ':setqflist()'
  else
    let title = ':setloclist()'
  endif
  call assert_equal(title, w:quickfix_title)
  Xclose
endfunction

" Tests for quickfix window's title
function Test_qf_title()
  call XqfTitleTests('c')
  call XqfTitleTests('l')
endfunction

" Tests for 'errorformat'
function Test_efm()
  let save_efm = &efm
  set efm=%EEEE%m,%WWWW%m,%+CCCC%.%#,%-GGGG%.%#
  cgetexpr ['WWWW', 'EEEE', 'CCCC']
  let l = strtrans(string(map(getqflist(), '[v:val.text, v:val.valid]')))
  call assert_equal("[['W', 1], ['E^@CCCC', 1]]", l)
  cgetexpr ['WWWW', 'GGGG', 'EEEE', 'CCCC']
  let l = strtrans(string(map(getqflist(), '[v:val.text, v:val.valid]')))
  call assert_equal("[['W', 1], ['E^@CCCC', 1]]", l)
  cgetexpr ['WWWW', 'GGGG', 'ZZZZ', 'EEEE', 'CCCC', 'YYYY']
  let l = strtrans(string(map(getqflist(), '[v:val.text, v:val.valid]')))
  call assert_equal("[['W', 1], ['ZZZZ', 0], ['E^@CCCC', 1], ['YYYY', 0]]", l)
  let &efm = save_efm
endfunction

" This will test for problems in quickfix:
" A. incorrectly copying location lists which caused the location list to show
"    a different name than the file that was actually being displayed.
" B. not reusing the window for which the location list window is opened but
"    instead creating new windows.
" C. make sure that the location list window is not reused instead of the
"    window it belongs to.
"
" Set up the test environment:
function! ReadTestProtocol(name)
  let base = substitute(a:name, '\v^test://(.*)%(\.[^.]+)?', '\1', '')
  let word = substitute(base, '\v(.*)\..*', '\1', '')

  setl modifiable
  setl noreadonly
  setl noswapfile
  setl bufhidden=delete
  %del _
  " For problem 2:
  " 'buftype' has to be set to reproduce the constant opening of new windows
  setl buftype=nofile

  call setline(1, word)

  setl nomodified
  setl nomodifiable
  setl readonly
  exe 'doautocmd BufRead ' . substitute(a:name, '\v^test://(.*)', '\1', '')
endfunction

function Test_locationlist()
    enew

    augroup testgroup
      au!
      autocmd BufReadCmd test://* call ReadTestProtocol(expand("<amatch>"))
    augroup END

    let words = [ "foo", "bar", "baz", "quux", "shmoo", "spam", "eggs" ]

    let qflist = []
    for word in words
      call add(qflist, {'filename': 'test://' . word . '.txt', 'text': 'file ' . word . '.txt', })
      " NOTE: problem 1:
      " intentionally not setting 'lnum' so that the quickfix entries are not
      " valid
      call setloclist(0, qflist, ' ')
    endfor

    " Test A
    lrewind
    enew
    lopen
    lnext
    lnext
    lnext
    lnext
    vert split
    wincmd L
    lopen
    wincmd p
    lnext
    let fileName = expand("%")
    wincmd p
    let locationListFileName = substitute(getline(line('.')), '\([^|]*\)|.*', '\1', '')
    let fileName = substitute(fileName, '\\', '/', 'g')
    let locationListFileName = substitute(locationListFileName, '\\', '/', 'g')
    call assert_equal("test://bar.txt", fileName)
    call assert_equal("test://bar.txt", locationListFileName)

    wincmd n | only

    " Test B:
    lrewind
    lopen
    2
    exe "normal \<CR>"
    wincmd p
    3
    exe "normal \<CR>"
    wincmd p
    4
    exe "normal \<CR>"
    call assert_equal(2, winnr('$'))
    wincmd n | only

    " Test C:
    lrewind
    lopen
    " Let's move the location list window to the top to check whether it (the
    " first window found) will be reused when we try to open new windows:
    wincmd K
    2
    exe "normal \<CR>"
    wincmd p
    3
    exe "normal \<CR>"
    wincmd p
    4
    exe "normal \<CR>"
    1wincmd w
    call assert_equal('quickfix', &buftype)
    2wincmd w
    let bufferName = expand("%")
    let bufferName = substitute(bufferName, '\\', '/', 'g')
    call assert_equal('test://quux.txt', bufferName)

    wincmd n | only

    augroup! testgroup
endfunction

function Test_locationlist_curwin_was_closed()
    augroup testgroup
      au!
      autocmd BufReadCmd test_curwin.txt call R(expand("<amatch>"))
    augroup END

    function! R(n)
      quit
    endfunc

    new
    let q = []
    call add(q, {'filename': 'test_curwin.txt' })
    call setloclist(0, q)
    call assert_fails('lrewind', 'E924:')

    augroup! testgroup
endfunction

" More tests for 'errorformat'
function! Test_efm1()
    if !has('unix')
	" The 'errorformat' setting is different on non-Unix systems.
	" This test works only on Unix-like systems.
	return
    endif

    let l = [
      \ '"Xtestfile", line 4.12: 1506-045 (S) Undeclared identifier fd_set.',
      \ '﻿"Xtestfile", line 6 col 19; this is an error',
      \ 'gcc -c -DHAVE_CONFIsing-prototypes -I/usr/X11R6/include  version.c',
      \ 'Xtestfile:9: parse error before `asd''',
      \ 'make: *** [vim] Error 1',
      \ 'in file "Xtestfile" linenr 10: there is an error',
      \ '',
      \ '2 returned',
      \ '"Xtestfile", line 11 col 1; this is an error',
      \ '"Xtestfile", line 12 col 2; this is another error',
      \ '"Xtestfile", line 14:10; this is an error in column 10',
      \ '=Xtestfile=, line 15:10; this is another error, but in vcol 10 this time',
      \ '"Xtestfile", linenr 16: yet another problem',
      \ 'Error in "Xtestfile" at line 17:',
      \ 'x should be a dot',
      \ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 17',
      \ '            ^',
      \ 'Error in "Xtestfile" at line 18:',
      \ 'x should be a dot',
      \ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 18',
      \ '.............^',
      \ 'Error in "Xtestfile" at line 19:',
      \ 'x should be a dot',
      \ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 19',
      \ '--------------^',
      \ 'Error in "Xtestfile" at line 20:',
      \ 'x should be a dot',
      \ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 20',
      \ '	       ^',
      \ '',
      \ 'Does anyone know what is the problem and how to correction it?',
      \ '"Xtestfile", line 21 col 9: What is the title of the quickfix window?',
      \ '"Xtestfile", line 22 col 9: What is the title of the quickfix window?'
      \ ]

    call writefile(l, 'Xerrorfile1')
    call writefile(l[:-2], 'Xerrorfile2')

    let m = [
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  2',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  3',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  4',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  5',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  6',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  7',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  8',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  9',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 10',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 11',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 12',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 13',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 14',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 15',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 16',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 17',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 18',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 19',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 20',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 21',
	\ '	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 22'
	\ ]
    call writefile(m, 'Xtestfile')

    let save_efm = &efm
    set efm+==%f=\\,\ line\ %l%*\\D%v%*[^\ ]\ %m
    set efm^=%AError\ in\ \"%f\"\ at\ line\ %l:,%Z%p^,%C%m

    exe 'cf Xerrorfile2'
    clast
    copen
    call assert_equal(':cf Xerrorfile2', w:quickfix_title)
    wincmd p

    exe 'cf Xerrorfile1'
    call assert_equal([4, 12], [line('.'), col('.')])
    cn
    call assert_equal([6, 19], [line('.'), col('.')])
    cn
    call assert_equal([9, 2], [line('.'), col('.')])
    cn
    call assert_equal([10, 2], [line('.'), col('.')])
    cn
    call assert_equal([11, 1], [line('.'), col('.')])
    cn
    call assert_equal([12, 2], [line('.'), col('.')])
    cn
    call assert_equal([14, 10], [line('.'), col('.')])
    cn
    call assert_equal([15, 3, 10], [line('.'), col('.'), virtcol('.')])
    cn
    call assert_equal([16, 2], [line('.'), col('.')])
    cn
    call assert_equal([17, 6], [line('.'), col('.')])
    cn
    call assert_equal([18, 7], [line('.'), col('.')])
    cn
    call assert_equal([19, 8], [line('.'), col('.')])
    cn
    call assert_equal([20, 9], [line('.'), col('.')])
    clast
    cprev
    cprev
    wincmd w
    call assert_equal(':cf Xerrorfile1', w:quickfix_title)
    wincmd p

    let &efm = save_efm
    call delete('Xerrorfile1')
    call delete('Xerrorfile2')
    call delete('Xtestfile')
endfunction

" Test for quickfix directory stack support
function! s:dir_stack_tests(cchar)
  call s:setup_commands(a:cchar)

  let save_efm=&efm
  set efm=%DEntering\ dir\ '%f',%f:%l:%m,%XLeaving\ dir\ '%f'

  let l = "Entering dir 'dir1/a'\n" .
		\ 'habits2.txt:1:Nine Healthy Habits' . "\n" .
		\ "Entering dir 'b'\n" .
		\ 'habits3.txt:2:0 Hours of television' . "\n" .
		\ 'habits2.txt:7:5 Small meals' . "\n" .
		\ "Entering dir 'dir1/c'\n" .
		\ 'habits4.txt:3:1 Hour of exercise' . "\n" .
		\ "Leaving dir 'dir1/c'\n" .
		\ "Leaving dir 'dir1/a'\n" .
		\ 'habits1.txt:4:2 Liters of water' . "\n" .
		\ "Entering dir 'dir2'\n" .
		\ 'habits5.txt:5:3 Cups of hot green tea' . "\n"
		\ "Leaving dir 'dir2'\n"

  Xgetexpr l

  let qf = g:Xgetlist()

  call assert_equal('dir1/a/habits2.txt', bufname(qf[1].bufnr))
  call assert_equal(1, qf[1].lnum)
  call assert_equal('dir1/a/b/habits3.txt', bufname(qf[3].bufnr))
  call assert_equal(2, qf[3].lnum)
  call assert_equal('dir1/a/habits2.txt', bufname(qf[4].bufnr))
  call assert_equal(7, qf[4].lnum)
  call assert_equal('dir1/c/habits4.txt', bufname(qf[6].bufnr))
  call assert_equal(3, qf[6].lnum)
  call assert_equal('habits1.txt', bufname(qf[9].bufnr))
  call assert_equal(4, qf[9].lnum)
  call assert_equal('dir2/habits5.txt', bufname(qf[11].bufnr))
  call assert_equal(5, qf[11].lnum)

  let &efm=save_efm
endfunction

" Tests for %D and %X errorformat options
function! Test_efm_dirstack()
  " Create the directory stack and files
  call mkdir('dir1')
  call mkdir('dir1/a')
  call mkdir('dir1/a/b')
  call mkdir('dir1/c')
  call mkdir('dir2')

  let lines = ["Nine Healthy Habits",
		\ "0 Hours of television",
		\ "1 Hour of exercise",
		\ "2 Liters of water",
		\ "3 Cups of hot green tea",
		\ "4 Short mental breaks",
		\ "5 Small meals",
		\ "6 AM wake up time",
		\ "7 Minutes of laughter",
		\ "8 Hours of sleep (at least)",
		\ "9 PM end of the day and off to bed"
		\ ]
  call writefile(lines, 'habits1.txt')
  call writefile(lines, 'dir1/a/habits2.txt')
  call writefile(lines, 'dir1/a/b/habits3.txt')
  call writefile(lines, 'dir1/c/habits4.txt')
  call writefile(lines, 'dir2/habits5.txt')

  call s:dir_stack_tests('c')
  call s:dir_stack_tests('l')

  call delete('dir1', 'rf')
  call delete('dir2', 'rf')
  call delete('habits1.txt')
endfunction

function XquickfixChangedByAutocmd(cchar)
  call s:setup_commands(a:cchar)
  if a:cchar == 'c'
    let ErrorNr = 'E925'
    function! ReadFunc()
      colder
      cgetexpr []
    endfunc
  else
    let ErrorNr = 'E926'
    function! ReadFunc()
      lolder
      lgetexpr []
    endfunc
  endif

  augroup testgroup
    au!
    autocmd BufReadCmd test_changed.txt call ReadFunc()
  augroup END

  new | only
  let words = [ "a", "b" ]
  let qflist = []
  for word in words
    call add(qflist, {'filename': 'test_changed.txt'})
    call g:Xsetlist(qflist, ' ')
  endfor
  call assert_fails('Xrewind', ErrorNr . ':')

  augroup! testgroup
endfunc

function Test_quickfix_was_changed_by_autocmd()
  call XquickfixChangedByAutocmd('c')
  call XquickfixChangedByAutocmd('l')
endfunction

func Test_caddbuffer_to_empty()
  helpgr quickfix
  call setqflist([], 'r')
  cad
  try
    cn
  catch
    " number of matches is unknown
    call assert_true(v:exception =~ 'E553:')
  endtry
  quit!
endfunc

func Test_cgetexpr_works()
  " this must not crash Vim
  cgetexpr [$x]
  lgetexpr [$x]
endfunc

" Tests for the setqflist() and setloclist() functions
function SetXlistTests(cchar, bnum)
  call s:setup_commands(a:cchar)

  call g:Xsetlist([{'bufnr': a:bnum, 'lnum': 1},
	      \  {'bufnr': a:bnum, 'lnum': 2}])
  let l = g:Xgetlist()
  call assert_equal(2, len(l))
  call assert_equal(2, l[1].lnum)

  Xnext
  call g:Xsetlist([{'bufnr': a:bnum, 'lnum': 3}], 'a')
  let l = g:Xgetlist()
  call assert_equal(3, len(l))
  Xnext
  call assert_equal(3, line('.'))

  " Appending entries to the list should not change the cursor position
  " in the quickfix window
  Xwindow
  1
  call g:Xsetlist([{'bufnr': a:bnum, 'lnum': 4},
	      \  {'bufnr': a:bnum, 'lnum': 5}], 'a')
  call assert_equal(1, line('.'))
  close

  call g:Xsetlist([{'bufnr': a:bnum, 'lnum': 3},
	      \  {'bufnr': a:bnum, 'lnum': 4},
	      \  {'bufnr': a:bnum, 'lnum': 5}], 'r')
  let l = g:Xgetlist()
  call assert_equal(3, len(l))
  call assert_equal(5, l[2].lnum)

  call g:Xsetlist([])
  let l = g:Xgetlist()
  call assert_equal(0, len(l))
endfunction

function Test_setqflist()
  new Xtestfile | only
  let bnum = bufnr('%')
  call setline(1, range(1,5))

  call SetXlistTests('c', bnum)
  call SetXlistTests('l', bnum)

  enew!
  call delete('Xtestfile')
endfunction

function Xlist_empty_middle(cchar)
  call s:setup_commands(a:cchar)

  " create three quickfix lists
  Xvimgrep Test_ test_quickfix.vim
  let testlen = len(g:Xgetlist())
  call assert_true(testlen > 0)
  Xvimgrep empty test_quickfix.vim
  call assert_true(len(g:Xgetlist()) > 0)
  Xvimgrep matches test_quickfix.vim
  let matchlen = len(g:Xgetlist())
  call assert_true(matchlen > 0)
  Xolder
  " make the middle list empty
  call g:Xsetlist([], 'r')
  call assert_true(len(g:Xgetlist()) == 0)
  Xolder
  call assert_equal(testlen, len(g:Xgetlist()))
  Xnewer
  Xnewer
  call assert_equal(matchlen, len(g:Xgetlist()))
endfunc

function Test_setqflist_empty_middle()
  call Xlist_empty_middle('c')
  call Xlist_empty_middle('l')
endfunction

function Xlist_empty_older(cchar)
  call s:setup_commands(a:cchar)

  " create three quickfix lists
  Xvimgrep one test_quickfix.vim
  let onelen = len(g:Xgetlist())
  call assert_true(onelen > 0)
  Xvimgrep two test_quickfix.vim
  let twolen = len(g:Xgetlist())
  call assert_true(twolen > 0)
  Xvimgrep three test_quickfix.vim
  let threelen = len(g:Xgetlist())
  call assert_true(threelen > 0)
  Xolder 2
  " make the first list empty, check the others didn't change
  call g:Xsetlist([], 'r')
  call assert_true(len(g:Xgetlist()) == 0)
  Xnewer
  call assert_equal(twolen, len(g:Xgetlist()))
  Xnewer
  call assert_equal(threelen, len(g:Xgetlist()))
endfunction

function Test_setqflist_empty_older()
  call Xlist_empty_older('c')
  call Xlist_empty_older('l')
endfunction

function! XquickfixSetListWithAct(cchar)
  call s:setup_commands(a:cchar)

  let list1 = [{'filename': 'fnameA', 'text': 'A'},
          \    {'filename': 'fnameB', 'text': 'B'}]
  let list2 = [{'filename': 'fnameC', 'text': 'C'},
          \    {'filename': 'fnameD', 'text': 'D'},
          \    {'filename': 'fnameE', 'text': 'E'}]

  " {action} is unspecified.  Same as specifing ' '.
  new | only
  silent! Xnewer 99
  call g:Xsetlist(list1)
  call g:Xsetlist(list2)
  let li = g:Xgetlist()
  call assert_equal(3, len(li))
  call assert_equal('C', li[0]['text'])
  call assert_equal('D', li[1]['text'])
  call assert_equal('E', li[2]['text'])
  silent! Xolder
  let li = g:Xgetlist()
  call assert_equal(2, len(li))
  call assert_equal('A', li[0]['text'])
  call assert_equal('B', li[1]['text'])

  " {action} is specified ' '.
  new | only
  silent! Xnewer 99
  call g:Xsetlist(list1)
  call g:Xsetlist(list2, ' ')
  let li = g:Xgetlist()
  call assert_equal(3, len(li))
  call assert_equal('C', li[0]['text'])
  call assert_equal('D', li[1]['text'])
  call assert_equal('E', li[2]['text'])
  silent! Xolder
  let li = g:Xgetlist()
  call assert_equal(2, len(li))
  call assert_equal('A', li[0]['text'])
  call assert_equal('B', li[1]['text'])

  " {action} is specified 'a'.
  new | only
  silent! Xnewer 99
  call g:Xsetlist(list1)
  call g:Xsetlist(list2, 'a')
  let li = g:Xgetlist()
  call assert_equal(5, len(li))
  call assert_equal('A', li[0]['text'])
  call assert_equal('B', li[1]['text'])
  call assert_equal('C', li[2]['text'])
  call assert_equal('D', li[3]['text'])
  call assert_equal('E', li[4]['text'])

  " {action} is specified 'r'.
  new | only
  silent! Xnewer 99
  call g:Xsetlist(list1)
  call g:Xsetlist(list2, 'r')
  let li = g:Xgetlist()
  call assert_equal(3, len(li))
  call assert_equal('C', li[0]['text'])
  call assert_equal('D', li[1]['text'])
  call assert_equal('E', li[2]['text'])

  " Test for wrong value.
  new | only
  call assert_fails("call g:Xsetlist(0)", 'E714:')
  call assert_fails("call g:Xsetlist(list1, '')", 'E927:')
  call assert_fails("call g:Xsetlist(list1, 'aa')", 'E927:')
  call assert_fails("call g:Xsetlist(list1, ' a')", 'E927:')
  call assert_fails("call g:Xsetlist(list1, 0)", 'E928:')
endfunc

function Test_quickfix_set_list_with_act()
  call XquickfixSetListWithAct('c')
  call XquickfixSetListWithAct('l')
endfunction

function XLongLinesTests(cchar)
  let l = g:Xgetlist()

  call assert_equal(3, len(l))
  call assert_equal(1, l[0].lnum)
  call assert_equal(1, l[0].col)
  call assert_equal(4070, len(l[0].text))
  call assert_equal(2, l[1].lnum)
  call assert_equal(1, l[1].col)
  call assert_equal(4070, len(l[1].text))
  call assert_equal(3, l[2].lnum)
  call assert_equal(1, l[2].col)
  call assert_equal(10, len(l[2].text))

  call g:Xsetlist([], 'r')
endfunction

function s:long_lines_tests(cchar)
  call s:setup_commands(a:cchar)

  let testfile = 'samples/quickfix.txt'

  " file
  exe 'Xgetfile' testfile
  call XLongLinesTests(a:cchar)

  " list
  Xexpr readfile(testfile)
  call XLongLinesTests(a:cchar)

  " string
  Xexpr join(readfile(testfile), "\n")
  call XLongLinesTests(a:cchar)

  " buffer
  exe 'edit' testfile
  exe 'Xbuffer' bufnr('%')
  call XLongLinesTests(a:cchar)
endfunction

function Test_long_lines()
  call s:long_lines_tests('c')
  call s:long_lines_tests('l')
endfunction
