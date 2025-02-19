" Vim filetype plugin file
" Language:     Vim's quickfix window
" Maintainer:   Lech Lorens <Lech.Lorens@gmail.com>
" Last Change: 	2019 Jul 15

if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

if !get(g:, 'qf_disable_statusline')
  let b:undo_ftplugin = "set stl<"

  " Display the command that produced the list in the quickfix window:
  setlocal stl=%t%{exists('w:quickfix_title')?\ '\ '.w:quickfix_title\ :\ ''}\ %=%-15(%l,%c%V%)\ %P
endif
