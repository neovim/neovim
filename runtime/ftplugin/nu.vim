" Vim filetype plugin
" Language:	Nushell
" Maintainer:	El Kasztano
" URL:		https://github.com/elkasztano/nushell-syntax-vim
" License:	MIT <https://opensource.org/license/mit>
" Last Change:	2025 Sep 05

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s
setlocal comments-=://
setlocal formatoptions=tcroql

let b:undo_ftplugin = "setl fo< cms< com<"
