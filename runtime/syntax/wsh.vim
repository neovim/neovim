" Vim syntax file
" Language:	Windows Scripting Host
" Maintainer:	Paul Moore <pf_moore AT yahoo.co.uk>
" Last Change:	Fre, 24 Nov 2000 21:54:09 +0100

" This reuses the XML, VB and JavaScript syntax files. While VB is not
" VBScript, it's close enough for us. No attempt is made to handle
" other languages.
" Send comments, suggestions and requests to the maintainer.

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:wsh_cpo_save = &cpo
set cpo&vim

runtime! syntax/xml.vim
unlet b:current_syntax

syn case ignore
syn include @wshVBScript <sfile>:p:h/vb.vim
unlet b:current_syntax
syn include @wshJavaScript <sfile>:p:h/javascript.vim
unlet b:current_syntax
syn region wshVBScript
    \ matchgroup=xmlTag    start="<script[^>]*VBScript\(>\|[^>]*[^/>]>\)"
    \ matchgroup=xmlEndTag end="</script>"
    \ fold
    \ contains=@wshVBScript
    \ keepend
syn region wshJavaScript
    \ matchgroup=xmlTag    start="<script[^>]*J\(ava\)\=Script\(>\|[^>]*[^/>]>\)"
    \ matchgroup=xmlEndTag end="</script>"
    \ fold
    \ contains=@wshJavaScript
    \ keepend

syn cluster xmlRegionHook add=wshVBScript,wshJavaScript

let b:current_syntax = "wsh"

let &cpo = s:wsh_cpo_save
unlet s:wsh_cpo_save
