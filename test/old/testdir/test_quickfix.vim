" Test for the quickfix feature.

source check.vim
source vim9.vim
CheckFeature quickfix

source screendump.vim

set encoding=utf-8

func s:setup_commands(cchar)
  if a:cchar == 'c'
    command! -nargs=* -bang Xlist <mods>clist<bang> <args>
    command! -nargs=* Xgetexpr <mods>cgetexpr <args>
    command! -nargs=* Xaddexpr <mods>caddexpr <args>
    command! -nargs=* -count Xolder <mods><count>colder <args>
    command! -nargs=* Xnewer <mods>cnewer <args>
    command! -nargs=* Xopen <mods> copen <args>
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
    command! -count -nargs=* -bang Xnfile <mods><count>cnfile<bang> <args>
    command! -nargs=* -bang Xpfile <mods>cpfile<bang> <args>
    command! -nargs=* Xexpr <mods>cexpr <args>
    command! -count=999 -nargs=* Xvimgrep <mods> <count>vimgrep <args>
    command! -nargs=* Xvimgrepadd <mods> vimgrepadd <args>
    command! -nargs=* Xgrep <mods> grep <args>
    command! -nargs=* Xgrepadd <mods> grepadd <args>
    command! -nargs=* Xhelpgrep helpgrep <args>
    command! -nargs=0 -count Xcc <count>cc
    command! -count=1 -nargs=0 Xbelow <mods><count>cbelow
    command! -count=1 -nargs=0 Xabove <mods><count>cabove
    command! -count=1 -nargs=0 Xbefore <mods><count>cbefore
    command! -count=1 -nargs=0 Xafter <mods><count>cafter
    command! -nargs=1 Xsethist <mods>set chistory=<args>
    command! -nargs=0 Xsethistdefault <mods>set chistory&
    let g:Xgetlist = function('getqflist')
    let g:Xsetlist = function('setqflist')
    call setqflist([], 'f')
  else
    command! -nargs=* -bang Xlist <mods>llist<bang> <args>
    command! -nargs=* Xgetexpr <mods>lgetexpr <args>
    command! -nargs=* Xaddexpr <mods>laddexpr <args>
    command! -nargs=* -count Xolder <mods><count>lolder <args>
    command! -nargs=* Xnewer <mods>lnewer <args>
    command! -nargs=* Xopen <mods> lopen <args>
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
    command! -count -nargs=* -bang Xnfile <mods><count>lnfile<bang> <args>
    command! -nargs=* -bang Xpfile <mods>lpfile<bang> <args>
    command! -nargs=* Xexpr <mods>lexpr <args>
    command! -count=999 -nargs=* Xvimgrep <mods> <count>lvimgrep <args>
    command! -nargs=* Xvimgrepadd <mods> lvimgrepadd <args>
    command! -nargs=* Xgrep <mods> lgrep <args>
    command! -nargs=* Xgrepadd <mods> lgrepadd <args>
    command! -nargs=* Xhelpgrep lhelpgrep <args>
    command! -nargs=0 -count Xcc <count>ll
    command! -count=1 -nargs=0 Xbelow <mods><count>lbelow
    command! -count=1 -nargs=0 Xabove <mods><count>labove
    command! -count=1 -nargs=0 Xbefore <mods><count>lbefore
    command! -count=1 -nargs=0 Xafter <mods><count>lafter
    command! -nargs=1 Xsethist <mods>set lhistory=<args>
    command! -nargs=1 Xsetlocalhist <mods>setlocal lhistory=<args>
    command! -nargs=0 Xsethistdefault <mods>set lhistory&
    let g:Xgetlist = function('getloclist', [0])
    let g:Xsetlist = function('setloclist', [0])
    call setloclist(0, [], 'f')
  endif
endfunc

" This must be run before any error lists are created.
func Test_AA_cc_no_errors()
  call assert_fails('cc', 'E42:')
  call assert_fails('ll', 'E42:')
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
  let lines =<< trim END
    non-error 1
    Xtestfile1:1:3:Line1
    non-error 2
    Xtestfile2:2:2:Line2
    non-error| 3
    Xtestfile3:3:1:Line3
  END
  Xgetexpr lines

  " List only valid entries
  let l = split(execute('Xlist', ''), "\n")
  call assert_equal([' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 6 Xtestfile3:3 col 1: Line3'], l)

  " List all the entries
  let l = split(execute('Xlist!', ''), "\n")
  call assert_equal([' 1: non-error 1', ' 2 Xtestfile1:1 col 3: Line1',
		   \ ' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2',
		   \ ' 5: non-error| 3', ' 6 Xtestfile3:3 col 1: Line3'], l)

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

  " Ranged entries
  call g:Xsetlist([{'lnum':10,'text':'Line1'},
	      \ {'lnum':20,'col':10,'text':'Line2'},
	      \ {'lnum':30,'col':15,'end_col':20,'text':'Line3'},
	      \ {'lnum':40,'end_lnum':45,'text':'Line4'},
	      \ {'lnum':50,'end_lnum':55,'col':15,'text':'Line5'},
	      \ {'lnum':60,'end_lnum':65,'col':25,'end_col':35,'text':'Line6'}])
  let l = split(execute('Xlist', ""), "\n")
  call assert_equal([' 1:10: Line1',
	      \ ' 2:20 col 10: Line2',
	      \ ' 3:30 col 15-20: Line3',
	      \ ' 4:40-45: Line4',
	      \ ' 5:50-55 col 15: Line5',
	      \ ' 6:60-65 col 25-35: Line6'], l)

  " Different types of errors
  call g:Xsetlist([{'lnum':10,'col':5,'type':'W', 'text':'Warning','nr':11},
	      \ {'lnum':20,'col':10,'type':'e','text':'Error','nr':22},
	      \ {'lnum':30,'col':15,'type':'i','text':'Info','nr':33},
	      \ {'lnum':40,'col':20,'type':'x', 'text':'Other','nr':44},
	      \ {'lnum':50,'col':25,'type':"\<C-A>",'text':'one','nr':55},
	      \ {'lnum':0,'type':'e','text':'Check type field is output even when lnum==0. ("error" was not output by v9.0.0736.)','nr':66}])
  let l = split(execute('Xlist', ""), "\n")
  call assert_equal([' 1:10 col 5 warning  11: Warning',
	      \ ' 2:20 col 10 error  22: Error',
	      \ ' 3:30 col 15 info  33: Info',
	      \ ' 4:40 col 20 x  44: Other',
	      \ ' 5:50 col 25  55: one',
              \ ' 6 error  66: Check type field is output even when lnum==0. ("error" was not output by v9.0.0736.)'], l)

  " Test for module names, one needs to explicitly set `'valid':v:true` so
  call g:Xsetlist([
	\ {'lnum':10,'col':5,'type':'W','module':'Data.Text','text':'ModuleWarning','nr':11,'valid':v:true},
	\ {'lnum':20,'col':10,'type':'W','module':'Data.Text','filename':'Data/Text.hs','text':'ModuleWarning','nr':22,'valid':v:true},
	\ {'lnum':30,'col':15,'type':'W','filename':'Data/Text.hs','text':'FileWarning','nr':33,'valid':v:true}])
  let l = split(execute('Xlist', ""), "\n")
  call assert_equal([' 1 Data.Text:10 col 5 warning  11: ModuleWarning',
	\ ' 2 Data.Text:20 col 10 warning  22: ModuleWarning',
	\ ' 3 Data/Text.hs:30 col 15 warning  33: FileWarning'], l)

  " Very long line should be displayed.
  let text = 'Line' .. repeat('1234567890', 130)
  let lines = ['Xtestfile9:2:9:' .. text]
  Xgetexpr lines

  let l = split(execute('Xlist', ''), "\n")
  call assert_equal([' 1 Xtestfile9:2 col 9: ' .. text] , l)

  " For help entries in the quickfix list, only the filename without directory
  " should be displayed
  Xhelpgrep setqflist()
  let l = split(execute('Xlist 1', ''), "\n")
  call assert_match('^ 1 [^\\/]\{-}:', l[0])

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

  if a:cchar == 'l'
    " No location list for the current window
    call assert_fails('lolder', 'E776:')
    call assert_fails('lnewer', 'E776:')
  endif

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
      call assert_fails('lwindow', 'E776:')
  endif

  " Create a list with no valid entries
  Xgetexpr ['non-error 1', 'non-error 2', 'non-error 3']

  " Quickfix/Location window should not open with no valid errors
  Xwindow
  call assert_true(winnr('$') == 1)

  " Create a list with valid entries
  let lines =<< trim END
    Xtestfile1:1:3:Line1
    Xtestfile2:2:2:Line2
    Xtestfile3:3:1:Line3
  END
  Xgetexpr lines

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
		      \  && winheight(0) == 5)

  " Opening the window again, should move the cursor to that window
  wincmd t
  Xopen 7
  call assert_true(winnr('$') == 2 && winnr() == 2 &&
	\ winheight(0) == 7 &&
	\ getline('.') ==# '|| non-error 1')

  " :cnext in quickfix window should move to the next entry
  Xnext
  call assert_equal(2, g:Xgetlist({'idx' : 0}).idx)

  " Calling cwindow should close the quickfix window with no valid errors
  Xwindow
  call assert_true(winnr('$') == 1)

  " Specifying the width should adjust the width for a vertically split
  " quickfix window.
  vert Xopen
  call assert_equal(10, winwidth(0))
  vert Xopen 12
  call assert_equal(12, winwidth(0))
  Xclose

  " Horizontally or vertically splitting the quickfix window should create a
  " normal window/buffer
  Xopen
  wincmd s
  call assert_equal(0, getwininfo(win_getid())[0].quickfix)
  call assert_equal(0, getwininfo(win_getid())[0].loclist)
  call assert_notequal('quickfix', &buftype)
  close
  Xopen
  wincmd v
  call assert_equal(0, getwininfo(win_getid())[0].quickfix)
  call assert_equal(0, getwininfo(win_getid())[0].loclist)
  call assert_notequal('quickfix', &buftype)
  close
  Xopen
  Xclose

  if a:cchar == 'c'
      " Opening the quickfix window in multiple tab pages should reuse the
      " quickfix buffer
      let lines =<< trim END
        Xtestfile1:1:3:Line1
        Xtestfile2:2:2:Line2
        Xtestfile3:3:1:Line3
      END
      Xgetexpr lines
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

func Test_copenHeight()
  copen
  wincmd H
  let height = winheight(0)
  copen 10
  call assert_equal(height, winheight(0))
  quit
endfunc

func Test_copenHeight_tabline()
  set tabline=foo showtabline=2
  copen
  wincmd H
  let height = winheight(0)
  copen 10
  call assert_equal(height, winheight(0))
  quit
  set tabline& showtabline&
endfunc

" Tests for the :cfile, :lfile, :caddfile, :laddfile, :cgetfile and :lgetfile
" commands.
func XfileTests(cchar)
  call s:setup_commands(a:cchar)

  let lines =<< trim END
    Xtestfile1:700:10:Line 700
    Xtestfile2:800:15:Line 800
  END
  call writefile(lines, 'Xqftestfile1')

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

  let lines =<< trim END
    Xtestfile1:222:77:Line 222
    Xtestfile2:333:88:Line 333
  END
  call writefile(lines, 'Xqftestfile1')

  enew!
  Xgetfile Xqftestfile1
  let l = g:Xgetlist()
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 222 && l[0].col == 77 && l[0].text ==# 'Line 222' &&
	\ l[1].lnum == 333 && l[1].col == 88 && l[1].text ==# 'Line 333')

  " Test for a file with a long line and without a newline at the end
  let text = repeat('x', 1024)
  let t = 'a.txt:18:' . text
  call writefile([t], 'Xqftestfile1', 'b')
  silent! Xfile Xqftestfile1
  call assert_equal(text, g:Xgetlist()[0].text)

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
  let lines =<< trim END
    Xtestfile7:700:10:Line 700
    Xtestfile8:800:15:Line 800
  END
  silent! call setline(1, lines)
  Xbuffer!
  let l = g:Xgetlist()
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 700 && l[0].col == 10 && l[0].text ==# 'Line 700' &&
	\ l[1].lnum == 800 && l[1].col == 15 && l[1].text ==# 'Line 800')

  enew!
  let lines =<< trim END
    Xtestfile9:900:55:Line 900
    Xtestfile10:950:66:Line 950
  END
  silent! call setline(1, lines)
  Xgetbuffer
  let l = g:Xgetlist()
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 900 && l[0].col == 55 && l[0].text ==# 'Line 900' &&
	\ l[1].lnum == 950 && l[1].col == 66 && l[1].text ==# 'Line 950')

  enew!
  let lines =<< trim END
    Xtestfile11:700:20:Line 700
    Xtestfile12:750:25:Line 750
  END
  silent! call setline(1, lines)
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
    let cmd = '$cc'
  else
    let err = 'E776:'
    let cmd = '$ll'
  endif
  call assert_fails('Xnext', err)
  call assert_fails('Xprev', err)
  call assert_fails('Xnfile', err)
  call assert_fails('Xpfile', err)
  call assert_fails(cmd, err)

  Xexpr ''
  call assert_fails(cmd, 'E42:')

  call s:create_test_file('Xqftestfile1')
  call s:create_test_file('Xqftestfile2')

  let lines =<< trim END
    Xqftestfile1:5:Line5
    Xqftestfile1:6:Line6
    Xqftestfile2:10:Line10
    Xqftestfile2:11:Line11
    RegularLine1
    RegularLine2
  END
  Xgetexpr lines

  Xfirst
  call assert_fails('-5Xcc', 'E16:')
  call assert_fails('Xprev', 'E553')
  call assert_fails('Xpfile', 'E553')
  Xnfile
  call assert_equal('Xqftestfile2', @%)
  call assert_equal(10, line('.'))
  Xpfile
  call assert_equal('Xqftestfile1', @%)
  call assert_equal(6, line('.'))
  5Xcc
  call assert_equal(5, g:Xgetlist({'idx':0}).idx)
  2Xcc
  call assert_equal(2, g:Xgetlist({'idx':0}).idx)
  if a:cchar == 'c'
    cc
  else
    ll
  endif
  call assert_equal(2, g:Xgetlist({'idx':0}).idx)
  10Xcc
  call assert_equal(6, g:Xgetlist({'idx':0}).idx)
  Xlast
  Xprev
  call assert_equal('Xqftestfile2', @%)
  call assert_equal(11, line('.'))
  call assert_fails('Xnext', 'E553')
  call assert_fails('Xnfile', 'E553')
  " To process the range using quickfix list entries, directly use the
  " quickfix commands (don't use the user defined commands)
  if a:cchar == 'c'
    $cc
  else
    $ll
  endif
  call assert_equal(6, g:Xgetlist({'idx':0}).idx)
  Xrewind
  call assert_equal('Xqftestfile1', @%)
  call assert_equal(5, line('.'))

  10Xnext
  call assert_equal('Xqftestfile2', @%)
  call assert_equal(11, line('.'))
  10Xprev
  call assert_equal('Xqftestfile1', @%)
  call assert_equal(5, line('.'))

  " Jumping to an error from the error window using cc command
  let lines =<< trim END
    Xqftestfile1:5:Line5
    Xqftestfile1:6:Line6
    Xqftestfile2:10:Line10
    Xqftestfile2:11:Line11
  END
  Xgetexpr lines
  Xopen
  10Xcc
  call assert_equal(11, line('.'))
  call assert_equal('Xqftestfile2', @%)
  Xopen
  call cursor(2, 1)
  if a:cchar == 'c'
    .cc
  else
    .ll
  endif
  call assert_equal(6, line('.'))
  call assert_equal('Xqftestfile1', @%)

  " Jumping to an error from the error window (when only the error window is
  " present)
  Xopen | only
  Xlast 1
  call assert_equal(5, line('.'))
  call assert_equal('Xqftestfile1', @%)

  Xexpr ""
  call assert_fails('Xnext', 'E42:')

  call delete('Xqftestfile1')
  call delete('Xqftestfile2')

  " Should be able to use next/prev with invalid entries
  Xexpr ""
  call assert_equal(0, g:Xgetlist({'idx' : 0}).idx)
  call assert_equal(0, g:Xgetlist({'size' : 0}).size)
  Xaddexpr ['foo', 'bar', 'baz', 'quux', 'sh|moo']
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
  call assert_match('|\d\+ col \d\+-\d\+|', getbufline(winbufnr(2), 1)[0])

  " This wipes out the buffer, make sure that doesn't cause trouble.
  Xclose

  " When the current window is vertically split, jumping to a help match
  " should open the help window at the top.
  only | enew
  let w1 = win_getid()
  vert new
  let w2 = win_getid()
  Xnext
  let w3 = win_getid()
  call assert_true(&buftype == 'help')
  call assert_true(winnr() == 1)
  " See jump_to_help_window() for details
  let w2_width = winwidth(w2)
  if w2_width != &columns && w2_width < 80
    call assert_equal(['col', [['leaf', w3],
          \ ['row', [['leaf', w2], ['leaf', w1]]]]], winlayout())
  else
    call assert_equal(['row', [['col', [['leaf', w3], ['leaf', w2]]],
          \ ['leaf', w1]]] , winlayout())
  endif

  new | only
  set buftype=help
  set modified
  call assert_fails('Xnext', 'E37:')
  set nomodified
  new | only

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
  " Invalid regular expression
  call assert_fails('Xhelpgrep \@<!', 'E866:')
endfunc

func Test_helpgrep()
  call s:test_xhelpgrep('c')
  helpclose
  call s:test_xhelpgrep('l')
endfunc

" When running the :helpgrep command, if an autocmd modifies the 'cpoptions'
" value, then Vim crashes. (issue fixed by 7.2b-004 and 8.2.4453)
func Test_helpgrep_restore_cpo_aucmd()
  let save_cpo = &cpo
  augroup QF_Test
    au!
    autocmd BufNew * set cpo=acd
  augroup END

  helpgrep quickfix
  call assert_equal('acd', &cpo)
  %bw!

  set cpo&vim
  augroup QF_Test
    au!
    autocmd BufReadPost * set cpo=
  augroup END

  helpgrep buffer
  call assert_equal('', &cpo)

  augroup QF_Test
    au!
  augroup END
  %bw!
  let &cpo = save_cpo
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

func Test_bufwinenter_once()
  augroup QfBufWinEnter
    au!
    au BufWinEnter * let g:got_afile ..= 'got ' .. expand('<afile>')
  augroup END
  let g:got_afile = ''
  copen
  call assert_equal('got quickfix', g:got_afile)

  cclose
  unlet g:got_afile
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
    eval qflist->setloclist(0, ' ')
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
  delfunc R
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
  " The 'errorformat' setting is different on non-Unix systems.
  " This test works only on Unix-like systems.
  CheckUnix

  let l =<< trim [DATA]
    "Xtestfile", line 4.12: 1506-045 (S) Undeclared identifier fd_set.
    ﻿"Xtestfile", line 6 col 19; this is an error
    gcc -c -DHAVE_CONFIsing-prototypes -I/usr/X11R6/include  version.c
    Xtestfile:9: parse error before `asd'
    make: *** [src/vim/testdir/Makefile:100: test_quickfix] Error 1
    in file "Xtestfile" linenr 10: there is an error

    2 returned
    "Xtestfile", line 11 col 1; this is an error
    "Xtestfile", line 12 col 2; this is another error
    "Xtestfile", line 14:10; this is an error in column 10
    =Xtestfile=, line 15:10; this is another error, but in vcol 10 this time
    "Xtestfile", linenr 16: yet another problem
    Error in "Xtestfile" at line 17:
    x should be a dot
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 17
                ^
    Error in "Xtestfile" at line 18:
    x should be a dot
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 18
    .............^
    Error in "Xtestfile" at line 19:
    x should be a dot
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 19
    --------------^
    Error in "Xtestfile" at line 20:
    x should be a dot
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 20
	       ^

    Does anyone know what is the problem and how to correction it?
    "Xtestfile", line 21 col 9: What is the title of the quickfix window?
    "Xtestfile", line 22 col 9: What is the title of the quickfix window?
  [DATA]

  call writefile(l, 'Xerrorfile1')
  call writefile(l[:-2], 'Xerrorfile2')

  let m =<< [DATA]
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  2
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  3
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  4
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  5
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  6
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  7
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  8
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  9
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 10
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 11
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 12
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 13
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 14
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 15
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 16
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 17
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 18
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 19
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 20
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 21
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 22
[DATA]
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

  let lines =<< trim END
    Entering dir 'dir1/a'
    habits2.txt:1:Nine Healthy Habits
    Entering dir 'b'
    habits3.txt:2:0 Hours of television
    habits2.txt:7:5 Small meals
    Entering dir 'dir1/c'
    habits4.txt:3:1 Hour of exercise
    Leaving dir 'dir1/c'
    Leaving dir 'dir1/a'
    habits1.txt:4:2 Liters of water
    Entering dir 'dir2'
    habits5.txt:5:3 Cups of hot green tea
    Leaving dir 'dir2'
  END

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
endfunc

" Tests for %D and %X errorformat options
func Test_efm_dirstack()
  " Create the directory stack and files
  call mkdir('dir1')
  call mkdir('dir1/a')
  call mkdir('dir1/a/b')
  call mkdir('dir1/c')
  call mkdir('dir2')

  let lines =<< trim END
    Nine Healthy Habits
    0 Hours of television
    1 Hour of exercise
    2 Liters of water
    3 Cups of hot green tea
    4 Short mental breaks
    5 Small meals
    6 AM wake up time
    7 Minutes of laughter
    8 Hours of sleep (at least)
    9 PM end of the day and off to bed
  END
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
  let lines =<< trim END
    ignored warning 1
    more ignored continuation 2
    ignored end
    error resync 4
  END
  Xgetexpr lines
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

  " Invalid regular expression
  set efm=%\\%%k
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E867:')

  set efm=
  call assert_fails('Xexpr "abc.txt:1:Hello world"', 'E378:')

  " Empty directory name. When there is an error in parsing new entries, make
  " sure the previous quickfix list is made the current list.
  set efm&
  cexpr ["one", "two"]
  let qf_id = getqflist(#{id: 0}).id
  set efm=%DEntering\ dir\ abc,%f:%l:%m
  call assert_fails('Xexpr ["Entering dir abc", "abc.txt:1:Hello world"]', 'E379:')
  call assert_equal(qf_id, getqflist(#{id: 0}).id)

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
  call assert_equal('^\VLine search text\$', l[0].pattern)
  call assert_equal(0, l[0].lnum)

  let l = split(execute('clist', ''), "\n")
  call assert_equal([' 1 Xtestfile:^\VLine search text\$:  '], l)

  " Test for a long line
  cexpr 'Xtestfile:' . repeat('a', 1026)
  let l = getqflist()
  call assert_equal('^\V' . repeat('a', 1019) . '\$', l[0].pattern)

  " Test for %P, %Q and %t format specifiers
  let lines =<< trim [DATA]
    [Xtestfile1]
    (1,17)  error: ';' missing
    (21,2)  warning: variable 'z' not defined
    (67,3)  error: end of file found before string ended
    --

    [Xtestfile2]
    --

    [Xtestfile3]
    NEW compiler v1.1
    (2,2)   warning: variable 'x' not defined
    (67,3)  warning: 's' already defined
    --
  [DATA]

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

  " Test for %P, %Q with non-existing files
  cexpr lines
  let l = getqflist()
  call assert_equal(14, len(l))
  call assert_equal('[Xtestfile1]', l[0].text)
  call assert_equal('[Xtestfile2]', l[6].text)
  call assert_equal('[Xtestfile3]', l[9].text)

  " Tests for %E, %C and %Z format specifiers
  let lines =<< trim [DATA]
    Error 275
    line 42
    column 3
    ' ' expected after '--'
  [DATA]

  set efm=%EError\ %n,%Cline\ %l,%Ccolumn\ %c,%Z%m
  cgetexpr lines
  let l = getqflist()
  call assert_equal(275, l[0].nr)
  call assert_equal(42, l[0].lnum)
  call assert_equal(3, l[0].col)
  call assert_equal('E', l[0].type)
  call assert_equal("\n' ' expected after '--'", l[0].text)

  " Test for %>
  let lines =<< trim [DATA]
    Error in line 147 of foo.c:
    unknown variable 'i'
  [DATA]

  set efm=unknown\ variable\ %m,%E%>Error\ in\ line\ %l\ of\ %f:,%Z%m
  cgetexpr lines
  let l = getqflist()
  call assert_equal(147, l[0].lnum)
  call assert_equal('E', l[0].type)
  call assert_equal("\nunknown variable 'i'", l[0].text)

  " Test for %A, %C and other formats
  let lines =<< trim [DATA]
    ==============================================================
    FAIL: testGetTypeIdCachesResult (dbfacadeTest.DjsDBFacadeTest)
    --------------------------------------------------------------
    Traceback (most recent call last):
      File "unittests/dbfacadeTest.py", line 89, in testFoo
        self.assertEquals(34, dtid)
      File "/usr/lib/python2.2/unittest.py", line 286, in
     failUnlessEqual
        raise self.failureException, \\
    W:AssertionError: 34 != 33

    --------------------------------------------------------------
    Ran 27 tests in 0.063s
  [DATA]

  set efm=%C\ %.%#,%A\ \ File\ \"%f\"\\,\ line\ %l%.%#,%Z%[%^\ ]%\\@=%t:%m
  cgetexpr lines
  let l = getqflist()
  call assert_equal(8, len(l))
  call assert_equal(89, l[4].lnum)
  call assert_equal(1, l[4].valid)
  call assert_equal('unittests/dbfacadeTest.py', bufname(l[4].bufnr))
  call assert_equal('W', l[4].type)

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

  " Test for a long module name
  cexpr 'Xtest(' . repeat('m', 1026) . '):15 message'
  let l = getqflist()
  " call assert_equal(repeat('m', 1024), l[0].module)
  call assert_equal(repeat('m', 1023), l[0].module)
  call assert_equal(15, l[0].lnum)
  call assert_equal('message', l[0].text)

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

  " When matching error lines, case should be ignored. Test for this.
  set noignorecase
  let l=getqflist({'lines' : ['Xtest:FOO10:Line 20'], 'efm':'%f:foo%l:%m'})
  call assert_equal(10, l.items[0].lnum)
  call assert_equal('Line 20', l.items[0].text)
  set ignorecase&

  new | only
  let &efm = save_efm
endfunc

" Test for '%t' (error type) field in 'efm'
func Test_efm_error_type()
  let save_efm = &efm

  " error type
  set efm=%f:%l:%t:%m
  let lines =<< trim END
    Xfile1:10:E:msg1
    Xfile1:20:W:msg2
    Xfile1:30:I:msg3
    Xfile1:40:N:msg4
    Xfile1:50:R:msg5
  END
  cexpr lines
  let output = split(execute('clist'), "\n")
  call assert_equal([
        \ ' 1 Xfile1:10 error: msg1',
        \ ' 2 Xfile1:20 warning: msg2',
        \ ' 3 Xfile1:30 info: msg3',
        \ ' 4 Xfile1:40 note: msg4',
        \ ' 5 Xfile1:50 R: msg5'], output)

  " error type and a error number
  set efm=%f:%l:%t:%n:%m
  let lines =<< trim END
    Xfile1:10:E:2:msg1
    Xfile1:20:W:4:msg2
    Xfile1:30:I:6:msg3
    Xfile1:40:N:8:msg4
    Xfile1:50:R:3:msg5
  END
  cexpr lines
  let output = split(execute('clist'), "\n")
  call assert_equal([
        \ ' 1 Xfile1:10 error   2: msg1',
        \ ' 2 Xfile1:20 warning   4: msg2',
        \ ' 3 Xfile1:30 info   6: msg3',
        \ ' 4 Xfile1:40 note   8: msg4',
        \ ' 5 Xfile1:50 R   3: msg5'], output)
  let &efm = save_efm
endfunc

" Test for end_lnum ('%e') and end_col ('%k') fields in 'efm'
func Test_efm_end_lnum_col()
  let save_efm = &efm

  " single line
  set efm=%f:%l-%e:%c-%k:%t:%m
  cexpr ["Xfile1:10-20:1-2:E:msg1", "Xfile1:20-30:2-3:W:msg2",]
  let output = split(execute('clist'), "\n")
  call assert_equal([
        \ ' 1 Xfile1:10-20 col 1-2 error: msg1',
        \ ' 2 Xfile1:20-30 col 2-3 warning: msg2'], output)

  " multiple lines
  set efm=%A%n)%m,%Z%f:%l-%e:%c-%k
  let lines =<< trim END
    1)msg1
    Xfile1:14-24:1-2
    2)msg2
    Xfile1:24-34:3-4
  END
  cexpr lines
  let output = split(execute('clist'), "\n")
  call assert_equal([
        \ ' 1 Xfile1:14-24 col 1-2 error   1: msg1',
        \ ' 2 Xfile1:24-34 col 3-4 error   2: msg2'], output)
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

  augroup QF_Test
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

  augroup QF_Test
    au!
  augroup END

  if a:cchar == 'c'
    cexpr ["Xtest1:1:Line"]
    cwindow
    only
    augroup QF_Test
      au!
      autocmd WinEnter * call setqflist([], 'f')
    augroup END
    call assert_fails('exe "normal \<CR>"', 'E925:')
    augroup QF_Test
      au!
    augroup END
  endif
  %bw!
endfunc

func Test_quickfix_was_changed_by_autocmd()
  call XquickfixChangedByAutocmd('c')
  call XquickfixChangedByAutocmd('l')
endfunc

func Test_setloclist_in_autocommand()
  call writefile(['test1', 'test2'], 'Xfile')
  edit Xfile
  let s:bufnr = bufnr()
  call setloclist(1,
        \ [{'bufnr' : s:bufnr, 'lnum' : 1, 'text' : 'test1'},
        \  {'bufnr' : s:bufnr, 'lnum' : 2, 'text' : 'test2'}])

  augroup Test_LocList
    au!
    autocmd BufEnter * call setloclist(1,
          \ [{'bufnr' : s:bufnr, 'lnum' : 1, 'text' : 'test1'},
          \  {'bufnr' : s:bufnr, 'lnum' : 2, 'text' : 'test2'}], 'r')
  augroup END

  lopen
  call assert_fails('exe "normal j\<CR>"', 'E926:')

  augroup Test_LocList
    au!
  augroup END
  call delete('Xfile')
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
        \  {'bufnr': a:bnum, 'lnum': 2, 'end_lnum': 3, 'col': 4, 'end_col': 5, 'user_data': {'6': [7, 8]}}])
  let l = g:Xgetlist()
  call assert_equal(2, len(l))
  call assert_equal(2, l[1].lnum)
  call assert_equal(3, l[1].end_lnum)
  call assert_equal(4, l[1].col)
  call assert_equal(5, l[1].end_col)
  call assert_equal({'6': [7, 8]}, l[1].user_data)

  " Test that user_data is garbage collected
  call g:Xsetlist([{'user_data': ['high', 5]},
        \  {'user_data': {'this': [7, 'eight'], 'is': ['a', 'dictionary']}}])
  call test_garbagecollect_now()
  let l = g:Xgetlist()
  call assert_equal(2, len(l))
  call assert_equal(['high', 5], l[0].user_data)
  call assert_equal({'this': [7, 'eight'], 'is': ['a', 'dictionary']}, l[1].user_data)

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
  " Adding a non-valid entry should not mark the list as having valid entries
  call g:Xsetlist([{'bufnr':a:bnum, 'lnum':5, 'valid':0}], 'a')
  Xwindow
  call assert_equal(1, winnr('$'))

  " :cnext/:cprev should still work even with invalid entries in the list
  let l = [{'bufnr' : a:bnum, 'lnum' : 1, 'text' : '1', 'valid' : 0},
	      \ {'bufnr' : a:bnum, 'lnum' : 2, 'text' : '2', 'valid' : 0}]
  call g:Xsetlist(l)
  Xnext
  call assert_equal(2, g:Xgetlist({'idx' : 0}).idx)
  Xprev
  call assert_equal(1, g:Xgetlist({'idx' : 0}).idx)
  " :cnext/:cprev should still work after appending invalid entries to an
  " empty list
  call g:Xsetlist([])
  call g:Xsetlist(l, 'a')
  Xnext
  call assert_equal(2, g:Xgetlist({'idx' : 0}).idx)
  Xprev
  call assert_equal(1, g:Xgetlist({'idx' : 0}).idx)

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
  call assert_fails('call g:Xsetlist([], [])', 'E928:')
  call g:Xsetlist([v:_null_dict])
  call assert_equal([], g:Xgetlist())
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

  " {action} is unspecified.  Same as specifying ' '.
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
  eval []->setqflist(' ', {'nr' : $XXX_DOES_NOT_EXIST})
endfunc

func Test_setqflist_user_sets_buftype()
  call setqflist([{'text': 'foo'}, {'text': 'bar'}])
  set buftype=quickfix
  call setqflist([], 'a')
  enew
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

func Test_cgetfile_on_long_lines()
  " Problematic values if the line is longer than 4096 bytes.  Then 1024 bytes
  " are read at a time.
  for len in [4078, 4079, 4080, 5102, 5103, 5104, 6126, 6127, 6128, 7150, 7151, 7152]
    let lines =<< trim END
      /tmp/file1:1:1:aaa
      /tmp/file2:1:1:%s
      /tmp/file3:1:1:bbb
      /tmp/file4:1:1:ccc
    END
    let lines[1] = substitute(lines[1], '%s', repeat('x', len), '')
    call writefile(lines, 'Xcqetfile.txt')
    cgetfile Xcqetfile.txt
    call assert_equal(4, getqflist(#{size: v:true}).size, 'with length ' .. len)
  endfor
  call delete('Xcqetfile.txt')
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
  let lines =<< trim END
    Xqftestfile1:5:Line5
    Xqftestfile1:6:Line6
    Xqftestfile2:10:Line10
    Xqftestfile2:11:Line11
    Xqftestfile3:15:Line15
    Xqftestfile3:16:Line16
  END
  cgetexpr lines

  new
  let winid = win_getid()
  cfirst | cnext
  call assert_equal(winid, win_getid())
  2cnext
  call assert_equal(winid, win_getid())
  2cnext
  call assert_equal(winid, win_getid())

  " Test for 'switchbuf' set to search for files in windows in the current
  " tabpage and jump to an existing window (if present)
  set switchbuf=useopen
  enew
  cfirst | cnext
  call assert_equal(file1_winid, win_getid())
  2cnext
  call assert_equal(file2_winid, win_getid())
  2cnext
  call assert_equal(file2_winid, win_getid())

  " Test for 'switchbuf' set to search for files in tabpages and jump to an
  " existing tabpage (if present)
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

  " Test for 'switchbuf' set to open a new window for every file
  set switchbuf=split
  cfirst | cnext
  call assert_equal(1, winnr('$'))
  cnext | cnext
  call assert_equal(2, winnr('$'))
  cnext | cnext
  call assert_equal(3, winnr('$'))

  " Test for 'switchbuf' set to open a new tabpage for every file
  set switchbuf=newtab
  enew | only
  cfirst | cnext
  call assert_equal(1, tabpagenr('$'))
  cnext | cnext
  call assert_equal(2, tabpagenr('$'))
  cnext | cnext
  call assert_equal(3, tabpagenr('$'))
  tabfirst | enew | tabonly | only

  set switchbuf=uselast
  split
  let last_winid = win_getid()
  copen
  exe "normal 1G\<CR>"
  call assert_equal(last_winid, win_getid())
  enew | only

  " With an empty 'switchbuf', jumping to a quickfix entry should open the
  " file in an existing window (if present)
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
  " entry with 'switchbuf' set to 'usetab' should search in other tabpages.
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

  " Jumping to a file that is not present in any of the tabpages and the
  " current tabpage doesn't have any usable windows, should open it in a new
  " window in the current tabpage.
  copen | only
  cfirst
  call assert_equal(1, tabpagenr())
  call assert_equal('Xqftestfile1', @%)

  " If opening a file changes 'switchbuf', then the new value should be
  " retained.
  set modeline&vim
  call writefile(["vim: switchbuf=split"], 'Xqftestfile1')
  enew | only
  set switchbuf&vim
  cexpr "Xqftestfile1:1:10"
  call assert_equal('split', &switchbuf)
  call writefile(["vim: switchbuf=usetab"], 'Xqftestfile1')
  enew | only
  set switchbuf=useopen
  cexpr "Xqftestfile1:1:10"
  call assert_equal('usetab', &switchbuf)
  call writefile(["vim: switchbuf&vim"], 'Xqftestfile1')
  enew | only
  set switchbuf=useopen
  cexpr "Xqftestfile1:1:10"
  call assert_equal('uselast', &switchbuf)

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

  " If a file doesn't have any quickfix entries, then deleting lines in the
  " file should not update the quickfix list
  call g:Xsetlist([], 'f')
  1,2delete
  call assert_equal([], g:Xgetlist())

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
  call assert_true(len(g:Xgetlist()) == 5)
  Xopen
  call assert_true(w:quickfix_title =~ '^:grep')
  Xclose
  enew
  set makeef=Temp_File_##
  silent Xgrepadd GrepAdd_Test_Text: test_quickfix.vim
  call assert_true(len(g:Xgetlist()) == 9)

  " Try with 'grepprg' set to 'internal'
  set grepprg=internal
  silent Xgrep Grep_Test_Text: test_quickfix.vim
  silent Xgrepadd GrepAdd_Test_Text: test_quickfix.vim
  call assert_true(len(g:Xgetlist()) == 9)
  set grepprg&vim

  call writefile(['Vim'], 'XtestTempFile')
  set makeef=XtestTempFile
  silent Xgrep Grep_Test_Text: test_quickfix.vim
  call assert_equal(5, len(g:Xgetlist()))
  call assert_false(filereadable('XtestTempFile'))
  set makeef&vim
endfunc

func Test_grep()
  " The grepprg may not be set on non-Unix systems
  CheckUnix

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
  call assert_equal('Xone/a/one.txt', bufname(loc_one[1].bufnr))
  call assert_equal(3, loc_one[1].lnum)

  let loc_two = getloclist(two_id)
  call assert_equal('Xtwo/a/two.txt', bufname(loc_two[1].bufnr))
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

  " Test for changing the quickfix lists
  call assert_equal(3, g:Xgetlist({'nr' : 0}).nr)
  exe '1' . a:cchar . 'hist'
  call assert_equal(1, g:Xgetlist({'nr' : 0}).nr)
  exe '3' . a:cchar . 'hist'
  call assert_equal(3, g:Xgetlist({'nr' : 0}).nr)
  call assert_fails('-2' . a:cchar . 'hist', 'E16:')
  call assert_fails('4' . a:cchar . 'hist', 'E16:')

  call g:Xsetlist([], 'f')
  let l = split(execute(a:cchar . 'hist'), "\n")
  call assert_equal('No entries', l[0])
  if a:cchar == 'c'
    call assert_fails('4chist', 'E16:')
  else
    call assert_fails('4lhist', 'E776:')
  endif

  " An empty list should still show the stack history
  call g:Xsetlist([])
  let res = split(execute(a:cchar . 'hist'), "\n")
  call assert_equal('> error list 1 of 1; 0 ' . common, res[0])

  call g:Xsetlist([], 'f')
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
  " Try setting title to a non-string value
  call assert_equal(-1, g:Xsetlist([], 'a', {'title' : ['Test']}))
  call assert_equal('Sample', g:Xgetlist({"title":1}).title)

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
  " set other Vim data types as context
  call g:Xsetlist([], 'a', {'context' : v:_null_blob})
  if has('channel')
    call g:Xsetlist([], 'a', {'context' : test_null_channel()})
  endif
  if has('job')
    call g:Xsetlist([], 'a', {'context' : test_null_job()})
  endif
  " Nvim doesn't have null functions
  " call g:Xsetlist([], 'a', {'context' : test_null_function()})
  " Nvim doesn't have null partials
  " call g:Xsetlist([], 'a', {'context' : test_null_partial()})
  call g:Xsetlist([], 'a', {'context' : ''})
  call test_garbagecollect_now()
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

  " Test for getting id of window associated with a location list window
  if a:cchar == 'l'
    only
    call assert_equal(0, g:Xgetlist({'all' : 1}).filewinid)
    let wid = win_getid()
    Xopen
    call assert_equal(wid, g:Xgetlist({'filewinid' : 1}).filewinid)
    wincmd w
    call assert_equal(0, g:Xgetlist({'filewinid' : 1}).filewinid)
    only
  endif

  " The following used to crash Vim with address sanitizer
  call g:Xsetlist([], 'f')
  call g:Xsetlist([], 'a', {'items' : [{'filename':'F1', 'lnum':10}]})
  call assert_equal(10, g:Xgetlist({'items':1}).items[0].lnum)

  " Try setting the items using a string
  call assert_equal(-1, g:Xsetlist([], ' ', {'items' : 'Test'}))

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

  " Cannot specify both a non-empty list argument and a dict argument
  call assert_fails("call g:Xsetlist([{}], ' ', {})", 'E475:')
endfunc

func Test_qf_property()
  call Xproperty_tests('c')
  call Xproperty_tests('l')
endfunc

" Test for setting the current index in the location/quickfix list
func Xtest_setqfidx(cchar)
  call s:setup_commands(a:cchar)

  Xgetexpr "F1:10:1:Line1\nF2:20:2:Line2\nF3:30:3:Line3"
  Xgetexpr "F4:10:1:Line1\nF5:20:2:Line2\nF6:30:3:Line3"
  Xgetexpr "F7:10:1:Line1\nF8:20:2:Line2\nF9:30:3:Line3"

  call g:Xsetlist([], 'a', {'nr' : 3, 'idx' : 2})
  call g:Xsetlist([], 'a', {'nr' : 2, 'idx' : 2})
  call g:Xsetlist([], 'a', {'nr' : 1, 'idx' : 3})
  Xolder 2
  Xopen
  call assert_equal(3, line('.'))
  Xnewer
  call assert_equal(2, line('.'))
  Xnewer
  call assert_equal(2, line('.'))
  " Update the current index with the quickfix window open
  wincmd w
  call g:Xsetlist([], 'a', {'nr' : 3, 'idx' : 3})
  Xopen
  call assert_equal(3, line('.'))
  Xclose

  " Set the current index to the last entry
  call g:Xsetlist([], 'a', {'nr' : 1, 'idx' : '$'})
  call assert_equal(3, g:Xgetlist({'nr' : 1, 'idx' : 0}).idx)
  " A large value should set the index to the last index
  call g:Xsetlist([], 'a', {'nr' : 1, 'idx' : 1})
  call g:Xsetlist([], 'a', {'nr' : 1, 'idx' : 999})
  call assert_equal(3, g:Xgetlist({'nr' : 1, 'idx' : 0}).idx)
  " Invalid index values
  call g:Xsetlist([], 'a', {'nr' : 1, 'idx' : -1})
  call assert_equal(3, g:Xgetlist({'nr' : 1, 'idx' : 0}).idx)
  call g:Xsetlist([], 'a', {'nr' : 1, 'idx' : 0})
  call assert_equal(3, g:Xgetlist({'nr' : 1, 'idx' : 0}).idx)
  call g:Xsetlist([], 'a', {'nr' : 1, 'idx' : 'xx'})
  call assert_equal(3, g:Xgetlist({'nr' : 1, 'idx' : 0}).idx)
  call assert_fails("call g:Xsetlist([], 'a', {'nr':1, 'idx':[]})", 'E745:')

  call g:Xsetlist([], 'f')
  new | only
endfunc

func Test_setqfidx()
  call Xtest_setqfidx('c')
  call Xtest_setqfidx('l')
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
  let l =<< trim END
    precexpr
    postcexpr
    precaddexpr
    postcaddexpr
    precgetexpr
    postcgetexpr
    precexpr
    postcexpr
    precaddexpr
    postcaddexpr
    precgetexpr
    postcgetexpr
    precexpr
    precaddexpr
    precgetexpr
  END
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
  let l =<< trim END
    precbuffer
    postcbuffer
    precgetbuffer
    postcgetbuffer
    precaddbuffer
    postcaddbuffer
    precbuffer
    precgetbuffer
    precaddbuffer
  END
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
  let l =<< trim END
    precfile
    postcfile
    precaddfile
    postcaddfile
    precgetfile
    postcgetfile
    precfile
    postcfile
    precaddfile
    postcaddfile
    precgetfile
    postcgetfile
    precfile
    postcfile
    precaddfile
    postcaddfile
    precgetfile
    postcgetfile
  END
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
  let l =<< trim END
    prehelpgrep
    posthelpgrep
    prehelpgrep
    posthelpgrep
    previmgrep
    postvimgrep
    previmgrepadd
    postvimgrepadd
    previmgrep
    postvimgrep
    previmgrepadd
    postvimgrepadd
    premake
    postmake
  END
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
    set grepprg=internal
    silent grep Grep_Autocmd_Text test_quickfix.vim
    silent grepadd GrepAdd_Autocmd_Text test_quickfix.vim
    silent lgrep Grep_Autocmd_Text test_quickfix.vim
    silent lgrepadd GrepAdd_Autocmd_Text test_quickfix.vim
    set grepprg&vim
    let l =<< trim END
      pregrep
      postgrep
      pregrepadd
      postgrepadd
      pregrep
      postgrep
      pregrepadd
      postgrepadd
      pregrep
      postgrep
      pregrepadd
      postgrepadd
      prelgrep
      postlgrep
      prelgrepadd
      postlgrepadd
    END
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
  " Should create a new window and jump to the entry. The scratch buffer
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

  " open the quickfix buffer in two windows and jump to an entry. Should open
  " the file in the first quickfix window.
  enew | only
  copen
  let bnum = bufnr('')
  exe 'sbuffer ' . bnum
  wincmd b
  cfirst
  call assert_equal(2, winnr())
  call assert_equal('F1', @%)
  enew | only
  exe 'sb' bnum
  exe 'botright sb' bnum
  wincmd t
  clast
  call assert_equal(2, winnr())
  call assert_equal('quickfix', getwinvar(1, '&buftype'))
  call assert_equal('quickfix', getwinvar(3, '&buftype'))

  " Jumping to a file from the location list window should find a usable
  " window by wrapping around the window list.
  enew | only
  call setloclist(0, [], 'f')
  new | new
  lgetexpr ["F1%10%Line 10", "F2%20%Line 20", "F3%30%Line 30"]
  lopen
  1close
  call assert_equal(0, getloclist(3, {'id' : 0}).id)
  lnext
  call assert_equal(3, winnr())
  call assert_equal(getloclist(1, {'id' : 0}).id, getloclist(3, {'id' : 0}).id)

  enew | only
  set efm&vim
endfunc

func Test_cwindow_highlight()
  CheckScreendump

  let lines =<< trim END
    call setline(1, ['some', 'text', 'with', 'matches'])
    write XCwindow
    vimgrep e XCwindow
    redraw
    cwindow 4
  END
  call writefile(lines, 'XtestCwindow')
  let buf = RunVimInTerminal('-S XtestCwindow', #{rows: 12})
  call VerifyScreenDump(buf, 'Test_quickfix_cwindow_1', {})

  call term_sendkeys(buf, ":cnext\<CR>")
  call VerifyScreenDump(buf, 'Test_quickfix_cwindow_2', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XtestCwindow')
  call delete('XCwindow')
endfunc

func XvimgrepTests(cchar)
  call s:setup_commands(a:cchar)

  let lines =<< trim END
    Editor:VIM vim
    Editor:Emacs EmAcS
    Editor:Notepad NOTEPAD
  END
  call writefile(lines, 'Xtestfile1')
  call writefile(['Linux', 'macOS', 'MS-Windows'], 'Xtestfile2')

  " Error cases
  call assert_fails('Xvimgrep /abc *', 'E682:')

  let @/=''
  call assert_fails('Xvimgrep // *', 'E35:')

  call assert_fails('Xvimgrep abc', 'E683:')
  call assert_fails('Xvimgrep a1b2c3 Xtestfile1', 'E480:')
  call assert_fails('Xvimgrep pat Xa1b2c3', 'E480:')

  Xexpr ""
  Xvimgrepadd Notepad Xtestfile1
  Xvimgrepadd macOS Xtestfile2
  let l = g:Xgetlist()
  call assert_equal(2, len(l))
  call assert_equal('Editor:Notepad NOTEPAD', l[0].text)

  10Xvimgrep #\cvim#g Xtestfile?
  let l = g:Xgetlist()
  call assert_equal(2, len(l))
  call assert_equal(8, l[0].col)
  call assert_equal(11, l[0].end_col)
  call assert_equal(12, l[1].col)
  call assert_equal(15, l[1].end_col)

  1Xvimgrep ?Editor? Xtestfile*
  let l = g:Xgetlist()
  call assert_equal(1, len(l))
  call assert_equal('Editor:VIM vim', l[0].text)

  edit +3 Xtestfile2
  Xvimgrep +\cemacs+j Xtestfile1
  let l = g:Xgetlist()
  call assert_equal('Xtestfile2', @%)
  call assert_equal('Editor:Emacs EmAcS', l[0].text)

  " Test for unloading a buffer after vimgrep searched the buffer
  %bwipe
  Xvimgrep /Editor/j Xtestfile*
  call assert_equal(0, getbufinfo('Xtestfile1')[0].loaded)
  call assert_equal([], getbufinfo('Xtestfile2'))

  " Test for opening the dummy buffer used by vimgrep in a window. The new
  " window should be closed
  %bw!
  augroup QF_Test
    au!
    autocmd BufReadPre * exe "sb " .. expand("<abuf>")
  augroup END
  call assert_fails("Xvimgrep /sublime/ Xtestfile1", 'E480:')
  call assert_equal(1, winnr('$'))
  augroup QF_Test
    au!
  augroup END

  call delete('Xtestfile1')
  call delete('Xtestfile2')
endfunc

" Tests for the :vimgrep command
func Test_vimgrep()
  call XvimgrepTests('c')
  call XvimgrepTests('l')
endfunc

func Test_vimgrep_wildcards_expanded_once()
  new X[id-01] file.txt
  call setline(1, 'some text to search for')
  vimgrep text %
  bwipe!
endfunc

" Test for incsearch highlighting of the :vimgrep pattern
" This test used to cause "E315: ml_get: invalid lnum" errors.
func Test_vimgrep_incsearch()
  CheckFunction test_override
  enew
  set incsearch
  call test_override("char_avail", 1)

  call feedkeys(":2vimgrep assert test_quickfix.vim test_cdo.vim\<CR>", "ntx")
  let l = getqflist()
  call assert_equal(2, len(l))

  call test_override("ALL", 0)
  set noincsearch
endfunc

" Test vimgrep with the last search pattern not set
func Test_vimgrep_with_no_last_search_pat()
  let lines =<< trim [SCRIPT]
    call assert_fails('vimgrep // *', 'E35:')
    call writefile(v:errors, 'Xresult')
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript')
  if RunVim([], [], '--clean -S Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xscript')
  call delete('Xresult')
endfunc

" Test vimgrep without swap file
func Test_vimgrep_without_swap_file()
  let lines =<< trim [SCRIPT]
    vimgrep grep test_c*
    call writefile(['done'], 'Xresult')
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript')
  if RunVim([], [], '--clean -n -S Xscript Xscript')
    call assert_equal(['done'], readfile('Xresult'))
  endif
  call delete('Xscript')
  call delete('Xresult')
endfunc

func Test_vimgrep_existing_swapfile()
  call writefile(['match apple with apple'], 'Xapple')
  call writefile(['swapfile'], '.Xapple.swp')
  let g:foundSwap = 0
  let g:ignoreSwapExists = 1
  augroup grep
    au SwapExists * let foundSwap = 1 | let v:swapchoice = 'e'
  augroup END
  vimgrep apple Xapple
  call assert_equal(1, g:foundSwap)
  call assert_match('.Xapple.swo', swapname(''))

  call delete('Xapple')
  call delete('.Xapple.swp')
  augroup grep
    au! SwapExists
  augroup END
  unlet g:ignoreSwapExists
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
  let lines =<< trim eval END
    Entering directory $"{repeat('a', 1006)}"
    File1:10:Hello World
  END
  cgetexpr lines
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
  " Problem is only triggered if "starting" is zero, so that the OptionSet
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

" Check that ":file" without an argument is possible even when "curbuf->b_ro_locked"
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
endfunc

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

func Test_filetype_autocmd()
  " this changes the location list while it is in use to fill a buffer
  lexpr ''
  lopen
  augroup FT_loclist
    au FileType * call setloclist(0, [], 'f')
  augroup END
  silent! lolder
  lexpr ''

  augroup FT_loclist
    au! FileType
  augroup END
endfunc

func Test_vimgrep_with_textlock()
  new

  " Simple way to execute something with "textlock" set.
  " Check that vimgrep without jumping can be executed.
  au InsertCharPre * vimgrep /RunTheTest/j runtest.vim
  normal ax
  let qflist = getqflist()
  call assert_true(len(qflist) > 0)
  call assert_match('RunTheTest', qflist[0].text)
  call setqflist([], 'r')
  au! InsertCharPre

  " Check that vimgrepadd without jumping can be executed.
  au InsertCharPre * vimgrepadd /RunTheTest/j runtest.vim
  normal ax
  let qflist = getqflist()
  call assert_true(len(qflist) > 0)
  call assert_match('RunTheTest', qflist[0].text)
  call setqflist([], 'r')
  au! InsertCharPre

  " Check that lvimgrep without jumping can be executed.
  au InsertCharPre * lvimgrep /RunTheTest/j runtest.vim
  normal ax
  let qflist = getloclist(0)
  call assert_true(len(qflist) > 0)
  call assert_match('RunTheTest', qflist[0].text)
  call setloclist(0, [], 'r')
  au! InsertCharPre

  " Check that lvimgrepadd without jumping can be executed.
  au InsertCharPre * lvimgrepadd /RunTheTest/j runtest.vim
  normal ax
  let qflist = getloclist(0)
  call assert_true(len(qflist) > 0)
  call assert_match('RunTheTest', qflist[0].text)
  call setloclist(0, [], 'r')
  au! InsertCharPre

  " trying to jump will give an error
  au InsertCharPre * vimgrep /RunTheTest/ runtest.vim
  call assert_fails('normal ax', 'E565:')
  au! InsertCharPre

  au InsertCharPre * vimgrepadd /RunTheTest/ runtest.vim
  call assert_fails('normal ax', 'E565:')
  au! InsertCharPre

  au InsertCharPre * lvimgrep /RunTheTest/ runtest.vim
  call assert_fails('normal ax', 'E565:')
  au! InsertCharPre

  au InsertCharPre * lvimgrepadd /RunTheTest/ runtest.vim
  call assert_fails('normal ax', 'E565:')
  au! InsertCharPre

  bwipe!
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
  call assert_equal('Xone/a/one.txt', bufname(l1.items[1].bufnr))
  call assert_equal(3, l1.items[1].lnum)
  call assert_equal('Xtwo/a/two.txt', bufname(l2.items[1].bufnr))
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
  let lines =<< trim END
    (one.txt
    Error l4 in one.txt
    ) (two.txt
    Error l6 in two.txt
    )
    Error l8 in one.txt
  END
  let l = g:Xgetlist({'lines': lines, 'efm' : efm_val})
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
  call assert_equal('F3', @%)
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
    let lines =<< trim END
      F1:1:1:Line1
      F1:2:2:Line2
      F2:1:1:Line1
      F2:2:2:Line2
      F3:1:1:Line1
      F3:2:2:Line2
    END
    call g:Xsetlist([], ' ', {'lines': lines})
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
  if a:cchar == 'c'
    call assert_equal({'context' : '', 'id' : 0, 'idx' : 0,
		  \ 'items' : [], 'nr' : 0, 'size' : 0, 'qfbufnr' : 0,
		  \ 'title' : '', 'winid' : 0, 'changedtick': 0,
                  \ 'quickfixtextfunc' : ''}, g:Xgetlist({'all' : 0}))
  else
    call assert_equal({'context' : '', 'id' : 0, 'idx' : 0,
		\ 'items' : [], 'nr' : 0, 'size' : 0, 'title' : '',
		\ 'winid' : 0, 'changedtick': 0, 'filewinid' : 0,
		\ 'qfbufnr' : 0, 'quickfixtextfunc' : ''},
		\ g:Xgetlist({'all' : 0}))
  endif

  " Quickfix window with empty stack
  silent! Xopen
  let qfwinid = (a:cchar == 'c') ? win_getid() : 0
  let qfbufnr = (a:cchar == 'c') ? bufnr('') : 0
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
  if a:cchar == 'c'
    call assert_equal({'context' : '', 'id' : 0, 'idx' : 0, 'items' : [],
		\ 'nr' : 0, 'size' : 0, 'title' : '', 'winid' : 0,
		\ 'qfbufnr' : qfbufnr, 'quickfixtextfunc' : '',
		\ 'changedtick' : 0}, g:Xgetlist({'id' : qfid, 'all' : 0}))
  else
    call assert_equal({'context' : '', 'id' : 0, 'idx' : 0, 'items' : [],
		\ 'nr' : 0, 'size' : 0, 'title' : '', 'winid' : 0,
		\ 'changedtick' : 0, 'filewinid' : 0, 'qfbufnr' : 0,
                \ 'quickfixtextfunc' : ''},
		\ g:Xgetlist({'id' : qfid, 'all' : 0}))
  endif

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
  if a:cchar == 'c'
    call assert_equal({'context' : '', 'id' : 0, 'idx' : 0, 'items' : [],
		\ 'nr' : 0, 'size' : 0, 'title' : '', 'winid' : 0,
		\ 'changedtick' : 0, 'qfbufnr' : qfbufnr,
                \ 'quickfixtextfunc' : ''}, g:Xgetlist({'nr' : 5, 'all' : 0}))
  else
    call assert_equal({'context' : '', 'id' : 0, 'idx' : 0, 'items' : [],
		\ 'nr' : 0, 'size' : 0, 'title' : '', 'winid' : 0,
		\ 'changedtick' : 0, 'filewinid' : 0, 'qfbufnr' : 0,
                \ 'quickfixtextfunc' : ''}, g:Xgetlist({'nr' : 5, 'all' : 0}))
  endif
endfunc

func Test_empty_list_quickfixtextfunc()
  " This was crashing.  Can only reproduce by running it in a separate Vim
  " instance.
  let lines =<< trim END
      func s:Func(o)
              cgetexpr '0'
      endfunc
      cope
      let &quickfixtextfunc = 's:Func'
      cgetfile [ex
  END
  call writefile(lines, 'Xquickfixtextfunc')
  call RunVim([], [], '-e -s -S Xquickfixtextfunc -c qa')
  call delete('Xquickfixtextfunc')
endfunc

func Test_getqflist()
  call Xgetlist_empty_tests('c')
  call Xgetlist_empty_tests('l')
endfunc

func Test_getqflist_invalid_nr()
  " The following commands used to crash Vim
  cexpr ""
  call getqflist({'nr' : $XXX_DOES_NOT_EXIST_XXX})

  " Cleanup
  call setqflist([], 'r')
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

  if isdirectory("Xone")
    call delete("Xone", 'rf')
  endif
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

" Test helpgrep with lang specifier
func Xtest_helpgrep_with_lang_specifier(cchar)
  call s:setup_commands(a:cchar)
  Xhelpgrep Vim@en
  call assert_equal('help', &filetype)
  call assert_notequal(0, g:Xgetlist({'nr' : '$'}).nr)
  new | only
endfunc

func Test_helpgrep_with_lang_specifier()
  call Xtest_helpgrep_with_lang_specifier('c')
  call Xtest_helpgrep_with_lang_specifier('l')
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

" Similar to the problem above, but for user data.
func Test_ll_window_user_data()
  call setloclist(0, [#{bufnr: bufnr(), user_data: {}}])
  lopen
  wincmd t
  close
  call test_garbagecollect_now()
  call feedkeys("\<CR>", 'tx')
  call test_garbagecollect_now()
  %bwipe!
endfunc

" The following test used to crash vim
func Test_lfile_crash()
  sp Xtest
  au QuickFixCmdPre * bw
  call assert_fails('lfile', 'E40:')
  au! QuickFixCmdPre
endfunc

" The following test used to crash vim
func Test_lbuffer_crash()
  sv Xtest
  augroup QF_Test
    au!
    au QuickFixCmdPre,QuickFixCmdPost,BufEnter,BufLeave * bw
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
    au QuickFixCmdPre,QuickFixCmdPost,BufEnter,BufLeave * call setloclist(0, [], 'f')
  augroup END
  lexpr ""
  augroup QF_Test
    au!
  augroup END

  enew | only
  augroup QF_Test
    au!
    au BufNew * call setloclist(0, [], 'f')
  augroup END
  lexpr 'x:1:x'
  augroup QF_Test
    au!
  augroup END

  enew | only
  lexpr ''
  lopen
  augroup QF_Test
    au!
    au FileType * call setloclist(0, [], 'f')
  augroup END
  lexpr ''
  augroup QF_Test
    au!
  augroup END
endfunc

" The following test used to crash Vim
func Test_lvimgrep_crash()
  " this leaves a swapfile .test_quickfix.vim.swp around, why?
  sv Xtest
  augroup QF_Test
    au!
    au QuickFixCmdPre,QuickFixCmdPost,BufEnter,BufLeave * call setloclist(0, [], 'f')
  augroup END
  lvimgrep quickfix test_quickfix.vim
  augroup QF_Test
    au!
  augroup END

  new | only
  augroup QF_Test
    au!
    au BufEnter * call setloclist(0, [], 'r')
  augroup END
  call assert_fails('lvimgrep Test_lvimgrep_crash *', 'E926:')
  augroup QF_Test
    au!
  augroup END

  enew | only
endfunc

func Test_lvimgrep_crash2()
  au BufNewFile x sfind
  call assert_fails('lvimgrep x x', 'E471:')
  call assert_fails('lvimgrep x x x', 'E471:')

  au! BufNewFile
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

" Tests for quickfix/location lists changed by autocommands when
" :vimgrep/:lvimgrep commands are running.
func Test_vimgrep_autocmd()
  call setqflist([], 'f')
  call writefile(['stars'], 'Xtest1.txt', 'D')
  call writefile(['stars'], 'Xtest2.txt', 'D')

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
  " cleanup the swap files
  bw! Xtest2.txt Xtest1.txt

  call setqflist([], 'f')
endfunc

" Test for an autocmd changing the current directory when running vimgrep
func Xvimgrep_autocmd_cd(cchar)
  call s:setup_commands(a:cchar)

  %bwipe
  let save_cwd = getcwd()

  augroup QF_Test
    au!
    autocmd BufRead * silent cd %:p:h
  augroup END

  10Xvimgrep /vim/ Xdir/**
  let l = g:Xgetlist()
  call assert_equal('f1.txt', bufname(l[0].bufnr))
  call assert_equal('f2.txt', fnamemodify(bufname(l[2].bufnr), ':t'))

  augroup QF_Test
    au!
  augroup END

  exe 'cd ' . save_cwd
endfunc

func Test_vimgrep_autocmd_cd()
  call mkdir('Xdir/a', 'p')
  call mkdir('Xdir/b', 'p')
  call writefile(['a_L1_vim', 'a_L2_vim'], 'Xdir/a/f1.txt')
  call writefile(['b_L1_vim', 'b_L2_vim'], 'Xdir/b/f2.txt')
  call Xvimgrep_autocmd_cd('c')
  call Xvimgrep_autocmd_cd('l')
  %bwipe
  call delete('Xdir', 'rf')
endfunc

" The following test used to crash Vim
func Test_lhelpgrep_autocmd()
  lhelpgrep quickfix
  augroup QF_Test
    au!
    autocmd QuickFixCmdPost * call setloclist(0, [], 'f')
  augroup END
  lhelpgrep buffer
  call assert_equal('help', &filetype)
  call assert_equal(0, getloclist(0, {'nr' : '$'}).nr)
  lhelpgrep tabpage
  call assert_equal('help', &filetype)
  call assert_equal(1, getloclist(0, {'nr' : '$'}).nr)
  augroup QF_Test
    au!
  augroup END

  new | only
  augroup QF_Test
    au!
    au BufEnter * call setqflist([], 'f')
  augroup END
  call assert_fails('helpgrep quickfix', 'E925:')
  " run the test with a help window already open
  help
  wincmd w
  call assert_fails('helpgrep quickfix', 'E925:')
  augroup QF_Test
    au!
  augroup END

  new | only
  augroup QF_Test
    au!
    au BufEnter * call setqflist([], 'r')
  augroup END
  call assert_fails('helpgrep quickfix', 'E925:')
  augroup QF_Test
    au!
  augroup END

  new | only
  augroup QF_Test
    au!
    au BufEnter * call setloclist(0, [], 'r')
  augroup END
  call assert_fails('lhelpgrep quickfix', 'E926:')
  augroup QF_Test
    au!
  augroup END

  " Replace the contents of a help window location list when it is still in
  " use.
  new | only
  lhelpgrep quickfix
  wincmd w
  augroup QF_Test
    au!
    autocmd WinEnter * call setloclist(0, [], 'r')
  augroup END
  call assert_fails('lhelpgrep win_getid', 'E926:')
  augroup QF_Test
    au!
  augroup END

  %bw!
endfunc

" The following test used to crash Vim
func Test_lhelpgrep_autocmd_free_loclist()
  %bw!
  lhelpgrep quickfix
  wincmd w
  augroup QF_Test
    au!
    autocmd WinEnter * call setloclist(0, [], 'f')
  augroup END
  lhelpgrep win_getid
  wincmd w
  wincmd w
  wincmd w
  augroup QF_Test
    au!
  augroup END
  %bw!
endfunc

" Test for shortening/simplifying the file name when opening the
" quickfix window or when displaying the quickfix list
func Test_shorten_fname()
  CheckUnix
  %bwipe
  " Create a quickfix list with an absolute path filename
  let fname = getcwd() . '/test_quickfix.vim'
  call setqflist([], ' ', {'lines':[fname . ":20:Line20"], 'efm':'%f:%l:%m'})
  call assert_equal(fname, bufname('test_quickfix.vim'))
  " Opening the quickfix window should simplify the file path
  cwindow
  call assert_equal('test_quickfix.vim', bufname('test_quickfix.vim'))
  cclose
  %bwipe
  " Create a quickfix list with an absolute path filename
  call setqflist([], ' ', {'lines':[fname . ":20:Line20"], 'efm':'%f:%l:%m'})
  call assert_equal(fname, bufname('test_quickfix.vim'))
  " Displaying the quickfix list should simplify the file path
  silent! clist
  call assert_equal('test_quickfix.vim', bufname('test_quickfix.vim'))
  " Add a few entries for the same file with different paths and check whether
  " the buffer name is shortened
  %bwipe
  call setqflist([], 'f')
  call setqflist([{'filename' : 'test_quickfix.vim', 'lnum' : 10},
        \ {'filename' : '../testdir/test_quickfix.vim', 'lnum' : 20},
        \ {'filename' : fname, 'lnum' : 30}], ' ')
  copen
  call assert_equal(['test_quickfix.vim|10| ',
        \ 'test_quickfix.vim|20| ',
        \ 'test_quickfix.vim|30| '], getline(1, '$'))
  cclose
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

  " Switching to another quickfix list in one tab page should update the
  " quickfix window title and statusline in all the other tab pages also
  call setqflist([], 'f')
  %bw!
  cgetexpr ['file_one:1:1: error in the first quickfix list']
  call setqflist([], 'a', {'title': 'first quickfix list'})
  cgetexpr ['file_two:2:1: error in the second quickfix list']
  call setqflist([], 'a', {'title': 'second quickfix list'})
  copen
  wincmd t
  tabnew two
  copen
  wincmd t
  colder
  call assert_equal('first quickfix list', gettabwinvar(1, 2, 'quickfix_title'))
  call assert_equal('first quickfix list', gettabwinvar(2, 2, 'quickfix_title'))
  call assert_equal(1, tabpagewinnr(1))
  call assert_equal(1, tabpagewinnr(2))
  tabnew
  call setqflist([], 'a', {'title': 'new quickfix title'})
  call assert_equal('new quickfix title', gettabwinvar(1, 2, 'quickfix_title'))
  call assert_equal('new quickfix title', gettabwinvar(2, 2, 'quickfix_title'))
  %bw!
endfunc

func Test_lbuffer_with_bwipe()
  new
  new
  augroup nasty
    au QuickFixCmdPre,QuickFixCmdPost,BufEnter,BufLeave * bwipe
  augroup END
  lbuffer
  augroup nasty
    au!
  augroup END
endfunc

" Test for an autocmd freeing the quickfix/location list when cexpr/lexpr is
" running
func Xexpr_acmd_freelist(cchar)
  call s:setup_commands(a:cchar)

  " This was using freed memory (but with what events?)
  augroup nasty
    au QuickFixCmdPre,QuickFixCmdPost,BufEnter,BufLeave * call g:Xsetlist([], 'f')
  augroup END
  Xexpr "x"
  augroup nasty
    au!
  augroup END
endfunc

func Test_cexpr_acmd_freelist()
  call Xexpr_acmd_freelist('c')
  call Xexpr_acmd_freelist('l')
endfunc

" Test for commands that create a new quickfix/location list and jump to the
" first error automatically.
func Xjumpto_first_error_test(cchar)
  call s:setup_commands(a:cchar)

  call s:create_test_file('Xtestfile1')
  call s:create_test_file('Xtestfile2')
  let l = ['Xtestfile1:2:Line2', 'Xtestfile2:4:Line4']

  " Test for cexpr/lexpr
  enew
  Xexpr l
  call assert_equal('Xtestfile1', @%)
  call assert_equal(2, line('.'))

  " Test for cfile/lfile
  enew
  call writefile(l, 'Xerr')
  Xfile Xerr
  call assert_equal('Xtestfile1', @%)
  call assert_equal(2, line('.'))

  " Test for cbuffer/lbuffer
  edit Xerr
  Xbuffer
  call assert_equal('Xtestfile1', @%)
  call assert_equal(2, line('.'))

  call delete('Xerr')
  call delete('Xtestfile1')
  call delete('Xtestfile2')
endfunc

func Test_jumpto_first_error()
  call Xjumpto_first_error_test('c')
  call Xjumpto_first_error_test('l')
endfunc

" Test for a quickfix autocmd changing the quickfix/location list before
" jumping to the first error in the new list.
func Xautocmd_changelist(cchar)
  call s:setup_commands(a:cchar)

  " Test for cfile/lfile
  call s:create_test_file('Xtestfile1')
  call s:create_test_file('Xtestfile2')
  Xexpr 'Xtestfile1:2:Line2'
  autocmd QuickFixCmdPost * Xolder
  call writefile(['Xtestfile2:4:Line4'], 'Xerr')
  Xfile Xerr
  call assert_equal('Xtestfile2', @%)
  call assert_equal(4, line('.'))
  autocmd! QuickFixCmdPost

  " Test for cbuffer/lbuffer
  call g:Xsetlist([], 'f')
  Xexpr 'Xtestfile1:2:Line2'
  autocmd QuickFixCmdPost * Xolder
  call writefile(['Xtestfile2:4:Line4'], 'Xerr')
  edit Xerr
  Xbuffer
  call assert_equal('Xtestfile2', @%)
  call assert_equal(4, line('.'))
  autocmd! QuickFixCmdPost

  " Test for cexpr/lexpr
  call g:Xsetlist([], 'f')
  Xexpr 'Xtestfile1:2:Line2'
  autocmd QuickFixCmdPost * Xolder
  Xexpr 'Xtestfile2:4:Line4'
  call assert_equal('Xtestfile2', @%)
  call assert_equal(4, line('.'))
  autocmd! QuickFixCmdPost

  " The grepprg may not be set on non-Unix systems
  if has('unix')
    " Test for grep/lgrep
    call g:Xsetlist([], 'f')
    Xexpr 'Xtestfile1:2:Line2'
    autocmd QuickFixCmdPost * Xolder
    silent Xgrep Line5 Xtestfile2
    call assert_equal('Xtestfile2', @%)
    call assert_equal(5, line('.'))
    autocmd! QuickFixCmdPost
  endif

  " Test for vimgrep/lvimgrep
  call g:Xsetlist([], 'f')
  Xexpr 'Xtestfile1:2:Line2'
  autocmd QuickFixCmdPost * Xolder
  silent Xvimgrep Line5 Xtestfile2
  call assert_equal('Xtestfile2', @%)
  call assert_equal(5, line('.'))
  autocmd! QuickFixCmdPost

  " Test for autocommands clearing the quickfix list before jumping to the
  " first error. This should not result in an error
  autocmd QuickFixCmdPost * call g:Xsetlist([], 'r')
  let v:errmsg = ''
  " Test for cfile/lfile
  Xfile Xerr
  call assert_true(v:errmsg !~# 'E42:')
  " Test for cbuffer/lbuffer
  edit Xerr
  Xbuffer
  call assert_true(v:errmsg !~# 'E42:')
  " Test for cexpr/lexpr
  Xexpr 'Xtestfile2:4:Line4'
  call assert_true(v:errmsg !~# 'E42:')
  " Test for grep/lgrep
  " The grepprg may not be set on non-Unix systems
  if has('unix')
    silent Xgrep Line5 Xtestfile2
    call assert_true(v:errmsg !~# 'E42:')
  endif
  " Test for vimgrep/lvimgrep
  call assert_fails('silent Xvimgrep Line5 Xtestfile2', 'E480:')
  autocmd! QuickFixCmdPost

  call delete('Xerr')
  call delete('Xtestfile1')
  call delete('Xtestfile2')
endfunc

func Test_autocmd_changelist()
  call Xautocmd_changelist('c')
  call Xautocmd_changelist('l')
endfunc

" Tests for the ':filter /pat/ clist' command
func Test_filter_clist()
  cexpr ['Xfile1:10:10:Line 10', 'Xfile2:15:15:Line 15']
  call assert_equal([' 2 Xfile2:15 col 15: Line 15'],
			\ split(execute('filter /Line 15/ clist'), "\n"))
  call assert_equal([' 1 Xfile1:10 col 10: Line 10'],
			\ split(execute('filter /Xfile1/ clist'), "\n"))
  call assert_equal([], split(execute('filter /abc/ clist'), "\n"))

  call setqflist([{'module' : 'abc', 'pattern' : 'pat1'},
			\ {'module' : 'pqr', 'pattern' : 'pat2'}], ' ')
  call assert_equal([' 2 pqr:pat2:  '],
			\ split(execute('filter /pqr/ clist'), "\n"))
  call assert_equal([' 1 abc:pat1:  '],
			\ split(execute('filter /pat1/ clist'), "\n"))
endfunc

" Tests for the "CTRL-W <CR>" command.
func Xview_result_split_tests(cchar)
  call s:setup_commands(a:cchar)

  " Test that "CTRL-W <CR>" in a qf/ll window fails with empty list.
  call g:Xsetlist([])
  Xopen
  let l:win_count = winnr('$')
  call assert_fails('execute "normal! \<C-W>\<CR>"', 'E42')
  call assert_equal(l:win_count, winnr('$'))
  Xclose
endfunc

func Test_view_result_split()
  call Xview_result_split_tests('c')
  call Xview_result_split_tests('l')
endfunc

" Test that :cc sets curswant
func Test_curswant()
  helpgrep quickfix
  normal! llll
  1cc
  call assert_equal(getcurpos()[4], virtcol('.'))
  cclose | helpclose
endfunc

" Test for opening a file from the quickfix window using CTRL-W <Enter>
" doesn't leave an empty buffer around.
func Test_splitview()
  call s:create_test_file('Xtestfile1')
  call s:create_test_file('Xtestfile2')
  new | only
  let last_bufnr = bufnr('Test_sv_1', 1)
  let l = ['Xtestfile1:2:Line2', 'Xtestfile2:4:Line4']
  cgetexpr l
  copen
  let numbufs = len(getbufinfo())
  exe "normal \<C-W>\<CR>"
  copen
  exe "normal j\<C-W>\<CR>"
  " Make sure new empty buffers are not created
  call assert_equal(numbufs, len(getbufinfo()))
  " Creating a new buffer should use the next available buffer number
  call assert_equal(last_bufnr + 4, bufnr("Test_sv_2", 1))
  bwipe Test_sv_1
  bwipe Test_sv_2
  new | only

  " When split opening files from location list window, make sure that two
  " windows doesn't refer to the same location list
  lgetexpr l
  let locid = getloclist(0, {'id' : 0}).id
  lopen
  exe "normal \<C-W>\<CR>"
  call assert_notequal(locid, getloclist(0, {'id' : 0}).id)
  call assert_equal(0, getloclist(0, {'winid' : 0}).winid)
  new | only

  " When split opening files from a helpgrep location list window, a new help
  " window should be opened with a copy of the location list.
  lhelpgrep window
  let locid = getloclist(0, {'id' : 0}).id
  lwindow
  exe "normal j\<C-W>\<CR>"
  call assert_notequal(locid, getloclist(0, {'id' : 0}).id)
  call assert_equal(0, getloclist(0, {'winid' : 0}).winid)
  new | only

  " Using :split or :vsplit from a quickfix window should behave like a :new
  " or a :vnew command
  copen
  split
  call assert_equal(3, winnr('$'))
  let l = getwininfo()
  call assert_equal([0, 0, 1], [l[0].quickfix, l[1].quickfix, l[2].quickfix])
  close
  copen
  vsplit
  let l = getwininfo()
  call assert_equal([0, 0, 1], [l[0].quickfix, l[1].quickfix, l[2].quickfix])
  new | only

  call delete('Xtestfile1')
  call delete('Xtestfile2')
endfunc

" Test for parsing entries using visual screen column
func Test_viscol()
  enew
  call writefile(["Col1\tCol2\tCol3"], 'Xfile1')
  edit Xfile1

  " Use byte offset for column number
  set efm&
  cexpr "Xfile1:1:5:XX\nXfile1:1:9:YY\nXfile1:1:20:ZZ"
  call assert_equal([5, 8], [col('.'), virtcol('.')])
  cnext
  call assert_equal([9, 12], [col('.'), virtcol('.')])
  cnext
  call assert_equal([14, 20], [col('.'), virtcol('.')])

  " Use screen column offset for column number
  set efm=%f:%l:%v:%m
  cexpr "Xfile1:1:8:XX\nXfile1:1:12:YY\nXfile1:1:20:ZZ"
  call assert_equal([5, 8], [col('.'), virtcol('.')])
  cnext
  call assert_equal([9, 12], [col('.'), virtcol('.')])
  cnext
  call assert_equal([14, 20], [col('.'), virtcol('.')])
  cexpr "Xfile1:1:6:XX\nXfile1:1:15:YY\nXfile1:1:24:ZZ"
  call assert_equal([5, 8], [col('.'), virtcol('.')])
  cnext
  call assert_equal([10, 16], [col('.'), virtcol('.')])
  cnext
  call assert_equal([14, 20], [col('.'), virtcol('.')])

  enew
  call writefile(["Col1\täü\töß\tCol4"], 'Xfile1')

  " Use byte offset for column number
  set efm&
  cexpr "Xfile1:1:8:XX\nXfile1:1:11:YY\nXfile1:1:16:ZZ"
  call assert_equal([8, 10], [col('.'), virtcol('.')])
  cnext
  call assert_equal([11, 17], [col('.'), virtcol('.')])
  cnext
  call assert_equal([16, 25], [col('.'), virtcol('.')])

  " Use screen column offset for column number
  set efm=%f:%l:%v:%m
  cexpr "Xfile1:1:10:XX\nXfile1:1:17:YY\nXfile1:1:25:ZZ"
  call assert_equal([8, 10], [col('.'), virtcol('.')])
  cnext
  call assert_equal([11, 17], [col('.'), virtcol('.')])
  cnext
  call assert_equal([16, 25], [col('.'), virtcol('.')])

  " Use screen column number with a multi-line error message
  enew
  call writefile(["à test"], 'Xfile1')
  set efm=%E===\ %f\ ===,%C%l:%v,%Z%m
  cexpr ["=== Xfile1 ===", "1:3", "errormsg"]
  call assert_equal('Xfile1', @%)
  call assert_equal([0, 1, 4, 0], getpos('.'))

  " Repeat previous test with byte offset %c: ensure that fix to issue #7145
  " does not break this
  set efm=%E===\ %f\ ===,%C%l:%c,%Z%m
  cexpr ["=== Xfile1 ===", "1:3", "errormsg"]
  call assert_equal('Xfile1', @%)
  call assert_equal([0, 1, 3, 0], getpos('.'))

  enew | only
  set efm&
  call delete('Xfile1')
endfunc

" Test for the quickfix window buffer
func Xqfbuf_test(cchar)
  call s:setup_commands(a:cchar)

  " Quickfix buffer should be reused across closing and opening a quickfix
  " window
  Xexpr "F1:10:Line10"
  Xopen
  let qfbnum = bufnr('')
  Xclose
  " Even after the quickfix window is closed, the buffer should be loaded
  call assert_true(bufloaded(qfbnum))
  call assert_true(qfbnum, g:Xgetlist({'qfbufnr' : 0}).qfbufnr)
  Xopen
  " Buffer should be reused when opening the window again
  call assert_equal(qfbnum, bufnr(''))
  Xclose

  " When quickfix buffer is wiped out, getqflist() should return 0
  %bw!
  Xexpr ""
  Xopen
  bw!
  call assert_equal(0, g:Xgetlist({'qfbufnr': 0}).qfbufnr)

  if a:cchar == 'l'
    %bwipe
    " For a location list, when both the file window and the location list
    " window for the list are closed, then the buffer should be freed.
    new | only
    lexpr "F1:10:Line10"
    let wid = win_getid()
    lopen
    let qfbnum = bufnr('')
    call assert_match(qfbnum . ' %a-  "\[Location List]"', execute('ls'))
    close
    " When the location list window is closed, the buffer name should not
    " change to 'Quickfix List'
    call assert_match(qfbnum . 'u h-  "\[Location List]"', execute('ls!'))
    call assert_true(bufloaded(qfbnum))

    " After deleting a location list buffer using ":bdelete", opening the
    " location list window should mark the buffer as a location list buffer.
    exe "bdelete " . qfbnum
    lopen
    call assert_equal("quickfix", &buftype)
    call assert_equal(1, getwininfo(win_getid(winnr()))[0].loclist)
    call assert_equal(wid, getloclist(0, {'filewinid' : 0}).filewinid)
    call assert_false(&swapfile)
    lclose

    " When the location list is cleared for the window, the buffer should be
    " removed
    call setloclist(0, [], 'f')
    call assert_false(bufexists(qfbnum))
    call assert_equal(0, getloclist(0, {'qfbufnr' : 0}).qfbufnr)

    " When the location list is freed with the location list window open, the
    " location list buffer should not be lost. It should be reused when the
    " location list is again populated.
    lexpr "F1:10:Line10"
    lopen
    let wid = win_getid()
    let qfbnum = bufnr('')
    wincmd p
    call setloclist(0, [], 'f')
    lexpr "F1:10:Line10"
    lopen
    call assert_equal(wid, win_getid())
    call assert_equal(qfbnum, bufnr(''))
    lclose

    " When the window with the location list is closed, the buffer should be
    " removed
    new | only
    call assert_false(bufexists(qfbnum))
  endif
endfunc

func Test_qfbuf()
  call Xqfbuf_test('c')
  call Xqfbuf_test('l')
endfunc

" If there is an autocmd to use only one window, then opening the location
" list window used to crash Vim.
func Test_winonly_autocmd()
  call s:create_test_file('Xtest1')
  " Autocmd to show only one Vim window at a time
  autocmd WinEnter * only
  new
  " Load the location list
  lexpr "Xtest1:5:Line5\nXtest1:10:Line10\nXtest1:15:Line15"
  let loclistid = getloclist(0, {'id' : 0}).id
  " Open the location list window. Only this window will be shown and the file
  " window is closed.
  lopen
  call assert_equal(loclistid, getloclist(0, {'id' : 0}).id)
  " Jump to an entry in the location list and make sure that the cursor is
  " positioned correctly.
  ll 3
  call assert_equal(loclistid, getloclist(0, {'id' : 0}).id)
  call assert_equal('Xtest1', @%)
  call assert_equal(15, line('.'))
  " Cleanup
  autocmd! WinEnter
  new | only
  call delete('Xtest1')
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

" Test for the :cbelow, :cabove, :lbelow and :labove commands.
" And for the :cafter, :cbefore, :lafter and :lbefore commands.
func Xtest_below(cchar)
  call s:setup_commands(a:cchar)

  " No quickfix/location list
  call assert_fails('Xbelow', 'E42:')
  call assert_fails('Xabove', 'E42:')
  call assert_fails('Xbefore', 'E42:')
  call assert_fails('Xafter', 'E42:')

  " Empty quickfix/location list
  call g:Xsetlist([])
  call assert_fails('Xbelow', 'E42:')
  call assert_fails('Xabove', 'E42:')
  call assert_fails('Xbefore', 'E42:')
  call assert_fails('Xafter', 'E42:')

  call s:create_test_file('X1')
  call s:create_test_file('X2')
  call s:create_test_file('X3')
  call s:create_test_file('X4')

  " Invalid entries
  edit X1
  call g:Xsetlist(["E1", "E2"])
  call assert_fails('Xbelow', 'E42:')
  call assert_fails('Xabove', 'E42:')
  call assert_fails('3Xbelow', 'E42:')
  call assert_fails('4Xabove', 'E42:')
  call assert_fails('Xbefore', 'E42:')
  call assert_fails('Xafter', 'E42:')
  call assert_fails('3Xbefore', 'E42:')
  call assert_fails('4Xafter', 'E42:')

  " Test the commands with various arguments
  Xexpr ["X1:5:3:L5", "X2:5:2:L5", "X2:10:3:L10", "X2:15:4:L15", "X3:3:5:L3"]
  edit +7 X2
  Xabove
  call assert_equal(['X2', 5], [@%, line('.')])
  call assert_fails('Xabove', 'E553:')
  normal 7G
  Xbefore
  call assert_equal(['X2', 5, 2], [@%, line('.'), col('.')])
  call assert_fails('Xbefore', 'E553:')

  normal 2j
  Xbelow
  call assert_equal(['X2', 10], [@%, line('.')])
  normal 7G
  Xafter
  call assert_equal(['X2', 10, 3], [@%, line('.'), col('.')])

  " Last error in this file
  Xbelow 99
  call assert_equal(['X2', 15], [@%, line('.')])
  call assert_fails('Xbelow', 'E553:')
  normal gg
  Xafter 99
  call assert_equal(['X2', 15, 4], [@%, line('.'), col('.')])
  call assert_fails('Xafter', 'E553:')

  " First error in this file
  Xabove 99
  call assert_equal(['X2', 5], [@%, line('.')])
  call assert_fails('Xabove', 'E553:')
  normal G
  Xbefore 99
  call assert_equal(['X2', 5, 2], [@%, line('.'), col('.')])
  call assert_fails('Xbefore', 'E553:')

  normal gg
  Xbelow 2
  call assert_equal(['X2', 10], [@%, line('.')])
  normal gg
  Xafter 2
  call assert_equal(['X2', 10, 3], [@%, line('.'), col('.')])

  normal G
  Xabove 2
  call assert_equal(['X2', 10], [@%, line('.')])
  normal G
  Xbefore 2
  call assert_equal(['X2', 10, 3], [@%, line('.'), col('.')])

  edit X4
  call assert_fails('Xabove', 'E42:')
  call assert_fails('Xbelow', 'E42:')
  call assert_fails('Xbefore', 'E42:')
  call assert_fails('Xafter', 'E42:')
  if a:cchar == 'l'
    " If a buffer has location list entries from some other window but not
    " from the current window, then the commands should fail.
    edit X1 | split | call setloclist(0, [], 'f')
    call assert_fails('Xabove', 'E776:')
    call assert_fails('Xbelow', 'E776:')
    call assert_fails('Xbefore', 'E776:')
    call assert_fails('Xafter', 'E776:')
    close
  endif

  " Test for lines with multiple quickfix entries
  let lines =<< trim END
    X1:5:L5
    X2:5:1:L5_1
    X2:5:2:L5_2
    X2:5:3:L5_3
    X2:10:1:L10_1
    X2:10:2:L10_2
    X2:10:3:L10_3
    X2:15:1:L15_1
    X2:15:2:L15_2
    X2:15:3:L15_3
    X3:3:L3
  END
  Xexpr lines
  edit +1 X2
  Xbelow 2
  call assert_equal(['X2', 10, 1], [@%, line('.'), col('.')])
  normal 1G
  Xafter 2
  call assert_equal(['X2', 5, 2], [@%, line('.'), col('.')])

  normal gg
  Xbelow 99
  call assert_equal(['X2', 15, 1], [@%, line('.'), col('.')])
  normal gg
  Xafter 99
  call assert_equal(['X2', 15, 3], [@%, line('.'), col('.')])

  normal G
  Xabove 2
  call assert_equal(['X2', 10, 1], [@%, line('.'), col('.')])
  normal G
  Xbefore 2
  call assert_equal(['X2', 15, 2], [@%, line('.'), col('.')])

  normal G
  Xabove 99
  call assert_equal(['X2', 5, 1], [@%, line('.'), col('.')])
  normal G
  Xbefore 99
  call assert_equal(['X2', 5, 1], [@%, line('.'), col('.')])

  normal 10G
  Xabove
  call assert_equal(['X2', 5, 1], [@%, line('.'), col('.')])
  normal 10G$
  2Xbefore
  call assert_equal(['X2', 10, 2], [@%, line('.'), col('.')])

  normal 10G
  Xbelow
  call assert_equal(['X2', 15, 1], [@%, line('.'), col('.')])
  normal 9G
  5Xafter
  call assert_equal(['X2', 15, 2], [@%, line('.'), col('.')])

  " Invalid range
  if a:cchar == 'c'
    call assert_fails('-2cbelow', 'E16:')
    call assert_fails('-2cafter', 'E16:')
  else
    call assert_fails('-2lbelow', 'E16:')
    call assert_fails('-2lafter', 'E16:')
  endif

  call delete('X1')
  call delete('X2')
  call delete('X3')
  call delete('X4')
endfunc

func Test_cbelow()
  call Xtest_below('c')
  call Xtest_below('l')
endfunc

func Test_quickfix_count()
  let commands =<< trim END
    cNext
    cNfile
    cabove
    cbelow
    cfirst
    clast
    cnewer
    cnext
    cnfile
    colder
    cprevious
    crewind
    lNext
    lNfile
    labove
    lbelow
    lfirst
    llast
    lnewer
    lnext
    lnfile
    lolder
    lprevious
    lrewind
  END
  for cmd in commands
    call assert_fails('-1' .. cmd, 'E16:')
    call assert_fails('.' .. cmd, 'E16:')
    call assert_fails('%' .. cmd, 'E16:')
    call assert_fails('$' .. cmd, 'E16:')
  endfor
endfunc

" Test for aborting quickfix commands using QuickFixCmdPre
func Xtest_qfcmd_abort(cchar)
  call s:setup_commands(a:cchar)

  call g:Xsetlist([], 'f')

  " cexpr/lexpr
  let e = ''
  try
    Xexpr ["F1:10:Line10", "F2:20:Line20"]
  catch /.*/
    let e = v:exception
  endtry
  call assert_equal('AbortCmd', e)
  call assert_equal(0, g:Xgetlist({'nr' : '$'}).nr)

  " cfile/lfile
  call writefile(["F1:10:Line10", "F2:20:Line20"], 'Xfile1')
  let e = ''
  try
    Xfile Xfile1
  catch /.*/
    let e = v:exception
  endtry
  call assert_equal('AbortCmd', e)
  call assert_equal(0, g:Xgetlist({'nr' : '$'}).nr)
  call delete('Xfile1')

  " cgetbuffer/lgetbuffer
  enew!
  call append(0, ["F1:10:Line10", "F2:20:Line20"])
  let e = ''
  try
    Xgetbuffer
  catch /.*/
    let e = v:exception
  endtry
  call assert_equal('AbortCmd', e)
  call assert_equal(0, g:Xgetlist({'nr' : '$'}).nr)
  enew!

  " vimgrep/lvimgrep
  let e = ''
  try
    Xvimgrep /func/ test_quickfix.vim
  catch /.*/
    let e = v:exception
  endtry
  call assert_equal('AbortCmd', e)
  call assert_equal(0, g:Xgetlist({'nr' : '$'}).nr)

  " helpgrep/lhelpgrep
  let e = ''
  try
    Xhelpgrep quickfix
  catch /.*/
    let e = v:exception
  endtry
  call assert_equal('AbortCmd', e)
  call assert_equal(0, g:Xgetlist({'nr' : '$'}).nr)

  " grep/lgrep
  if has('unix')
    let e = ''
    try
      silent Xgrep func test_quickfix.vim
    catch /.*/
      let e = v:exception
    endtry
    call assert_equal('AbortCmd', e)
    call assert_equal(0, g:Xgetlist({'nr' : '$'}).nr)
  endif
endfunc

func Test_qfcmd_abort()
  augroup QF_Test
    au!
    autocmd  QuickFixCmdPre * throw "AbortCmd"
  augroup END

  call Xtest_qfcmd_abort('c')
  call Xtest_qfcmd_abort('l')

  augroup QF_Test
    au!
  augroup END
endfunc

" Test for using a file in one of the parent directories.
func Test_search_in_dirstack()
  call mkdir('Xtestdir/a/b/c', 'p')
  let save_cwd = getcwd()
  call writefile(["X1_L1", "X1_L2"], 'Xtestdir/Xfile1')
  call writefile(["X2_L1", "X2_L2"], 'Xtestdir/a/Xfile2')
  call writefile(["X3_L1", "X3_L2"], 'Xtestdir/a/b/Xfile3')
  call writefile(["X4_L1", "X4_L2"], 'Xtestdir/a/b/c/Xfile4')

  let lines = "Entering dir Xtestdir\n" .
	      \ "Entering dir a\n" .
	      \ "Entering dir b\n" .
	      \ "Xfile2:2:X2_L2\n" .
	      \ "Leaving dir a\n" .
	      \ "Xfile1:2:X1_L2\n" .
	      \ "Xfile3:1:X3_L1\n" .
	      \ "Entering dir c\n" .
	      \ "Xfile4:2:X4_L2\n" .
	      \ "Leaving dir c\n"
  set efm=%DEntering\ dir\ %f,%XLeaving\ dir\ %f,%f:%l:%m
  cexpr lines .. "Leaving dir Xtestdir|\n" | let next = 1
  call assert_equal(11, getqflist({'size' : 0}).size)
  call assert_equal(4, getqflist({'idx' : 0}).idx)
  call assert_equal('X2_L2', getline('.'))
  call assert_equal(1, next)
  cnext
  call assert_equal(6, getqflist({'idx' : 0}).idx)
  call assert_equal('X1_L2', getline('.'))
  cnext
  call assert_equal(7, getqflist({'idx' : 0}).idx)
  call assert_equal(1, line('$'))
  call assert_equal('', getline(1))
  cnext
  call assert_equal(9, getqflist({'idx' : 0}).idx)
  call assert_equal(1, line('$'))
  call assert_equal('', getline(1))

  set efm&
  exe 'cd ' . save_cwd
  call delete('Xtestdir', 'rf')
endfunc

" Test for :cquit
func Test_cquit()
  " Exit Vim with a non-zero value
  if RunVim([], ["cquit 7"], '')
    call assert_equal(7, v:shell_error)
  endif

  if RunVim([], ["50cquit"], '')
    call assert_equal(50, v:shell_error)
  endif

  " Exit Vim with default value
  if RunVim([], ["cquit"], '')
    call assert_equal(1, v:shell_error)
  endif

  " Exit Vim with zero value
  if RunVim([], ["cquit 0"], '')
    call assert_equal(0, v:shell_error)
  endif

  " Exit Vim with negative value
  call assert_fails('-3cquit', 'E16:')
endfunc

" Test for getting a specific item from a quickfix list
func Xtest_getqflist_by_idx(cchar)
  call s:setup_commands(a:cchar)
  " Empty list
  call assert_equal([], g:Xgetlist({'idx' : 1, 'items' : 0}).items)
  Xexpr ['F1:10:L10', 'F1:20:L20']
  let l = g:Xgetlist({'idx' : 2, 'items' : 0}).items
  call assert_equal(bufnr('F1'), l[0].bufnr)
  call assert_equal(20, l[0].lnum)
  call assert_equal('L20', l[0].text)
  call assert_equal([], g:Xgetlist({'idx' : -1, 'items' : 0}).items)
  call assert_equal([], g:Xgetlist({'idx' : 3, 'items' : 0}).items)
  call assert_equal({}, g:Xgetlist(#{idx: "abc"}))
  %bwipe!
endfunc

func Test_getqflist_by_idx()
  call Xtest_getqflist_by_idx('c')
  call Xtest_getqflist_by_idx('l')
endfunc

" Test for the 'quickfixtextfunc' setting
func Tqfexpr(info)
  if a:info.quickfix
    let qfl = getqflist({'id' : a:info.id, 'items' : 1}).items
  else
    let qfl = getloclist(a:info.winid, {'id' : a:info.id, 'items' : 1}).items
  endif

  let l = []
  for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
    let e = qfl[idx]
    let s = ''
    if e.bufnr != 0
      let bname = bufname(e.bufnr)
      let s ..= fnamemodify(bname, ':.')
    endif
    let s ..= '-'
    let s ..= 'L' .. string(e.lnum) .. 'C' .. string(e.col) .. '-'
    let s ..= e.text
    call add(l, s)
  endfor

  return l
endfunc

func Xtest_qftextfunc(cchar)
  call s:setup_commands(a:cchar)

  set efm=%f:%l:%c:%m
  set quickfixtextfunc=Tqfexpr
  call assert_equal('Tqfexpr', &quickfixtextfunc)
  call assert_equal('',
        \ g:Xgetlist({'quickfixtextfunc' : 1}).quickfixtextfunc)
  call g:Xsetlist([
        \ { 'filename': 'F1', 'lnum': 10, 'col': 2,
        \   'end_col': 7, 'text': 'green'},
        \ { 'filename': 'F1', 'lnum': 20, 'end_lnum': 25, 'col': 4,
        \   'end_col': 8, 'text': 'blue'},
        \ ])

  Xwindow
  call assert_equal('F1-L10C2-green', getline(1))
  call assert_equal('F1-L20C4-blue', getline(2))
  Xclose
  set quickfixtextfunc&vim
  Xwindow
  call assert_equal('F1|10 col 2-7| green', getline(1))
  call assert_equal('F1|20-25 col 4-8| blue', getline(2))
  Xclose

  set efm=%f:%l:%c:%m
  set quickfixtextfunc=Tqfexpr
  " Update the list with only the cwindow
  Xwindow
  only
  call g:Xsetlist([
        \ { 'filename': 'F2', 'lnum': 20, 'col': 2,
        \   'end_col': 7, 'text': 'red'}
        \ ])
  call assert_equal(['F2-L20C2-red'], getline(1, '$'))
  new
  Xclose
  set efm&
  set quickfixtextfunc&

  " Test for per list 'quickfixtextfunc' setting
  func PerQfText(info)
    if a:info.quickfix
      let qfl = getqflist({'id' : a:info.id, 'items' : 1}).items
    else
      let qfl = getloclist(a:info.winid, {'id' : a:info.id, 'items' : 1}).items
    endif
    if empty(qfl)
      return []
    endif
    let l = []
    for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
      call add(l, 'Line ' .. qfl[idx].lnum .. ', Col ' .. qfl[idx].col)
    endfor
    return l
  endfunc
  set quickfixtextfunc=Tqfexpr
  call g:Xsetlist([], ' ', {'quickfixtextfunc' : "PerQfText"})
  Xaddexpr ['F1:10:2:green', 'F1:20:4:blue']
  Xwindow
  call assert_equal('Line 10, Col 2', getline(1))
  call assert_equal('Line 20, Col 4', getline(2))
  Xclose
  call assert_equal(function('PerQfText'),
        \ g:Xgetlist({'quickfixtextfunc' : 1}).quickfixtextfunc)
  " Add entries to the list when the quickfix buffer is hidden
  Xaddexpr ['F1:30:6:red']
  Xwindow
  call assert_equal('Line 30, Col 6', getline(3))
  Xclose
  call g:Xsetlist([], 'r', {'quickfixtextfunc' : ''})
  call assert_equal('', g:Xgetlist({'quickfixtextfunc' : 1}).quickfixtextfunc)
  set quickfixtextfunc&
  delfunc PerQfText

  " Non-existing function
  set quickfixtextfunc=Tabc
  call assert_fails("Xexpr ['F1:10:2:green', 'F1:20:4:blue']", 'E117:')
  call assert_fails("Xwindow", 'E117:')
  Xclose
  set quickfixtextfunc&

  " set option to a non-function
  set quickfixtextfunc=[10,\ 20]
  call assert_fails("Xexpr ['F1:10:2:green', 'F1:20:4:blue']", 'E117:')
  call assert_fails("Xwindow", 'E117:')
  Xclose
  set quickfixtextfunc&

  " set option to a function with different set of arguments
  func Xqftext(a, b, c)
    return a:a .. a:b .. a:c
  endfunc
  set quickfixtextfunc=Xqftext
  call assert_fails("Xexpr ['F1:10:2:green', 'F1:20:4:blue']", 'E119:')
  call assert_fails("Xwindow", 'E119:')
  Xclose

  " set option to a function that returns a list with non-strings
  func Xqftext2(d)
    return ['one', [], 'two']
  endfunc
  set quickfixtextfunc=Xqftext2
  call assert_fails("Xexpr ['F1:10:2:green', 'F1:20:4:blue', 'F1:30:6:red']",
                                                                  \ 'E730:')
  call assert_fails('Xwindow', 'E730:')
  call assert_equal(['one', 'F1|20 col 4| blue', 'F1|30 col 6| red'],
        \ getline(1, '$'))
  Xclose

  set quickfixtextfunc&
  delfunc Xqftext
  delfunc Xqftext2

  " set the global option to a lambda function
  set quickfixtextfunc={d\ ->\ map(g:Xgetlist({'id'\ :\ d.id,\ 'items'\ :\ 1}).items[d.start_idx-1:d.end_idx-1],\ 'v:val.text')}
  Xexpr ['F1:10:2:green', 'F1:20:4:blue']
  Xwindow
  call assert_equal(['green', 'blue'], getline(1, '$'))
  Xclose
  call assert_equal("{d -> map(g:Xgetlist({'id' : d.id, 'items' : 1}).items[d.start_idx-1:d.end_idx-1], 'v:val.text')}", &quickfixtextfunc)
  set quickfixtextfunc&

  " use a lambda function that returns an empty list
  set quickfixtextfunc={d\ ->\ []}
  Xexpr ['F1:10:2:green', 'F1:20:4:blue']
  Xwindow
  call assert_equal(['F1|10 col 2| green', 'F1|20 col 4| blue'],
        \ getline(1, '$'))
  Xclose
  set quickfixtextfunc&

  " use a lambda function that returns a list with empty strings
  set quickfixtextfunc={d\ ->\ ['',\ '']}
  Xexpr ['F1:10:2:green', 'F1:20:4:blue']
  Xwindow
  call assert_equal(['F1|10 col 2| green', 'F1|20 col 4| blue'],
        \ getline(1, '$'))
  Xclose
  set quickfixtextfunc&

  " set the per-quickfix list text function to a lambda function
  call g:Xsetlist([], ' ',
        \ {'quickfixtextfunc' :
        \   {d -> map(g:Xgetlist({'id' : d.id, 'items' : 1}).items[d.start_idx-1:d.end_idx-1],
        \ "'Line ' .. v:val.lnum .. ', Col ' .. v:val.col")}})
  Xaddexpr ['F1:10:2:green', 'F1:20:4:blue']
  Xwindow
  call assert_equal('Line 10, Col 2', getline(1))
  call assert_equal('Line 20, Col 4', getline(2))
  Xclose
  call assert_match("function('<lambda>\\d\\+')", string(g:Xgetlist({'quickfixtextfunc' : 1}).quickfixtextfunc))
  call g:Xsetlist([], 'f')
endfunc

func Test_qftextfunc()
  call Xtest_qftextfunc('c')
  call Xtest_qftextfunc('l')
endfunc

func Test_qftextfunc_callback()
  let lines =<< trim END
    set efm=%f:%l:%c:%m

    #" Test for using a function name
    LET &qftf = 'g:Tqfexpr'
    cexpr "F0:0:0:L0"
    copen
    call assert_equal('F0-L0C0-L0', getline(1))
    cclose

    #" Test for using a function()
    set qftf=function('g:Tqfexpr')
    cexpr "F1:1:1:L1"
    copen
    call assert_equal('F1-L1C1-L1', getline(1))
    cclose

    #" Using a funcref variable to set 'quickfixtextfunc'
    VAR Fn = function('g:Tqfexpr')
    LET &qftf = Fn
    cexpr "F2:2:2:L2"
    copen
    call assert_equal('F2-L2C2-L2', getline(1))
    cclose

    #" Using string(funcref_variable) to set 'quickfixtextfunc'
    LET Fn = function('g:Tqfexpr')
    LET &qftf = string(Fn)
    cexpr "F3:3:3:L3"
    copen
    call assert_equal('F3-L3C3-L3', getline(1))
    cclose

    #" Test for using a funcref()
    set qftf=funcref('g:Tqfexpr')
    cexpr "F4:4:4:L4"
    copen
    call assert_equal('F4-L4C4-L4', getline(1))
    cclose

    #" Using a funcref variable to set 'quickfixtextfunc'
    LET Fn = funcref('g:Tqfexpr')
    LET &qftf = Fn
    cexpr "F5:5:5:L5"
    copen
    call assert_equal('F5-L5C5-L5', getline(1))
    cclose

    #" Using a string(funcref_variable) to set 'quickfixtextfunc'
    LET Fn = funcref('g:Tqfexpr')
    LET &qftf = string(Fn)
    cexpr "F5:5:5:L5"
    copen
    call assert_equal('F5-L5C5-L5', getline(1))
    cclose

    #" Test for using a lambda function with set
    VAR optval = "LSTART a LMIDDLE Tqfexpr(a) LEND"
    LET optval = substitute(optval, ' ', '\\ ', 'g')
    exe "set qftf=" .. optval
    cexpr "F6:6:6:L6"
    copen
    call assert_equal('F6-L6C6-L6', getline(1))
    cclose

    #" Set 'quickfixtextfunc' to a lambda expression
    LET &qftf = LSTART a LMIDDLE Tqfexpr(a) LEND
    cexpr "F7:7:7:L7"
    copen
    call assert_equal('F7-L7C7-L7', getline(1))
    cclose

    #" Set 'quickfixtextfunc' to string(lambda_expression)
    LET &qftf = "LSTART a LMIDDLE Tqfexpr(a) LEND"
    cexpr "F8:8:8:L8"
    copen
    call assert_equal('F8-L8C8-L8', getline(1))
    cclose

    #" Set 'quickfixtextfunc' to a variable with a lambda expression
    VAR Lambda = LSTART a LMIDDLE Tqfexpr(a) LEND
    LET &qftf = Lambda
    cexpr "F9:9:9:L9"
    copen
    call assert_equal('F9-L9C9-L9', getline(1))
    cclose

    #" Set 'quickfixtextfunc' to a string(variable with a lambda expression)
    LET Lambda = LSTART a LMIDDLE Tqfexpr(a) LEND
    LET &qftf = string(Lambda)
    cexpr "F9:9:9:L9"
    copen
    call assert_equal('F9-L9C9-L9', getline(1))
    cclose
  END
  call CheckLegacyAndVim9Success(lines)

  " Test for using a script-local function name
  func s:TqfFunc2(info)
    let g:TqfFunc2Args = [a:info.start_idx, a:info.end_idx]
    return ''
  endfunc
  let g:TqfFunc2Args = []
  set quickfixtextfunc=s:TqfFunc2
  cexpr "F10:10:10:L10"
  cclose
  call assert_equal([1, 1], g:TqfFunc2Args)

  let &quickfixtextfunc = 's:TqfFunc2'
  cexpr "F11:11:11:L11"
  cclose
  call assert_equal([1, 1], g:TqfFunc2Args)
  delfunc s:TqfFunc2

  " set 'quickfixtextfunc' to a partial with dict. This used to cause a crash.
  func SetQftfFunc()
    let params = {'qftf': function('g:DictQftfFunc')}
    let &quickfixtextfunc = params.qftf
  endfunc
  func g:DictQftfFunc(_) dict
  endfunc
  call SetQftfFunc()
  new
  call SetQftfFunc()
  bw
  call test_garbagecollect_now()
  new
  set qftf=
  wincmd w
  set qftf=
  :%bw!

  " set per-quickfix list 'quickfixtextfunc' to a partial with dict. This used
  " to cause a crash.
  let &qftf = ''
  func SetLocalQftfFunc()
    let params = {'qftf': function('g:DictQftfFunc')}
    call setqflist([], 'a', {'quickfixtextfunc' : params.qftf})
  endfunc
  call SetLocalQftfFunc()
  call test_garbagecollect_now()
  call setqflist([], 'a', {'quickfixtextfunc' : ''})
  delfunc g:DictQftfFunc
  delfunc SetQftfFunc
  delfunc SetLocalQftfFunc
  set efm&
endfunc

" Test for updating a location list for some other window and check that
" 'qftextfunc' uses the correct location list.
func Test_qftextfunc_other_loclist()
  %bw!
  call setloclist(0, [], 'f')

  " create a window and a location list for it and open the location list
  " window
  lexpr ['F1:10:12:one', 'F1:20:14:two']
  let w1_id = win_getid()
  call setloclist(0, [], ' ',
        \ {'lines': ['F1:10:12:one', 'F1:20:14:two'],
        \  'quickfixtextfunc':
        \    {d -> map(getloclist(d.winid, {'id' : d.id,
        \                'items' : 1}).items[d.start_idx-1:d.end_idx-1],
        \          "'Line ' .. v:val.lnum .. ', Col ' .. v:val.col")}})
  lwindow
  let w2_id = win_getid()

  " create another window and a location list for it and open the location
  " list window
  topleft new
  let w3_id = win_getid()
  call setloclist(0, [], ' ',
        \ {'lines': ['F2:30:32:eleven', 'F2:40:34:twelve'],
        \  'quickfixtextfunc':
        \    {d -> map(getloclist(d.winid, {'id' : d.id,
        \                'items' : 1}).items[d.start_idx-1:d.end_idx-1],
        \          "'Ligne ' .. v:val.lnum .. ', Colonne ' .. v:val.col")}})
  lwindow
  let w4_id = win_getid()

  topleft new
  lexpr ['F3:50:52:green', 'F3:60:54:blue']
  let w5_id = win_getid()

  " change the location list for some other window
  call setloclist(0, [], 'r', {'lines': ['F3:55:56:aaa', 'F3:57:58:bbb']})
  call setloclist(w1_id, [], 'r', {'lines': ['F1:62:63:bbb', 'F1:64:65:ccc']})
  call setloclist(w3_id, [], 'r', {'lines': ['F2:76:77:ddd', 'F2:78:79:eee']})
  call assert_equal(['Line 62, Col 63', 'Line 64, Col 65'],
        \ getbufline(winbufnr(w2_id), 1, '$'))
  call assert_equal(['Ligne 76, Colonne 77', 'Ligne 78, Colonne 79'],
        \ getbufline(winbufnr(w4_id), 1, '$'))
  call setloclist(w2_id, [], 'r', {'lines': ['F1:32:33:fff', 'F1:34:35:ggg']})
  call setloclist(w4_id, [], 'r', {'lines': ['F2:46:47:hhh', 'F2:48:49:jjj']})
  call assert_equal(['Line 32, Col 33', 'Line 34, Col 35'],
        \ getbufline(winbufnr(w2_id), 1, '$'))
  call assert_equal(['Ligne 46, Colonne 47', 'Ligne 48, Colonne 49'],
        \ getbufline(winbufnr(w4_id), 1, '$'))

  call win_gotoid(w5_id)
  lwindow
  call assert_equal(['F3|55 col 56| aaa', 'F3|57 col 58| bbb'],
        \ getline(1, '$'))
  %bw!
endfunc

" Running :lhelpgrep command more than once in a help window, doesn't jump to
" the help topic
func Test_lhelpgrep_from_help_window()
  call mkdir('Xtestdir/doc', 'p')
  call writefile(['window'], 'Xtestdir/doc/a.txt')
  call writefile(['buffer'], 'Xtestdir/doc/b.txt')
  let save_rtp = &rtp
  let &rtp = 'Xtestdir'
  lhelpgrep window
  lhelpgrep buffer
  call assert_equal('b.txt', fnamemodify(@%, ":p:t"))
  lhelpgrep window
  call assert_equal('a.txt', fnamemodify(@%, ":p:t"))
  let &rtp = save_rtp
  call delete('Xtestdir', 'rf')
  new | only!
endfunc

" Test for the crash fixed by 7.3.715
func Test_setloclist_crash()
  %bw!
  let g:BufNum = bufnr()
  augroup QF_Test
    au!
    au BufUnload * call setloclist(0, [{'bufnr':g:BufNum, 'lnum':1, 'col':1, 'text': 'tango down'}])
  augroup END

  try
    lvimgrep /.*/ *.mak
  catch /E926:/
  endtry
  call assert_equal('tango down', getloclist(0, {'items' : 0}).items[0].text)
  call assert_equal(1, getloclist(0, {'size' : 0}).size)

  augroup QF_Test
    au!
  augroup END
  unlet g:BufNum
  %bw!
endfunc

" Test for adding an invalid entry with the quickfix window open and making
" sure that the window contents are not changed
func Test_add_invalid_entry_with_qf_window()
  call setqflist([], 'f')
  cexpr "Xfile1:10:aa"
  copen
  call setqflist(['bb'], 'a')
  call assert_equal(1, line('$'))
  call assert_equal(['Xfile1|10| aa'], getline(1, '$'))
  call assert_equal([{'lnum': 10                    , 'end_lnum': 0    , 'bufnr': bufnr('Xfile1') , 'col': 0   , 'end_col': 0    , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , getqflist())

  call setqflist([{'lnum': 10                                          , 'bufnr': bufnr('Xfile1') , 'col': 0                     , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , 'r')
  call assert_equal(1                               , line('$'))
  call assert_equal(['Xfile1|10| aa']               , getline(1        , '$'))
  call assert_equal([{'lnum': 10                    , 'end_lnum': 0    , 'bufnr': bufnr('Xfile1') , 'col': 0   , 'end_col': 0    , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , getqflist())

  call setqflist([{'lnum': 10                       , 'end_lnum': 0    , 'bufnr': bufnr('Xfile1') , 'col': 0   , 'end_col': 0    , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , 'r')
  call assert_equal(1                               , line('$'))
  call assert_equal(['Xfile1|10| aa']               , getline(1        , '$'))
  call assert_equal([{'lnum': 10                    , 'end_lnum': 0    , 'bufnr': bufnr('Xfile1') , 'col': 0   , 'end_col': 0    , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , getqflist())

  call setqflist([{'lnum': 10                       , 'end_lnum': -123 , 'bufnr': bufnr('Xfile1') , 'col': 0   , 'end_col': -456 , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , 'r')
  call assert_equal(1                               , line('$'))
  call assert_equal(['Xfile1|10| aa']               , getline(1        , '$'))
  call assert_equal([{'lnum': 10                    , 'end_lnum': -123 , 'bufnr': bufnr('Xfile1') , 'col': 0   , 'end_col': -456 , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , getqflist())

  call setqflist([{'lnum': 10                       , 'end_lnum': -123 , 'bufnr': bufnr('Xfile1') , 'col': 666 , 'end_col': 0    , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , 'r')
  call assert_equal(1                               , line('$'))
  call assert_equal(['Xfile1|10 col 666| aa']       , getline(1        , '$'))
  call assert_equal([{'lnum': 10                    , 'end_lnum': -123 , 'bufnr': bufnr('Xfile1') , 'col': 666 , 'end_col': 0    , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , getqflist())

  call setqflist([{'lnum': 10                       , 'end_lnum': -123 , 'bufnr': bufnr('Xfile1') , 'col': 666 , 'end_col': -456 , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , 'r')
  call assert_equal(1                               , line('$'))
  call assert_equal(['Xfile1|10 col 666| aa']       , getline(1        , '$'))
  call assert_equal([{'lnum': 10                    , 'end_lnum': -123 , 'bufnr': bufnr('Xfile1') , 'col': 666 , 'end_col': -456 , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , getqflist())

  call setqflist([{'lnum': 10                       , 'end_lnum': -123 , 'bufnr': bufnr('Xfile1') , 'col': 666 , 'end_col': 222  , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , 'r')
  call assert_equal(1                               , line('$'))
  call assert_equal(['Xfile1|10 col 666-222| aa']   , getline(1        , '$'))
  call assert_equal([{'lnum': 10                    , 'end_lnum': -123 , 'bufnr': bufnr('Xfile1') , 'col': 666 , 'end_col': 222  , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , getqflist())

  call setqflist([{'lnum': 10                       , 'end_lnum': 6 , 'bufnr': bufnr('Xfile1') , 'col': 666 , 'end_col': 222  , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , 'r')
  call assert_equal(1                               , line('$'))
  call assert_equal(['Xfile1|10-6 col 666-222| aa'] , getline(1        , '$'))
  call assert_equal([{'lnum': 10                    , 'end_lnum': 6 , 'bufnr': bufnr('Xfile1') , 'col': 666 , 'end_col': 222  , 'pattern': '' , 'valid': 1 , 'vcol': 0 , 'nr': -1 , 'type': '' , 'module': '' , 'text': 'aa'}] , getqflist())
  cclose
endfunc

" Test for very weird problem: autocommand causes a failure, resulting opening
" the quickfix window to fail. This still splits the window, but otherwise
" should not mess up buffers.
func Test_quickfix_window_fails_to_open()
  CheckScreendump

  let lines =<< trim END
      anything
      try
        anything
      endtry
  END
  call writefile(lines, 'XquickfixFails')

  let lines =<< trim END
      split XquickfixFails
      silent vimgrep anything %
      normal o
      au BufLeave * ++once source XquickfixFails
      " This will trigger the autocommand, which causes an error, what follows
      " is aborted but the window was already split.
      silent! cwindow
  END
  call writefile(lines, 'XtestWinFails')
  let buf = RunVimInTerminal('-S XtestWinFails', #{rows: 13})
  call VerifyScreenDump(buf, 'Test_quickfix_window_fails', {})

  " clean up
  call term_sendkeys(buf, ":bwipe!\<CR>")
  call term_wait(buf)
  call StopVimInTerminal(buf)
  call delete('XtestWinFails')
  call delete('XquickfixFails')
endfunc

" Test for updating the quickfix buffer whenever the associated quickfix list
" is changed.
func Xqfbuf_update(cchar)
  call s:setup_commands(a:cchar)

  Xexpr "F1:1:line1"
  Xopen
  call assert_equal(['F1|1| line1'], getline(1, '$'))
  call assert_equal(1, g:Xgetlist({'changedtick' : 0}).changedtick)

  " Test setqflist() using the 'lines' key in 'what'
  " add a new entry
  call g:Xsetlist([], 'a', {'lines' : ['F2:2: line2']})
  call assert_equal(['F1|1| line1', 'F2|2| line2'], getline(1, '$'))
  call assert_equal(2, g:Xgetlist({'changedtick' : 0}).changedtick)
  " replace all the entries with a single entry
  call g:Xsetlist([], 'r', {'lines' : ['F3:3: line3']})
  call assert_equal(['F3|3| line3'], getline(1, '$'))
  call assert_equal(3, g:Xgetlist({'changedtick' : 0}).changedtick)
  " remove all the entries
  call g:Xsetlist([], 'r', {'lines' : []})
  call assert_equal([''], getline(1, '$'))
  call assert_equal(4, g:Xgetlist({'changedtick' : 0}).changedtick)
  " add a new list
  call g:Xsetlist([], ' ', {'lines' : ['F4:4: line4']})
  call assert_equal(['F4|4| line4'], getline(1, '$'))
  call assert_equal(1, g:Xgetlist({'changedtick' : 0}).changedtick)

  " Test setqflist() using the 'items' key in 'what'
  " add a new entry
  call g:Xsetlist([], 'a', {'items' : [{'filename' : 'F5', 'lnum' : 5, 'text' : 'line5'}]})
  call assert_equal(['F4|4| line4', 'F5|5| line5'], getline(1, '$'))
  call assert_equal(2, g:Xgetlist({'changedtick' : 0}).changedtick)
  " replace all the entries with a single entry
  call g:Xsetlist([], 'r', {'items' : [{'filename' : 'F6', 'lnum' : 6, 'text' : 'line6'}]})
  call assert_equal(['F6|6| line6'], getline(1, '$'))
  call assert_equal(3, g:Xgetlist({'changedtick' : 0}).changedtick)
  " remove all the entries
  call g:Xsetlist([], 'r', {'items' : []})
  call assert_equal([''], getline(1, '$'))
  call assert_equal(4, g:Xgetlist({'changedtick' : 0}).changedtick)
  " add a new list
  call g:Xsetlist([], ' ', {'items' : [{'filename' : 'F7', 'lnum' : 7, 'text' : 'line7'}]})
  call assert_equal(['F7|7| line7'], getline(1, '$'))
  call assert_equal(1, g:Xgetlist({'changedtick' : 0}).changedtick)

  call g:Xsetlist([], ' ', {})
  call assert_equal([''], getline(1, '$'))
  call assert_equal(1, g:Xgetlist({'changedtick' : 0}).changedtick)

  Xclose
endfunc

func Test_qfbuf_update()
  call Xqfbuf_update('c')
  call Xqfbuf_update('l')
endfunc

func Test_vimgrep_noswapfile()
  set noswapfile
  call writefile(['one', 'two', 'three'], 'Xgreppie')
  vimgrep two Xgreppie
  call assert_equal('two', getline('.'))

  call delete('Xgreppie')
  set swapfile
endfunc

" Test for the :vimgrep 'f' flag (fuzzy match)
func Xvimgrep_fuzzy_match(cchar)
  call s:setup_commands(a:cchar)

  Xvimgrep /three one/f Xfile*
  let l = g:Xgetlist()
  call assert_equal(2, len(l))
  call assert_equal(['Xfile1', 1, 9, 'one two three'],
        \ [bufname(l[0].bufnr), l[0].lnum, l[0].col, l[0].text])
  call assert_equal(['Xfile2', 2, 1, 'three one two'],
        \ [bufname(l[1].bufnr), l[1].lnum, l[1].col, l[1].text])

  Xvimgrep /the/f Xfile*
  let l = g:Xgetlist()
  call assert_equal(3, len(l))
  call assert_equal(['Xfile1', 1, 9, 'one two three'],
        \ [bufname(l[0].bufnr), l[0].lnum, l[0].col, l[0].text])
  call assert_equal(['Xfile2', 2, 1, 'three one two'],
        \ [bufname(l[1].bufnr), l[1].lnum, l[1].col, l[1].text])
  call assert_equal(['Xfile2', 4, 4, 'aaathreeaaa'],
        \ [bufname(l[2].bufnr), l[2].lnum, l[2].col, l[2].text])

  Xvimgrep /aaa/fg Xfile*
  let l = g:Xgetlist()
  call assert_equal(4, len(l))
  call assert_equal(['Xfile1', 2, 1, 'aaaaaa'],
        \ [bufname(l[0].bufnr), l[0].lnum, l[0].col, l[0].text])
  call assert_equal(['Xfile1', 2, 4, 'aaaaaa'],
        \ [bufname(l[1].bufnr), l[1].lnum, l[1].col, l[1].text])
  call assert_equal(['Xfile2', 4, 1, 'aaathreeaaa'],
        \ [bufname(l[2].bufnr), l[2].lnum, l[2].col, l[2].text])
  call assert_equal(['Xfile2', 4, 9, 'aaathreeaaa'],
        \ [bufname(l[3].bufnr), l[3].lnum, l[3].col, l[3].text])

  call assert_fails('Xvimgrep /xyz/fg Xfile*', 'E480:')
endfunc

func Test_vimgrep_fuzzy_match()
  call writefile(['one two three', 'aaaaaa'], 'Xfile1')
  call writefile(['one', 'three one two', 'two', 'aaathreeaaa'], 'Xfile2')
  call Xvimgrep_fuzzy_match('c')
  call Xvimgrep_fuzzy_match('l')
  call delete('Xfile1')
  call delete('Xfile2')
endfunc

func Test_locationlist_open_in_newtab()
  call s:create_test_file('Xqftestfile1')
  call s:create_test_file('Xqftestfile2')
  call s:create_test_file('Xqftestfile3')

  %bwipe!

  let lines =<< trim END
    Xqftestfile1:5:Line5
    Xqftestfile2:10:Line10
    Xqftestfile3:16:Line16
  END
  lgetexpr lines

  silent! llast
  call assert_equal(1, tabpagenr('$'))
  call assert_equal('Xqftestfile3', bufname())

  set switchbuf=newtab

  silent! lfirst
  call assert_equal(2, tabpagenr('$'))
  call assert_equal('Xqftestfile1', bufname())

  silent! lnext
  call assert_equal(3, tabpagenr('$'))
  call assert_equal('Xqftestfile2', bufname())

  call delete('Xqftestfile1')
  call delete('Xqftestfile2')
  call delete('Xqftestfile3')
  set switchbuf&vim

  %bwipe!
endfunc

" Test for win_gettype() in quickfix and location list windows
func Test_win_gettype()
  copen
  call assert_equal("quickfix", win_gettype())
  let wid = win_getid()
  wincmd p
  call assert_equal("quickfix", win_gettype(wid))
  cclose
  lexpr ''
  lopen
  call assert_equal("loclist", win_gettype())
  let wid = win_getid()
  wincmd p
  call assert_equal("loclist", win_gettype(wid))
  lclose
endfunc

fun Test_vimgrep_nomatch()
  call XexprTests('c')
  call g:Xsetlist([{'lnum':10,'text':'Line1'}])
  copen
  if has("win32")
    call assert_fails('vimgrep foo *.zzz', 'E479:')
    let expected = [{'lnum': 10, 'bufnr': 0, 'end_lnum': 0, 'pattern': '', 'valid': 0, 'vcol': 0, 'nr': 0, 'module': '', 'type': '', 'end_col': 0, 'col': 0, 'text': 'Line1'}]
  else
    call assert_fails('vimgrep foo *.zzz', 'E480:')
    let expected = []
  endif
  call assert_equal(expected, getqflist())
  cclose
endfunc

" Test for opening the quickfix window in two tab pages and then closing one
" of the quickfix windows. This should not make the quickfix buffer unlisted.
" (github issue #9300).
func Test_two_qf_windows()
  cexpr "F1:1:line1"
  copen
  tabnew
  copen
  call assert_true(&buflisted)
  cclose
  tabfirst
  call assert_true(&buflisted)
  let bnum = bufnr()
  cclose
  " if all the quickfix windows are closed, then buffer should be unlisted.
  call assert_false(buflisted(bnum))
  %bw!

  " Repeat the test for a location list
  lexpr "F2:2:line2"
  lopen
  let bnum = bufnr()
  tabnew
  exe "buffer" bnum
  tabfirst
  lclose
  tablast
  call assert_true(buflisted(bnum))
  tabclose
  lopen
  call assert_true(buflisted(bnum))
  lclose
  call assert_false(buflisted(bnum))
  %bw!
endfunc

" Weird sequence of commands that caused entering a wiped-out buffer
func Test_lopen_bwipe()
  func R()
    silent! tab lopen
    e x
    silent! lfile
  endfunc

  cal R()
  cal R()
  cal R()
  bw!
  delfunc R
endfunc

" Another sequence of commands that caused all buffers to be wiped out
func Test_lopen_bwipe_all()
  let lines =<< trim END
    func R()
      silent! tab lopen
      e foo
      silent! lfile
    endfunc
    cal R()
    exe "norm \<C-W>\<C-V>0"
    cal R()
    bwipe

    call writefile(['done'], 'Xresult')
    qall!
  END
  call writefile(lines, 'Xscript')
  if RunVim([], [], '-u NONE -n -X -Z -e -m -s -S Xscript')
    call assert_equal(['done'], readfile('Xresult'))
  endif

  call delete('Xscript')
  call delete('Xresult')
endfunc

" Test for calling setqflist() function recursively
func Test_recursive_setqflist()
  augroup QF_Test
    au!
    autocmd BufWinEnter quickfix call setqflist([], 'r')
  augroup END

  copen
  call assert_fails("call setqflist([], 'a')", 'E952:')

  augroup QF_Test
    au!
  augroup END
  %bw!
endfunc

" Test for failure to create a new window when selecting a file from the
" quickfix window
func Test_cwindow_newwin_fails()
  cgetexpr ["Xfile1:10:L10", "Xfile1:20:L20"]
  cwindow
  only
  let qf_wid = win_getid()
  " create the maximum number of scratch windows
  let hor_win_count = (&lines - 1)/2
  let hor_split_count = hor_win_count - 1
  for s in range(1, hor_split_count) | new | set buftype=nofile | endfor
  call win_gotoid(qf_wid)
  call assert_fails('exe "normal \<CR>"', 'E36:')
  %bw!
endfunc

" Test for updating the location list when only the location list window is
" present and the corresponding file window is closed.
func Test_loclist_update_with_llwin_only()
  %bw!
  new
  wincmd w
  lexpr ["Xfile1:1:Line1"]
  lopen
  wincmd p
  close
  call setloclist(2, [], 'r', {'lines': ["Xtest2:2:Line2"]})
  call assert_equal(['Xtest2|2| Line2'], getbufline(winbufnr(2), 1, '$'))
  %bw!
endfunc

" Test for getting the quickfix list after a buffer with an error is wiped out
func Test_getqflist_wiped_out_buffer()
  %bw!
  cexpr ["Xtest1:34:Wiped out"]
  let bnum = bufnr('Xtest1')
  call assert_equal(bnum, getqflist()[0].bufnr)
  bw Xtest1
  call assert_equal(0, getqflist()[0].bufnr)
  %bw!
endfunc

" Test for the status message that is displayed when opening a new quickfix
" list
func Test_qflist_statusmsg()
  cexpr "1\n2"
  cexpr "1\n2\n3\ntest_quickfix.vim:1:msg"
  call assert_equal('(4 of 4): msg', v:statusmsg)
  call setqflist([], 'f')
  %bw!

  " When creating a new quickfix list, if an autocmd changes the quickfix list
  " in the stack, then an error message should be displayed.
  augroup QF_Test
    au!
    au BufEnter test_quickfix.vim colder
  augroup END
  cexpr "1\n2"
  call assert_fails('cexpr "1\n2\n3\ntest_quickfix.vim:1:msg"', 'E925:')
  call setqflist([], 'f')
  augroup QF_Test
    au!
  augroup END
  %bw!

  augroup QF_Test
    au!
    au BufEnter test_quickfix.vim caddexpr "4"
  augroup END
  call assert_fails('cexpr "1\n2\n3\ntest_quickfix.vim:1:msg"', 'E925:')
  call setqflist([], 'f')
  augroup QF_Test
    au!
  augroup END
  %bw!
endfunc

func Test_quickfixtextfunc_recursive()
  func s:QFTfunc(o)
    cgete '0'
  endfunc
  copen
  let &quickfixtextfunc = 's:QFTfunc'
  cex ""

  let &quickfixtextfunc = ''
  cclose
endfunc

" Test for replacing the location list from an autocmd. This used to cause a
" read from freed memory.
func Test_loclist_replace_autocmd()
  %bw!
  call setloclist(0, [], 'f')
  let s:bufnr = bufnr()
  cal setloclist(0, [{'0': 0, '': ''}])
  au BufEnter * cal setloclist(1, [{'t': ''}, {'bufnr': s:bufnr}], 'r')
  lopen
  try
    exe "norm j\<CR>"
  catch
  endtry
  lnext
  %bw!
  call setloclist(0, [], 'f')
endfunc

" Test for a very long error line and a very long information line
func Test_very_long_error_line()
  let msg = repeat('abcdefghijklmn', 146)
  let emsg = 'Xlonglines.c:1:' . msg
  call writefile([msg, emsg], 'Xerror', 'D')
  cfile Xerror
  cwindow
  call assert_equal($'|| {msg}', getline(1))
  call assert_equal($'Xlonglines.c|1| {msg}', getline(2))
  cclose

  let l = execute('clist!')->split("\n")
  call assert_equal([$' 1: {msg}', $' 2 Xlonglines.c:1: {msg}'], l)

  let l = execute('cc')->split("\n")
  call assert_equal([$'(2 of 2): {msg}'], l)

  call setqflist([], 'f')
endfunc

" In the quickfix window, spaces at the beginning of an informational line
" should not be removed but should be removed from an error line.
func Test_info_line_with_space()
  cexpr ["a.c:20:12:         error: expected ';' before ':' token",
        \ '   20 |     Afunc():', '', '      |            ^']
  copen
  call assert_equal(["a.c|20 col 12| error: expected ';' before ':' token",
        \ '||    20 |     Afunc():', '|| ',
        \ '||       |            ^'], getline(1, '$'))
  cclose

  let l = execute('clist!')->split("\n")
  call assert_equal([" 1 a.c:20 col 12: error: expected ';' before ':' token",
        \ ' 2:    20 |     Afunc():', ' 3:  ', ' 4:       |            ^'], l)

  call setqflist([], 'f')
endfunc

func s:QfTf(_)
endfunc

func Test_setqflist_cb_arg()
  " This was changing the callback name in the dictionary.
  let d = #{quickfixtextfunc: 's:QfTf'}
  call setqflist([], 'a', d)
  call assert_equal('s:QfTf', d.quickfixtextfunc)

  call setqflist([], 'f')
endfunc

" Test that setqflist() should not prevent :stopinsert from working
func Test_setqflist_stopinsert()
  new
  call setqflist([], 'f')
  copen
  cclose
  func StopInsert()
    stopinsert
    call setqflist([{'text': 'foo'}])
    return ''
  endfunc

  call setline(1, 'abc')
  call cursor(1, 1)
  call feedkeys("i\<C-R>=StopInsert()\<CR>$", 'tnix')
  call assert_equal('foo', getqflist()[0].text)
  call assert_equal([0, 1, 3, 0, v:maxcol], getcurpos())
  call assert_equal(['abc'], getline(1, '$'))

  delfunc StopInsert
  call setqflist([], 'f')
  bwipe!
endfunc

func Test_quickfix_buffer_contents()
  call setqflist([{'filename':'filename', 'pattern':'pattern', 'text':'text'}])
  copen
  call assert_equal(['filename|pattern| text'], getline(1, '$'))  " The assert failed with Vim v9.0.0736; '| text' did not appear after the pattern.
  call setqflist([], 'f')
endfunc

func XquickfixUpdateTests(cchar)
  call s:setup_commands(a:cchar)

  " Setup: populate a couple buffers
  new
  call setline(1, range(1, 5))
  let b1 = bufnr()
  new
  call setline(1, range(1, 3))
  let b2 = bufnr()
  " Setup: set a quickfix list.
  let items = [{'bufnr': b1, 'lnum': 1}, {'bufnr': b1, 'lnum': 2}, {'bufnr': b2, 'lnum': 1}, {'bufnr': b2, 'lnum': 2}]
  call g:Xsetlist(items)

  " Open the quickfix list, select the third entry.
  Xopen
  exe "normal jj\<CR>"
  call assert_equal(3, g:Xgetlist({'idx' : 0}).idx)

  " Update the quickfix list. Make sure the third entry is still selected.
  call g:Xsetlist([], 'u', { 'items': items })
  call assert_equal(3, g:Xgetlist({'idx' : 0}).idx)

  " Update the quickfix list again, but this time with missing line number
  " information. Confirm that we keep the current buffer selected.
  call g:Xsetlist([{'bufnr': b1}, {'bufnr': b2}], 'u')
  call assert_equal(2, g:Xgetlist({'idx' : 0}).idx)

  Xclose

  " Cleanup the buffers we allocated during this test.
  %bwipe!
endfunc

" Test for updating a quickfix list using the "u" flag in setqflist()
func Test_quickfix_update()
  call XquickfixUpdateTests('c')
  call XquickfixUpdateTests('l')
endfunc

func Test_quickfix_update_with_missing_coordinate_info()
  new
  call setline(1, range(1, 5))
  let b1 = bufnr()

  new
  call setline(1, range(1, 3))
  let b2 = bufnr()

  new
  call setline(1, range(1, 2))
  let b3 = bufnr()

  " Setup: set a quickfix list with no coordinate information at all.
  call setqflist([{}, {}])

  " Open the quickfix list, select the second entry.
  copen
  exe "normal j\<CR>"
  call assert_equal(2, getqflist({'idx' : 0}).idx)

  " Update the quickfix list. As the previously selected entry has no
  " coordinate information, we expect the first entry to now be selected.
  call setqflist([{'bufnr': b1}, {'bufnr': b2}, {'bufnr': b3}], 'u')
  call assert_equal(1, getqflist({'idx' : 0}).idx)

  " Select the second entry in the quickfix list.
  copen
  exe "normal j\<CR>"
  call assert_equal(2, getqflist({'idx' : 0}).idx)

  " Update the quickfix list again. The currently selected entry does not have
  " a line number, but we should keep the file selected.
  call setqflist([{'bufnr': b1}, {'bufnr': b2, 'lnum': 3}, {'bufnr': b3}], 'u')
  call assert_equal(2, getqflist({'idx' : 0}).idx)

  " Update the quickfix list again. The currently selected entry (bufnr=b2, lnum=3)
  " is no longer present. We should pick the nearest entry.
  call setqflist([{'bufnr': b1}, {'bufnr': b2, 'lnum': 1}, {'bufnr': b2, 'lnum': 4}], 'u')
  call assert_equal(3, getqflist({'idx' : 0}).idx)

  " Set the quickfix list again, with a specific column number. The currently selected entry doesn't have a
  " column number, but they share a line number.
  call setqflist([{'bufnr': b1}, {'bufnr': b2, 'lnum': 4, 'col': 5}, {'bufnr': b2, 'lnum': 4, 'col': 6}], 'u')
  call assert_equal(2, getqflist({'idx' : 0}).idx)

  " Set the quickfix list again. The currently selected column number (6) is
  " no longer present. We should select the nearest column number.
  call setqflist([{'bufnr': b1}, {'bufnr': b2, 'lnum': 4, 'col': 2}, {'bufnr': b2, 'lnum': 4, 'col': 4}], 'u')
  call assert_equal(3, getqflist({'idx' : 0}).idx)

  " Now set the quickfix list, but without columns. We should still pick the
  " same line.
  call setqflist([{'bufnr': b2, 'lnum': 3}, {'bufnr': b2, 'lnum': 4}, {'bufnr': b2, 'lnum': 4}], 'u')
  call assert_equal(2, getqflist({'idx' : 0}).idx)

  " Cleanup the buffers we allocated during this test.
  %bwipe!
endfunc

" Test for "%b" in "errorformat"
func Test_efm_format_b()
  call setqflist([], 'f')
  new
  call setline(1, ['1: abc', '1: def', '1: ghi'])
  let b1 = bufnr()
  new
  call setline(1, ['2: abc', '2: def', '2: ghi'])
  let b2 = bufnr()
  new
  call setline(1, ['3: abc', '3: def', '3: ghi'])
  let b3 = bufnr()
  new
  let lines =<< trim eval END
    {b1}:1:1
    {b2}:2:2
    {b3}:3:3
  END
  call setqflist([], ' ', #{lines: lines, efm: '%b:%l:%c'})
  cfirst
  call assert_equal([b1, 1, 1], [bufnr(), line('.'), col('.')])
  cnext
  call assert_equal([b2, 2, 2], [bufnr(), line('.'), col('.')])
  cnext
  call assert_equal([b3, 3, 3], [bufnr(), line('.'), col('.')])
  enew!

  " Use a non-existing buffer
  let lines =<< trim eval END
    9991:1:1:m1
    9992:2:2:m2
    {b3}:3:3:m3
  END
  call setqflist([], ' ', #{lines: lines, efm: '%b:%l:%c:%m'})
  cfirst | cnext
  call assert_equal([b3, 3, 3], [bufnr(), line('.'), col('.')])
  " Lines with non-existing buffer numbers should be used as non-error lines
  call assert_equal([
    \ #{lnum: 0, bufnr: 0, end_lnum: 0, pattern: '', valid: 0, vcol: 0, nr: -1,
    \   module: '', type: '', end_col: 0, col: 0, text: '9991:1:1:m1'},
    \ #{lnum: 0, bufnr: 0, end_lnum: 0, pattern: '', valid: 0, vcol: 0, nr: -1,
    \   module: '', type: '', end_col: 0, col: 0, text: '9992:2:2:m2'},
    \ #{lnum: 3, bufnr: b3, end_lnum: 0, pattern: '', valid: 1, vcol: 0,
    \   nr: -1, module: '', type: '', end_col: 0, col: 3, text: 'm3'}],
    \ getqflist())
  %bw!
  call setqflist([], 'f')
endfunc

func XbufferTests_range(cchar)
  call s:setup_commands(a:cchar)

  enew!
  let lines =<< trim END
    Xtestfile7:700:10:Line 700
    Xtestfile8:800:15:Line 800
  END
  silent! call setline(1, lines)
  norm! Vy
  " Note: We cannot use :Xbuffer here,
  " it doesn't properly fail, so we need to
  " test using the raw c/l commands.
  " (also further down)
  if (a:cchar == 'c')
     exe "'<,'>cbuffer!"
  else
    exe "'<,'>lbuffer!"
  endif
  let l = g:Xgetlist()
  call assert_true(len(l) == 1 &&
	\ l[0].lnum == 700 && l[0].col == 10 && l[0].text ==# 'Line 700')

  enew!
  let lines =<< trim END
    Xtestfile9:900:55:Line 900
    Xtestfile10:950:66:Line 950
  END
  silent! call setline(1, lines)
  if (a:cchar == 'c')
    1cgetbuffer
  else
    1lgetbuffer
  endif
  let l = g:Xgetlist()
  call assert_true(len(l) == 1 &&
	\ l[0].lnum == 900 && l[0].col == 55 && l[0].text ==# 'Line 900')

  enew!
  let lines =<< trim END
    Xtestfile11:700:20:Line 700
    Xtestfile12:750:25:Line 750
  END
  silent! call setline(1, lines)
  if (a:cchar == 'c')
    1,1caddbuffer
  else
    1,1laddbuffer
  endif
  let l = g:Xgetlist()
  call assert_true(len(l) == 2 &&
	\ l[0].lnum == 900 && l[0].col == 55 && l[0].text ==# 'Line 900' &&
	\ l[1].lnum == 700 && l[1].col == 20 && l[1].text ==# 'Line 700')
  enew!

  " Check for invalid range
  " Using Xbuffer will not run the range check in the cbuffer/lbuffer
  " commands. So directly call the commands.
  if (a:cchar == 'c')
      call assert_fails('900,999caddbuffer', 'E16:')
  else
      call assert_fails('900,999laddbuffer', 'E16:')
  endif
endfunc

func Test_cbuffer_range()
  call XbufferTests_range('c')
  call XbufferTests_range('l')
endfunc

" Test for displaying fname passed from setqflist() when the names include
" hard links to prevent seemingly duplicate entries.
func Xtest_hardlink_fname(cchar)
  call s:setup_commands(a:cchar)
  %bwipe
  " Create a sample source file
  let lines =<< trim END
    void sample() {}
    int main() { sample(); return 0; }
  END
  call writefile(lines, 'test_qf_hardlink1.c', 'D')
  defer delete('test_qf_hardlink1.c')
  defer delete('test_qf_hardlink2.c')
  call system('ln test_qf_hardlink1.c test_qf_hardlink2.c')
  if v:shell_error
    throw 'Skipped: ln throws error on this platform'
  endif
  call g:Xsetlist([], 'f')
  " Make a qflist that contains the file and it's hard link
  " like how LSP plugins set response into qflist
  call g:Xsetlist([{'filename' : 'test_qf_hardlink1.c', 'lnum' : 1},
        \ {'filename' : 'test_qf_hardlink2.c', 'lnum' : 1}], ' ')
  Xopen
  " Ensure that two entries are displayed with different name
  " so that they aren't seen as duplication.
  call assert_equal(['test_qf_hardlink1.c|1| ',
        \ 'test_qf_hardlink2.c|1| '], getline(1, '$'))
  Xclose
endfunc

func Test_hardlink_fname()
  CheckUnix
  CheckExecutable ln
  call Xtest_hardlink_fname('c')
  call Xtest_hardlink_fname('l')
endfunc

" Test for checking if correct number of tests are deleted
" and current list stays the same after setting Xhistory
" to a smaller number. Do roughly the same for growing the stack.
func Xtest_resize_list_stack(cchar)
  call s:setup_commands(a:cchar)
  Xsethist 100

  for i in range(1, 100)
    Xexpr string(i)
  endfor
  Xopen
  call assert_equal(g:Xgetlist({'nr': '$'}).nr, 100)
  call assert_equal("|| 100", getline(1))
  Xsethist 8
  call assert_equal("|| 100", getline(1))
  Xolder 5
  call assert_equal("|| 95", getline(1))
  Xsethist 6
  call assert_equal("|| 95", getline(1))
  Xsethist 1
  call assert_equal("|| 100", getline(1))

  " grow array again
  Xsethist 100
  for i in range(1, 99)
    Xexpr string(i)
  endfor
  call assert_equal("|| 99", getline(1))
  Xolder 99
  call assert_equal("|| 100", getline(1))

  Xsethistdefault
endfunc

func Test_resize_list_stack()
  call Xtest_resize_list_stack('c')
  call Xtest_resize_list_stack('l')
endfunc

" Test to check if order of lists is from
" oldest at the bottom to newest at the top
func Xtest_Xhistory_check_order(cchar)

  Xsethist 100

  for i in range(1, 100)
    Xexpr string(i)
  endfor

  Xopen
  for i in range(100, 1, -1)
    let l:ret = assert_equal("|| " .. i, getline(1))

    if ret == 1 || i == 1
      break
    endif
    Xolder
  endfor

  for i in range(1, 50)
    Xexpr string(i)
  endfor

  for i in range(50, 1, -1)
    let l:ret = assert_equal("|| " .. i, getline(1))

    if ret == 1 || i == 50
      break
    endif
    Xolder
  endfor

  for i in range(50, 1, -1)
    let l:ret = assert_equal("|| " .. i, getline(1))

    if ret == 1 || i == 50
      break
    endif
    Xolder
  endfor

  Xsethistdefault
endfunc

func Test_set_history_to_check_order()
  call Xtest_Xhistory_check_order('c')
  call Xtest_Xhistory_check_order('l')
endfunc

" Check if 'lhistory' is the same between the location list window
" and associated normal window
func Test_win_and_loc_synced()
  new
  set lhistory=2
  lexpr "Text"
  lopen

  " check if lhistory is synced when modified inside the
  " location list window
  setlocal lhistory=1
  wincmd k
  call assert_equal(&lhistory, 1)

  " check if lhistory is synced when modified inside the
  " normal window
  setlocal lhistory=10
  lopen
  call assert_equal(&lhistory, 10)

  wincmd k
  lclose
  wincmd q

  set lhistory&
endfunc

" Test if setting the lhistory of one window doesn't affect the other
func Test_two_win_are_independent_of_history()
  setlocal lhistory=10
  new
  setlocal lhistory=20
  wincmd  w
  call assert_equal(&lhistory, 10)
  wincmd w
  wincmd q

  set lhistory&
endfunc

" Test if lhistory is copied over to a new window
func Test_lhistory_copied_over()
  setlocal lhistory=3
  split
  call assert_equal(&lhistory, 3)
  wincmd q

  set lhistory&
endfunc

" Test if error occurs when given invalid history number
func Xtest_invalid_history_num(cchar)
  call s:setup_commands(a:cchar)

  call assert_fails('Xsethist -10000', "E1542:")
  call assert_fails('Xsethist 10000', "E1543:")
  Xsethistdefault
endfunc

func Test_invalid_history_num()
  call Xtest_invalid_history_num('c')
  call Xtest_invalid_history_num('l')
endfunc

" Test if chistory and lhistory don't affect each other
func Test_chi_and_lhi_are_independent()
  set chistory=100
  set lhistory=100

  set chistory=10
  call assert_equal(&lhistory, 100)

  set lhistory=1
  call assert_equal(&chistory, 10)

  set chistory&
  set lhistory&
endfunc

func Test_quickfix_close_buffer_crash()
  new
  lexpr 'test' | lopen
  wincmd k
  lclose
  wincmd q
endfunc

func Test_vimgrep_dummy_buffer_crash()
  augroup DummyCrash
    autocmd!
    " Make the dummy buffer non-current, but still open in a window.
    autocmd BufReadCmd * ++once let s:dummy_buf = bufnr()
          \| split | wincmd p | enew

    " Autocmds from cleaning up the dummy buffer in this case should be blocked.
    autocmd BufWipeout *
          \ call assert_notequal(s:dummy_buf, str2nr(expand('<abuf>')))
  augroup END

  silent! vimgrep /./ .
  redraw! " Window to freed dummy buffer used to remain; heap UAF.
  call assert_equal([], win_findbuf(s:dummy_buf))
  call assert_equal(0, bufexists(s:dummy_buf))

  unlet! s:dummy_buf
  autocmd! DummyCrash
  %bw!
endfunc

func Test_vimgrep_dummy_buffer_keep()
  augroup DummyKeep
    autocmd!
    " Trigger a wipe of the dummy buffer by aborting script processing. Prevent
    " wiping it by splitting it from the autocmd window into an only window.
    autocmd BufReadCmd * ++once let s:dummy_buf = bufnr()
          \| tab split | call interrupt()
  augroup END

  call assert_fails('vimgrep /./ .')
  call assert_equal(1, bufexists(s:dummy_buf))
  " Ensure it's no longer considered a dummy; should be able to switch to it.
  execute s:dummy_buf 'sbuffer'

  unlet! s:dummy_buf
  autocmd! DummyKeep
  %bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
