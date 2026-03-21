" Vim syntax file
" Language: confini
" Last Change:
" 2025 May 02 by Vim project commented line starts with # only

" Quit if a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Use the cfg syntax for now, it's similar.
runtime! syntax/cfg.vim

" Only accept '#' as the start of a comment.
syn clear CfgComment
syn match CfgComment "#.*" contains=@Spell

let b:current_syntax = 'confini'
