" Vim filetype plugin
" Language:         KerML
" Author:           Daumantas Kavolis <daumantas.kavolis@sensmetry.com>
" Last Change:      2025-10-06

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Set 'comments' to format dashed and starred lists in comments,
" include /*...*/ in 'comments' for formatting even if it technically
" is not
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,sO:*\ *,mO:*\ \ ,exO:*/,sr://*,mb:*,ex:*/,sr:/*,mb:*,ex:*/,:///,://
setlocal commentstring=//\ %s

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o"
setlocal formatoptions-=t
setlocal formatoptions+=croql

let b:undo_ftplugin = 'setlocal comments< commentstring< formatoptions<'
