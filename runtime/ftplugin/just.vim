" Vim ftplugin file
" Language:	Justfile
" Maintainer:	Peter Benjamin <@pbnj>
" Last Change:	2025 Jan 19
" Credits:	The original author, Noah Bogart <https://github.com/NoahTheDuke/vim-just/>

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal iskeyword+=-
setlocal comments=n:#
setlocal commentstring=#\ %s

let b:undo_ftplugin = "setlocal iskeyword< comments< commentstring<"
