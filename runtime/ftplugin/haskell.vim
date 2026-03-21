" Vim filetype plugin file
" Language:             Haskell
" Maintainer:           Daniel Campoverde <alx@sillybytes.net>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2018-08-27
" 2025 Jul 09 by Vim Project revert setting iskeyword #8191
" 2026 Jan 18 by Vim Project add include-search and define support #19143

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo< su< sua< inex< inc< def<"

setlocal comments=s1fl:{-,mb:-,ex:-},:-- commentstring=--\ %s
setlocal formatoptions-=t formatoptions+=croql
setlocal omnifunc=haskellcomplete#Complete

setlocal suffixes+=.hi
setlocal suffixesadd=.hs,.lhs,.hsc

setlocal includeexpr=findfile(tr(v:fname,'.','/'),'.;')
setlocal include=^import\\>\\%(\\s\\+safe\\>\\)\\?\\%(\\s\\+qualified\\>\\)\\?

setlocal define=^\\%(data\\>\\\|class\\>\\%(.*=>\\)\\?\\\|\\%(new\\)\\?type\\>\\\|\\ze\\k\\+\\s*\\%(::\\\|=\\)\\)

let &cpo = s:cpo_save
unlet s:cpo_save
