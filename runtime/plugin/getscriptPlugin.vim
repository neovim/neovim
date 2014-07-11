" ---------------------------------------------------------------------
" getscriptPlugin.vim
"  Author:	Charles E. Campbell
"  Date:	Nov 29, 2013
"  Installing:	:help glvs-install
"  Usage:	:help glvs
"
" GetLatestVimScripts: 642 1 :AutoInstall: getscript.vim
"
" (Rom 15:11 WEB) Again, "Praise the Lord, all you Gentiles!  Let
" all the peoples praise Him."
" ---------------------------------------------------------------------
" Initialization:	{{{1
" if you're sourcing this file, surely you can't be
" expecting vim to be in its vi-compatible mode
if exists("g:loaded_getscriptPlugin")
 finish
endif
if &cp
 if &verbose
  echo "GetLatestVimScripts is not vi-compatible; not loaded (you need to set nocp)"
 endif
 finish
endif
let g:loaded_getscriptPlugin = "v36"
let s:keepcpo                = &cpo
set cpo&vim

" ---------------------------------------------------------------------
"  Public Interface: {{{1
com!        -nargs=0 GetLatestVimScripts call getscript#GetLatestVimScripts()
com!        -nargs=0 GetScripts          call getscript#GetLatestVimScripts()
silent! com -nargs=0 GLVS                call getscript#GetLatestVimScripts()

" ---------------------------------------------------------------------
" Restore Options: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo

" ---------------------------------------------------------------------
" vim: ts=8 sts=2 fdm=marker nowrap
