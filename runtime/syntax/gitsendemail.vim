" Vim syntax file
" Language:	git send-email message
" Maintainer:	Tim Pope
" Filenames:	.gitsendemail.*
" Last Change:	2016 Aug 29

if exists("b:current_syntax")
  finish
endif

runtime! syntax/mail.vim
unlet! b:current_syntax
syn include @gitsendemailDiff syntax/diff.vim
syn region gitsendemailDiff start=/\%(^diff --\%(git\|cc\|combined\) \)\@=/ end=/^-- %/ fold contains=@gitsendemailDiff

syn case match

syn match   gitsendemailComment "\%^From.*#.*"
syn match   gitsendemailComment "^GIT:.*"

hi def link gitsendemailComment Comment

let b:current_syntax = "gitsendemail"
