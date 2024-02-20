" Language:		tags
" Maintainer:	This runtime file is looking for a new maintainer.
" Former Maintainer:	Charles E. Campbell
" Last Change:	Oct 26, 2016
"   2024 Feb 19 by Vim Project (announce adoption)
" Version:		8
" Former URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_TAGS

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match	tagName		"^[^\t]\+"	skipwhite	nextgroup=tagPath
syn match	tagPath		"[^\t]\+"	contained	skipwhite	nextgroup=tagAddr	contains=tagBaseFile
syn match	tagBaseFile	"[a-zA-Z_]\+[\.a-zA-Z_0-9]*\t"me=e-1		contained
syn match	tagAddr		"\d*"		contained skipwhite nextgroup=tagComment
syn region	tagAddr				matchgroup=tagDelim start="/" skip="\(\\\\\)*\\/" matchgroup=tagDelim end="$\|/" oneline contained skipwhite nextgroup=tagComment
syn match	tagComment	";.*$"		contained contains=tagField
syn match	tagComment	"^!_TAG_.*$"
syn match	tagField			contained "[a-z]*:"

" Define the default highlighting.
if !exists("skip_drchip_tags_inits")
 hi def link tagBaseFile	PreProc
 hi def link tagComment		Comment
 hi def link tagDelim		Delimiter
 hi def link tagField		Number
 hi def link tagName		Identifier
 hi def link tagPath		PreProc
endif

let b:current_syntax = "tags"
