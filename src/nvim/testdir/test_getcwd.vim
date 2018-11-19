function! GetCwdInfo(win, tab)
 	let tab_changed = 0
 	let mod = ":t"
 	if a:tab > 0 && a:tab != tabpagenr()
   	let tab_changed = 1
   	exec "tabnext " . a:tab
 	endif
 	let bufname = fnamemodify(bufname(winbufnr(a:win)), mod)
 	if tab_changed
   	tabprevious
 	endif
 	if a:win == 0 && a:tab == 0
   	let dirname = fnamemodify(getcwd(), mod)
   	let lflag = haslocaldir()
 	elseif a:tab == 0
   	let dirname = fnamemodify(getcwd(a:win), mod)
   	let lflag = haslocaldir(a:win)
 	else
   	let dirname = fnamemodify(getcwd(a:win, a:tab), mod)
   	let lflag = haslocaldir(a:win, a:tab)
 	endif
 	return bufname . ' ' . dirname . ' ' . lflag
endfunction

" Do all test in a separate window to avoid E211 when we recursively
" delete the Xtopdir directory during cleanup
function SetUp()
	set visualbell
	set nocp viminfo+=nviminfo

	" On windows a swapfile in Xtopdir prevents it from being cleaned up.
	set noswapfile

	" On windows a stale "Xtopdir" directory may exist, remove it so that
	" we start from a clean state.
	call delete("Xtopdir", "rf")
	new
	call mkdir('Xtopdir')
	cd Xtopdir
	let g:topdir = getcwd()
	call mkdir('Xdir1')
	call mkdir('Xdir2')
	call mkdir('Xdir3')
endfunction

let g:cwd=getcwd()
function TearDown()
	q
	exec "cd " . g:cwd
	call delete("Xtopdir", "rf")
endfunction

function Test_GetCwd()
	new a
	new b
	new c
	3wincmd w
	lcd Xdir1
	call assert_equal("a Xdir1 1", GetCwdInfo(0, 0))
	call assert_equal(g:topdir, getcwd(-1))
	wincmd W
	call assert_equal("b Xtopdir 0", GetCwdInfo(0, 0))
	call assert_equal(g:topdir, getcwd(-1))
	wincmd W
	lcd Xdir3
	call assert_equal("c Xdir3 1", GetCwdInfo(0, 0))
	call assert_equal("a Xdir1 1", GetCwdInfo(bufwinnr("a"), 0))
	call assert_equal("b Xtopdir 0", GetCwdInfo(bufwinnr("b"), 0))
	call assert_equal("c Xdir3 1", GetCwdInfo(bufwinnr("c"), 0))
	call assert_equal(g:topdir, getcwd(-1))
	wincmd W
	call assert_equal("a Xdir1 1", GetCwdInfo(bufwinnr("a"), tabpagenr()))
	call assert_equal("b Xtopdir 0", GetCwdInfo(bufwinnr("b"), tabpagenr()))
	call assert_equal("c Xdir3 1", GetCwdInfo(bufwinnr("c"), tabpagenr()))
	call assert_equal(g:topdir, getcwd(-1))

	tabnew x
	new y
	new z
	3wincmd w
	call assert_equal("x Xtopdir 0", GetCwdInfo(0, 0))
	call assert_equal(g:topdir, getcwd(-1))
	wincmd W
	lcd Xdir2
	call assert_equal("y Xdir2 1", GetCwdInfo(0, 0))
	call assert_equal(g:topdir, getcwd(-1))
	wincmd W
	lcd Xdir3
	call assert_equal("z Xdir3 1", GetCwdInfo(0, 0))
	call assert_equal("x Xtopdir 0", GetCwdInfo(bufwinnr("x"), 0))
	call assert_equal("y Xdir2 1", GetCwdInfo(bufwinnr("y"), 0))
	call assert_equal("z Xdir3 1", GetCwdInfo(bufwinnr("z"), 0))
	call assert_equal(g:topdir, getcwd(-1))
	let tp_nr = tabpagenr()
	tabrewind
	call assert_equal("x Xtopdir 0", GetCwdInfo(3, tp_nr))
	call assert_equal("y Xdir2 1", GetCwdInfo(2, tp_nr))
	call assert_equal("z Xdir3 1", GetCwdInfo(1, tp_nr))
	call assert_equal(g:topdir, getcwd(-1))
endfunc

function Test_GetCwd_lcd_shellslash()
	new
	let root = fnamemodify('/', ':p')
	exe 'lcd '.root
	let cwd = getcwd()
	if !exists('+shellslash') || &shellslash
		call assert_equal(cwd[-1:], '/')
	else
		call assert_equal(cwd[-1:], '\')
	endif
endfunc
