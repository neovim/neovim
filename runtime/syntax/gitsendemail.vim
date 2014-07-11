" Vim syntax file
" Language:	git send-email message
" Maintainer:	Tim Pope
" Filenames:	*.msg.[0-9]* (first line is "From ... # This line is ignored.")
" Last Change:	2010 May 21

if exists("b:current_syntax")
  finish
endif

runtime! syntax/mail.vim
syn case match

syn match   gitsendemailComment "\%^From.*#.*"
syn match   gitsendemailComment "^GIT:.*"

hi def link gitsendemailComment Comment

let b:current_syntax = "gitsendemail"
