let encoding = &enc
if encoding == ''
	let encoding = 'utf-8'
endif

if encoding == 'utf-8'
	source <sfile>:p:h/persian-iranian_utf-8.vim
endif
