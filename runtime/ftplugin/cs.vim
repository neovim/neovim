" Vim filetype plugin file
" Language:	C#
" Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Tue, 09 Mar 2004 14:09:33 CET

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1
let s:keepcpo= &cpo
set cpo&vim

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://

if has("gui_win32") && !exists("b:browsefilter")
    let b:browsefilter = "C# Source Files (*.cs)\t*.cs\n" .
		       \ "All Files (*.*)\t*.*\n"
endif

let &cpo = s:keepcpo
unlet s:keepcpo
