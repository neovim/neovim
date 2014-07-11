" Vim syntax file
" Language:	Dylan Library Interface Files
" Authors:	Justus Pendleton <justus@acm.org>
"		Brent Fulgham <bfulgham@debian.org>
" Last Change:	Fri Sep 29 13:50:20 PDT 2000
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

syn region	dylanlidInfo		matchgroup=Statement start="^" end=":" oneline
syn region	dylanlidEntry		matchgroup=Statement start=":%" end="$" oneline

syn sync	lines=50

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_dylan_lid_syntax_inits")
  if version < 508
    let did_dylan_lid_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink dylanlidInfo		Type
  HiLink dylanlidEntry		String

  delcommand HiLink
endif

let b:current_syntax = "dylanlid"

" vim:ts=8
