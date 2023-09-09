" Vim filetype plugin file
" Language:	Diff
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl modeline< commentstring<"

" Don't use modelines in a diff, they apply to the diffed file
setlocal nomodeline

" If there are comments they start with #
let &l:commentstring = "# %s"

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Diff Files (*.diff)\t*.diff\nPatch Files (*.patch)\t*.h\nAll Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif
