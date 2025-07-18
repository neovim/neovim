" Vim filetype plugin
" Language:	twig
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2025 Jul 14

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=s:{#,e:#}
setlocal commentstring={#\ %s\ #}

let b:undo_ftplugin = 'setl comments< commentstring<'
