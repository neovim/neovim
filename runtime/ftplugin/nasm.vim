" Vim filetype plugin
" Language:    NASM - The Netwide Assembler
" Maintainer:  Amelia Clarke <selene@perilune.dev>
" Last Change: 2026 Sep 15
" NASM Home:   https://nasm.us/

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:;
setlocal commentstring=;\ %s
let &l:define = '\v\c^\s*\%i?%(x?define|def%(alias|str|tok)|macro)>'
setlocal formatoptions-=t formatoptions+=croql
let &l:include = '\c^\s*%include\>'
setlocal iskeyword=@,48-57,#,$,.,?,@-@,_,~
let b:undo_ftplugin = 'setl cms< com< def< fo< inc< isk<'

" vim: et sts=2 sw=2 ts=8 tw=80
