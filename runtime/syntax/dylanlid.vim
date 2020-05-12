" Vim syntax file
" Language:	Dylan Library Interface Files
" Authors:	Justus Pendleton <justus@acm.org>
"		Brent Fulgham <bfulgham@debian.org>
" Last Change:	Fri Sep 29 13:50:20 PDT 2000
"

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

syn region	dylanlidInfo		matchgroup=Statement start="^" end=":" oneline
syn region	dylanlidEntry		matchgroup=Statement start=":%" end="$" oneline

syn sync	lines=50

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link dylanlidInfo		Type
hi def link dylanlidEntry		String


let b:current_syntax = "dylanlid"

" vim:ts=8
