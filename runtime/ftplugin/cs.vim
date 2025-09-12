" Vim filetype plugin file
" Language:            C#
" Maintainer:          Nick Jensen <nickspoon@gmail.com>
" Former Maintainer:   Johannes Zellner <johannes@zellner.org>
" Last Change:         2025-03-14
" License:             Vim (see :h license)
" Repository:          https://github.com/nickspoons/vim-cs

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t formatoptions+=croql

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://
setlocal commentstring=//\ %s

setlocal cinoptions=J1

let b:undo_ftplugin = 'setl com< fo< cino<'

if exists('loaded_matchit') && !exists('b:match_words')
  " #if/#endif support included by default
  let b:match_ignorecase = 0
  let b:match_words = '\%(^\s*\)\@<=#\s*region\>:\%(^\s*\)\@<=#\s*endregion\>,'
  let b:undo_ftplugin .= ' | unlet! b:match_ignorecase b:match_words'
endif

if (has('gui_win32') || has('gui_gtk')) && !exists('b:browsefilter')
  let b:browsefilter = "C# Source Files (*.cs, *.csx)\t*.cs;*.csx\n" .
        \              "C# Project Files (*.csproj)\t*.csproj\n" .
        \              "Visual Studio Solution Files (*.sln)\t*.sln\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin .= ' | unlet! b:browsefilter'
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
