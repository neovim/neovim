" Vim syntax file
" Language:	SubRip
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	*.srt
" Last Change:	2022 Sep 12

if exists('b:current_syntax')
    finish
endif

syn spell toplevel

syn cluster srtSpecial contains=srtBold,srtItalics,srtStrikethrough,srtUnderline,srtFont,srtTag,srtEscape

" Number
syn match srtNumber /^\d\+$/ contains=@NoSpell

" Range
syn match srtRange /\d\d:\d\d:\d\d[,.]\d\d\d --> \d\d:\d\d:\d\d[,.]\d\d\d/ skipwhite contains=srtArrow,srtTime nextgroup=srtCoordinates
syn match srtArrow /-->/ contained contains=@NoSpell
syn match srtTime /\d\d:\d\d:\d\d[,.]\d\d\d/ contained contains=@NoSpell
syn match srtCoordinates /X1:\d\+ X2:\d\+ Y1:\d\+ Y2:\d\+/ contained contains=@NoSpell

" Bold
syn region srtBold matchgroup=srtFormat start=+<b>+ end=+</b>+ contains=@srtSpecial
syn region srtBold matchgroup=srtFormat start=+{b}+ end=+{/b}+ contains=@srtSpecial

" Italics
syn region srtItalics matchgroup=srtFormat start=+<i>+ end=+</i>+ contains=@srtSpecial
syn region srtItalics matchgroup=srtFormat start=+{i}+ end=+{/i}+ contains=@srtSpecial

" Strikethrough
syn region srtStrikethrough matchgroup=srtFormat start=+<s>+ end=+</s>+ contains=@srtSpecial
syn region srtStrikethrough matchgroup=srtFormat start=+{s}+ end=+{/s}+ contains=@srtSpecial

" Underline
syn region srtUnderline matchgroup=srtFormat start=+<u>+ end=+</u>+ contains=@srtSpecial
syn region srtUnderline matchgroup=srtFormat start=+{u}+ end=+{/u}+ contains=@srtSpecial

" Font
syn region srtFont matchgroup=srtFormat start=+<font[^>]\{-}>+ end=+</font>+ contains=@srtSpecial

" ASS tags
syn match srtTag /{\\[^}]\{1,}}/ contains=@NoSpell

" Special characters
syn match srtEscape /\\[nNh]/ contains=@NoSpell

hi def link srtArrow Delimiter
hi def link srtCoordinates Label
hi def link srtEscape SpecialChar
hi def link srtFormat Special
hi def link srtNumber Number
hi def link srtTag PreProc
hi def link srtTime String

hi srtBold cterm=bold gui=bold
hi srtItalics cterm=italic gui=italic
hi srtStrikethrough cterm=strikethrough gui=strikethrough
hi srtUnderline cterm=underline gui=underline

let b:current_syntax = 'srt'
