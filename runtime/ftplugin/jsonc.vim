" Vim filetype plugin
" Language:         JSONC (JSON with Comments)
" Original Author:  Izhak Jakov <izhak724@gmail.com>
" Acknowledgement:  Based off of vim-jsonc maintained by Kevin Locke <kevin@kevinlocke.name>
"                   https://github.com/kevinoid/vim-jsonc
" License:          MIT
" Last Change:      2021-07-01

runtime! ftplugin/json.vim

if exists('b:did_ftplugin_jsonc')
  finish
else
  let b:did_ftplugin_jsonc = 1
endif

" A list of commands that undo buffer local changes made below.
let s:undo_ftplugin = []

" Set comment (formatting) related options. {{{1
setlocal commentstring=//%s comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
call add(s:undo_ftplugin, 'commentstring< comments<')

" Let Vim know how to disable the plug-in.
call map(s:undo_ftplugin, "'execute ' . string(v:val)")
let b:undo_ftplugin = join(s:undo_ftplugin, ' | ')
unlet s:undo_ftplugin
