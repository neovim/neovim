" Tests for the getbufinfo(), getwininfo() and gettabinfo() functions

function Test_getbufwintabinfo()
    edit Xtestfile1
    edit Xtestfile2
    let buflist = getbufinfo()
    call assert_equal(2, len(buflist))
    call assert_match('Xtestfile1', buflist[0].name)
    call assert_match('Xtestfile2', getbufinfo('Xtestfile2')[0].name)
    call assert_equal([], getbufinfo(2016))
    edit Xtestfile1
    hide edit Xtestfile2
    hide enew
    call assert_equal(3, len(getbufinfo({'bufloaded':1})))

    set tabstop&vim
    let b:editor = 'vim'
    let l = getbufinfo('%')
    call assert_equal(bufnr('%'), l[0].bufnr)
    call assert_equal('vim', l[0].variables.editor)
    call assert_notequal(-1, index(l[0].windows, bufwinid('%')))

    " Test for getbufinfo() with 'bufmodified'
    call assert_equal(0, len(getbufinfo({'bufmodified' : 1})))
    call setbufline('Xtestfile1', 1, ["Line1"])
    let l = getbufinfo({'bufmodified' : 1})
    call assert_equal(1, len(l))
    call assert_equal(bufnr('Xtestfile1'), l[0].bufnr)

    if has('signs')
	call append(0, ['Linux', 'Windows', 'Mac'])
	sign define Mark text=>> texthl=Search
	exe "sign place 2 line=3 name=Mark buffer=" . bufnr('%')
	let l = getbufinfo('%')
	call assert_equal(2, l[0].signs[0].id)
	call assert_equal(3, l[0].signs[0].lnum)
	call assert_equal('Mark', l[0].signs[0].name)
	sign unplace *
	sign undefine Mark
	enew!
    endif

    only
    let w1_id = win_getid()
    new
    let w2_id = win_getid()
    tabnew | let w3_id = win_getid()
    new | let w4_id = win_getid()
    vert new | let w5_id = win_getid()
    call setwinvar(0, 'signal', 'green')
    tabfirst
    let winlist = getwininfo()
    call assert_equal(5, len(winlist))
    call assert_equal(winwidth(1), winlist[0].width)
    call assert_equal(1, winlist[0].wincol)
    " tabline adds one row in terminal, not in GUI
    let tablineheight = winlist[0].winrow == 2 ? 1 : 0
    call assert_equal(tablineheight + 1, winlist[0].winrow)

    call assert_equal(winbufnr(2), winlist[1].bufnr)
    call assert_equal(winheight(2), winlist[1].height)
    call assert_equal(1, winlist[1].wincol)
    call assert_equal(tablineheight + winheight(1) + 2, winlist[1].winrow)

    call assert_equal(1, winlist[2].winnr)
    call assert_equal(tablineheight + 1, winlist[2].winrow)
    call assert_equal(1, winlist[2].wincol)

    call assert_equal(winlist[2].width + 2, winlist[3].wincol)
    call assert_equal(1, winlist[4].wincol)

    call assert_equal(1, winlist[0].tabnr)
    call assert_equal(1, winlist[1].tabnr)
    call assert_equal(2, winlist[2].tabnr)
    call assert_equal(2, winlist[3].tabnr)
    call assert_equal(2, winlist[4].tabnr)

    call assert_equal('green', winlist[2].variables.signal)
    call assert_equal(w4_id, winlist[3].winid)
    let winfo = getwininfo(w5_id)[0]
    call assert_equal(2, winfo.tabnr)
    call assert_equal([], getwininfo(3))

    call settabvar(1, 'space', 'build')
    let tablist = gettabinfo()
    call assert_equal(2, len(tablist))
    call assert_equal(3, len(tablist[1].windows))
    call assert_equal(2, tablist[1].tabnr)
    call assert_equal('build', tablist[0].variables.space)
    call assert_equal(w2_id, tablist[0].windows[0])
    call assert_equal([], gettabinfo(3))

    tabonly | only

    lexpr ''
    lopen
    copen
    let winlist = getwininfo()
    call assert_false(winlist[0].quickfix)
    call assert_false(winlist[0].loclist)
    call assert_true(winlist[1].quickfix)
    call assert_true(winlist[1].loclist)
    call assert_true(winlist[2].quickfix)
    call assert_false(winlist[2].loclist)
    wincmd t | only
endfunction

function Test_get_buf_options()
  let opts = getbufvar(bufnr('%'), '&')
  call assert_equal(v:t_dict, type(opts))
  call assert_equal(8, opts.tabstop)
endfunc

function Test_get_win_options()
  if has('folding')
    set foldlevel=999
  endif
  set list
  let opts = getwinvar(1, '&')
  call assert_equal(v:t_dict, type(opts))
  call assert_equal(0, opts.linebreak)
  call assert_equal(1, opts.list)
  if has('folding')
    call assert_equal(999, opts.foldlevel)
  endif
  if has('signs')
    call assert_equal('auto', opts.signcolumn)
  endif

  let opts = gettabwinvar(1, 1, '&')
  call assert_equal(v:t_dict, type(opts))
  call assert_equal(0, opts.linebreak)
  call assert_equal(1, opts.list)
  if has('signs')
    call assert_equal('auto', opts.signcolumn)
  endif
  set list&
  if has('folding')
    set foldlevel=0
  endif
endfunc
