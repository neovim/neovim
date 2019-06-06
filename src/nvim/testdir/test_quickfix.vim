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
    command! -nargs=* -count Xolder <mods><count>colder <args>
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
    command! -nargs=* -bang -range Xnfile <mods><count>cnfile<bang> <args>
    command! -nargs=* -bang Xpfile <mods>cpfile<bang> <args>
    command! -nargs=* Xexpr <mods>cexpr <args>
    command! -range -nargs=* Xvimgrep <mods><count>vimgrep <args>
    command! -nargs=* Xvimgrepadd <mods>vimgrepadd <args>
    command! -nargs=* Xgrep <mods> grep <args>
    command! -nargs=* Xgrepadd <mods> grepadd <args>
    command! -nargs=* Xhelpgrep helpgrep <args>
    command! -nargs=0 -count Xcc <count>cc
    let g:Xgetlist = function('getqflist')
    let g:Xsetlist = function('setqflist')
    call setqflist([], 'f')
  else
    command! -nargs=* -bang Xlist <mods>llist<bang> <args>
    command! -nargs=* Xgetexpr <mods>lgetexpr <args>
    command! -nargs=* Xaddexpr <mods>laddexpr <args>
    command! -nargs=* -count Xolder <mods><count>lolder <args>
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
    command! -nargs=* -bang -range Xnfile <mods><count>lnfile<bang> <args>
    command! -nargs=* -bang Xpfile <mods>lpfile<bang> <args>
    command! -nargs=* Xexpr <mods>lexpr <args>
    command! -range -nargs=* Xvimgrep <mods><count>lvimgrep <args>
    command! -nargs=* Xvimgrepadd <mods>lvimgrepadd <args>
    command! -nargs=* Xgrep <mods> lgrep <args>
    command! -nargs=* Xgrepadd <mods> lgrepadd <args>
    command! -nargs=* Xhelpgrep lhelpgrep <args>
    command! -nargs=0 -count Xcc <count>ll
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

  " Test for module names, one needs to explicitly set `'valid':v:true` so
  let save_shellslash = &shellslash
  set shellslash
  call g:Xsetlist([
        \ {'lnum':10,'col':5,'type':'W','module':'Data.Text','text':'ModuleWarning','nr':11,'valid':v:true},
        \ {'lnum':20,'col':10,'type':'W','module':'Data.Text','filename':'Data/Text.hs','text':'ModuleWarning','nr':22,'valid':v:true},
        \ {'lnum':30,'col':15,'type':'W','filename':'Data/Text.hs','text':'FileWarning','nr':33,'valid':v:true}])
  let l = split(execute('Xlist', ""), "\n")
  call assert_equal([' 1 Data.Text:10 col 5 warning  11: ModuleWarning',
        \ ' 2 Data.Text:20 col 10 warning  22: ModuleWarning',
        \ ' 3 Data/Text.hs:30 col 15 warning  33: FileWarning'], l)
  let &shellslash = save_shellslash

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

  call g:Xsetlist([], 'f')
  " Jumping to first or next location list entry without any error should
  " result in failure
  if a:cchar == 'c'
    let err = 'E42:'
  else
    let err = 'E776:'
  endif
  call assert_fails('Xnext', err)
  call assert_fails('Xprev', err)
  call assert_fails('Xnfile', err)
  call assert_fails('Xpfile', err)

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
  5Xcc
  call assert_equal(5, g:Xgetlist({'idx':0}).idx)
  2Xcc
  call assert_equal(2, g:Xgetlist({'idx':0}).idx)
  10Xcc
  call assert_equal(6, g:Xgetlist({'idx':0}).idx)
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

  " Jumping to an error from the error window using cc command
  Xgetexpr ['Xqftestfile1:5:Line5',
		\ 'Xqftestfile1:6:Line6',
		\ 'Xqftestfile2:10:Line10',
		\ 'Xqftestfile2:11:Line11']
  Xopen
  10Xcc
  call assert_equal(11, line('.'))
  call assert_equal('Xqftestfile2', bufname('%'))

  " Jumping to an error from the error window (when only the error window is
  " present)
  Xopen | only
  Xlast 1
  call assert_equal(5, line('.'))
  call assert_equal('Xqftestfile1', bufname('%'))

  Xexpr ""
  call assert_fails('Xnext', 'E42:')

  call delete('Xqftestfile1')
  call delete('Xqftestfile2')

  " Should be able to use next/prev with invalid entries
  Xexpr ""
  call assert_equal(0, g:Xgetlist({'idx' : 0}).idx)
  call assert_equal(0, g:Xgetlist({'size' : 0}).size)
  Xaddexpr ['foo', 'bar', 'baz', 'quux', 'shmoo']
  call assert_equal(5, g:Xgetlist({'size' : 0}).size)
  Xlast
  call assert_equal(5, g:Xgetlist({'idx' : 0}).idx)
  Xfirst
  call assert_equal(1, g:Xgetlist({'idx' : 0}).idx)
  2Xnext
  call assert_equal(3, g:Xgetlist({'idx' : 0}).idx)
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

  if a:cchar == 'l'
      " When a help window is present, running :lhelpgrep should reuse the
      " help window and not the current window
      new | only
      call g:Xsetlist([], 'f')
      help index.txt
      wincmd w
      lhelpgrep quickfix
      call assert_equal(1, winnr())
      call assert_notequal([], getloclist(1))
      call assert_equal([], getloclist(2))
  endif

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

  " Test for %o
  set efm=%f(%o):%l\ %m
  cgetexpr ['Xotestfile(Language.PureScript.Types):20 Error']
  call writefile(['Line1'], 'Xotestfile')
  let l = getqflist()
  call assert_equal(1, len(l), string(l))
  call assert_equal('Language.PureScript.Types', l[0].module)
  copen
  call assert_equal('Language.PureScript.Types|20| Error', getline(1))
  call feedkeys("\<CR>", 'xn')
  call assert_equal('Xotestfile', expand('%:t'))
  cclose
  bd
  call delete("Xotestfile")

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

func Test_setqflist_invalid_nr()
  " The following command used to crash Vim
  call setqflist([], ' ', {'nr' : $XXX_DOES_NOT_EXIST})
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
  tabedit Xqftestfile3
  tabfirst
  cfirst | cnext
  call assert_equal(2, tabpagenr())
  2cnext
  call assert_equal(3, tabpagenr())
  6cnext
  call assert_equal(4, tabpagenr())
  2cpfile
  call assert_equal(2, tabpagenr())
  2cnfile
  call assert_equal(4, tabpagenr())
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

  call g:Xsetlist([], 'f')
  let l = split(execute(a:cchar . 'hist'), "\n")
  call assert_equal('No entries', l[0])
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
    let s = g:Xsetlist([], 'a', {'title' : 'Sample'})
    call assert_equal(0, s)
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
    call g:Xsetlist([], 'r', {'title' : 'NewTitle', 'nr' : 2})
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
    call assert_equal('', g:Xgetlist({'nr':99, 'title':1}).title)
    call assert_equal('', g:Xgetlist({'nr':[], 'title':1}).title)

    if a:cchar == 'l'
	call assert_equal({}, getloclist(99, {'title': 1}))
    endif

    " Context related tests
    let s = g:Xsetlist([], 'a', {'context':[1,2,3]})
    call assert_equal(0, s)
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
	call assert_equal('', getloclist(0, {'context':1}).context)
    endif

    " Test for changing the context of previous quickfix lists
    call g:Xsetlist([], 'f')
    Xexpr "One"
    Xexpr "Two"
    Xexpr "Three"
    call g:Xsetlist([], 'r', {'context' : [1], 'nr' : 1})
    call g:Xsetlist([], 'a', {'context' : [2], 'nr' : 2})
    " Also, check for setting the context using quickfix list number zero.
    call g:Xsetlist([], 'r', {'context' : [3], 'nr' : 0})
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
    let s = g:Xsetlist([], ' ', {'title':'Green',
		\ 'items' : [{'filename':'F1', 'lnum':10}]})
    call assert_equal(0, s)
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

    call g:Xsetlist([], 'r', {'title' : 'TestTitle'})
    call g:Xsetlist([], 'r', {'items' : [{'filename' : 'F1', 'lnum' : 10, 'text' : 'L10'}]})
    call g:Xsetlist([], 'r', {'items' : [{'filename' : 'F1', 'lnum' : 10, 'text' : 'L10'}]})
    call assert_equal('TestTitle', g:Xgetlist({'title' : 1}).title)

    " The following used to crash Vim with address sanitizer
    call g:Xsetlist([], 'f')
    call g:Xsetlist([], 'a', {'items' : [{'filename':'F1', 'lnum':10}]})
    call assert_equal(10, g:Xgetlist({'items':1}).items[0].lnum)

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
    let save_id = l1.id
    let l1.id=l2.id
    let l2.id=save_id
    call g:Xsetlist([], 'r', l1)
    call g:Xsetlist([], 'r', l2)
    let newl1=g:Xgetlist({'nr':1,'all':1})
    let newl2=g:Xgetlist({'nr':2,'all':1})
    call assert_equal('Fruits', newl1.title)
    call assert_equal(['Fruits'], newl1.context)
    call assert_equal('Line20', newl1.items[0].text)
    call assert_equal('Colors', newl2.title)
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
  cexpr ""
  caddexpr ""
  cgetexpr ""
  silent! cexpr non_existing_func()
  silent! caddexpr non_existing_func()
  silent! cgetexpr non_existing_func()
  let l = ['precexpr',
        \ 'postcexpr',
        \ 'precaddexpr',
        \ 'postcaddexpr',
        \ 'precgetexpr',
        \ 'postcgetexpr',
        \ 'precexpr',
        \ 'postcexpr',
        \ 'precaddexpr',
        \ 'postcaddexpr',
        \ 'precgetexpr',
        \ 'postcgetexpr',
        \ 'precexpr',
        \ 'precaddexpr',
        \ 'precgetexpr']
  call assert_equal(l, g:acmds)

  let g:acmds = []
  enew! | call append(0, "F2:10:Line 10")
  cbuffer!
  enew! | call append(0, "F2:20:Line 20")
  cgetbuffer
  enew! | call append(0, "F2:30:Line 30")
  caddbuffer

  new
  let bnum = bufnr('%')
  bunload
  exe 'silent! cbuffer! ' . bnum
  exe 'silent! cgetbuffer ' . bnum
  exe 'silent! caddbuffer ' . bnum
  enew!
  let l = ['precbuffer',
      \ 'postcbuffer',
      \ 'precgetbuffer',
      \ 'postcgetbuffer',
      \ 'precaddbuffer',
      \ 'postcaddbuffer',
      \ 'precbuffer',
      \ 'precgetbuffer',
      \ 'precaddbuffer']
  call assert_equal(l, g:acmds)

  call writefile(['Xtest:1:Line1'], 'Xtest')
  call writefile([], 'Xempty')
  let g:acmds = []
  cfile Xtest
  caddfile Xtest
  cgetfile Xtest
  cfile Xempty
  caddfile Xempty
  cgetfile Xempty
  silent! cfile do_not_exist
  silent! caddfile do_not_exist
  silent! cgetfile do_not_exist
  let l = ['precfile',
        \ 'postcfile',
        \ 'precaddfile',
        \ 'postcaddfile',
        \ 'precgetfile',
        \ 'postcgetfile',
        \ 'precfile',
        \ 'postcfile',
        \ 'precaddfile',
        \ 'postcaddfile',
        \ 'precgetfile',
        \ 'postcgetfile',
        \ 'precfile',
        \ 'postcfile',
        \ 'precaddfile',
        \ 'postcaddfile',
        \ 'precgetfile',
        \ 'postcgetfile']
  call assert_equal(l, g:acmds)

  let g:acmds = []
  helpgrep quickfix
  silent! helpgrep non_existing_help_topic
  vimgrep test Xtest
  vimgrepadd test Xtest
  silent! vimgrep non_existing_test Xtest
  silent! vimgrepadd non_existing_test Xtest
  set makeprg=
  silent! make
  set makeprg&
  let l = ['prehelpgrep',
        \ 'posthelpgrep',
        \ 'prehelpgrep',
        \ 'posthelpgrep',
        \ 'previmgrep',
        \ 'postvimgrep',
        \ 'previmgrepadd',
        \ 'postvimgrepadd',
        \ 'previmgrep',
        \ 'postvimgrep',
        \ 'previmgrepadd',
        \ 'postvimgrepadd',
        \ 'premake',
        \ 'postmake']
  call assert_equal(l, g:acmds)

  if has('unix')
    " Run this test only on Unix-like systems. The grepprg may not be set on
    " non-Unix systems.
    " The following lines are used for the grep test. Don't remove.
    " Grep_Autocmd_Text: Match 1
    " GrepAdd_Autocmd_Text: Match 2
    let g:acmds = []
    silent grep Grep_Autocmd_Text test_quickfix.vim
    silent grepadd GrepAdd_Autocmd_Text test_quickfix.vim
    silent grep abc123def Xtest
    silent grepadd abc123def Xtest
    let l = ['pregrep',
          \ 'postgrep',
          \ 'pregrepadd',
          \ 'postgrepadd',
          \ 'pregrep',
          \ 'postgrep',
          \ 'pregrepadd',
          \ 'postgrepadd']
    call assert_equal(l, g:acmds)
  endif

  call delete('Xtest')
  call delete('Xempty')
  au! QuickFixCmdPre
  au! QuickFixCmdPost
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

" Tests for the quickfix free functionality
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

" Tests for getting the quickfix stack size
func XsizeTests(cchar)
  call s:setup_commands(a:cchar)

  call g:Xsetlist([], 'f')
  call assert_equal(0, g:Xgetlist({'nr':'$'}).nr)
  call assert_equal('', g:Xgetlist({'nr':'$', 'all':1}).title)
  call assert_equal(0, g:Xgetlist({'nr':0}).nr)

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

func Test_cclose_from_copen()
    augroup QF_Test
	au!
        au FileType qf :call assert_fails(':cclose', 'E788')
    augroup END
    copen
    augroup QF_Test
	au!
    augroup END
    augroup! QF_Test
endfunc

func Test_cclose_in_autocmd()
  " Problem is only triggered if "starting" is zero, so that the OptionsSet
  " event will be triggered.
  " call test_override('starting', 1)
  augroup QF_Test
    au!
    au FileType qf :call assert_fails(':cclose', 'E788')
  augroup END
  copen
  augroup QF_Test
    au!
  augroup END
  augroup! QF_Test
  " call test_override('starting', 0)
endfunc

" Check that ":file" without an argument is possible even when "curbuf_lock"
" is set.
func Test_file_from_copen()
  " Works without argument.
  augroup QF_Test
    au!
    au FileType qf file
  augroup END
  copen

  augroup QF_Test
    au!
  augroup END
  cclose

  " Fails with argument.
  augroup QF_Test
    au!
    au FileType qf call assert_fails(':file foo', 'E788')
  augroup END
  copen
  augroup QF_Test
    au!
  augroup END
  cclose

  augroup! QF_Test
endfunction

func Test_resize_from_copen()
    augroup QF_Test
	au!
        au FileType qf resize 5
    augroup END
    try
	" This should succeed without any exception.  No other buffers are
	" involved in the autocmd.
	copen
    finally
	augroup QF_Test
	    au!
	augroup END
	augroup! QF_Test
    endtry
endfunc

" Tests for the quickfix buffer b:changedtick variable
func Xchangedtick_tests(cchar)
  call s:setup_commands(a:cchar)

  new | only

  Xexpr "" | Xexpr "" | Xexpr ""

  Xopen
  Xolder
  Xolder
  Xaddexpr "F1:10:Line10"
  Xaddexpr "F2:20:Line20"
  call g:Xsetlist([{"filename":"F3", "lnum":30, "text":"Line30"}], 'a')
  call g:Xsetlist([], 'f')
  call assert_equal(8, getbufvar('%', 'changedtick'))
  Xclose
endfunc

func Test_changedtick()
  call Xchangedtick_tests('c')
  call Xchangedtick_tests('l')
endfunc

" Tests for parsing an expression using setqflist()
func Xsetexpr_tests(cchar)
  call s:setup_commands(a:cchar)

  let t = ["File1:10:Line10", "File1:20:Line20"]
  call g:Xsetlist([], ' ', {'lines' : t})
  call g:Xsetlist([], 'a', {'lines' : ["File1:30:Line30"]})

  let l = g:Xgetlist()
  call assert_equal(3, len(l))
  call assert_equal(20, l[1].lnum)
  call assert_equal('Line30', l[2].text)
  call g:Xsetlist([], 'r', {'lines' : ["File2:5:Line5"]})
  let l = g:Xgetlist()
  call assert_equal(1, len(l))
  call assert_equal('Line5', l[0].text)
  call assert_equal(-1, g:Xsetlist([], 'a', {'lines' : 10}))
  call assert_equal(-1, g:Xsetlist([], 'a', {'lines' : "F1:10:L10"}))

  call g:Xsetlist([], 'f')
  " Add entries to multiple lists
  call g:Xsetlist([], 'a', {'nr' : 1, 'lines' : ["File1:10:Line10"]})
  call g:Xsetlist([], 'a', {'nr' : 2, 'lines' : ["File2:20:Line20"]})
  call g:Xsetlist([], 'a', {'nr' : 1, 'lines' : ["File1:15:Line15"]})
  call g:Xsetlist([], 'a', {'nr' : 2, 'lines' : ["File2:25:Line25"]})
  call assert_equal('Line15', g:Xgetlist({'nr':1, 'items':1}).items[1].text)
  call assert_equal('Line25', g:Xgetlist({'nr':2, 'items':1}).items[1].text)

  " Adding entries using a custom efm
  set efm&
  call g:Xsetlist([], ' ', {'efm' : '%f#%l#%m',
				\ 'lines' : ["F1#10#L10", "F2#20#L20"]})
  call assert_equal(20, g:Xgetlist({'items':1}).items[1].lnum)
  call g:Xsetlist([], 'a', {'efm' : '%f#%l#%m', 'lines' : ["F3:30:L30"]})
  call assert_equal('F3:30:L30', g:Xgetlist({'items':1}).items[2].text)
  call assert_equal(20, g:Xgetlist({'items':1}).items[1].lnum)
  call assert_equal(-1, g:Xsetlist([], 'a', {'efm' : [],
				\ 'lines' : ['F1:10:L10']}))
endfunc

func Test_setexpr()
  call Xsetexpr_tests('c')
  call Xsetexpr_tests('l')
endfunc

" Tests for per quickfix/location list directory stack
func Xmultidirstack_tests(cchar)
  call s:setup_commands(a:cchar)

  call g:Xsetlist([], 'f')
  Xexpr "" | Xexpr ""

  call g:Xsetlist([], 'a', {'nr' : 1, 'lines' : ["Entering dir 'Xone/a'"]})
  call g:Xsetlist([], 'a', {'nr' : 2, 'lines' : ["Entering dir 'Xtwo/a'"]})
  call g:Xsetlist([], 'a', {'nr' : 1, 'lines' : ["one.txt:3:one one one"]})
  call g:Xsetlist([], 'a', {'nr' : 2, 'lines' : ["two.txt:5:two two two"]})

  let l1 = g:Xgetlist({'nr':1, 'items':1})
  let l2 = g:Xgetlist({'nr':2, 'items':1})
  call assert_equal(expand('Xone/a/one.txt'), bufname(l1.items[1].bufnr))
  call assert_equal(3, l1.items[1].lnum)
  call assert_equal(expand('Xtwo/a/two.txt'), bufname(l2.items[1].bufnr))
  call assert_equal(5, l2.items[1].lnum)
endfunc

func Test_multidirstack()
  call mkdir('Xone/a', 'p')
  call mkdir('Xtwo/a', 'p')
  let lines = ['1', '2', 'one one one', '4', 'two two two', '6', '7']
  call writefile(lines, 'Xone/a/one.txt')
  call writefile(lines, 'Xtwo/a/two.txt')
  let save_efm = &efm
  set efm=%DEntering\ dir\ '%f',%f:%l:%m,%XLeaving\ dir\ '%f'

  call Xmultidirstack_tests('c')
  call Xmultidirstack_tests('l')

  let &efm = save_efm
  call delete('Xone', 'rf')
  call delete('Xtwo', 'rf')
endfunc

" Tests for per quickfix/location list file stack
func Xmultifilestack_tests(cchar)
  call s:setup_commands(a:cchar)

  call g:Xsetlist([], 'f')
  Xexpr "" | Xexpr ""

  call g:Xsetlist([], 'a', {'nr' : 1, 'lines' : ["[one.txt]"]})
  call g:Xsetlist([], 'a', {'nr' : 2, 'lines' : ["[two.txt]"]})
  call g:Xsetlist([], 'a', {'nr' : 1, 'lines' : ["(3,5) one one one"]})
  call g:Xsetlist([], 'a', {'nr' : 2, 'lines' : ["(5,9) two two two"]})

  let l1 = g:Xgetlist({'nr':1, 'items':1})
  let l2 = g:Xgetlist({'nr':2, 'items':1})
  call assert_equal('one.txt', bufname(l1.items[1].bufnr))
  call assert_equal(3, l1.items[1].lnum)
  call assert_equal('two.txt', bufname(l2.items[1].bufnr))
  call assert_equal(5, l2.items[1].lnum)

  " Test for start of a new error line in the same line where a previous
  " error line ends with a file stack.
  let efm_val = 'Error\ l%l\ in\ %f,'
  let efm_val .= '%-P%>(%f%r,Error\ l%l\ in\ %m,%-Q)%r'
  let l = g:Xgetlist({'lines' : [
              \ '(one.txt',
              \ 'Error l4 in one.txt',
              \ ') (two.txt',
              \ 'Error l6 in two.txt',
              \ ')',
              \ 'Error l8 in one.txt'
              \ ], 'efm' : efm_val})
  call assert_equal(3, len(l.items))
  call assert_equal('one.txt', bufname(l.items[0].bufnr))
  call assert_equal(4, l.items[0].lnum)
  call assert_equal('one.txt', l.items[0].text)
  call assert_equal('two.txt', bufname(l.items[1].bufnr))
  call assert_equal(6, l.items[1].lnum)
  call assert_equal('two.txt', l.items[1].text)
  call assert_equal('one.txt', bufname(l.items[2].bufnr))
  call assert_equal(8, l.items[2].lnum)
  call assert_equal('', l.items[2].text)
endfunc

func Test_multifilestack()
  let lines = ['1', '2', 'one one one', '4', 'two two two', '6', '7']
  call writefile(lines, 'one.txt')
  call writefile(lines, 'two.txt')
  let save_efm = &efm
  set efm=%+P[%f],(%l\\,%c)\ %m,%-Q

  call Xmultifilestack_tests('c')
  call Xmultifilestack_tests('l')

  let &efm = save_efm
  call delete('one.txt')
  call delete('two.txt')
endfunc

" Tests for per buffer 'efm' setting
func Test_perbuf_efm()
  call writefile(["File1-10-Line10"], 'one.txt')
  call writefile(["File2#20#Line20"], 'two.txt')
  set efm=%f#%l#%m
  new | only
  new
  setlocal efm=%f-%l-%m
  cfile one.txt
  wincmd w
  caddfile two.txt

  let l = getqflist()
  call assert_equal(10, l[0].lnum)
  call assert_equal('Line20', l[1].text)

  set efm&
  new | only
  call delete('one.txt')
  call delete('two.txt')
endfunc

" Open multiple help windows using ":lhelpgrep
" This test used to crash Vim
func Test_Multi_LL_Help()
    new | only
    lhelpgrep window
    lopen
    e#
    lhelpgrep buffer
    call assert_equal(3, winnr('$'))
    call assert_true(len(getloclist(1)) != 0)
    call assert_true(len(getloclist(2)) != 0)
    new | only
endfunc

" Tests for adding new quickfix lists using setqflist()
func XaddQf_tests(cchar)
  call s:setup_commands(a:cchar)

  " Create a new list using ' ' for action
  call g:Xsetlist([], 'f')
  call g:Xsetlist([], ' ', {'title' : 'Test1'})
  let l = g:Xgetlist({'nr' : '$', 'all' : 1})
  call assert_equal(1, l.nr)
  call assert_equal('Test1', l.title)

  " Create a new list using ' ' for action and '$' for 'nr'
  call g:Xsetlist([], 'f')
  call g:Xsetlist([], ' ', {'title' : 'Test2', 'nr' : '$'})
  let l = g:Xgetlist({'nr' : '$', 'all' : 1})
  call assert_equal(1, l.nr)
  call assert_equal('Test2', l.title)

  " Create a new list using 'a' for action
  call g:Xsetlist([], 'f')
  call g:Xsetlist([], 'a', {'title' : 'Test3'})
  let l = g:Xgetlist({'nr' : '$', 'all' : 1})
  call assert_equal(1, l.nr)
  call assert_equal('Test3', l.title)

  " Create a new list using 'a' for action and '$' for 'nr'
  call g:Xsetlist([], 'f')
  call g:Xsetlist([], 'a', {'title' : 'Test3', 'nr' : '$'})
  call g:Xsetlist([], 'a', {'title' : 'Test4'})
  let l = g:Xgetlist({'nr' : '$', 'all' : 1})
  call assert_equal(1, l.nr)
  call assert_equal('Test4', l.title)

  " Adding a quickfix list should remove all the lists following the current
  " list.
  Xexpr "" | Xexpr "" | Xexpr ""
  silent! 10Xolder
  call g:Xsetlist([], ' ', {'title' : 'Test5'})
  let l = g:Xgetlist({'nr' : '$', 'all' : 1})
  call assert_equal(2, l.nr)
  call assert_equal('Test5', l.title)

  " Add a quickfix list using '$' as the list number.
  let lastqf = g:Xgetlist({'nr':'$'}).nr
  silent! 99Xolder
  call g:Xsetlist([], ' ', {'nr' : '$', 'title' : 'Test6'})
  let l = g:Xgetlist({'nr' : '$', 'all' : 1})
  call assert_equal(lastqf + 1, l.nr)
  call assert_equal('Test6', l.title)

  " Add a quickfix list using 'nr' set to one more than the quickfix
  " list size.
  let lastqf = g:Xgetlist({'nr':'$'}).nr
  silent! 99Xolder
  call g:Xsetlist([], ' ', {'nr' : lastqf + 1, 'title' : 'Test7'})
  let l = g:Xgetlist({'nr' : '$', 'all' : 1})
  call assert_equal(lastqf + 1, l.nr)
  call assert_equal('Test7', l.title)

  " Add a quickfix list to a stack with 10 lists using 'nr' set to '$'
  exe repeat('Xexpr "" |', 9) . 'Xexpr ""'
  silent! 99Xolder
  call g:Xsetlist([], ' ', {'nr' : '$', 'title' : 'Test8'})
  let l = g:Xgetlist({'nr' : '$', 'all' : 1})
  call assert_equal(10, l.nr)
  call assert_equal('Test8', l.title)

  " Add a quickfix list using 'nr' set to a value greater than 10
  call assert_equal(-1, g:Xsetlist([], ' ', {'nr' : 12, 'title' : 'Test9'}))

  " Try adding a quickfix list with 'nr' set to a value greater than the
  " quickfix list size but less than 10.
  call g:Xsetlist([], 'f')
  Xexpr "" | Xexpr "" | Xexpr ""
  silent! 99Xolder
  call assert_equal(-1, g:Xsetlist([], ' ', {'nr' : 8, 'title' : 'Test10'}))

  " Add a quickfix list using 'nr' set to a some string or list
  call assert_equal(-1, g:Xsetlist([], ' ', {'nr' : [1,2], 'title' : 'Test11'}))
endfunc

func Test_add_qf()
  call XaddQf_tests('c')
  call XaddQf_tests('l')
endfunc

" Test for getting the quickfix list items from some text without modifying
" the quickfix stack
func XgetListFromLines(cchar)
  call s:setup_commands(a:cchar)
  call g:Xsetlist([], 'f')

  let l = g:Xgetlist({'lines' : ["File2:20:Line20", "File2:30:Line30"]}).items
  call assert_equal(2, len(l))
  call assert_equal(30, l[1].lnum)

  call assert_equal({}, g:Xgetlist({'lines' : 10}))
  call assert_equal({}, g:Xgetlist({'lines' : 'File1:10:Line10'}))
  call assert_equal([], g:Xgetlist({'lines' : []}).items)
  call assert_equal([], g:Xgetlist({'lines' : [10, 20]}).items)

  " Parse text using a custom efm
  set efm&
  let l = g:Xgetlist({'lines':['File3#30#Line30'], 'efm' : '%f#%l#%m'}).items
  call assert_equal('Line30', l[0].text)
  let l = g:Xgetlist({'lines':['File3:30:Line30'], 'efm' : '%f-%l-%m'}).items
  call assert_equal('File3:30:Line30', l[0].text)
  let l = g:Xgetlist({'lines':['File3:30:Line30'], 'efm' : [1,2]})
  call assert_equal({}, l)
  call assert_fails("call g:Xgetlist({'lines':['abc'], 'efm':'%2'})", 'E376:')
  call assert_fails("call g:Xgetlist({'lines':['abc'], 'efm':''})", 'E378:')

  " Make sure that the quickfix stack is not modified
  call assert_equal(0, g:Xgetlist({'nr' : '$'}).nr)
endfunc

func Test_get_list_from_lines()
  call XgetListFromLines('c')
  call XgetListFromLines('l')
endfunc

" Tests for the quickfix list id
func Xqfid_tests(cchar)
  call s:setup_commands(a:cchar)

  call g:Xsetlist([], 'f')
  call assert_equal(0, g:Xgetlist({'id':0}).id)
  Xexpr ''
  let start_id = g:Xgetlist({'id' : 0}).id
  Xexpr '' | Xexpr ''
  Xolder
  call assert_equal(start_id, g:Xgetlist({'id':0, 'nr':1}).id)
  call assert_equal(start_id + 1, g:Xgetlist({'id':0, 'nr':0}).id)
  call assert_equal(start_id + 2, g:Xgetlist({'id':0, 'nr':'$'}).id)
  call assert_equal(0, g:Xgetlist({'id':0, 'nr':99}).id)
  call assert_equal(2, g:Xgetlist({'id':start_id + 1, 'nr':0}).nr)
  call assert_equal(0, g:Xgetlist({'id':99, 'nr':0}).id)
  call assert_equal(0, g:Xgetlist({'id':"abc", 'nr':0}).id)

  call g:Xsetlist([], 'a', {'id':start_id, 'context':[1,2]})
  call assert_equal([1,2], g:Xgetlist({'nr':1, 'context':1}).context)
  call g:Xsetlist([], 'a', {'id':start_id+1, 'lines':['F1:10:L10']})
  call assert_equal('L10', g:Xgetlist({'nr':2, 'items':1}).items[0].text)
  call assert_equal(-1, g:Xsetlist([], 'a', {'id':999, 'title':'Vim'}))
  call assert_equal(-1, g:Xsetlist([], 'a', {'id':'abc', 'title':'Vim'}))

  let qfid = g:Xgetlist({'id':0, 'nr':0})
  call g:Xsetlist([], 'f')
  call assert_equal(0, g:Xgetlist({'id':qfid, 'nr':0}).id)
endfunc

func Test_qf_id()
  call Xqfid_tests('c')
  call Xqfid_tests('l')
endfunc

func Test_getqflist_invalid_nr()
  " The following commands used to crash Vim
  cexpr ""
  call getqflist({'nr' : $XXX_DOES_NOT_EXIST_XXX})

  " Cleanup
  call setqflist([], 'r')
endfunc

" Test for shortening/simplifying the file name when opening the
" quickfix window or when displaying the quickfix list
func Test_shorten_fname()
  if !has('unix')
    return
  endif
  %bwipe
  " Create a quickfix list with a absolute path filename
  let fname = getcwd() . '/test_quickfix.vim'
  call setqflist([], ' ', {'lines':[fname . ":20:Line20"], 'efm':'%f:%l:%m'})
  call assert_equal(fname, bufname('test_quickfix.vim'))
  " Opening the quickfix window should simplify the file path
  cwindow
  call assert_equal('test_quickfix.vim', bufname('test_quickfix.vim'))
  cclose
  %bwipe
  " Create a quickfix list with a absolute path filename
  call setqflist([], ' ', {'lines':[fname . ":20:Line20"], 'efm':'%f:%l:%m'})
  call assert_equal(fname, bufname('test_quickfix.vim'))
  " Displaying the quickfix list should simplify the file path
  silent! clist
  call assert_equal('test_quickfix.vim', bufname('test_quickfix.vim'))
endfunc

" Quickfix title tests
" In the below tests, 'exe "cmd"' is used to invoke the quickfix commands.
" Otherwise due to indentation, the title is set with spaces at the beginning
" of the command.
func Test_qftitle()
  call writefile(["F1:1:Line1"], 'Xerr')

  " :cexpr
  exe "cexpr readfile('Xerr')"
  call assert_equal(":cexpr readfile('Xerr')", getqflist({'title' : 1}).title)

  " :cgetexpr
  exe "cgetexpr readfile('Xerr')"
  call assert_equal(":cgetexpr readfile('Xerr')",
					\ getqflist({'title' : 1}).title)

  " :caddexpr
  call setqflist([], 'f')
  exe "caddexpr readfile('Xerr')"
  call assert_equal(":caddexpr readfile('Xerr')",
					\ getqflist({'title' : 1}).title)

  " :cbuffer
  new Xerr
  exe "cbuffer"
  call assert_equal(':cbuffer (Xerr)', getqflist({'title' : 1}).title)

  " :cgetbuffer
  edit Xerr
  exe "cgetbuffer"
  call assert_equal(':cgetbuffer (Xerr)', getqflist({'title' : 1}).title)

  " :caddbuffer
  call setqflist([], 'f')
  edit Xerr
  exe "caddbuffer"
  call assert_equal(':caddbuffer (Xerr)', getqflist({'title' : 1}).title)

  " :cfile
  exe "cfile Xerr"
  call assert_equal(':cfile Xerr', getqflist({'title' : 1}).title)

  " :cgetfile
  exe "cgetfile Xerr"
  call assert_equal(':cgetfile Xerr', getqflist({'title' : 1}).title)

  " :caddfile
  call setqflist([], 'f')
  exe "caddfile Xerr"
  call assert_equal(':caddfile Xerr', getqflist({'title' : 1}).title)

  " :grep
  set grepprg=internal
  exe "grep F1 Xerr"
  call assert_equal(':grep F1 Xerr', getqflist({'title' : 1}).title)

  " :grepadd
  call setqflist([], 'f')
  exe "grepadd F1 Xerr"
  call assert_equal(':grepadd F1 Xerr', getqflist({'title' : 1}).title)
  set grepprg&vim

  " :vimgrep
  exe "vimgrep F1 Xerr"
  call assert_equal(':vimgrep F1 Xerr', getqflist({'title' : 1}).title)

  " :vimgrepadd
  call setqflist([], 'f')
  exe "vimgrepadd F1 Xerr"
  call assert_equal(':vimgrepadd F1 Xerr', getqflist({'title' : 1}).title)

  call setqflist(['F1:10:L10'], ' ')
  call assert_equal(':setqflist()', getqflist({'title' : 1}).title)

  call setqflist([], 'f')
  call setqflist(['F1:10:L10'], 'a')
  call assert_equal(':setqflist()', getqflist({'title' : 1}).title)

  call setqflist([], 'f')
  call setqflist(['F1:10:L10'], 'r')
  call assert_equal(':setqflist()', getqflist({'title' : 1}).title)

  close
  call delete('Xerr')

  call setqflist([], ' ', {'title' : 'Errors'})
  copen
  call assert_equal('Errors', w:quickfix_title)
  call setqflist([], 'r', {'items' : [{'filename' : 'a.c', 'lnum' : 10}]})
  call assert_equal('Errors', w:quickfix_title)
  cclose
endfunc

" Test for the position of the quickfix and location list window
func Test_qfwin_pos()
  " Open two windows
  new | only
  new
  cexpr ['F1:10:L10']
  copen
  " Quickfix window should be the bottom most window
  call assert_equal(3, winnr())
  close
  " Open at the very top
  wincmd t
  topleft copen
  call assert_equal(1, winnr())
  close
  " open left of the current window
  wincmd t
  below new
  leftabove copen
  call assert_equal(2, winnr())
  close
  " open right of the current window
  rightbelow copen
  call assert_equal(3, winnr())
  close
endfunc

" The following test used to crash Vim
func Test_lhelpgrep_autocmd()
  lhelpgrep quickfix
  autocmd QuickFixCmdPost * call setloclist(0, [], 'f')
  lhelpgrep buffer
  call assert_equal('help', &filetype)
  call assert_equal(0, getloclist(0, {'nr' : '$'}).nr)
  lhelpgrep tabpage
  call assert_equal('help', &filetype)
  call assert_equal(1, getloclist(0, {'nr' : '$'}).nr)
  au! QuickFixCmdPost
  new | only
endfunc

" Test to make sure that an empty quickfix buffer is not reused for loading
" a normal buffer.
func Test_empty_qfbuf()
  enew | only
  call writefile(["Test"], 'Xfile1')
  call setqflist([], 'f')
  copen | only
  let qfbuf = bufnr('')
  edit Xfile1
  call assert_notequal(qfbuf, bufnr(''))
  enew
  call delete('Xfile1')
endfunc

" Tests for the getqflist() and getloclist() functions when the list is not
" present or is empty
func Xgetlist_empty_tests(cchar)
  call s:setup_commands(a:cchar)

  " Empty quickfix stack
  call g:Xsetlist([], 'f')
  call assert_equal('', g:Xgetlist({'context' : 0}).context)
  call assert_equal(0, g:Xgetlist({'id' : 0}).id)
  call assert_equal(0, g:Xgetlist({'idx' : 0}).idx)
  call assert_equal([], g:Xgetlist({'items' : 0}).items)
  call assert_equal(0, g:Xgetlist({'nr' : 0}).nr)
  call assert_equal(0, g:Xgetlist({'size' : 0}).size)
  call assert_equal('', g:Xgetlist({'title' : 0}).title)
  call assert_equal(0, g:Xgetlist({'winid' : 0}).winid)
  call assert_equal(0, g:Xgetlist({'changedtick' : 0}).changedtick)
  call assert_equal({'context' : '', 'id' : 0, 'idx' : 0, 'items' : [], 'nr' : 0, 'size' : 0, 'title' : '', 'winid' : 0, 'changedtick': 0}, g:Xgetlist({'all' : 0}))

  " Quickfix window with empty stack
  silent! Xopen
  let qfwinid = (a:cchar == 'c') ? win_getid() : 0
  call assert_equal(qfwinid, g:Xgetlist({'winid' : 0}).winid)
  Xclose

  " Empty quickfix list
  Xexpr ""
  call assert_equal('', g:Xgetlist({'context' : 0}).context)
  call assert_notequal(0, g:Xgetlist({'id' : 0}).id)
  call assert_equal(0, g:Xgetlist({'idx' : 0}).idx)
  call assert_equal([], g:Xgetlist({'items' : 0}).items)
  call assert_notequal(0, g:Xgetlist({'nr' : 0}).nr)
  call assert_equal(0, g:Xgetlist({'size' : 0}).size)
  call assert_notequal('', g:Xgetlist({'title' : 0}).title)
  call assert_equal(0, g:Xgetlist({'winid' : 0}).winid)
  call assert_equal(1, g:Xgetlist({'changedtick' : 0}).changedtick)

  let qfid = g:Xgetlist({'id' : 0}).id
  call g:Xsetlist([], 'f')

  " Non-existing quickfix identifier
  call assert_equal('', g:Xgetlist({'id' : qfid, 'context' : 0}).context)
  call assert_equal(0, g:Xgetlist({'id' : qfid}).id)
  call assert_equal(0, g:Xgetlist({'id' : qfid, 'idx' : 0}).idx)
  call assert_equal([], g:Xgetlist({'id' : qfid, 'items' : 0}).items)
  call assert_equal(0, g:Xgetlist({'id' : qfid, 'nr' : 0}).nr)
  call assert_equal(0, g:Xgetlist({'id' : qfid, 'size' : 0}).size)
  call assert_equal('', g:Xgetlist({'id' : qfid, 'title' : 0}).title)
  call assert_equal(0, g:Xgetlist({'id' : qfid, 'winid' : 0}).winid)
  call assert_equal(0, g:Xgetlist({'id' : qfid, 'changedtick' : 0}).changedtick)
  call assert_equal({'context' : '', 'id' : 0, 'idx' : 0, 'items' : [], 'nr' : 0, 'size' : 0, 'title' : '', 'winid' : 0, 'changedtick' : 0}, g:Xgetlist({'id' : qfid, 'all' : 0}))

  " Non-existing quickfix list number
  call assert_equal('', g:Xgetlist({'nr' : 5, 'context' : 0}).context)
  call assert_equal(0, g:Xgetlist({'nr' : 5}).nr)
  call assert_equal(0, g:Xgetlist({'nr' : 5, 'idx' : 0}).idx)
  call assert_equal([], g:Xgetlist({'nr' : 5, 'items' : 0}).items)
  call assert_equal(0, g:Xgetlist({'nr' : 5, 'id' : 0}).id)
  call assert_equal(0, g:Xgetlist({'nr' : 5, 'size' : 0}).size)
  call assert_equal('', g:Xgetlist({'nr' : 5, 'title' : 0}).title)
  call assert_equal(0, g:Xgetlist({'nr' : 5, 'winid' : 0}).winid)
  call assert_equal(0, g:Xgetlist({'nr' : 5, 'changedtick' : 0}).changedtick)
  call assert_equal({'context' : '', 'id' : 0, 'idx' : 0, 'items' : [], 'nr' : 0, 'size' : 0, 'title' : '', 'winid' : 0, 'changedtick' : 0}, g:Xgetlist({'nr' : 5, 'all' : 0}))
endfunc

func Test_getqflist()
  call Xgetlist_empty_tests('c')
  call Xgetlist_empty_tests('l')
endfunc

" Tests for the quickfix/location list changedtick
func Xqftick_tests(cchar)
  call s:setup_commands(a:cchar)

  call g:Xsetlist([], 'f')

  Xexpr "F1:10:Line10"
  let qfid = g:Xgetlist({'id' : 0}).id
  call assert_equal(1, g:Xgetlist({'changedtick' : 0}).changedtick)
  Xaddexpr "F2:20:Line20\nF2:21:Line21"
  call assert_equal(2, g:Xgetlist({'changedtick' : 0}).changedtick)
  call g:Xsetlist([], 'a', {'lines' : ["F3:30:Line30", "F3:31:Line31"]})
  call assert_equal(3, g:Xgetlist({'changedtick' : 0}).changedtick)
  call g:Xsetlist([], 'r', {'lines' : ["F4:40:Line40"]})
  call assert_equal(4, g:Xgetlist({'changedtick' : 0}).changedtick)
  call g:Xsetlist([], 'a', {'title' : 'New Title'})
  call assert_equal(5, g:Xgetlist({'changedtick' : 0}).changedtick)

  enew!
  call append(0, ["F5:50:L50", "F6:60:L60"])
  Xaddbuffer
  call assert_equal(6, g:Xgetlist({'changedtick' : 0}).changedtick)
  enew!

  call g:Xsetlist([], 'a', {'context' : {'bus' : 'pci'}})
  call assert_equal(7, g:Xgetlist({'changedtick' : 0}).changedtick)
  call g:Xsetlist([{'filename' : 'F7', 'lnum' : 10, 'text' : 'L7'},
	      \ {'filename' : 'F7', 'lnum' : 11, 'text' : 'L11'}], 'a')
  call assert_equal(8, g:Xgetlist({'changedtick' : 0}).changedtick)
  call g:Xsetlist([{'filename' : 'F7', 'lnum' : 10, 'text' : 'L7'},
	      \ {'filename' : 'F7', 'lnum' : 11, 'text' : 'L11'}], ' ')
  call assert_equal(1, g:Xgetlist({'changedtick' : 0}).changedtick)
  call g:Xsetlist([{'filename' : 'F7', 'lnum' : 10, 'text' : 'L7'},
	      \ {'filename' : 'F7', 'lnum' : 11, 'text' : 'L11'}], 'r')
  call assert_equal(2, g:Xgetlist({'changedtick' : 0}).changedtick)

  call writefile(["F8:80:L80", "F8:81:L81"], "Xone")
  Xfile Xone
  call assert_equal(1, g:Xgetlist({'changedtick' : 0}).changedtick)
  Xaddfile Xone
  call assert_equal(2, g:Xgetlist({'changedtick' : 0}).changedtick)

  " Test case for updating a non-current quickfix list
  call g:Xsetlist([], 'f')
  Xexpr "F1:1:L1"
  Xexpr "F2:2:L2"
  call g:Xsetlist([], 'a', {'nr' : 1, "lines" : ["F10:10:L10"]})
  call assert_equal(1, g:Xgetlist({'changedtick' : 0}).changedtick)
  call assert_equal(2, g:Xgetlist({'nr' : 1, 'changedtick' : 0}).changedtick)

  call delete("Xone")
endfunc

func Test_qf_tick()
  call Xqftick_tests('c')
  call Xqftick_tests('l')
endfunc

" The following test used to crash vim
func Test_lbuffer_crash()
  sv Xtest
  augroup QF_Test
    au!
    au * * bw
  augroup END
  lbuffer
  augroup QF_Test
    au!
  augroup END
endfunc

" The following test used to crash vim
func Test_lexpr_crash()
  augroup QF_Test
    au!
    au * * call setloclist(0, [], 'f')
  augroup END
  lexpr ""
  augroup QF_Test
    au!
  augroup END
  enew | only
endfunc

" The following test used to crash Vim
func Test_lvimgrep_crash()
  sv Xtest
  augroup QF_Test
    au!
    au * * call setloclist(0, [], 'f')
  augroup END
  lvimgrep quickfix test_quickfix.vim
  augroup QF_Test
    au!
  augroup END
  enew | only
endfunc

func Xqfjump_tests(cchar)
  call s:setup_commands(a:cchar)

  call writefile(["Line1\tFoo", "Line2"], 'F1')
  call writefile(["Line1\tBar", "Line2"], 'F2')
  call writefile(["Line1\tBaz", "Line2"], 'F3')

  call g:Xsetlist([], 'f')

  " Tests for
  "   Jumping to a line using a pattern
  "   Jumping to a column greater than the last column in a line
  "   Jumping to a line greater than the last line in the file
  let l = []
  for i in range(1, 7)
    call add(l, {})
  endfor
  let l[0].filename='F1'
  let l[0].pattern='Line1'
  let l[1].filename='F2'
  let l[1].pattern='Line1'
  let l[2].filename='F3'
  let l[2].pattern='Line1'
  let l[3].filename='F3'
  let l[3].lnum=1
  let l[3].col=9
  let l[3].vcol=1
  let l[4].filename='F3'
  let l[4].lnum=99
  let l[5].filename='F3'
  let l[5].lnum=1
  let l[5].col=99
  let l[5].vcol=1
  let l[6].filename='F3'
  let l[6].pattern='abcxyz'

  call g:Xsetlist([], ' ', {'items' : l})
  Xopen | only
  2Xnext
  call assert_equal(3, g:Xgetlist({'idx' : 0}).idx)
  call assert_equal('F3', bufname('%'))
  Xnext
  call assert_equal(7, col('.'))
  Xnext
  call assert_equal(2, line('.'))
  Xnext
  call assert_equal(9, col('.'))
  2
  Xnext
  call assert_equal(2, line('.'))

  if a:cchar == 'l'
    " When jumping to a location list entry in the location list window and
    " no usable windows are available, then a new window should be opened.
    enew! | new | only
    call g:Xsetlist([], 'f')
    setlocal buftype=nofile
    new
    call g:Xsetlist([], ' ', {'lines' : ['F1:1:1:Line1', 'F1:2:2:Line2', 'F2:1:1:Line1', 'F2:2:2:Line2', 'F3:1:1:Line1', 'F3:2:2:Line2']})
    Xopen
    let winid = win_getid()
    wincmd p
    close
    call win_gotoid(winid)
    Xnext
    call assert_equal(3, winnr('$'))
    call assert_equal(1, winnr())
    call assert_equal(2, line('.'))

    " When jumping to an entry in the location list window and the window
    " associated with the location list is not present and a window containing
    " the file is already present, then that window should be used.
    close
    belowright new
    call g:Xsetlist([], 'f')
    edit F3
    call win_gotoid(winid)
    Xlast
    call assert_equal(3, winnr())
    call assert_equal(6, g:Xgetlist({'size' : 1}).size)
    call assert_equal(winid, g:Xgetlist({'winid' : 1}).winid)
  endif

  " Cleanup
  enew!
  new | only

  call delete('F1')
  call delete('F2')
  call delete('F3')
endfunc

func Test_qfjump()
  call Xqfjump_tests('c')
  call Xqfjump_tests('l')
endfunc

" The following test used to crash Vim.
" Open the location list window and close the regular window associated with
" the location list. When the garbage collection runs now, it incorrectly
" marks the location list context as not in use and frees the context.
func Test_ll_window_ctx()
  call setloclist(0, [], 'f')
  call setloclist(0, [], 'a', {'context' : []})
  lopen | only
  call test_garbagecollect_now()
  echo getloclist(0, {'context' : 1}).context
  enew | only
endfunc

" The following test used to crash vim
func Test_lfile_crash()
  sp Xtest
  au QuickFixCmdPre * bw
  call assert_fails('lfile', 'E40')
  au! QuickFixCmdPre
endfunc

" Tests for quickfix/location lists changed by autocommands when
" :vimgrep/:lvimgrep commands are running.
func Test_vimgrep_autocmd()
  call setqflist([], 'f')
  call writefile(['stars'], 'Xtest1.txt')
  call writefile(['stars'], 'Xtest2.txt')

  " Test 1:
  " When searching for a pattern using :vimgrep, if the quickfix list is
  " changed by an autocmd, the results should be added to the correct quickfix
  " list.
  autocmd BufRead Xtest2.txt cexpr '' | cexpr ''
  silent vimgrep stars Xtest*.txt
  call assert_equal(1, getqflist({'nr' : 0}).nr)
  call assert_equal(3, getqflist({'nr' : '$'}).nr)
  call assert_equal('Xtest2.txt', bufname(getqflist()[1].bufnr))
  au! BufRead Xtest2.txt

  " Test 2:
  " When searching for a pattern using :vimgrep, if the quickfix list is
  " freed, then a error should be given.
  silent! %bwipe!
  call setqflist([], 'f')
  autocmd BufRead Xtest2.txt for i in range(10) | cexpr '' | endfor
  call assert_fails('vimgrep stars Xtest*.txt', 'E925:')
  au! BufRead Xtest2.txt

  " Test 3:
  " When searching for a pattern using :lvimgrep, if the location list is
  " freed, then the command should error out.
  silent! %bwipe!
  let g:save_winid = win_getid()
  autocmd BufRead Xtest2.txt call setloclist(g:save_winid, [], 'f')
  call assert_fails('lvimgrep stars Xtest*.txt', 'E926:')
  au! BufRead Xtest2.txt

  call delete('Xtest1.txt')
  call delete('Xtest2.txt')
  call setqflist([], 'f')
endfunc

func Test_lbuffer_with_bwipe()
  new
  new
  augroup nasty
    au * * bwipe
  augroup END
  lbuffer
  augroup nasty
    au!
  augroup END
endfunc
