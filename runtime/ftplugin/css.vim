" Vim filetype plugin file
" Language:		CSS
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		2020 Dec 21
"			2024 Jun 02 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< inc< fo< ofu< isk<"

setlocal comments=s1:/*,mb:*,ex:*/ commentstring=/*\ %s\ */
setlocal formatoptions-=t formatoptions+=croql
setlocal omnifunc=csscomplete#CompleteCSS
setlocal iskeyword+=-

let &l:include = '^\s*@import\s\+\%(url(\)\='

let &cpo = s:cpo_save
unlet s:cpo_save
