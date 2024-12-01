" Vim filetype plugin file
" Language:    Typst
" Maintainer:  Gregory Anders
" Last Change: 2024 Dev 01
" Based on:    https://github.com/kaarmu/typst.vim

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=//\ %s
setlocal comments=s1:/*,mb:*,ex:*/,://
setlocal formatoptions+=croqn
setlocal formatlistpat=^\\s*\\d\\+[\\]:.)}\\t\ ]\\s*
setlocal formatlistpat+=\\\|^\\s*[-+\]\\s\\+
setlocal suffixesadd=.typ

let b:undo_ftplugin = 'setl cms< com< fo< flp< sua<'

if get(g:, 'typst_conceal', 0)
  setlocal conceallevel=2
  let b:undo_ftplugin .= ' cole<'
endif

if has("folding") && get(g:, 'typst_folding', 0)
    setlocal foldexpr=typst#foldexpr()
    setlocal foldmethod=expr
    let b:undo_ftplugin .= "|setl foldexpr< foldmethod<"
endif

if !exists('current_compiler')
  compiler typst
  let b:undo_ftplugin ..= "| compiler make"
endif
