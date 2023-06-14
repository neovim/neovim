" Vim filetype plugin
" Language:         Corn
" Original Author:  Jake Stanger (mail@jstanger.dev) 
" License:          MIT
" Last Change:      2023 May 28

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal formatoptions-=t

" Set comment (formatting) related options.
setlocal commentstring=//\ %s comments=:// 

" Let Vim know how to disable the plug-in.
let b:undo_ftplugin = 'setlocal commentstring< comments< formatoptions<'
