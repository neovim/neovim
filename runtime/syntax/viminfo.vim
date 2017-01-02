" Vim syntax file
" Language:	Vim .viminfo file
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2016 Jun 05

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" The lines that are NOT recognized
syn match viminfoError "^[^\t].*"

" The one-character one-liners that are recognized
syn match viminfoStatement "^[/&$@:?=%!<]"

" The two-character one-liners that are recognized
syn match viminfoStatement "^[-'>"]."
syn match viminfoStatement +^"".+
syn match viminfoStatement "^\~[/&]"
syn match viminfoStatement "^\~[hH]"
syn match viminfoStatement "^\~[mM][sS][lL][eE]\d\+\~\=[/&]"

syn match viminfoOption "^\*.*=" contains=viminfoOptionName
syn match viminfoOptionName "\*\a*"ms=s+1 contained

" Comments
syn match viminfoComment "^#.*"

" New style lines.  TODO: highlight numbers and strings.
syn match viminfoNew "^|.*"

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link viminfoComment	Comment
hi def link viminfoError	Error
hi def link viminfoStatement	Statement
hi def link viminfoNew		String

let b:current_syntax = "viminfo"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2
