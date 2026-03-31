let encoding = &enc
if encoding == 'latin1'
    if has("unix")
	let encoding = 'iso-8859-2'
    else
	let encoding = 'cp1250'
    endif
endif

if encoding == 'utf-8'
	source <sfile>:p:h/serbian_utf-8.vim
elseif encoding == 'cp1250'
	source <sfile>:p:h/serbian_cp1250.vim
elseif encoding == 'cp1251'
	source <sfile>:p:h/serbian_cp1251.vim
elseif encoding == 'iso-8859-2'
	source <sfile>:p:h/serbian_iso-8859-2.vim
else
	source <sfile>:p:h/serbian_iso-8859-5.vim
endif
