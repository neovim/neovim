" Vim syntax file
" Language:      MS Windows URL shortcut file
" Maintainer:    ObserverOfTime <chronobserver@disroot.org>
" LastChange:    2023-06-04

" Quit when a syntax file was already loaded.
if exists("b:current_syntax")
   finish
endif

" Just use the dosini syntax for now
runtime! syntax/dosini.vim

let b:current_syntax = "urlshortcut"
