" Test for the quickfix commands.

if !has('quickfix')
  finish
endif

set encoding=utf-8

func s:setup_commands(cchar)
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
    command! -count -nargs=* -bang Xnext <mods><count>cnext<bang> <args>
    command! -count -nargs=* -bang Xprev <mods><count>cprev<bang> <args>
    command! -nargs=* -bang Xfirst <mods>cfirst<bang> <args>
    command! -nargs=* -bang Xlast <mods>clast<bang> <args>
    command! -nargs=* -bang Xnfile <mods>cnfile<bang> <args>
    command! -nargs=* -bang Xpfile <mods>cpfile<bang> <args>
    command! -nargs=* Xexpr <mods>cexpr <args>
    command! -range -nargs=* Xvimgrep <mods><count>vimgrep <args>
    command! -nargs=* Xvimgrepadd <mods>vimgrepadd <args>
    command! -nargs=* Xgrep <mods> grep <args>
    command! -nargs=* Xgrepadd <mods> grepadd <args>
    command! -nargs=* Xhelpgrep helpgrep <args>
    let g:Xgetlist = function('getqflist')
    let g:Xsetlist = function('setqflist')
    call setqflist([], 'f')
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
    command! -count -nargs=* -bang Xnext <mods><count>lnext<bang> <args>
    command! -count -nargs=* -bang Xprev <mods><count>lprev<bang> <args>
    command! -nargs=* -bang Xfirst <mods>lfirst<bang> <args>
    command! -nargs=* -bang Xlast <mods>llast<bang> <args>
    command! -nargs=* -bang Xnfile <mods>lnfile<bang> <args>
    command! -nargs=* -bang Xpfile <mods>lpfile<bang> <args>
    command! -nargs=* Xexpr <mods>lexpr <args>
    command! -range -nargs=* Xvimgrep <mods><count>lvimgrep <args>
    command! -nargs=* Xvimgrepadd <mods>lvimgrepadd <args>
    command! -nargs=* Xgrep <mods> lgrep <args>
    command! -nargs=* Xgrepadd <mods> lgrepadd <args>
    command! -nargs=* Xhelpgrep lhelpgrep <args>
    let g:Xgetlist = function('getloclist', [0])
    let g:Xsetlist = function('setloclist', [0])
    call setloclist(0, [], 'f')
  endif
endfunc

" Tests for the :clist and :llist commands
func XlistTests(cchar)
  call s:setup_commands(a:cchar)

  if a:cchar == 'l'
      call assert_fails('llist', 'E776:')
  endif
  " With an empty list, command should return error
  Xgetexpr []
  silent! Xlist
  call assert_true(v:errmsg ==# 'E42: No Errors')

  " Populate the list and then try
  Xgetexpr ['non-error 1', 'Xtestfile1:1:3:Line1',
		  \ 'non-error 2', 'Xtestfile2:2:2:Line2',
		  \ 'non-error 3', 'Xtestfile3:3:1:Line3']

  " List only valid entries
  let l = split(execute('Xlist', ''), "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 6 Xtestfile3:3 col 1: Line3'], l)

  " List all the entries
  let l = split(execute('Xlist!', ''), "\n")
  call assert_equal([' 1: non-error 1', ' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 5: non-error 3', ' 6 Xtestfile3:3 col 1: Line3'], l)

  " List a range of errors
  let l = split(execute('Xlist 3,6', ''), "\n")
  call assert_equal([' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 6 Xtestfile3:3 col 1: Line3'], l)

  let l = split(execute('Xlist! 3,4', ''), "\n")
  call assert_equal([' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2'], l)

  let l = split(execute('Xlist -6,-4', ''), "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1'], l)

  let l = split(execute('Xlist! -5,-3', ''), "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2'], l)

  " Test for '+'
  let l = split(execute('Xlist! +2', ''), "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2'], l)

  " Different types of errors
  call g:Xsetlist([{'lnum':10,'col':5,'type':'W', 'text':'Warning','nr':11},
	      \ {'lnum':20,'col':10,'type':'e','text':'Error','nr':22},
	      \ {'lnum':30,'col':15,'type':'i','text':'Info','nr':33},
	      \ {'lnum':40,'col':20,'type':'x', 'text':'Other','nr':44},
	      \ {'lnum':50,'col':25,'type':"\<C-A>",'text':'one','nr':55}])
  let l = split(execute('Xlist', ""), "\n")
  call assert_equal([' 1:10 col 5 warning  11: Warning',
	      \ ' 2:20 col 10 error  22: Error',
	      \ ' 3:30 col 15 info  33: Info',
	      \ ' 4:40 col 20 x  44: Other',
	      \ ' 5:50 col 25  55: one'], l)

  " Error cases
  call assert_fails('Xlist abc', 'E488:')
endfunc

func Test_clist()
  call XlistTests('c')
  call XlistTests('l')
endfunc

" Tests for the :colder, :cnewer, :lolder and :lnewer commands
" Note that this test assumes that a quickfix/location list is
" already set by the caller.
func XageTests(cchar)
  call s:setup_commands(a:cchar)

  let list = [{'bufnr': bufnr('%'), 'lnum': 1}]
  call g:Xsetlist(list)

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
endfunc

func Test_cage()
  call XageTests('c')
  call XageTests('l')
endfunc

" Tests for the :cwindow, :lwindow :cclose, :lclose, :copen and :lopen
" commands
func XwindowTests(cchar)
  call s:setup_commands(a:cchar)

  " Opening the location list window without any errors should fail
  if a:cchar == 'l'
      call assert_fails('lopen', 'E776:')
  endif

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

  if a:cchar == 'c'
      " Opening the quickfix window in multiple tab pages should reuse the
      " quickfix buffer
      Xgetexpr ['Xtestfile1:1:3:Line1', 'Xtestfile2:2:2:Line2',
		  \ 'Xtestfile3:3:1:Line3']
      Xopen
      let qfbufnum = bufnr('%')
      tabnew
      Xopen
      call assert_equal(qfbufnum, bufnr('%'))
      new | only | tabonly
  endif
endfunc

func Test_cwindow()
  call XwindowTests('c')
  call XwindowTests('l')
endfunc

" Tests for the :cfile, :lfile, :caddfile, :laddfile, :cgetfile and :lgetfile
" commands.
func XfileTests(cchar)
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
endfunc

func Test_cfile()
  call XfileTests('c')
  call XfileTests('l')
endfunc

" Tests for the :cbuffer, :lbuffer, :caddbuffer, :laddbuffer, :cgetbuffer and
" :lgetbuffer commands.
func XbufferTests(cchar)
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

  " Check for invalid buffer
  call assert_fails('Xbuffer 199', 'E474:')

  " Check for unloaded buffer
  edit Xtestfile1
  let bnr = bufnr('%')
  enew!
  call assert_fails('Xbuffer ' . bnr, 'E681:')

  " Check for invalid range
  " Using Xbuffer will not run the range check in the cbuffer/lbuffer
  " commands. So directly call the commands.
  if (a:cchar == 'c')
      call assert_fails('900,999cbuffer', 'E16:')
  else
      call assert_fails('900,999lbuffer', 'E16:')
  endif
endfunc

func Test_cbuffer()
  call XbufferTests('c')
  call XbufferTests('l')
endfunc

func XexprTests(cchar)
  call s:setup_commands(a:cchar)

  call assert_fails('Xexpr 10', 'E777:')
endfunc

func Test_cexpr()
  call XexprTests('c')
  call XexprTests('l')
endfunc

" Tests for :cnext, :cprev, :cfirst, :clast commands
func Xtest_browse(cchar)
  call s:setup_commands(a:cchar)

  " Jumping to first or next location list entry without any error should
  " result in failure
  if a:cchar == 'l'
      call assert_fails('lfirst', 'E776:')
      call assert_fails('lnext', 'E776:')
  endif

  call s:create_test_file('Xqftestfile1')
  call s:create_test_file('Xqftestfile2')

  Xgetexpr ['Xqftestfile1:5:Line5',
		\ 'Xqftestfile1:6:Line6',
		\ 'Xqftestfile2:10:Line10',
		\ 'Xqftestfile2:11:Line11',
		\ 'RegularLine1',
		\ 'RegularLine2']

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
  Xprev
  call assert_equal('Xqftestfile2', bufname('%'))
  call assert_equal(11, line('.'))
  call assert_fails('Xnext', 'E553')
  call assert_fails('Xnfile', 'E553')
  Xrewind
  call assert_equal('Xqftestfile1', bufname('%'))
  call assert_equal(5, line('.'))

  10Xnext
  call assert_equal('Xqftestfile2', bufname('%'))
  call assert_equal(11, line('.'))
  10Xprev
  call assert_equal('Xqftestfile1', bufname('%'))
  call assert_equal(5, line('.'))

  Xexpr ""
  call assert_fails('Xnext', 'E42:')

  call delete('Xqftestfile1')
  call delete('Xqftestfile2')
endfunc

func Test_browse()
  call Xtest_browse('c')
  call Xtest_browse('l')
endfunc

func s:test_xhelpgrep(cchar)
  call s:setup_commands(a:cchar)
  Xhelpgrep quickfix
  Xopen
  if a:cchar == 'c'
    let title_text = ':helpgrep quickfix'
  else
    let title_text = ':lhelpgrep quickfix'
  endif
  call assert_true(w:quickfix_title =~ title_text, w:quickfix_title)

  " Jumping to a help topic should open the help window
  only
  Xnext
  call assert_true(&buftype == 'help')
  call assert_true(winnr('$') == 2)
  " Jumping to the next match should reuse the help window
  Xnext
  call assert_true(&buftype == 'help')
  call assert_true(winnr() == 1)
  call assert_true(winnr('$') == 2)
  " Jumping to the next match from the quickfix window should reuse the help
  " window
  Xopen
  Xnext
  call assert_true(&buftype == 'help')
  call assert_true(winnr() == 1)
  call assert_true(winnr('$') == 2)

  " This wipes out the buffer, make sure that doesn't cause trouble.
  Xclose

  new | only

  " Search for non existing help string
  call assert_fails('Xhelpgrep a1b2c3', 'E480:')
endfunc

func Test_helpgrep()
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

func XqfTitleTests(cchar)
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
endfunc

" Tests for quickfix window's title
func Test_qf_title()
  call XqfTitleTests('c')
  call XqfTitleTests('l')
endfunc

" Tests for 'errorformat'
func Test_efm()
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
endfunc

" This will test for problems in quickfix:
" A. incorrectly copying location lists which caused the location list to show
"    a different name than the file that was actually being displayed.
" B. not reusing the window for which the location list window is opened but
"    instead creating new windows.
" C. make sure that the location list window is not reused instead of the
"    window it belongs to.
"
" Set up the test environment:
func ReadTestProtocol(name)
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
endfunc

func Test_locationlist()
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
    4lnext
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
endfunc

func Test_locationlist_curwin_was_closed()
    augroup testgroup
      au!
      autocmd BufReadCmd test_curwin.txt call R(expand("<amatch>"))
    augroup END

    func! R(n)
      quit
    endfunc

    new
    let q = []
    call add(q, {'filename': 'test_curwin.txt' })
    call setloclist(0, q)
    call assert_fails('lrewind', 'E924:')

    augroup! testgroup
endfunc

func Test_locationlist_cross_tab_jump()
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
endfunc

" More tests for 'errorformat'
func Test_efm1()
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
endfunc

" Test for quickfix directory stack support
func s:dir_stack_tests(cchar)
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

  call assert_equal(expand('dir1/a/habits2.txt'), bufname(qf[1].bufnr))
  call assert_equal(1, qf[1].lnum)
  call assert_equal(expand('dir1/a/b/habits3.txt'), bufname(qf[3].bufnr))
  call assert_equal(2, qf[3].lnum)
  call assert_equal(expand('dir1/a/habits2.txt'), bufname(qf[4].bufnr))
  call assert_equal(7, qf[4].lnum)
  call assert_equal(expand('dir1/c/habits4.txt'), bufname(qf[6].bufnr))
  call assert_equal(3, qf[6].lnum)
  call assert_equal('habits1.txt', bufname(qf[9].bufnr))
  call assert_equal(4, qf[9].lnum)
  call assert_equal(expand('dir2/habits5.txt'), bufname(qf[11].bufnr))
  call assert_equal(5, qf[11].lnum)

  let &efm=save_efm
endfunc

" Tests for %D and %X errorformat options
func Test_efm_dirstack()
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
endfunc

" Test for resync after continuing an ignored message
func Xefm_ignore_continuations(cchar)
  call s:setup_commands(a:cchar)

  let save_efm = &efm

  let &efm =
	\ '%Eerror %m %l,' .
	\ '%-Wignored %m %l,' .
	\ '%+Cmore ignored %m %l,' .
	\ '%Zignored end'
  Xgetexpr ['ignored warning 1', 'more ignored continuation 2', 'ignored end', 'error resync 4']
  let l = map(g:Xgetlist(), '[v:val.text, v:val.valid, v:val.lnum, v:val.type]')
  call assert_equal([['resync', 1, 4, 'E']], l)

  let &efm = save_efm
endfunc

func Test_efm_ignore_continuations()
  call Xefm_ignore_continuations('c')
  call Xefm_ignore_continuations('l')
endfunc

" Tests for invalid error format specifies
func Xinvalid_efm_Tests(cchar)
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
endfunc

func Test_invalid_efm()
  call Xinvalid_efm_Tests('c')
  call Xinvalid_efm_Tests('l')
endfunc

" TODO:
" Add tests for the following formats in 'errorformat'
"	%r  %O
func Test_efm2()
  let save_efm = &efm

  " Test for %s format in efm
  set efm=%f:%s
  cexpr 'Xtestfile:Line search text'
  let l = getqflist()
  call assert_equal(l[0].pattern, '^\VLine search text\$')
  call assert_equal(l[0].lnum, 0)

  let l = split(execute('clist', ''), "\n")
  call assert_equal([' 1 Xtestfile:^\VLine search text\$:  '], l)

  " Test for %P, %Q and %t format specifiers
  let lines=["[Xtestfile1]",
	      \ "(1,17)  error: ';' missing",
	      \ "(21,2)  warning: variable 'z' not defined",
	      \ "(67,3)  error: end of file found before string ended",
	      \ "--",
	      \ "",
	      \ "[Xtestfile2]",
	      \ "--",
	      \ "",
	      \ "[Xtestfile3]",
	      \ "NEW compiler v1.1",
	      \ "(2,2)   warning: variable 'x' not defined",
	      \ "(67,3)  warning: 's' already defined",
	      \ "--"
	      \]
  set efm=%+P[%f]%r,(%l\\,%c)%*[\ ]%t%*[^:]:\ %m,%+Q--%r
  " To exercise the push/pop file functionality in quickfix, the test files
  " need to be created.
  call writefile(['Line1'], 'Xtestfile1')
  call writefile(['Line2'], 'Xtestfile2')
  call writefile(['Line3'], 'Xtestfile3')
  cexpr ""
  for l in lines
      caddexpr l
  endfor
  let l = getqflist()
  call assert_equal(12, len(l))
  call assert_equal(21, l[2].lnum)
  call assert_equal(2, l[2].col)
  call assert_equal('w', l[2].type)
  call assert_equal('e', l[3].type)
  call delete('Xtestfile1')
  call delete('Xtestfile2')
  call delete('Xtestfile3')

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
  call assert_equal(expand('unittests/dbfacadeTest.py'), bufname(l[4].bufnr))

  " The following sequence of commands used to crash Vim
  set efm=%W%m
  cgetexpr ['msg1']
  let l = getqflist()
  call assert_equal(1, len(l), string(l))
  call assert_equal('msg1', l[0].text)
  set efm=%C%m
  lexpr 'msg2'
  let l = getloclist(0)
  call assert_equal(1, len(l), string(l))
  call assert_equal('msg2', l[0].text)
  lopen
  call setqflist([], 'r')
  caddbuf
  let l = getqflist()
  call assert_equal(1, len(l), string(l))
  call assert_equal('|| msg2', l[0].text)

  new | only
  let &efm = save_efm
endfunc

func XquickfixChangedByAutocmd(cchar)
  call s:setup_commands(a:cchar)
  if a:cchar == 'c'
    let ErrorNr = 'E925'
    func! ReadFunc()
      colder
      cgetexpr []
    endfunc
  else
    let ErrorNr = 'E926'
    func! ReadFunc()
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

func Test_quickfix_was_changed_by_autocmd()
  call XquickfixChangedByAutocmd('c')
  call XquickfixChangedByAutocmd('l')
endfunc

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
func SetXlistTests(cchar, bnum)
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

  " Tests for setting the 'valid' flag
  call g:Xsetlist([{'bufnr':a:bnum, 'lnum':4, 'valid':0}])
  Xwindow
  call assert_equal(1, winnr('$'))
  let l = g:Xgetlist()
  call g:Xsetlist(l)
  call assert_equal(0, g:Xgetlist()[0].valid)
  call g:Xsetlist([{'text':'Text1', 'valid':1}])
  Xwindow
  call assert_equal(2, winnr('$'))
  Xclose
  let save_efm = &efm
  set efm=%m
  Xgetexpr 'TestMessage'
  let l = g:Xgetlist()
  call g:Xsetlist(l)
  call assert_equal(1, g:Xgetlist()[0].valid)
  let &efm = save_efm

  " Error cases:
  " Refer to a non-existing buffer and pass a non-dictionary type
  call assert_fails("call g:Xsetlist([{'bufnr':998, 'lnum':4}," .
	      \ " {'bufnr':999, 'lnum':5}])", 'E92:')
  call g:Xsetlist([[1, 2,3]])
  call assert_equal(0, len(g:Xgetlist()))
endfunc

func Test_setqflist()
  new Xtestfile | only
  let bnum = bufnr('%')
  call setline(1, range(1,5))

  call SetXlistTests('c', bnum)
  call SetXlistTests('l', bnum)

  enew!
  call delete('Xtestfile')
endfunc

func Xlist_empty_middle(cchar)
  call s:setup_commands(a:cchar)

  " create three quickfix lists
  let @/ = 'Test_'
  Xvimgrep // test_quickfix.vim
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

func Test_setqflist_empty_middle()
  call Xlist_empty_middle('c')
  call Xlist_empty_middle('l')
endfunc

func Xlist_empty_older(cchar)
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
endfunc

func Test_setqflist_empty_older()
  call Xlist_empty_older('c')
  call Xlist_empty_older('l')
endfunc

func XquickfixSetListWithAct(cchar)
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

func Test_quickfix_set_list_with_act()
  call XquickfixSetListWithAct('c')
  call XquickfixSetListWithAct('l')
endfunc

func XLongLinesTests(cchar)
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
endfunc

func s:long_lines_tests(cchar)
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
endfunc

func Test_long_lines()
  call s:long_lines_tests('c')
  call s:long_lines_tests('l')
endfunc

func s:create_test_file(filename)
  let l = []
  for i in range(1, 20)
      call add(l, 'Line' . i)
  endfor
  call writefile(l, a:filename)
endfunc

func Test_switchbuf()
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
  2cnext
  call assert_equal(winid, win_getid())
  2cnext
  call assert_equal(winid, win_getid())
  enew

  set switchbuf=useopen
  cfirst | cnext
  call assert_equal(file1_winid, win_getid())
  2cnext
  call assert_equal(file2_winid, win_getid())
  2cnext
  call assert_equal(file2_winid, win_getid())

  enew | only
  set switchbuf=usetab
  tabedit Xqftestfile1
  tabedit Xqftestfile2
  tabfirst
  cfirst | cnext
  call assert_equal(2, tabpagenr())
  2cnext
  call assert_equal(3, tabpagenr())
  2cnext
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

  " If only quickfix window is open in the current tabpage, jumping to an
  " entry with 'switchubf' set to 'usetab' should search in other tabpages.
  enew | only
  set switchbuf=usetab
  tabedit Xqftestfile1
  tabedit Xqftestfile2
  tabedit Xqftestfile3
  tabfirst
  copen | only
  clast
  call assert_equal(4, tabpagenr())
  tabfirst | tabonly | enew | only

  call delete('Xqftestfile1')
  call delete('Xqftestfile2')
  call delete('Xqftestfile3')
  set switchbuf&vim

  enew | only
endfunc

func Xadjust_qflnum(cchar)
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
endfunc

func Test_adjust_lnum()
  call setloclist(0, [])
  call Xadjust_qflnum('c')
  call setqflist([])
  call Xadjust_qflnum('l')
endfunc

" Tests for the :grep/:lgrep and :grepadd/:lgrepadd commands
func s:test_xgrep(cchar)
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
endfunc

func Test_grep()
  if !has('unix')
    " The grepprg may not be set on non-Unix systems
    return
  endif

  call s:test_xgrep('c')
  call s:test_xgrep('l')
endfunc

func Test_two_windows()
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
  call assert_equal(expand('Xone/a/one.txt'), bufname(loc_one[1].bufnr))
  call assert_equal(3, loc_one[1].lnum)

  let loc_two = getloclist(two_id)
  call assert_equal(expand('Xtwo/a/two.txt'), bufname(loc_two[1].bufnr))
  call assert_equal(5, loc_two[1].lnum)

  call win_gotoid(one_id)
  bwipe!
  call win_gotoid(two_id)
  bwipe!
  call delete('Xone', 'rf')
  call delete('Xtwo', 'rf')
endfunc

func XbottomTests(cchar)
  call s:setup_commands(a:cchar)

  " Calling lbottom without any errors should fail
  if a:cchar == 'l'
      call assert_fails('lbottom', 'E776:')
  endif

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
func Test_cbottom()
  call XbottomTests('c')
  call XbottomTests('l')
endfunc

func HistoryTest(cchar)
  call s:setup_commands(a:cchar)

  " clear all lists after the first one, then replace the first one.
  call g:Xsetlist([])
  call assert_fails('Xolder 99', 'E380:')
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
func Xproperty_tests(cchar)
    call s:setup_commands(a:cchar)

    " Error cases
    call assert_fails('call g:Xgetlist(99)', 'E715:')
    call assert_fails('call g:Xsetlist(99)', 'E714:')
    call assert_fails('call g:Xsetlist([], "a", [])', 'E715:')

    " Set and get the title
    call g:Xsetlist([])
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

    let res = g:Xgetlist({'nr': 0})
    call assert_equal(qfnr + 1, res.nr)
    call assert_equal(['nr'], keys(res))

    call g:Xsetlist([], ' ', {'title' : 'N3'})
    call assert_equal('N2', g:Xgetlist({'nr':2, 'title':1}).title)

    " Changing the title of an earlier quickfix list
    call g:Xsetlist([], ' ', {'title' : 'NewTitle', 'nr' : 2})
    call assert_equal('NewTitle', g:Xgetlist({'nr':2, 'title':1}).title)

    " Changing the title of an invalid quickfix list
    call assert_equal(-1, g:Xsetlist([], ' ',
		\ {'title' : 'SomeTitle', 'nr' : 99}))
    call assert_equal(-1, g:Xsetlist([], ' ',
		\ {'title' : 'SomeTitle', 'nr' : 'abc'}))

    if a:cchar == 'c'
	copen
	call assert_equal({'winid':win_getid()}, getqflist({'winid':1}))
	cclose
    endif

    " Invalid arguments
    call assert_fails('call g:Xgetlist([])', 'E715')
    call assert_fails('call g:Xsetlist([], "a", [])', 'E715')
    let s = g:Xsetlist([], 'a', {'abc':1})
    call assert_equal(-1, s)

    call assert_equal({}, g:Xgetlist({'abc':1}))
    call assert_equal({}, g:Xgetlist({'nr':99, 'title':1}))
    call assert_equal({}, g:Xgetlist({'nr':[], 'title':1}))

    if a:cchar == 'l'
	call assert_equal({}, getloclist(99, {'title': 1}))
    endif

    " Context related tests
    call g:Xsetlist([], 'a', {'context':[1,2,3]})
    call test_garbagecollect_now()
    let d = g:Xgetlist({'context':1})
    call assert_equal([1,2,3], d.context)
    call g:Xsetlist([], 'a', {'context':{'color':'green'}})
    let d = g:Xgetlist({'context':1})
    call assert_equal({'color':'green'}, d.context)
    call g:Xsetlist([], 'a', {'context':"Context info"})
    let d = g:Xgetlist({'context':1})
    call assert_equal("Context info", d.context)
    call g:Xsetlist([], 'a', {'context':246})
    let d = g:Xgetlist({'context':1})
    call assert_equal(246, d.context)
    if a:cchar == 'l'
	" Test for copying context across two different location lists
	new | only
	let w1_id = win_getid()
	let l = [1]
	call setloclist(0, [], 'a', {'context':l})
	new
	let w2_id = win_getid()
	call add(l, 2)
	call assert_equal([1, 2], getloclist(w1_id, {'context':1}).context)
	call assert_equal([1, 2], getloclist(w2_id, {'context':1}).context)
	unlet! l
	call assert_equal([1, 2], getloclist(w2_id, {'context':1}).context)
	only
	call setloclist(0, [], 'f')
	call assert_equal({}, getloclist(0, {'context':1}))
    endif

    " Test for changing the context of previous quickfix lists
    call g:Xsetlist([], 'f')
    Xexpr "One"
    Xexpr "Two"
    Xexpr "Three"
    call g:Xsetlist([], ' ', {'context' : [1], 'nr' : 1})
    call g:Xsetlist([], ' ', {'context' : [2], 'nr' : 2})
    " Also, check for setting the context using quickfix list number zero.
    call g:Xsetlist([], ' ', {'context' : [3], 'nr' : 0})
    call test_garbagecollect_now()
    let l = g:Xgetlist({'nr' : 1, 'context' : 1})
    call assert_equal([1], l.context)
    let l = g:Xgetlist({'nr' : 2, 'context' : 1})
    call assert_equal([2], l.context)
    let l = g:Xgetlist({'nr' : 3, 'context' : 1})
    call assert_equal([3], l.context)

    " Test for changing the context through reference and for garbage
    " collection of quickfix context
    let l = ["red"]
    call g:Xsetlist([], ' ', {'context' : l})
    call add(l, "blue")
    let x = g:Xgetlist({'context' : 1})
    call add(x.context, "green")
    call assert_equal(["red", "blue", "green"], l)
    call assert_equal(["red", "blue", "green"], x.context)
    unlet l
    call test_garbagecollect_now()
    let m = g:Xgetlist({'context' : 1})
    call assert_equal(["red", "blue", "green"], m.context)

    " Test for setting/getting items
    Xexpr ""
    let qfprev = g:Xgetlist({'nr':0})
    call g:Xsetlist([], ' ', {'title':'Green',
		\ 'items' : [{'filename':'F1', 'lnum':10}]})
    let qfcur = g:Xgetlist({'nr':0})
    call assert_true(qfcur.nr == qfprev.nr + 1)
    let l = g:Xgetlist({'items':1})
    call assert_equal('F1', bufname(l.items[0].bufnr))
    call assert_equal(10, l.items[0].lnum)
    call g:Xsetlist([], 'a', {'items' : [{'filename':'F2', 'lnum':20},
		\  {'filename':'F2', 'lnum':30}]})
    let l = g:Xgetlist({'items':1})
    call assert_equal('F2', bufname(l.items[2].bufnr))
    call assert_equal(30, l.items[2].lnum)
    call g:Xsetlist([], 'r', {'items' : [{'filename':'F3', 'lnum':40}]})
    let l = g:Xgetlist({'items':1})
    call assert_equal('F3', bufname(l.items[0].bufnr))
    call assert_equal(40, l.items[0].lnum)
    call g:Xsetlist([], 'r', {'items' : []})
    let l = g:Xgetlist({'items':1})
    call assert_equal(0, len(l.items))

    " Save and restore the quickfix stack
    call g:Xsetlist([], 'f')
    call assert_equal(0, g:Xgetlist({'nr':'$'}).nr)
    Xexpr "File1:10:Line1"
    Xexpr "File2:20:Line2"
    Xexpr "File3:30:Line3"
    let last_qf = g:Xgetlist({'nr':'$'}).nr
    call assert_equal(3, last_qf)
    let qstack = []
    for i in range(1, last_qf)
	let qstack = add(qstack, g:Xgetlist({'nr':i, 'all':1}))
    endfor
    call g:Xsetlist([], 'f')
    for i in range(len(qstack))
	call g:Xsetlist([], ' ', qstack[i])
    endfor
    call assert_equal(3, g:Xgetlist({'nr':'$'}).nr)
    call assert_equal(10, g:Xgetlist({'nr':1, 'items':1}).items[0].lnum)
    call assert_equal(20, g:Xgetlist({'nr':2, 'items':1}).items[0].lnum)
    call assert_equal(30, g:Xgetlist({'nr':3, 'items':1}).items[0].lnum)
    call g:Xsetlist([], 'f')

    " Swap two quickfix lists
    Xexpr "File1:10:Line10"
    Xexpr "File2:20:Line20"
    Xexpr "File3:30:Line30"
    call g:Xsetlist([], 'r', {'nr':1,'title':'Colors','context':['Colors']})
    call g:Xsetlist([], 'r', {'nr':2,'title':'Fruits','context':['Fruits']})
    let l1=g:Xgetlist({'nr':1,'all':1})
    let l2=g:Xgetlist({'nr':2,'all':1})
    let l1.nr=2
    let l2.nr=1
    call g:Xsetlist([], 'r', l1)
    call g:Xsetlist([], 'r', l2)
    let newl1=g:Xgetlist({'nr':1,'all':1})
    let newl2=g:Xgetlist({'nr':2,'all':1})
    call assert_equal(':Fruits', newl1.title)
    call assert_equal(['Fruits'], newl1.context)
    call assert_equal('Line20', newl1.items[0].text)
    call assert_equal(':Colors', newl2.title)
    call assert_equal(['Colors'], newl2.context)
    call assert_equal('Line10', newl2.items[0].text)
    call g:Xsetlist([], 'f')
endfunc

func Test_qf_property()
    call Xproperty_tests('c')
    call Xproperty_tests('l')
endfunc

" Tests for the QuickFixCmdPre/QuickFixCmdPost autocommands
func QfAutoCmdHandler(loc, cmd)
  call add(g:acmds, a:loc . a:cmd)
endfunc

func Test_Autocmd()
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
endfunc

func Test_Autocmd_Exception()
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
endfunc

func Test_caddbuffer_wrong()
  " This used to cause a memory access in freed memory.
  let save_efm = &efm
  set efm=%EEEE%m,%WWWW,%+CCCC%>%#,%GGGG%.#
  cgetexpr ['WWWW', 'EEEE', 'CCCC']
  let &efm = save_efm
  caddbuffer
  bwipe!
endfunc

func Test_caddexpr_wrong()
  " This used to cause a memory access in freed memory.
  cbuffer
  cbuffer
  copen
  let save_efm = &efm
  set efm=%
  call assert_fails('caddexpr ""', 'E376:')
  let &efm = save_efm
endfunc

func Test_dirstack_cleanup()
  " This used to cause a memory access in freed memory.
  let save_efm = &efm
  lexpr '0'
  lopen
  fun X(c)
    let save_efm=&efm
    set efm=%D%f
    if a:c == 'c'
      caddexpr '::'
    else
      laddexpr ':0:0'
    endif
    let &efm=save_efm
  endfun
  call X('c')
  call X('l')
  call setqflist([], 'r')
  caddbuffer
  let &efm = save_efm
endfunc

" Tests for jumping to entries from the location list window and quickfix
" window
func Test_cwindow_jump()
  set efm=%f%%%l%%%m
  lgetexpr ["F1%10%Line 10", "F2%20%Line 20", "F3%30%Line 30"]
  lopen | only
  lfirst
  call assert_true(winnr('$') == 2)
  call assert_true(winnr() == 1)
  " Location list for the new window should be set
  call assert_true(getloclist(0)[2].text == 'Line 30')

  " Open a scratch buffer
  " Open a new window and create a location list
  " Open the location list window and close the other window
  " Jump to an entry.
  " Should create a new window and jump to the entry. The scrtach buffer
  " should not be used.
  enew | only
  set buftype=nofile
  below new
  lgetexpr ["F1%10%Line 10", "F2%20%Line 20", "F3%30%Line 30"]
  lopen
  2wincmd c
  lnext
  call assert_true(winnr('$') == 3)
  call assert_true(winnr() == 2)

  " Open two windows with two different location lists
  " Open the location list window and close the previous window
  " Jump to an entry in the location list window
  " Should open the file in the first window and not set the location list.
  enew | only
  lgetexpr ["F1%5%Line 5"]
  below new
  lgetexpr ["F1%10%Line 10", "F2%20%Line 20", "F3%30%Line 30"]
  lopen
  2wincmd c
  lnext
  call assert_true(winnr() == 1)
  call assert_true(getloclist(0)[0].text == 'Line 5')

  enew | only
  cgetexpr ["F1%10%Line 10", "F2%20%Line 20", "F3%30%Line 30"]
  copen
  cnext
  call assert_true(winnr('$') == 2)
  call assert_true(winnr() == 1)

  enew | only
  set efm&vim
endfunc

func XvimgrepTests(cchar)
  call s:setup_commands(a:cchar)

  call writefile(['Editor:VIM vim',
	      \ 'Editor:Emacs EmAcS',
	      \ 'Editor:Notepad NOTEPAD'], 'Xtestfile1')
  call writefile(['Linux', 'MacOS', 'MS-Windows'], 'Xtestfile2')

  " Error cases
  call assert_fails('Xvimgrep /abc *', 'E682:')

  let @/=''
  call assert_fails('Xvimgrep // *', 'E35:')

  call assert_fails('Xvimgrep abc', 'E683:')
  call assert_fails('Xvimgrep a1b2c3 Xtestfile1', 'E480:')
  call assert_fails('Xvimgrep pat Xa1b2c3', 'E480:')

  Xexpr ""
  Xvimgrepadd Notepad Xtestfile1
  Xvimgrepadd MacOS Xtestfile2
  let l = g:Xgetlist()
  call assert_equal(2, len(l))
  call assert_equal('Editor:Notepad NOTEPAD', l[0].text)

  Xvimgrep #\cvim#g Xtestfile?
  let l = g:Xgetlist()
  call assert_equal(2, len(l))
  call assert_equal(8, l[0].col)
  call assert_equal(12, l[1].col)

  1Xvimgrep ?Editor? Xtestfile*
  let l = g:Xgetlist()
  call assert_equal(1, len(l))
  call assert_equal('Editor:VIM vim', l[0].text)

  edit +3 Xtestfile2
  Xvimgrep +\cemacs+j Xtestfile1
  let l = g:Xgetlist()
  call assert_equal('Xtestfile2', bufname(''))
  call assert_equal('Editor:Emacs EmAcS', l[0].text)

  call delete('Xtestfile1')
  call delete('Xtestfile2')
endfunc

" Tests for the :vimgrep command
func Test_vimgrep()
  call XvimgrepTests('c')
  call XvimgrepTests('l')
endfunc

func XfreeTests(cchar)
  call s:setup_commands(a:cchar)

  enew | only

  " Deleting the quickfix stack should work even When the current list is
  " somewhere in the middle of the stack
  Xexpr ['Xfile1:10:10:Line 10', 'Xfile1:15:15:Line 15']
  Xexpr ['Xfile2:20:20:Line 20', 'Xfile2:25:25:Line 25']
  Xexpr ['Xfile3:30:30:Line 30', 'Xfile3:35:35:Line 35']
  Xolder
  call g:Xsetlist([], 'f')
  call assert_equal(0, len(g:Xgetlist()))

  " After deleting the stack, adding a new list should create a stack with a
  " single list.
  Xexpr ['Xfile1:10:10:Line 10', 'Xfile1:15:15:Line 15']
  call assert_equal(1, g:Xgetlist({'all':1}).nr)

  " Deleting the stack from a quickfix window should update/clear the
  " quickfix/location list window.
  Xexpr ['Xfile1:10:10:Line 10', 'Xfile1:15:15:Line 15']
  Xexpr ['Xfile2:20:20:Line 20', 'Xfile2:25:25:Line 25']
  Xexpr ['Xfile3:30:30:Line 30', 'Xfile3:35:35:Line 35']
  Xolder
  Xwindow
  call g:Xsetlist([], 'f')
  call assert_equal(2, winnr('$'))
  call assert_equal(1, line('$'))
  Xclose

  " Deleting the stack from a non-quickfix window should update/clear the
  " quickfix/location list window.
  Xexpr ['Xfile1:10:10:Line 10', 'Xfile1:15:15:Line 15']
  Xexpr ['Xfile2:20:20:Line 20', 'Xfile2:25:25:Line 25']
  Xexpr ['Xfile3:30:30:Line 30', 'Xfile3:35:35:Line 35']
  Xolder
  Xwindow
  wincmd p
  call g:Xsetlist([], 'f')
  call assert_equal(0, len(g:Xgetlist()))
  wincmd p
  call assert_equal(2, winnr('$'))
  call assert_equal(1, line('$'))

  " After deleting the location list stack, if the location list window is
  " opened, then a new location list should be created. So opening the
  " location list window again should not create a new window.
  if a:cchar == 'l'
      lexpr ['Xfile1:10:10:Line 10', 'Xfile1:15:15:Line 15']
      wincmd p
      lopen
      call assert_equal(2, winnr('$'))
  endif
  Xclose
endfunc

" Tests for the quickifx free functionality
func Test_qf_free()
  call XfreeTests('c')
  call XfreeTests('l')
endfunc

" Test for buffer overflow when parsing lines and adding new entries to
" the quickfix list.
func Test_bufoverflow()
  set efm=%f:%l:%m
  cgetexpr ['File1:100:' . repeat('x', 1025)]

  set efm=%+GCompiler:\ %.%#,%f:%l:%m
  cgetexpr ['Compiler: ' . repeat('a', 1015), 'File1:10:Hello World']

  set efm=%DEntering\ directory\ %f,%f:%l:%m
  cgetexpr ['Entering directory ' . repeat('a', 1006),
	      \ 'File1:10:Hello World']
  set efm&vim
endfunc

func Test_cclose_from_copen()
    augroup QF_Test
	au!
	au FileType qf :cclose
    augroup END
    copen
    augroup QF_Test
	au!
    augroup END
    augroup! QF_Test
endfunc

" Tests for getting the quickfix stack size
func XsizeTests(cchar)
  call s:setup_commands(a:cchar)

  call g:Xsetlist([], 'f')
  call assert_equal(0, g:Xgetlist({'nr':'$'}).nr)
  call assert_equal(1, len(g:Xgetlist({'nr':'$', 'all':1})))
  call assert_equal(0, len(g:Xgetlist({'nr':0})))

  Xexpr "File1:10:Line1"
  Xexpr "File2:20:Line2"
  Xexpr "File3:30:Line3"
  Xolder | Xolder
  call assert_equal(3, g:Xgetlist({'nr':'$'}).nr)
  call g:Xsetlist([], 'f')

  Xexpr "File1:10:Line1"
  Xexpr "File2:20:Line2"
  Xexpr "File3:30:Line3"
  Xolder | Xolder
  call g:Xsetlist([], 'a', {'nr':'$', 'title':'Compiler'})
  call assert_equal('Compiler', g:Xgetlist({'nr':3, 'all':1}).title)
endfunc

func Test_Qf_Size()
  call XsizeTests('c')
  call XsizeTests('l')
endfunc
