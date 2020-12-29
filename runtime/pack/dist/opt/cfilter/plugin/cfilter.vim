" cfilter.vim: Plugin to filter entries from a quickfix/location list
" Last Change: Aug 23, 2018
" Maintainer: Yegappan Lakshmanan (yegappan AT yahoo DOT com)
" Version: 1.1
"
" Commands to filter the quickfix list:
"   :Cfilter[!] /{pat}/
"       Create a new quickfix list from entries matching {pat} in the current
"       quickfix list. Both the file name and the text of the entries are
"       matched against {pat}. If ! is supplied, then entries not matching
"       {pat} are used. The pattern can be optionally enclosed using one of
"       the following characters: ', ", /. If the pattern is empty, then the
"       last used search pattern is used.
"   :Lfilter[!] /{pat}/
"       Same as :Cfilter but operates on the current location list.
"
if exists("loaded_cfilter")
    finish
endif
let loaded_cfilter = 1

func s:Qf_filter(qf, searchpat, bang)
    if a:qf
	let Xgetlist = function('getqflist')
	let Xsetlist = function('setqflist')
	let cmd = ':Cfilter' . a:bang
    else
	let Xgetlist = function('getloclist', [0])
	let Xsetlist = function('setloclist', [0])
	let cmd = ':Lfilter' . a:bang
    endif

    let firstchar = a:searchpat[0]
    let lastchar = a:searchpat[-1:]
    if firstchar == lastchar &&
		\ (firstchar == '/' || firstchar == '"' || firstchar == "'")
	let pat = a:searchpat[1:-2]
	if pat == ''
	    " Use the last search pattern
	    let pat = @/
	endif
    else
	let pat = a:searchpat
    endif

    if pat == ''
	return
    endif

    if a:bang == '!'
	let cond = 'v:val.text !~# pat && bufname(v:val.bufnr) !~# pat'
    else
	let cond = 'v:val.text =~# pat || bufname(v:val.bufnr) =~# pat'
    endif

    let items = filter(Xgetlist(), cond)
    let title = cmd . ' /' . pat . '/'
    call Xsetlist([], ' ', {'title' : title, 'items' : items})
endfunc

com! -nargs=+ -bang Cfilter call s:Qf_filter(1, <q-args>, <q-bang>)
com! -nargs=+ -bang Lfilter call s:Qf_filter(0, <q-args>, <q-bang>)
