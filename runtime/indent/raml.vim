" Vim indent file
" Language:         RAML (RESTful API Modeling Language)
" Maintainer:       mucheng <leisurelicht@gmail.com>
" License:          VIM LICENSE
" Latest Revision:  2018-11-03

if exists("b:did_indent")
  finish
endif

" Same as yaml indenting.
runtime! indent/yaml.vim
