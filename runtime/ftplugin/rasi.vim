" Vim filetype plugin file
" Language:		RASI
" Maintainer:		Pierrick Guillaume <pierguill@gmail.com>
" Last Change:		2024 May 21

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< isk< inc<"

setlocal comments=s1:/*,mb:*,ex:*/
setlocal commentstring=//\ %s
setlocal iskeyword+=-

let &l:include = '^\s*@import\s\+\%(url(\)\='

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
