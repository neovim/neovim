" Test for the quickfix commands.

if !has('quickfix')
  finish
endif

set encoding=utf-8

function! s:setup_commands(cchar)
  if a:cchar == 'c'
    command! -nargs=* -bang Xlist <mods>clist<bang> <args>
    command! -nargs=* Xgetexpr <mods>cgetexpr <args>
    command! -nargs=* Xaddexpr <mods>caddexpr <args>
    command! -nargs=* Xolder <mods>colder <args>
    command! -nargs=* Xnewer <mods>cnewer <args>
    command! -nargs=* Xopen <mods>copen <args>
    command! -nargs=* Xwindow <mods>cwindow <args>
    command! -nargs=* Xbottom <mods>cbottom <args>
    command! -nargs=* Xclose <mods>cclose <args>
    command! -nargs=* -bang Xfile <mods>cfile<bang> <args>
    command! -nargs=* Xgetfile <mods>cgetfile <args>
    command! -nargs=* Xaddfile <mods>caddfile <args>
    command! -nargs=* -bang Xbuffer <mods>cbuffer<bang> <args>
    command! -nargs=* Xgetbuffer <mods>cgetbuffer <args>
    command! -nargs=* Xaddbuffer <mods>caddbuffer <args>
    command! -nargs=* Xrewind <mods>crewind <args>
    command! -nargs=* -bang Xnext <mods>cnext<bang> <args>
    command! -nargs=* -bang Xprev <mods>cprev<bang> <args>
    command! -nargs=* -bang Xfirst <mods>cfirst<bang> <args>
    command! -nargs=* -bang Xlast <mods>clast<bang> <args>
    command! -nargs=* -bang Xnfile <mods>cnfile<bang> <args>
    command! -nargs=* -bang Xpfile <mods>cpfile<bang> <args>
    command! -nargs=* Xexpr <mods>cexpr <args>
    command! -nargs=* Xvimgrep <mods>vimgrep <args>
    command! -nargs=* Xgrep <mods> grep <args>
    command! -nargs=* Xgrepadd <mods> grepadd <args>
    command! -nargs=* Xhelpgrep helpgrep <args>
    let g:Xgetlist = function('getqflist')
    let g:Xsetlist = function('setqflist')
  else
    command! -nargs=* -bang Xlist <mods>llist<bang> <args>
    command! -nargs=* Xgetexpr <mods>lgetexpr <args>
    command! -nargs=* Xaddexpr <mods>laddexpr <args>
    command! -nargs=* Xolder <mods>lolder <args>
    command! -nargs=* Xnewer <mods>lnewer <args>
    command! -nargs=* Xopen <mods>lopen <args>
    command! -nargs=* Xwindow <mods>lwindow <args>
    command! -nargs=* Xbottom <mods>lbottom <args>
    command! -nargs=* Xclose <mods>lclose <args>
    command! -nargs=* -bang Xfile <mods>lfile<bang> <args>
    command! -nargs=* Xgetfile <mods>lgetfile <args>
    command! -nargs=* Xaddfile <mods>laddfile <args>
    command! -nargs=* -bang Xbuffer <mods>lbuffer<bang> <args>
    command! -nargs=* Xgetbuffer <mods>lgetbuffer <args>
    command! -nargs=* Xaddbuffer <mods>laddbuffer <args>
    command! -nargs=* Xrewind <mods>lrewind <args>
    command! -nargs=* -bang Xnext <mods>lnext<bang> <args>
    command! -nargs=* -bang Xprev <mods>lprev<bang> <args>
    command! -nargs=* -bang Xfirst <mods>lfirst<bang> <args>
    command! -nargs=* -bang Xlast <mods>llast<bang> <args>
    command! -nargs=* -bang Xnfile <mods>lnfile<bang> <args>
    command! -nargs=* -bang Xpfile <mods>lpfile<bang> <args>
    command! -nargs=* Xexpr <mods>lexpr <args>
    command! -nargs=* Xvimgrep <mods>lvimgrep <args>
    command! -nargs=* Xgrep <mods> lgrep <args>
    command! -nargs=* Xgrepadd <mods> lgrepadd <args>
    command! -nargs=* Xhelpgrep lhelpgrep <args>
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
  redraw!

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

  " Test with a non existent file
  call assert_fails('Xfile non_existent_file', 'E40')

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

function XexprTests(cchar)
  call s:setup_commands(a:cchar)

  call assert_fails('Xexpr 10', 'E777:')
endfunction

function Test_cexpr()
  call XexprTests('c')
  call XexprTests('l')
endfunction

" Tests for :cnext, :cprev, :cfirst, :clast commands
function Xtest_browse(cchar)
  call s:setup_commands(a:cchar)

  call s:create_test_file('Xqftestfile1')
  call s:create_test_file('Xqftestfile2')

  Xgetexpr ['Xqftestfile1:5:Line5',
		\ 'Xqftestfile1:6:Line6',
		\ 'Xqftestfile2:10:Line10',
		\ 'Xqftestfile2:11:Line11']

  Xfirst
  call assert_fails('Xprev', 'E553')
  call assert_fails('Xpfile', 'E553')
  Xnfile
  call assert_equal('Xqftestfile2', bufname('%'))
  call assert_equal(10, line('.'))
  Xpfile
  call assert_equal('Xqftestfile1', bufname('%'))
  call assert_equal(6, line('.'))
  Xlast
  call assert_equal('Xqftestfile2', bufname('%'))
  call assert_equal(11, line('.'))
  call assert_fails('Xnext', 'E553')
  call assert_fails('Xnfile', 'E553')
  Xrewind
  call assert_equal('Xqftestfile1', bufname('%'))
  call assert_equal(5, line('.'))

  call delete('Xqftestfile1')
  call delete('Xqftestfile2')
endfunction

function Test_browse()
  call Xtest_browse('c')
  call Xtest_browse('l')
endfunction

function! s:test_xhelpgrep(cchar)
  call s:setup_commands(a:cchar)
  Xhelpgrep quickfix
  Xopen
  if a:cchar == 'c'
    let title_text = ':helpgrep quickfix'
  else
    let title_text = ':lhelpgrep quickfix'
  endif
  call assert_true(w:quickfix_title =~ title_text, w:quickfix_title)
  " This wipes out the buffer, make sure that doesn't cause trouble.
  Xclose
endfunction

function Test_helpgrep()
  call s:test_xhelpgrep('c')
  helpclose
  call s:test_xhelpgrep('l')
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

function Test_locationlist_cross_tab_jump()
  call writefile(['loclistfoo'], 'loclistfoo')
  call writefile(['loclistbar'], 'loclistbar')
  set switchbuf=usetab

  edit loclistfoo
  tabedit loclistbar
  silent lgrep loclistfoo loclist*
  call assert_equal(1, tabpagenr())

  enew | only | tabonly
  set switchbuf&vim
  call delete('loclistfoo')
  call delete('loclistbar')
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

  let lines = ["Entering dir 'dir1/a'",
		\ 'habits2.txt:1:Nine Healthy Habits',
		\ "Entering dir 'b'",
		\ 'habits3.txt:2:0 Hours of television',
		\ 'habits2.txt:7:5 Small meals',
		\ "Entering dir 'dir1/c'",
		\ 'habits4.txt:3:1 Hour of exercise',
		\ "Leaving dir 'dir1/c'",
		\ "Leaving dir 'dir1/a'",
		\ 'habits1.txt:4:2 Liters of water',
		\ "Entering dir 'dir2'",
		\ 'habits5.txt:5:3 Cups of hot green tea',
		\ "Leaving dir 'dir2'"
		\]

  Xexpr ""
  for l in lines
      Xaddexpr l
  endfor

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

" Tests for invalid error format specifies
function Xinvalid_efm_Tests(cchar)
  call s:setup_commands(a:cchar)

  let save_efm = &efm

  set efm=%f:%l:%m,%f:%f:%l:%m
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E372:')

  set efm=%f:%l:%m,%f:%l:%r:%m
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E373:')

  set efm=%f:%l:%m,%O:%f:%l:%m
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E373:')

  set efm=%f:%l:%m,%f:%l:%*[^a-z
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E374:')

  set efm=%f:%l:%m,%f:%l:%*c
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E375:')

  set efm=%f:%l:%m,%L%M%N
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E376:')

  set efm=%f:%l:%m,%f:%l:%m:%R
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E377:')

  set efm=
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E378:')

  set efm=%DEntering\ dir\ abc,%f:%l:%m
  call assert_fails('Xexpr ["Entering dir abc", "abc.txt:1:Hello world"]', 'E379:')

  let &efm = save_efm
endfunction

function Test_invalid_efm()
  call Xinvalid_efm_Tests('c')
  call Xinvalid_efm_Tests('l')
endfunction

" TODO:
" Add tests for the following formats in 'errorformat'
"	%r  %O
function! Test_efm2()
  let save_efm = &efm

  " Test for %s format in efm
  set efm=%f:%s
  cexpr 'Xtestfile:Line search text'
  let l = getqflist()
  call assert_equal(l[0].pattern, '^\VLine search text\$')
  call assert_equal(l[0].lnum, 0)

  " Test for %P, %Q and %t format specifiers
  let lines=["[Xtestfile1]",
	      \ "(1,17)  error: ';' missing",
	      \ "(21,2)  warning: variable 'z' not defined",
	      \ "(67,3)  error: end of file found before string ended",
	      \ "",
	      \ "[Xtestfile2]",
	      \ "",
	      \ "[Xtestfile3]",
	      \ "NEW compiler v1.1",
	      \ "(2,2)   warning: variable 'x' not defined",
	      \ "(67,3)  warning: 's' already defined"
	      \]
  set efm=%+P[%f],(%l\\,%c)%*[\ ]%t%*[^:]:\ %m,%-Q
  cexpr ""
  for l in lines
      caddexpr l
  endfor
  let l = getqflist()
  call assert_equal(9, len(l))
  call assert_equal(21, l[2].lnum)
  call assert_equal(2, l[2].col)
  call assert_equal('w', l[2].type)
  call assert_equal('e', l[3].type)

  " Tests for %E, %C and %Z format specifiers
  let lines = ["Error 275",
	      \ "line 42",
	      \ "column 3",
	      \ "' ' expected after '--'"
	      \]
  set efm=%EError\ %n,%Cline\ %l,%Ccolumn\ %c,%Z%m
  cgetexpr lines
  let l = getqflist()
  call assert_equal(275, l[0].nr)
  call assert_equal(42, l[0].lnum)
  call assert_equal(3, l[0].col)
  call assert_equal('E', l[0].type)
  call assert_equal("\n' ' expected after '--'", l[0].text)

  " Test for %>
  let lines = ["Error in line 147 of foo.c:",
	      \"unknown variable 'i'"
	      \]
  set efm=unknown\ variable\ %m,%E%>Error\ in\ line\ %l\ of\ %f:,%Z%m
  cgetexpr lines
  let l = getqflist()
  call assert_equal(147, l[0].lnum)
  call assert_equal('E', l[0].type)
  call assert_equal("\nunknown variable 'i'", l[0].text)

  " Test for %A, %C and other formats
  let lines = [
	  \"==============================================================",
	  \"FAIL: testGetTypeIdCachesResult (dbfacadeTest.DjsDBFacadeTest)",
	  \"--------------------------------------------------------------",
	  \"Traceback (most recent call last):",
	  \'  File "unittests/dbfacadeTest.py", line 89, in testFoo',
	  \"    self.assertEquals(34, dtid)",
	  \'  File "/usr/lib/python2.2/unittest.py", line 286, in',
	  \" failUnlessEqual",
	  \"    raise self.failureException, \\",
	  \"AssertionError: 34 != 33",
	  \"",
	  \"--------------------------------------------------------------",
	  \"Ran 27 tests in 0.063s"
	  \]
  set efm=%C\ %.%#,%A\ \ File\ \"%f\"\\,\ line\ %l%.%#,%Z%[%^\ ]%\\@=%m
  cgetexpr lines
  let l = getqflist()
  call assert_equal(8, len(l))
  call assert_equal(89, l[4].lnum)
  call assert_equal(1, l[4].valid)
  call assert_equal('unittests/dbfacadeTest.py', bufname(l[4].bufnr))

  let &efm = save_efm
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

  call assert_equal(4, len(l))
  call assert_equal(1, l[0].lnum)
  call assert_equal(1, l[0].col)
  call assert_equal(1975, len(l[0].text))
  call assert_equal(2, l[1].lnum)
  call assert_equal(1, l[1].col)
  call assert_equal(4070, len(l[1].text))
  call assert_equal(3, l[2].lnum)
  call assert_equal(1, l[2].col)
  call assert_equal(4070, len(l[2].text))
  call assert_equal(4, l[3].lnum)
  call assert_equal(1, l[3].col)
  call assert_equal(10, len(l[3].text))

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

function! s:create_test_file(filename)
  let l = []
  for i in range(1, 20)
      call add(l, 'Line' . i)
  endfor
  call writefile(l, a:filename)
endfunction

function! Test_switchbuf()
  call s:create_test_file('Xqftestfile1')
  call s:create_test_file('Xqftestfile2')
  call s:create_test_file('Xqftestfile3')

  new | only
  edit Xqftestfile1
  let file1_winid = win_getid()
  new Xqftestfile2
  let file2_winid = win_getid()
  cgetexpr ['Xqftestfile1:5:Line5',
		\ 'Xqftestfile1:6:Line6',
		\ 'Xqftestfile2:10:Line10',
		\ 'Xqftestfile2:11:Line11',
		\ 'Xqftestfile3:15:Line15',
		\ 'Xqftestfile3:16:Line16']

  new
  let winid = win_getid()
  cfirst | cnext
  call assert_equal(winid, win_getid())
  cnext | cnext
  call assert_equal(winid, win_getid())
  cnext | cnext
  call assert_equal(winid, win_getid())
  enew

  set switchbuf=useopen
  cfirst | cnext
  call assert_equal(file1_winid, win_getid())
  cnext | cnext
  call assert_equal(file2_winid, win_getid())
  cnext | cnext
  call assert_equal(file2_winid, win_getid())

  enew | only
  set switchbuf=usetab
  tabedit Xqftestfile1
  tabedit Xqftestfile2
  tabfirst
  cfirst | cnext
  call assert_equal(2, tabpagenr())
  cnext | cnext
  call assert_equal(3, tabpagenr())
  cnext | cnext
  call assert_equal(3, tabpagenr())
  tabfirst | tabonly | enew

  set switchbuf=split
  cfirst | cnext
  call assert_equal(1, winnr('$'))
  cnext | cnext
  call assert_equal(2, winnr('$'))
  cnext | cnext
  call assert_equal(3, winnr('$'))
  enew | only

  set switchbuf=newtab
  cfirst | cnext
  call assert_equal(1, tabpagenr('$'))
  cnext | cnext
  call assert_equal(2, tabpagenr('$'))
  cnext | cnext
  call assert_equal(3, tabpagenr('$'))
  tabfirst | enew | tabonly | only

  set switchbuf=
  edit Xqftestfile1
  let file1_winid = win_getid()
  new Xqftestfile2
  let file2_winid = win_getid()
  copen
  exe "normal 1G\<CR>"
  call assert_equal(file1_winid, win_getid())
  copen
  exe "normal 3G\<CR>"
  call assert_equal(file2_winid, win_getid())
  copen | only
  exe "normal 5G\<CR>"
  call assert_equal(2, winnr('$'))
  call assert_equal(1, bufwinnr('Xqftestfile3'))

  enew | only

  call delete('Xqftestfile1')
  call delete('Xqftestfile2')
  call delete('Xqftestfile3')
endfunction

function! Xadjust_qflnum(cchar)
  call s:setup_commands(a:cchar)

  enew | only

  let fname = 'Xqftestfile' . a:cchar
  call s:create_test_file(fname)
  exe 'edit ' . fname

  Xgetexpr [fname . ':5:Line5',
	      \ fname . ':10:Line10',
	      \ fname . ':15:Line15',
	      \ fname . ':20:Line20']

  6,14delete
  call append(6, ['Buffer', 'Window'])

  let l = g:Xgetlist()

  call assert_equal(5, l[0].lnum)
  call assert_equal(6, l[2].lnum)
  call assert_equal(13, l[3].lnum)

  enew!
  call delete(fname)
endfunction

function! Test_adjust_lnum()
  call setloclist(0, [])
  call Xadjust_qflnum('c')
  call setqflist([])
  call Xadjust_qflnum('l')
endfunction

" Tests for the :grep/:lgrep and :grepadd/:lgrepadd commands
function! s:test_xgrep(cchar)
  call s:setup_commands(a:cchar)

  " The following lines are used for the grep test. Don't remove.
  " Grep_Test_Text: Match 1
  " Grep_Test_Text: Match 2
  " GrepAdd_Test_Text: Match 1
  " GrepAdd_Test_Text: Match 2
  enew! | only
  set makeef&vim
  silent Xgrep Grep_Test_Text: test_quickfix.vim
  call assert_true(len(g:Xgetlist()) == 3)
  Xopen
  call assert_true(w:quickfix_title =~ '^:grep')
  Xclose
  enew
  set makeef=Temp_File_##
  silent Xgrepadd GrepAdd_Test_Text: test_quickfix.vim
  call assert_true(len(g:Xgetlist()) == 6)
endfunction

function! Test_grep()
  if !has('unix')
    " The grepprg may not be set on non-Unix systems
    return
  endif

  call s:test_xgrep('c')
  call s:test_xgrep('l')
endfunction

function! Test_two_windows()
  " Use one 'errorformat' for two windows.  Add an expression to each of them,
  " make sure they each keep their own state.
  set efm=%DEntering\ dir\ '%f',%f:%l:%m,%XLeaving\ dir\ '%f'
  call mkdir('Xone/a', 'p')
  call mkdir('Xtwo/a', 'p')
  let lines = ['1', '2', 'one one one', '4', 'two two two', '6', '7']
  call writefile(lines, 'Xone/a/one.txt')
  call writefile(lines, 'Xtwo/a/two.txt')

  new one
  let one_id = win_getid()
  lexpr ""
  new two
  let two_id = win_getid()
  lexpr ""

  laddexpr "Entering dir 'Xtwo/a'"
  call win_gotoid(one_id)
  laddexpr "Entering dir 'Xone/a'"
  call win_gotoid(two_id)
  laddexpr 'two.txt:5:two two two'
  call win_gotoid(one_id)
  laddexpr 'one.txt:3:one one one'

  let loc_one = getloclist(one_id)
echo string(loc_one)
  call assert_equal('Xone/a/one.txt', bufname(loc_one[1].bufnr))
  call assert_equal(3, loc_one[1].lnum)

  let loc_two = getloclist(two_id)
echo string(loc_two)
  call assert_equal('Xtwo/a/two.txt', bufname(loc_two[1].bufnr))
  call assert_equal(5, loc_two[1].lnum)

  call win_gotoid(one_id)
  bwipe!
  call win_gotoid(two_id)
  bwipe!
  call delete('Xone', 'rf')
  call delete('Xtwo', 'rf')
endfunc

function XbottomTests(cchar)
  call s:setup_commands(a:cchar)

  call g:Xsetlist([{'filename': 'foo', 'lnum': 42}]) 
  Xopen
  let wid = win_getid()
  call assert_equal(1, line('.'))
  wincmd w
  call g:Xsetlist([{'filename': 'var', 'lnum': 24}], 'a') 
  Xbottom
  call win_gotoid(wid)
  call assert_equal(2, line('.'))
  Xclose
endfunc

" Tests for the :cbottom and :lbottom commands
function Test_cbottom()
  call XbottomTests('c')
  call XbottomTests('l')
endfunction

function HistoryTest(cchar)
  call s:setup_commands(a:cchar)

  call assert_fails(a:cchar . 'older 99', 'E380:')
  " clear all lists after the first one, then replace the first one.
  call g:Xsetlist([])
  Xolder
  let entry = {'filename': 'foo', 'lnum': 42}
  call g:Xsetlist([entry], 'r')
  call g:Xsetlist([entry, entry])
  call g:Xsetlist([entry, entry, entry])
  let res = split(execute(a:cchar . 'hist'), "\n")
  call assert_equal(3, len(res))
  let common = 'errors     :set' . (a:cchar == 'c' ? 'qf' : 'loc') . 'list()'
  call assert_equal('  error list 1 of 3; 1 ' . common, res[0])
  call assert_equal('  error list 2 of 3; 2 ' . common, res[1])
  call assert_equal('> error list 3 of 3; 3 ' . common, res[2])
endfunc

func Test_history()
  call HistoryTest('c')
  call HistoryTest('l')
endfunc

func Test_duplicate_buf()
  " make sure we can get the highest buffer number
  edit DoesNotExist
  edit DoesNotExist2
  let last_buffer = bufnr("$")

  " make sure only one buffer is created
  call writefile(['this one', 'that one'], 'Xgrepthis')
  vimgrep one Xgrepthis
  vimgrep one Xgrepthis
  call assert_equal(last_buffer + 1, bufnr("$"))

  call delete('Xgrepthis')
endfunc

" Quickfix/Location list set/get properties tests
function Xproperty_tests(cchar)
    call s:setup_commands(a:cchar)

    " Error cases
    call assert_fails('call g:Xgetlist(99)', 'E715:')
    call assert_fails('call g:Xsetlist(99)', 'E714:')
    call assert_fails('call g:Xsetlist([], "a", [])', 'E715:')

    " Set and get the title
    Xopen
    wincmd p
    call g:Xsetlist([{'filename':'foo', 'lnum':27}])
    call g:Xsetlist([], 'a', {'title' : 'Sample'})
    let d = g:Xgetlist({"title":1})
    call assert_equal('Sample', d.title)

    Xopen
    call assert_equal('Sample', w:quickfix_title)
    Xclose

    " Tests for action argument
    silent! Xolder 999
    let qfnr = g:Xgetlist({'all':1}).nr
    call g:Xsetlist([], 'r', {'title' : 'N1'})
    call assert_equal('N1', g:Xgetlist({'all':1}).title)
    call g:Xsetlist([], ' ', {'title' : 'N2'})
    call assert_equal(qfnr + 1, g:Xgetlist({'all':1}).nr)
    call g:Xsetlist([], ' ', {'title' : 'N3'})
    call assert_equal('N2', g:Xgetlist({'nr':2, 'title':1}).title)

    " Invalid arguments
    call assert_fails('call g:Xgetlist([])', 'E715')
    call assert_fails('call g:Xsetlist([], "a", [])', 'E715')
    let s = g:Xsetlist([], 'a', {'abc':1})
    call assert_equal(-1, s)

    call assert_equal({}, g:Xgetlist({'abc':1}))

    if a:cchar == 'l'
	call assert_equal({}, getloclist(99, ['title']))
    endif
endfunction

function Test_qf_property()
    call Xproperty_tests('c')
    call Xproperty_tests('l')
endfunction

" Tests for the QuickFixCmdPre/QuickFixCmdPost autocommands
function QfAutoCmdHandler(loc, cmd)
  call add(g:acmds, a:loc . a:cmd)
endfunction

function Test_Autocmd()
  autocmd QuickFixCmdPre * call QfAutoCmdHandler('pre', expand('<amatch>'))
  autocmd QuickFixCmdPost * call QfAutoCmdHandler('post', expand('<amatch>'))

  let g:acmds = []
  cexpr "F1:10:Line 10"
  caddexpr "F1:20:Line 20"
  cgetexpr "F1:30:Line 30"
  enew! | call append(0, "F2:10:Line 10")
  cbuffer!
  enew! | call append(0, "F2:20:Line 20")
  cgetbuffer
  enew! | call append(0, "F2:30:Line 30")
  caddbuffer

  let l = ['precexpr',
      \ 'postcexpr',
      \ 'precaddexpr',
      \ 'postcaddexpr',
      \ 'precgetexpr',
      \ 'postcgetexpr',
      \ 'precbuffer',
      \ 'postcbuffer',
      \ 'precgetbuffer',
      \ 'postcgetbuffer',
      \ 'precaddbuffer',
      \ 'postcaddbuffer']
  call assert_equal(l, g:acmds)
endfunction

function! Test_Autocmd_Exception()
  set efm=%m
  lgetexpr '?'

  try
    call DoesNotExit()
  catch
    lgetexpr '1'
  finally
    lgetexpr '1'
  endtry

  call assert_equal('1', getloclist(0)[0].text)

  set efm&vim
endfunction
