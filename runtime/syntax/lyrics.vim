" Vim syntax file
" Language:     LyRiCs
" Maintainer:   ObserverOfTime <chronobserver@disroot.org>
" Filenames:    *.lrc
" Last Change:  2022 Sep 18

if exists('b:current_syntax')
    finish
endif

let s:cpo_save = &cpoptions
set cpoptions&vim

syn case ignore

" Errors
syn match lrcError /^.\+$/

" ID tags
syn match lrcTag /^\s*\[\a\+:.\+\]\s*$/ contains=lrcTagName,lrcTagValue
syn match lrcTagName contained nextgroup=lrcTagValue
            \ /\[\zs\(al\|ar\|au\|by\|encoding\|la\|id\|length\|offset\|re\|ti\|ve\)\ze:/
syn match lrcTagValue /:\zs.\+\ze\]/ contained

" Lyrics
syn match lrcLyricTime /^\s*\[\d\d:\d\d\.\d\d\]/
            \ contains=lrcNumber nextgroup=lrcLyricLine
syn match lrcLyricLine /.*$/ contained contains=lrcWordTime,@Spell
syn match lrcWordTime /<\d\d:\d\d\.\d\d>/ contained contains=lrcNumber,@NoSpell
syn match lrcNumber /[+-]\=\d\+/ contained

hi def link lrcLyricTime Label
hi def link lrcNumber Number
hi def link lrcTag PreProc
hi def link lrcTagName Identifier
hi def link lrcTagValue String
hi def link lrcWordTime Special
hi def link lrcError Error

let b:current_syntax = 'lyrics'

let &cpoptions = s:cpo_save
unlet s:cpo_save
