" scdoc filetype plugin
" Maintainer: Gregory Anders <greg@gpanders.com>
" Last Updated: 2021-08-04

" Only do this when not done yet for this buffer
if exists('b:did_ftplugin')
    finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

setlocal comments=b:;
setlocal commentstring=;%s
setlocal formatoptions+=t
setlocal noexpandtab
setlocal shiftwidth=0
setlocal softtabstop=0
setlocal textwidth=80

let b:undo_ftplugin = 'setl com< cms< fo< et< sw< sts< tw<'

if has('conceal')
    setlocal conceallevel=2
    let b:undo_ftplugin .= ' cole<'
endif
