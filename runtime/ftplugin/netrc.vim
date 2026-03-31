" Vim filetype plugin file
" Language:             netrc(5) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2008-07-09
" Last Change:		2023 Feb 27 by Keith Smiley

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments=b:# commentstring=#\ %s formatoptions-=tcroq formatoptions+=l

let &cpo = s:cpo_save
unlet s:cpo_save
