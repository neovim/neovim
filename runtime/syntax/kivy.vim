" Vim syntax file
" Language:    Kivy
" Maintainer:  Corey Prophitt <corey@prophitt.me>
" Last Change: Jul 31st, 2024
" Version:     1
" URL:         https://kivy.org/

if exists("b:current_syntax")
    finish
endif

" Load Python syntax first (Python can be used within Kivy)
syn include @pyth $VIMRUNTIME/syntax/python.vim

" Kivy language rules can be found here
"   https://kivy.org/doc/stable/guide/lang.html

" Define Kivy syntax
syn match kivyPreProc   /#:.*/
syn match kivyComment   /#[^:].*/
syn match kivyRule      /<\I\i*\(,\s*\I\i*\)*>:/
syn match kivyAttribute /\<\I\i*\>/ nextgroup=kivyValue

syn region kivyValue start=":" end=/$/  contains=@pyth skipwhite

syn region kivyAttribute matchgroup=kivyIdent start=/[\a_][\a\d_]*:/ end=/$/ contains=@pyth skipwhite

hi def link kivyPreproc   PreProc
hi def link kivyComment   Comment
hi def link kivyRule      Function
hi def link kivyIdent     Statement
hi def link kivyAttribute Label

let b:current_syntax = "kivy"

" vim: ts=8
