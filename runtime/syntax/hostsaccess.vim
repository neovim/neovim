" Vim syntax file
" Language:	hosts.deny, hosts.allow configuration files
" Maintainer:	Thilo Six <T.Six@gmx.de>
" Last Change:	2011 May 01
" Derived From: conf.vim
" Credits:	Bram Moolenaar
"
" This file is there to get at least a minimal highlighting.
" A later version may be improved.


" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" For a starter we just use conf.vim for highlighting
runtime! syntax/conf.vim
unlet b:current_syntax


let b:current_syntax = "hostsaccess"
" vim: ts=8 sw=2
