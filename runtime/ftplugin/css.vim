" Vim filetype plugin file
" Language:		CSS
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Contributors:		Riley Bruins <ribru17@gmail.com> ('commentstring')
" Last Change:		2026 Aug 22

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl com< cms< inc< fo< ofu< isk<"

setlocal comments=s1:/*,mb:*,ex:*/ commentstring=/*\ %s\ */
" exclude "ro" - CSS universal selector "*" cannot be distinguished from
" 'comments' middle "*" pattern
setlocal formatoptions-=rot formatoptions+=cql
setlocal omnifunc=csscomplete#CompleteCSS
setlocal iskeyword+=-

let &l:include = '^\s*@import\s\+\%(url(\)\='

