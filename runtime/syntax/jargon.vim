" Vim syntax file
" Language:	Jargon File
" Maintainer:	<rms@poczta.onet.pl>
" Last Change:	2001 May 26
"
" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syn match jargonChaptTitle	/:[^:]*:/
syn match jargonEmailAddr	/[^<@ ^I]*@[^ ^I>]*/
syn match jargonUrl	 +\(http\|ftp\)://[^\t )"]*+
syn match jargonMark	/{[^}]*}/

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>
HiLink jargonChaptTitle	Title
HiLink jargonEmailAddr	 Comment
HiLink jargonUrl	 Comment
HiLink jargonMark	Label
delcommand HiLink

let b:current_syntax = "jargon"
