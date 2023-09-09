" Vim filetype plugin file
" Language:     RPL/2
" Maintainer:   Joël BERTRAND <rpl2@free.fr>
" Last Change:	2012 Mar 07
" Version: 		0.1

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://

let b:undo_ftplugin = "setlocal fo< comments<"
