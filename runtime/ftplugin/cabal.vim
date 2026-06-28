" Vim filetype plugin file
" Language:	Haskell Cabal Build file
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Jul 06
" 2026 Jan 13 by Vim project: set compiler #19152
" 2026 Jun 26 by Vim project: set expandtab #20623

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal expandtab
setlocal comments=:-- commentstring=--\ %s

compiler cabal

let b:undo_ftplugin = 'compiler make | setlocal com< cms< et<'
