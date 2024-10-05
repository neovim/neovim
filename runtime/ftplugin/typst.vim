" Vim filetype plugin file
" Language:    Typst
" Maintainer:  Gregory Anders
" Last Change: 2024 Oct 04
" Based on:    https://github.com/kaarmu/typst.vim

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=//\ %s
setlocal comments=s1:/*,mb:*,ex:*/,://
setlocal formatoptions+=croq
setlocal suffixesadd=.typ

let b:undo_ftplugin = 'setl cms< com< fo< sua<'

if get(g:, 'typst_conceal', 0)
  setlocal conceallevel=2
  let b:undo_ftplugin .= ' cole<'
endif

if !exists('current_compiler')
  compiler typst
  let b:undo_ftplugin ..= "| compiler make"
endif
