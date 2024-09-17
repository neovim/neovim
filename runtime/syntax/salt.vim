" Vim syntax file
" Maintainer: Gregory Anders
" Last Changed: 2024-09-16

if exists('b:current_syntax')
  finish
endif

" Salt state files are just YAML with embedded Jinja
runtime! syntax/yaml.vim
unlet! b:current_syntax

runtime! syntax/jinja.vim
unlet! b:current_syntax

let b:current_syntax = 'salt'
