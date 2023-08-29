" Vim filetype plugin
" Language: Hare
" Maintainer: Amelia Clarke <me@rsaihe.dev>
" Previous Maintainer: Drew DeVault <sir@cmpwn.com>
" Last Updated: 2022-09-28
"               2023 Aug 28 by Vim Project (undo_ftplugin)

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Formatting settings.
setlocal formatoptions-=t formatoptions+=croql/

" Miscellaneous.
setlocal comments=://
setlocal commentstring=//\ %s
setlocal suffixesadd=.ha

let b:undo_ftplugin = "setl cms< com< fo< sua<"

" Hare recommended style.
if get(g:, "hare_recommended_style", 1)
  setlocal noexpandtab
  setlocal shiftwidth=8
  setlocal softtabstop=0
  setlocal tabstop=8
  setlocal textwidth=80
  let b:undo_ftplugin ..= " | setl et< sts< sw< ts< tw<"
endif

compiler hare

" vim: et sw=2 sts=2 ts=8
