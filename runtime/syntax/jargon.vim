" Vim syntax file
" Language:	Jargon File
" Maintainer:	Dan Church (https://github.com/h3xx)
" Last Change:	2020 Mar 16
"
" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syn region jargonHeader start="^:" end="$" contains=jargonChaptTitle
syn match jargonChaptTitle /:[^:]*:/ contained
syn match jargonEmailAddr /[+._A-Za-z0-9-]\+@[+._A-Za-z0-9-]\+/
syn match jargonUrl +\(https\?\|ftp\)://[^\t )"]*+
syn region jargonMark start="{[^\t {}]" end="}"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link jargonChaptTitle Title
hi def link jargonEmailAddr Comment
hi def link jargonUrl Comment
hi def link jargonMark Label

let b:current_syntax = "jargon"
