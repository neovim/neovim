" Vim filetype plugin
" Language:	ANTLR4, ANother Tool for Language Recognition v4 <www.antlr.org>
" Maintainer:	Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Last Change:	2024 July 09

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
