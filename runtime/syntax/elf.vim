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

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet

" The default methods for highlighting. Can be overridden later.
hi def link elfComment Comment
hi def link elfPPCom Include
hi def link elfKeyword Keyword
hi def link elfSpecial Special
hi def link elfEnvironment Special
hi def link elfBraceError Error
hi def link elfConditional Conditional
hi def link elfMacro Function
hi def link elfNumber Number
hi def link elfString String
hi def link elfParens Delimiter
hi def link elfPunct Delimiter


let b:current_syntax = "elf"

" vim:ts=8:sw=4:nocindent:smartindent:
