" Vim filetype plugin
" Language:	generic git output
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2023 Mar 26

" Only do this when not done yet for this buffer
if (exists("b:did_ftplugin"))
  finish
endif

let b:did_ftplugin = 1

setlocal nomodeline

let b:undo_ftplugin = "setl modeline<"
