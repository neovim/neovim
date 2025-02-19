let encoding = &enc
if encoding == 'latin1'
    if has("unix")
	let encoding = 'iso-8859-8'
    else
	let encoding = 'cp1255'
    endif
endif

if encoding == 'utf-8'
	source <sfile>:p:h/hebrewp_utf-8.vim
elseif encoding == 'cp1255'
	source <sfile>:p:h/hebrewp_cp1255.vim
else
	source <sfile>:p:h/hebrewp_iso-8859-8.vim
endif
