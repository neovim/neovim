" Vim filetype plugin file
" Language:    KAREL
" Last Change: 2024-11-18
" Maintainer:  Kirill Morozov <kirill@robotix.pro>
" Credits:     Patrick Meiser-Knosowski for the initial implementation.

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:--
setlocal commentstring=--\ %s
setlocal suffixesadd+=.kl,.KL

let b:undo_ftplugin = "setlocal com< cms< sua<"
