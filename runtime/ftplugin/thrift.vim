" Vim filetype plugin file
" Language: Apache Thrift
" Maintainer: Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Last Change: 2024/07/29

if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1

" Thrift supports shell-style, C-style multi-line as well as single-line Java/C++ style comments.
" Reference: https://diwakergupta.github.io/thrift-missing-guide/#_language_reference
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://,b:#
setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl comments< commentstring<'
