" Vim syntax file
" Language:	CVS commit file
" Maintainer:	Matt Dunford (zoot@zotikos.com)
" URL:		http://www.zotikos.com/downloads/cvs.vim
" Last Change:	Sat Nov 24 23:25:11 CET 2001

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

syn region cvsLine start="^CVS: " end="$" contains=cvsFile,cvsCom,cvsFiles,cvsTag
syn match cvsFile  contained " \t\(\(\S\+\) \)\+"
syn match cvsTag   contained " Tag:"
syn match cvsFiles contained "\(Added\|Modified\|Removed\) Files:"
syn region cvsCom start="Committing in" end="$" contains=cvsDir contained extend keepend
syn match cvsDir   contained "\S\+$"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_cvs_syn_inits")
	if version < 508
		let did_cvs_syn_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink cvsLine		Comment
	HiLink cvsDir		cvsFile
	HiLink cvsFile		Constant
	HiLink cvsFiles		cvsCom
	HiLink cvsTag		cvsCom
	HiLink cvsCom		Statement

	delcommand HiLink
endif

let b:current_syntax = "cvs"
