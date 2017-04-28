" Language:		tags
" Maintainer:	Charles E. Campbell  <NdrOchip@PcampbellAfamily.Mbiz>
" Last Change:	Oct 23, 2014
" Version:		4
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_TAGS

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match	tagName	"^[^\t]\+"		skipwhite	nextgroup=tagPath
syn match	tagPath	"[^\t]\+"	contained	skipwhite	nextgroup=tagAddr	contains=tagBaseFile
syn match	tagBaseFile	"[a-zA-Z_]\+[\.a-zA-Z_0-9]*\t"me=e-1		contained
syn match	tagAddr	"\d*"	contained skipwhite nextgroup=tagComment
syn region	tagAddr	matchgroup=tagDelim start="/" skip="\(\\\\\)*\\/" matchgroup=tagDelim end="$\|/" oneline contained skipwhite nextgroup=tagComment
syn match	tagComment	";.*$"	contained contains=tagField
syn match	tagComment	"^!_TAG_.*$"
syn match	tagField	contained "[a-z]*:"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink tagBaseFile	PreProc
HiLink tagComment	Comment
HiLink tagDelim	Delimiter
HiLink tagField	Number
HiLink tagName	Identifier
HiLink tagPath	PreProc

delcommand HiLink

let b:current_syntax = "tags"

" vim: ts=12
