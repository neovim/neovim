" Polish letters under VIM >= 6
" Maintainer:   HS6_06 <hs6_06@o2.pl>
" Last changed: 2005 Jan 12
" Current version: 1.0.2
" History:
"  2005.01.12 1.0.2 keymap_name shortened, added Current version, History
"  2005.01.10 1.0.1 un*x line ends for all files
"  2005.01.09 1.0.0 Initial release

let encoding = &enc
if encoding == 'latin1'
    if has("unix")
	let encoding = 'iso-8859-2'
    else
	let encoding = 'cp1250'
    endif
endif

if encoding == 'utf-8'
	source <sfile>:p:h/polish-slash_utf-8.vim
elseif encoding == 'cp1250'
	source <sfile>:p:h/polish-slash_cp1250.vim
elseif encoding == 'iso-8859-2'
	source <sfile>:p:h/polish-slash_iso-8859-2.vim
else
	source <sfile>:p:h/polish-slash_cp852.vim
endif
