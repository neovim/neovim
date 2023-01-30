" Vim filetype plugin
" Language: nginx.conf
" Maintainer: Chris Aumann <me@chr4.org>
" Last Change: Apr 15, 2017

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions+=croql formatoptions-=t

let b:undo_ftplugin = "setl fo< cms< com<"
