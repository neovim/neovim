" Vim syntax file
" Language:    Terraform
" Maintainer:  Gregory Anders
" Upstream:    https://github.com/hashivim/vim-terraform
" Last Change: 2024-09-03

if exists('b:current_syntax')
  finish
endif

runtime! syntax/hcl.vim

syn keyword terraType string bool number object tuple list map set any

hi def link terraType Type

let b:current_syntax = 'terraform'
