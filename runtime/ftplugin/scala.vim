" Vim filetype plugin file
" Language:             Scala
" Maintainer:           Derek Wyatt
" URL:                  https://github.com/derekwyatt/vim-scala
" License:              Same as Vim
" Last Change:          11 August 2021
"                       2023 Aug 28 by Vim Project (undo_ftplugin)
" ----------------------------------------------------------------------------

if exists('b:did_ftplugin') || &cp
  finish
endif
let b:did_ftplugin = 1

" j is fairly new in Vim, so don't complain if it's not there
setlocal formatoptions-=t formatoptions+=croqnl
silent! setlocal formatoptions+=j

" Just like c.vim, but additionally doesn't wrap text onto /** line when
" formatting. Doesn't bungle bulleted lists when formatting.
if get(g:, 'scala_scaladoc_indent', 0)
  setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s2:/**,mb:*,ex:*/,s1:/*,mb:*,ex:*/,://
else
  setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/**,mb:*,ex:*/,s1:/*,mb:*,ex:*/,://
endif
setlocal commentstring=//\ %s

setlocal shiftwidth=2 softtabstop=2 expandtab

setlocal include=^\\s*import
setlocal includeexpr=substitute(v:fname,'\\.','/','g')

setlocal path+=src/main/scala,src/test/scala
setlocal suffixesadd=.scala

let b:undo_ftplugin = "setlocal cms< com< et< fo< inc< inex< pa< sts< sua< sw<"

" vim:set sw=2 sts=2 ts=8 et:
