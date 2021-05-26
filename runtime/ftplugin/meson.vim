" Vim filetype plugin file
" Language:	meson
" License:	VIM License
" Maintainer:   Liam Beguin <liambeguin@gmail.com>
" Original Author:	Laurent Pinchart <laurent.pinchart@ideasonboard.com>
" Last Change:		2018 Nov 27

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1
let s:keepcpo= &cpo
set cpo&vim

setlocal commentstring=#\ %s
setlocal comments=:#

setlocal shiftwidth=2
setlocal softtabstop=2

let &cpo = s:keepcpo
unlet s:keepcpo
