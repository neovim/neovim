" Test for the quickfix commands.

if !has('quickfix')
  finish
endif

set encoding=utf-8

" Tests for the :clist and :llist commands
function XlistTests(cchar)
  let Xlist = a:cchar . 'list'
  let Xgetexpr = a:cchar . 'getexpr'

  " With an empty list, command should return error
  exe Xgetexpr . ' []'
  exe 'silent! ' . Xlist
  call assert_true(v:errmsg ==# 'E42: No Errors')

  " Populate the list and then try
  exe Xgetexpr . " ['non-error 1', 'Xtestfile1:1:3:Line1',
		  \ 'non-error 2', 'Xtestfile2:2:2:Line2',
		  \ 'non-error 3', 'Xtestfile3:3:1:Line3']"

  " List only valid entries
  redir => result
  exe Xlist
  redir END
  let l = split(result, "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 6 Xtestfile3:3 col 1: Line3'], l)

  " List all the entries
  redir => result
  exe Xlist . "!"
  redir END
  let l = split(result, "\n")
  call assert_equal([' 1: non-error 1', ' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 5: non-error 3', ' 6 Xtestfile3:3 col 1: Line3'], l)

  " List a range of errors
  redir => result
  exe Xlist . " 3,6"
  redir END
  let l = split(result, "\n")
  call assert_equal([' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 6 Xtestfile3:3 col 1: Line3'], l)

  redir => result
  exe Xlist . "! 3,4"
  redir END
  let l = split(result, "\n")
  call assert_equal([' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2'], l)

  redir => result
  exe Xlist . " -6,-4"
  redir END
  let l = split(result, "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1'], l)

  redir => result
  exe Xlist . "! -5,-3"
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
  let Xolder = a:cchar . 'older'
  let Xnewer = a:cchar . 'newer'
  let Xgetexpr = a:cchar . 'getexpr'
  if a:cchar == 'c'
    let Xgetlist = 'getqflist()'
  else
    let Xgetlist = 'getloclist(0)'
  endif

  " Jumping to a non existent list should return error
  exe 'silent! ' . Xolder . ' 99'
  call assert_true(v:errmsg ==# 'E380: At bottom of quickfix stack')

  exe 'silent! ' . Xnewer . ' 99'
  call assert_true(v:errmsg ==# 'E381: At top of quickfix stack')

  " Add three quickfix/location lists
  exe Xgetexpr . " ['Xtestfile1:1:3:Line1']"
  exe Xgetexpr . " ['Xtestfile2:2:2:Line2']"
  exe Xgetexpr . " ['Xtestfile3:3:1:Line3']"

  " Go back two lists
  exe Xolder
  exe 'let l = ' . Xgetlist
  call assert_equal('Line2', l[0].text)

  " Go forward two lists
  exe Xnewer
  exe 'let l = ' . Xgetlist
  call assert_equal('Line3', l[0].text)

  " Test for the optional count argument
  exe Xolder . ' 2'
  exe 'let l = ' . Xgetlist
  call assert_equal('Line1', l[0].text)

  exe Xnewer . ' 2'
  exe 'let l = ' . Xgetlist
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
  let Xwindow = a:cchar . 'window'
  let Xclose = a:cchar . 'close'
  let Xopen = a:cchar . 'open'
  let Xgetexpr = a:cchar . 'getexpr'

  " Create a list with no valid entries
  exe Xgetexpr . " ['non-error 1', 'non-error 2', 'non-error 3']"

  " Quickfix/Location window should not open with no valid errors
  exe Xwindow
  call assert_true(winnr('$') == 1)

  " Create a list with valid entries
  exe Xgetexpr . " ['Xtestfile1:1:3:Line1', 'Xtestfile2:2:2:Line2',
		  \ 'Xtestfile3:3:1:Line3']"

  " Open the window
  exe Xwindow
  call assert_true(winnr('$') == 2 && winnr() == 2 &&
	\ getline('.') ==# 'Xtestfile1|1 col 3| Line1')

  " Close the window
  exe Xclose
  call assert_true(winnr('$') == 1)

  " Create a list with no valid entries
  exe Xgetexpr . " ['non-error 1', 'non-error 2', 'non-error 3']"

  " Open the window
  exe Xopen . ' 5'
  call assert_true(winnr('$') == 2 && getline('.') ==# '|| non-error 1'
		      \  && winheight('.') == 5)

  " Opening the window again, should move the cursor to that window
  wincmd t
  exe Xopen . ' 7'
  call assert_true(winnr('$') == 2 && winnr() == 2 &&
	\ winheight('.') == 7 &&
	\ getline('.') ==# '|| non-error 1')


  " Calling cwindow should close the quickfix window with no valid errors
  exe Xwindow
  call assert_true(winnr('$') == 1)
endfunction

function Test_cwindow()
  call XwindowTests('c')
  call XwindowTests('l')
endfunction

" Tests for the :cfile, :lfile, :caddfile, :laddfile, :cgetfile and :lgetfile
" commands.
function XfileTests(cchar)
  let Xfile = a:cchar . 'file'
  let Xgetfile = a:cchar . 'getfile'
  let Xaddfile = a:cchar . 'addfile'
  if a:cchar == 'c'
    let Xgetlist = 'getqflist()'
  else
    let Xgetlist = 'getloclist(0)'
  endif

  call writefile(['Xtestfile1:700:10:Line 700',
	\ 'Xtestfile2:800:15:Line 800'], 'Xqftestfile1')

  enew!
  exe Xfile . ' Xqftestfile1'
  exe 'let l = ' . Xgetlist
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 700 && l[0].col == 10 && l[0].text ==# 'Line 700' &&
	\ l[1].lnum == 800 && l[1].col == 15 && l[1].text ==# 'Line 800')

  " Run cfile/lfile from a modified buffer
  enew!
  silent! put ='Quickfix'
  exe 'silent! ' . Xfile . ' Xqftestfile1'
  call assert_true(v:errmsg ==# 'E37: No write since last change (add ! to override)')

  call writefile(['Xtestfile3:900:30:Line 900'], 'Xqftestfile1')
  exe Xaddfile . ' Xqftestfile1'
  exe 'let l = ' . Xgetlist
  call assert_true(len(l) == 3 &&
	\ l[2].lnum == 900 && l[2].col == 30 && l[2].text ==# 'Line 900')

  call writefile(['Xtestfile1:222:77:Line 222',
	\ 'Xtestfile2:333:88:Line 333'], 'Xqftestfile1')

  enew!
  exe Xgetfile . ' Xqftestfile1'
  exe 'let l = ' . Xgetlist
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
  let Xbuffer = a:cchar . 'buffer'
  let Xgetbuffer = a:cchar . 'getbuffer'
  let Xaddbuffer = a:cchar . 'addbuffer'
  if a:cchar == 'c'
    let Xgetlist = 'getqflist()'
  else
    let Xgetlist = 'getloclist(0)'
  endif

  enew!
  silent! call setline(1, ['Xtestfile7:700:10:Line 700',
	\ 'Xtestfile8:800:15:Line 800'])
  exe Xbuffer . "!"
  exe 'let l = ' . Xgetlist
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 700 && l[0].col == 10 && l[0].text ==# 'Line 700' &&
	\ l[1].lnum == 800 && l[1].col == 15 && l[1].text ==# 'Line 800')

  enew!
  silent! call setline(1, ['Xtestfile9:900:55:Line 900',
	\ 'Xtestfile10:950:66:Line 950'])
  exe Xgetbuffer
  exe 'let l = ' . Xgetlist
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 900 && l[0].col == 55 && l[0].text ==# 'Line 900' &&
	\ l[1].lnum == 950 && l[1].col == 66 && l[1].text ==# 'Line 950')

  enew!
  silent! call setline(1, ['Xtestfile11:700:20:Line 700',
	\ 'Xtestfile12:750:25:Line 750'])
  exe Xaddbuffer
  exe 'let l = ' . Xgetlist
  call assert_true(len(l) == 4 &&
	\ l[1].lnum == 950 && l[1].col == 66 && l[1].text ==# 'Line 950' &&
	\ l[2].lnum == 700 && l[2].col == 20 && l[2].text ==# 'Line 700' &&
	\ l[3].lnum == 750 && l[3].col == 25 && l[3].text ==# 'Line 750')

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
  let Xgetexpr = a:cchar . 'getexpr'
  if a:cchar == 'c'
    let Xgetlist = 'getqflist()'
  else
    let Xgetlist = 'getloclist(0)'
  endif
  let Xopen = a:cchar . 'open'
  let Xclose = a:cchar . 'close'

  exe Xgetexpr . " ['file:1:1:message']"
  exe 'let l = ' . Xgetlist
  if a:cchar == 'c'
    call setqflist(l, 'r')
  else
    call setloclist(0, l, 'r')
  endif

  exe Xopen
  if a:cchar == 'c'
    let title = ':setqflist()'
  else
    let title = ':setloclist()'
  endif
  call assert_equal(title, w:quickfix_title)
  exe Xclose
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

function XquickfixChangedByAutocmd(cchar)
  let Xolder = a:cchar . 'older'
  let Xgetexpr = a:cchar . 'getexpr'
  let Xrewind = a:cchar . 'rewind'
  if a:cchar == 'c'
    let Xsetlist = function('setqflist')
    let ErrorNr = 'E925'
    function! ReadFunc()
      colder
      cgetexpr []
    endfunc
  else
    let Xsetlist = function('setloclist', [0])
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
    call Xsetlist(qflist, ' ')
  endfor
  exec "call assert_fails('" . Xrewind . "', '" . ErrorNr . ":')"

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
endfunc

" Tests for the setqflist() and setloclist() functions
function SetXlistTests(cchar, bnum)
  let Xwindow = a:cchar . 'window'
  let Xnext = a:cchar . 'next'
  if a:cchar == 'c'
    let Xsetlist = function('setqflist')
    let Xgetlist = function('getqflist')
  else
    let Xsetlist = function('setloclist', [0])
    let Xgetlist = function('getloclist', [0])
  endif

  call Xsetlist([{'bufnr': a:bnum, 'lnum': 1},
	      \  {'bufnr': a:bnum, 'lnum': 2}])
  let l = Xgetlist()
  call assert_equal(2, len(l))
  call assert_equal(2, l[1].lnum)

  exe Xnext
  call Xsetlist([{'bufnr': a:bnum, 'lnum': 3}], 'a')
  let l = Xgetlist()
  call assert_equal(3, len(l))
  exe Xnext
  call assert_equal(3, line('.'))

  " Appending entries to the list should not change the cursor position
  " in the quickfix window
  exe Xwindow
  1
  call Xsetlist([{'bufnr': a:bnum, 'lnum': 4},
	      \  {'bufnr': a:bnum, 'lnum': 5}], 'a')
  call assert_equal(1, line('.'))
  close

  call Xsetlist([{'bufnr': a:bnum, 'lnum': 3},
	      \  {'bufnr': a:bnum, 'lnum': 4},
	      \  {'bufnr': a:bnum, 'lnum': 5}], 'r')
  let l = Xgetlist()
  call assert_equal(3, len(l))
  call assert_equal(5, l[2].lnum)

  call Xsetlist([])
  let l = Xgetlist()
  call assert_equal(0, len(l))
endfunction

function Test_setqflist()
  new Xtestfile | only
  let bnum = bufnr('%')
  call setline(1, range(1,5))

  call SetXlistTests('c', bnum)
  call SetXlistTests('l', bnum)

  call delete('Xtestfile')
endfunction

function! XquickfixSetListWithAct(cchar)
  let Xolder = a:cchar . 'older'
  let Xnewer = a:cchar . 'newer'
  if a:cchar == 'c'
    let Xsetlist = function('setqflist')
    let Xgetlist = function('getqflist')
  else
    let Xsetlist = function('setloclist', [0])
    let Xgetlist = function('getloclist', [0])
  endif
  let list1 = [{'filename': 'fnameA', 'text': 'A'},
          \    {'filename': 'fnameB', 'text': 'B'}]
  let list2 = [{'filename': 'fnameC', 'text': 'C'},
          \    {'filename': 'fnameD', 'text': 'D'},
          \    {'filename': 'fnameE', 'text': 'E'}]

  " {action} is unspecified.  Same as specifing ' '.
  new | only
  exec "silent! " . Xnewer . "99"
  call Xsetlist(list1)
  call Xsetlist(list2)
  let li = Xgetlist()
  call assert_equal(3, len(li))
  call assert_equal('C', li[0]['text'])
  call assert_equal('D', li[1]['text'])
  call assert_equal('E', li[2]['text'])
  exec "silent! " . Xolder
  let li = Xgetlist()
  call assert_equal(2, len(li))
  call assert_equal('A', li[0]['text'])
  call assert_equal('B', li[1]['text'])

  " {action} is specified ' '.
  new | only
  exec "silent! " . Xnewer . "99"
  call Xsetlist(list1)
  call Xsetlist(list2, ' ')
  let li = Xgetlist()
  call assert_equal(3, len(li))
  call assert_equal('C', li[0]['text'])
  call assert_equal('D', li[1]['text'])
  call assert_equal('E', li[2]['text'])
  exec "silent! " . Xolder
  let li = Xgetlist()
  call assert_equal(2, len(li))
  call assert_equal('A', li[0]['text'])
  call assert_equal('B', li[1]['text'])

  " {action} is specified 'a'.
  new | only
  exec "silent! " . Xnewer . "99"
  call Xsetlist(list1)
  call Xsetlist(list2, 'a')
  let li = Xgetlist()
  call assert_equal(5, len(li))
  call assert_equal('A', li[0]['text'])
  call assert_equal('B', li[1]['text'])
  call assert_equal('C', li[2]['text'])
  call assert_equal('D', li[3]['text'])
  call assert_equal('E', li[4]['text'])

  " {action} is specified 'r'.
  new | only
  exec "silent! " . Xnewer . "99"
  call Xsetlist(list1)
  call Xsetlist(list2, 'r')
  let li = Xgetlist()
  call assert_equal(3, len(li))
  call assert_equal('C', li[0]['text'])
  call assert_equal('D', li[1]['text'])
  call assert_equal('E', li[2]['text'])

  " Test for wrong value.
  new | only
  call assert_fails("call Xsetlist(0)", 'E714:')
  call assert_fails("call Xsetlist(list1, '')", 'E927:')
  call assert_fails("call Xsetlist(list1, 'aa')", 'E927:')
  call assert_fails("call Xsetlist(list1, ' a')", 'E927:')
  call assert_fails("call Xsetlist(list1, 0)", 'E928:')
endfunc

function Test_quickfix_set_list_with_act()
  call XquickfixSetListWithAct('c')
  call XquickfixSetListWithAct('l')
endfunction

func XLongLinesTests()
  let l = getqflist()

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

  call setqflist([], 'r')
endfunc

func Test_long_lines()
  let testfile = 'samples/quickfix.txt'

  " file
  exe 'cgetfile' testfile
  call XLongLinesTests()

  " list
  cexpr readfile(testfile)
  call XLongLinesTests()

  " string
  cexpr join(readfile(testfile), "\n")
  call XLongLinesTests()

  " buffer
  e testfile
  exe 'cbuffer' bufnr('%')
endfunc
