" Vim filetype plugin file
" Language:      Verbose TAP Output
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2021 Oct 22

" Only do this when not done yet for this buffer
if exists('b:did_ftplugin')
    finish
endif
let b:did_ftplugin = 1

setlocal foldtext=TAPTestLine_foldtext()
function! TAPTestLine_foldtext()
    let line = getline(v:foldstart)
    let sub = substitute(line, '/\*\|\*/\|{{{\d\=', '', 'g')
    return sub
endfunction

setlocal foldminlines=5
setlocal foldcolumn=2
setlocal foldenable
setlocal foldmethod=syntax

let b:undo_ftplugin = 'setlocal foldtext< foldminlines< foldcolumn< foldenable< foldmethod<'
