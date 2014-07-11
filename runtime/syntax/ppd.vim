" Vim syntax file
" Language:	PPD (PostScript printer description) file
" Maintainer:	Bjoern Jacke <bjacke@suse.de>
" Last Change:	2001-10-06

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif


syn match	ppdComment	"^\*%.*"
syn match	ppdDef		"\*[a-zA-Z0-9]\+"
syn match	ppdDefine	"\*[a-zA-Z0-9\-_]\+:"
syn match	ppdUI		"\*[a-zA-Z]*\(Open\|Close\)UI"
syn match	ppdUIGroup	"\*[a-zA-Z]*\(Open\|Close\)Group"
syn match	ppdGUIText	"/.*:"
syn match	ppdContraints	"^*UIConstraints:"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_ahdl_syn_inits")
  if version < 508
    let did_ahdl_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif


  HiLink ppdComment		Comment
  HiLink ppdDefine		Statement
  HiLink ppdUI			Function
  HiLink ppdUIGroup		Function
  HiLink ppdDef			String
  HiLink ppdGUIText		Type
  HiLink ppdContraints		Special

  delcommand HiLink
endif

let b:current_syntax = "ppd"

" vim: ts=8
