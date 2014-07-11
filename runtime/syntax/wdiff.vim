" Vim syntax file
" Language:     wDiff (wordwise diff)
" Maintainer:   Gerfried Fuchs <alfie@ist.org>
" Last Change:  25 Apr 2001
" URL:		http://alfie.ist.org/vim/syntax/wdiff.vim
"
" Comments are very welcome - but please make sure that you are commenting on
" the latest version of this file.
" SPAM is _NOT_ welcome - be ready to be reported!


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syn clear
elseif exists("b:current_syntax")
  finish
endif


syn region wdiffOld start=+\[-+ end=+-]+
syn region wdiffNew start="{+" end="+}"


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_wdiff_syn_inits")
  let did_wdiff_syn_inits = 1
  if version < 508
    let did_wdiff_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink wdiffOld       Special
  HiLink wdiffNew       Identifier

  delcommand HiLink
endif

let b:current_syntax = "wdiff"
