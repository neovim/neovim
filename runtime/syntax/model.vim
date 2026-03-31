" Vim syntax file
" Language:	Model
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" very basic things only (based on the vgrindefs file).
" If you use this language, please improve it, and send patches!

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" A bunch of keywords
syn keyword modelKeyword abs and array boolean by case cdnl char copied dispose
syn keyword modelKeyword div do dynamic else elsif end entry external FALSE false
syn keyword modelKeyword fi file for formal fortran global if iff ift in integer include
syn keyword modelKeyword inline is lbnd max min mod new NIL nil noresult not notin od of
syn keyword modelKeyword or procedure public read readln readonly record recursive rem rep
syn keyword modelKeyword repeat res result return set space string subscript such then TRUE
syn keyword modelKeyword true type ubnd union until varies while width

" Special keywords
syn keyword modelBlock beginproc endproc

" Comments
syn region modelComment start="\$" end="\$" end="$"

" Strings
syn region modelString start=+"+ end=+"+

" Character constant (is this right?)
syn match modelString "'."

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link modelKeyword	Statement
hi def link modelBlock		PreProc
hi def link modelComment	Comment
hi def link modelString		String

let b:current_syntax = "model"

" vim: ts=8 sw=2
