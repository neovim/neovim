" Language:	abnf
" Maintainer:	A4-Tacks <wdsjxhno1001@163.com>
" Last Change:	2025-05-02
" Upstream:	https://github.com/A4-Tacks/abnf.vim

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = 'setlocal iskeyword< comments< commentstring<'

setlocal iskeyword=@,48-57,_,-,192-255
setlocal comments=:;;,:;
setlocal commentstring=;%s

" vim:ts=8
