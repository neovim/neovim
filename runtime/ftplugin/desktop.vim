" Vim filetype plugin file
" Language: XDG desktop entry
" Maintainer: Eisuke Kawashima ( e.kawaschima+vim AT gmail.com )
" Last Change: 2022-07-26

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = v:true

setl comments=:#
setl commentstring=#%s
let b:undo_ftplugin = 'setl com< cms<'
