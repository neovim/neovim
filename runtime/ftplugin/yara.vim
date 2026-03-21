" Vim filetype plugin file
" Language: YARA
" Maintainer: The Vim Project <https://github.com/vim/vim>
" Last Change: 2026 Mar 17

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t formatoptions+=croql

setlocal commentstring=//\ %s
setlocal comments=s1:/*,mb:*,ex:*/,://

" Undo settings when leaving buffer
let b:undo_ftplugin = "setlocal commentstring< comments< formatoptions<"
