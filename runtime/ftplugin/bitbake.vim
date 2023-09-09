" Vim filetype plugin file
" Language: Bitbake
" Maintainer: Gregory Anders <greg@gpanders.com>
" Repository: https://github.com/openembedded/bitbake
" Latest Revision: 2022-07-23

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#%s
setlocal comments=:#
setlocal suffixesadd=.bb,.bbclass

let b:undo_ftplugin = "setl cms< com< sua<"
