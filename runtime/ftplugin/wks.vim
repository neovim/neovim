" Vim filetype plugin file
" Language:	OpenEmbedded Image Creator (WIC) Kickstarter files wks
" Maintainer:	Anakin Childerhose <anakin@childerhose.ca>
" Last Change:	2026 Mar 23

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:#
setlocal commentstring=#\ %s

let b:undo_ftplugin = 'setlocal com< cms<'
