" Tests for the getbufinfo(), getwininfo() and gettabinfo() functions

function Test_getbufwintabinfo()
    1,$bwipeout
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

    only
    let w1_id = win_getid()
    new
    let w2_id = win_getid()
    tabnew | let w3_id = win_getid()
    new | let w4_id = win_getid()
    new | let w5_id = win_getid()
    tabfirst
    let winlist = getwininfo()
    call assert_equal(5, len(winlist))
    call assert_equal(2, winlist[3].tpnr)
    let winfo = getwininfo(w5_id)[0]
    call assert_equal(2, winfo.tpnr)
    call assert_equal([], getwininfo(3))

    let tablist = gettabinfo()
    call assert_equal(2, len(tablist))
    call assert_equal(3, len(tablist[1].windows))
    call assert_equal([], gettabinfo(3))

    tabonly | only
endfunction
