" Vim filetype plugin file
" Language:	Haskell Cabal Build file
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Jul 06
" 2026 Jan 13 by Vim project: set compiler #19152

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

compiler cabal

let b:undo_ftplugin = 'compiler make'

setl comments=:-- commentstring=--\ %s

let b:undo_ftplugin .= '| setl com< cms<'
