" Vim syntax file
" Language:     wDiff (wordwise diff)
" Maintainer:   Gerfried Fuchs <alfie@ist.org>
" Last Change:  25 Apr 2001
" URL:		http://alfie.ist.org/vim/syntax/wdiff.vim
"
" Comments are very welcome - but please make sure that you are commenting on
" the latest version of this file.
" SPAM is _NOT_ welcome - be ready to be reported!


" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif


syn region wdiffOld start=+\[-+ end=+-]+
syn region wdiffNew start="{+" end="+}"


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link wdiffOld       Special
hi def link wdiffNew       Identifier


let b:current_syntax = "wdiff"
