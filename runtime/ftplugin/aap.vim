" Vim filetype plugin file
" Language:	Aap recipe
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2024 Jan 14
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Reset 'formatoptions', 'comments', 'commentstring' and 'expandtab' to undo
" this plugin.
let b:undo_ftplugin = "setl fo< com< cms< et<"

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" Set 'comments' to format dashed lists in comments.
setlocal comments=s:#\ -,m:#\ \ ,e:#,n:#,fb:-
setlocal commentstring=#\ %s

" Expand tabs to spaces to avoid trouble.
setlocal expandtab

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Aap Recipe Files (*.aap)\t*.aap\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif
