" Vim syntax file
" Language:    ELF
" Maintainer:  Christian V. J. Brüssow <cvjb@cvjb.de>
" Last Change: Son 22 Jun 2003 20:43:14 CEST
" Filenames:   *.ab,*.am
" URL:	       http://www.cvjb.de/comp/vim/elf.vim
" $Id: elf.vim,v 1.1 2004/06/13 19:52:27 vimboss Exp $
"
" ELF: Extensible Language Facility
"      This is the Applix Inc., Macro and Builder programming language.
"      It has nothing in common with the binary format called ELF.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

" Case does not matter
syn case ignore

" Environments
syn region elfEnvironment transparent matchgroup=Special start="{" matchgroup=Special end="}" contains=ALLBUT,elfBraceError

" Unmatched braces
syn match elfBraceError "}"

" All macros must have at least one of these definitions
syn keyword elfSpecial endmacro
syn region elfSpecial transparent matchgroup=Special start="^\(\(macro\)\|\(set\)\) \S\+$" matchgroup=Special end="^\(\(endmacro\)\|\(endset\)\)$" contains=ALLBUT,elfBraceError

" Preprocessor Commands
syn keyword elfPPCom define include

" Some keywords
syn keyword elfKeyword  false true null
syn keyword elfKeyword	var format object function endfunction

" Conditionals and loops
syn keyword elfConditional if else case of endcase for to next while until return goto

" All built-in elf macros end with an '@'
syn match elfMacro "[0-9_A-Za-z]\+@"

" Strings and characters
syn region elfString start=+"+  skip=+\\\\\|\\"+  end=+"+

" Numbers
syn match elfNumber "-\=\<[0-9]*\.\=[0-9_]\>"

" Comments
syn region elfComment start="/\*"  end="\*/"
syn match elfComment  "\'.*$"

syn sync ccomment elfComment

" Parenthesis
syn match elfParens "[\[\]()]"

" Punctuation
syn match elfPunct "[,;]"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_elf_syn_inits")
	if version < 508
		let did_elf_syn_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
   endif

  " The default methods for highlighting. Can be overridden later.
  HiLink elfComment Comment
  HiLink elfPPCom Include
  HiLink elfKeyword Keyword
  HiLink elfSpecial Special
  HiLink elfEnvironment Special
  HiLink elfBraceError Error
  HiLink elfConditional Conditional
  HiLink elfMacro Function
  HiLink elfNumber Number
  HiLink elfString String
  HiLink elfParens Delimiter
  HiLink elfPunct Delimiter

  delcommand HiLink
endif

let b:current_syntax = "elf"

" vim:ts=8:sw=4:nocindent:smartindent:
