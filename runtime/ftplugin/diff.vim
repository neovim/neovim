" Vim filetype plugin file
" Language:	Diff
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2005 Jul 27

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl modeline<"

" Don't use modelines in a diff, they apply to the diffed file
setlocal nomodeline
