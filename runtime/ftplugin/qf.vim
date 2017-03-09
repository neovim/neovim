" Vim filetype plugin file
" Language:     Vim's quickfix window
" Maintainer:   Lech Lorens <Lech.Lorens@gmail.com>
" Last Changed: 30 Apr 2012

if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let b:undo_ftplugin = "set stl<"

" Display the command that produced the list in the quickfix window:
setlocal stl=%t%{exists('w:quickfix_title')?\ '\ '.w:quickfix_title\ :\ ''}\ %=%-15(%l,%c%V%)\ %P

autocmd Syntax <buffer>
      \ if get(w:, 'quickfix_title') =~# '^:\%(Man\|Help\) TOC$' && &syntax == 'qf' |
      \   setlocal modifiable |
      \   silent %delete _ |
      \   call setline(1, map(getloclist(0), 'v:val.text')) |
      \   setlocal nomodifiable nomodified |
      \   let &syntax = tolower(matchstr(w:quickfix_title, '\w\+')) |
      \ endif
