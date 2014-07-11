" Vim syntax file
" Language:	Jargon File
" Maintainer:	<rms@poczta.onet.pl>
" Last Change:	2001 May 26
"
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

syn match jargonChaptTitle	/:[^:]*:/
syn match jargonEmailAddr	/[^<@ ^I]*@[^ ^I>]*/
syn match jargonUrl	 +\(http\|ftp\)://[^\t )"]*+
syn match jargonMark	/{[^}]*}/

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_jargon_syntax_inits")
	if version < 508
		let did_jargon_syntax_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif
	HiLink jargonChaptTitle	Title
	HiLink jargonEmailAddr	 Comment
	HiLink jargonUrl	 Comment
	HiLink jargonMark	Label
	delcommand HiLink
endif

let b:current_syntax = "jargon"
