" Vim syntax file
" Language:     RCS file
" Maintainer:   Dmitry Vasiliev <dima at hlabs dot org>
" URL:          https://github.com/hdima/vim-scripts/blob/master/syntax/rcs.vim
" Last Change:  2012-02-11
" Filenames:    *,v
" Version:      1.12

" Options:
"   rcs_folding = 1   For folding strings

" quit when a syntax file was already loaded.
if exists("b:current_syntax")
  finish
endif

" RCS file must end with a newline.
syn match rcsEOFError   ".\%$" containedin=ALL

" Keywords.
syn keyword rcsKeyword  head branch access symbols locks strict
syn keyword rcsKeyword  comment expand date author state branches
syn keyword rcsKeyword  next desc log
syn keyword rcsKeyword  text nextgroup=rcsTextStr skipwhite skipempty

" Revision numbers and dates.
syn match rcsNumber "\<[0-9.]\+\>" display

" Strings.
if exists("rcs_folding") && has("folding")
  " Folded strings.
  syn region rcsString  matchgroup=rcsString start="@" end="@" skip="@@" fold contains=rcsSpecial
  syn region rcsTextStr matchgroup=rcsTextStr start="@" end="@" skip="@@" fold contained contains=rcsSpecial,rcsDiffLines
else
  syn region rcsString  matchgroup=rcsString start="@" end="@" skip="@@" contains=rcsSpecial
  syn region rcsTextStr matchgroup=rcsTextStr start="@" end="@" skip="@@" contained contains=rcsSpecial,rcsDiffLines
endif
syn match rcsSpecial    "@@" contained
syn match rcsDiffLines  "[da]\d\+ \d\+$" contained

" Synchronization.
syn sync clear
if exists("rcs_folding") && has("folding")
  syn sync fromstart
else
  " We have incorrect folding if following sync patterns is turned on.
  syn sync match rcsSync    grouphere rcsString "[0-9.]\+\(\s\|\n\)\+log\(\s\|\n\)\+@"me=e-1
  syn sync match rcsSync    grouphere rcsTextStr "@\(\s\|\n\)\+text\(\s\|\n\)\+@"me=e-1
endif

" Define the default highlighting.
" Only when an item doesn't have highlighting yet.

hi def link rcsKeyword     Keyword
hi def link rcsNumber      Identifier
hi def link rcsString      String
hi def link rcsTextStr     String
hi def link rcsSpecial     Special
hi def link rcsDiffLines   Special
hi def link rcsEOFError    Error


let b:current_syntax = "rcs"
