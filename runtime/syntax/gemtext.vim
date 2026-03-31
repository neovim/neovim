" Vim syntax file
" Language:             Gemtext markup language
" Maintainer:           Suneel Freimuth <suneelfreimuth1@gmail.com>
" Latest Revision:      2020-11-21
" Filenames:            *.gmi

if exists('b:current_syntax')
    finish
endif

syntax match  Heading  /^#\{1,3}.\+$/
syntax match  List     /^\* /
syntax match  LinkURL  /^=>\s*\S\+/
syntax match  Quote    /^>.\+/
syntax region Preformatted start=/^```/ end=/```/

highlight default link Heading  Special
highlight default link List     Statement
highlight default link LinkURL  Underlined
highlight default link Quote    Constant
highlight default link Preformatted Identifier

let b:current_syntax = 'gemtext'

