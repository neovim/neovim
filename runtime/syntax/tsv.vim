" Vim filetype plugin file
" Language:	Tab separated values (TSV)
" Last Change:	2024 Jul 16
" This runtime file is looking for a new maintainer.

if exists('b:current_syntax')
  finish
endif

let b:csv_delimiter = '\t'  " enforce tab delimiter
runtime! syntax/csv.vim
let b:current_syntax = 'tsv'
