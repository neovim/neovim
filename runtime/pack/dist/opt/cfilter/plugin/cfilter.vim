" cfilter.vim: Plugin to filter entries from a quickfix/location list
" Last Change: 	May 12, 2018
" Maintainer: 	Yegappan Lakshmanan (yegappan AT yahoo DOT com)
" Version:	1.0
"
" Commands to filter the quickfix list:
"   :Cfilter[!] {pat}
"       Create a new quickfix list from entries matching {pat} in the current
"       quickfix list. Both the file name and the text of the entries are
"       matched against {pat}. If ! is supplied, then entries not matching
"       {pat} are used.
"   :Lfilter[!] {pat}
"       Same as :Cfilter but operates on the current location list.
"
if exists("loaded_cfilter")
    finish
endif
let loaded_cfilter = 1

func s:Qf_filter(qf, pat, bang)
    if a:qf
	let Xgetlist = function('getqflist')
	let Xsetlist = function('setqflist')
	let cmd = ':Cfilter' . a:bang
    else
	let Xgetlist = function('getloclist', [0])
	let Xsetlist = function('setloclist', [0])
	let cmd = ':Lfilter' . a:bang
    endif

    if a:bang == '!'
	let cond = 'v:val.text !~# a:pat && bufname(v:val.bufnr) !~# a:pat'
    else
	let cond = 'v:val.text =~# a:pat || bufname(v:val.bufnr) =~# a:pat'
    endif

    let items = filter(Xgetlist(), cond)
    let title = cmd . ' ' . a:pat
    call Xsetlist([], ' ', {'title' : title, 'items' : items})
endfunc

com! -nargs=+ -bang Cfilter call s:Qf_filter(1, <q-args>, <q-bang>)
com! -nargs=+ -bang Lfilter call s:Qf_filter(0, <q-args>, <q-bang>)
