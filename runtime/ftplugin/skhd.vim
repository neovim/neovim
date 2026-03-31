" Vim filetype plugin file
" Language:	skhd(simple hotkey daemon for macOS) configuration file
" Maintainer:	Kiyoon Kim <https://github.com/kiyoon>
" Last Change:	2026 Jan 23

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:# commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl com< cms< fo<"

let &cpo = s:cpo_save
unlet s:cpo_save
