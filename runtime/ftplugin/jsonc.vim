" Vim filetype plugin
" Language:         JSONC (JSON with Comments)
" Original Author:  Izhak Jakov <izhak724@gmail.com>
" Acknowledgement:  Based off of vim-jsonc maintained by Kevin Locke <kevin@kevinlocke.name>
"                   https://github.com/kevinoid/vim-jsonc
" License:          MIT
" Last Change:      2021 Nov 22

runtime! ftplugin/json.vim

if exists('b:did_ftplugin_jsonc')
  finish
else
  let b:did_ftplugin_jsonc = 1
endif

" Set comment (formatting) related options. {{{1
setlocal commentstring=//%s comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://

" Let Vim know how to disable the plug-in.
let b:undo_ftplugin = 'setlocal commentstring< comments<'
