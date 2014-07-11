" Vim filetype plugin file
" Language:	csc
" Maintainer:	Dan Sharp <dwsharp at users dot sourceforge dot net>
" Last Changed: 20 Jan 2009
" URL:		http://dwsharp.users.sourceforge.net/vim/ftplugin

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

if exists("loaded_matchit")
    let b:match_words=
	\ '\<fix\>:\<endfix\>,' .
	\ '\<if\>:\<else\%(if\)\=\>:\<endif\>,' .
	\ '\<!loopondimensions\>\|\<!looponselected\>:\<!endloop\>'
endif

" Undo the stuff we changed.
let b:undo_ftplugin = "unlet! b:match_words"

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo
