let s:encoding = &enc
if s:encoding == 'latin1'
    if has("unix")
	let s:encoding = 'iso-8859-2'
    else
	let s:encoding = 'cp1250'
    endif
endif

if s:encoding == 'utf-8'
	source <sfile>:p:h/croatian_utf-8.vim
elseif s:encoding == 'cp1250'
	source <sfile>:p:h/croatian_cp1250.vim
else
	source <sfile>:p:h/croatian_iso-8859-2.vim
endif
