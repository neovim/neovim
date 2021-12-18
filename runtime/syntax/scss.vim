" Vim syntax file
" Language:	SCSS
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Filenames:	*.scss
" Last Change:	2019 Dec 05

if exists("b:current_syntax")
  finish
endif

runtime! syntax/sass.vim

syn clear sassComment
syn clear sassCssComment
syn clear sassEndOfLineComment

syn match scssComment "//.*" contains=sassTodo,@Spell
syn region scssCssComment start="/\*" end="\*/" contains=sassTodo,@Spell

hi def link scssCssComment scssComment
hi def link scssComment Comment

let b:current_syntax = "scss"

" vim:set sw=2:
