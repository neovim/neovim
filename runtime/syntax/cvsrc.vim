" Vim syntax file
" Language:             cvs(1) RC file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn region  cvsrcString   display oneline start=+"+ skip=+\\\\\|\\\\"+ end=+"+
syn region  cvsrcString   display oneline start=+'+ skip=+\\\\\|\\\\'+ end=+'+

syn match   cvsrcNumber   display '\<\d\+\>'

syn match   cvsrcBegin    display '^' nextgroup=cvsrcCommand skipwhite

syn region  cvsrcCommand  contained transparent matchgroup=cvsrcCommand
                          \ start='add\|admin\|checkout\|commit\|cvs\|diff'
                          \ start='export\|history\|import\|init\|log'
                          \ start='rdiff\|release\|remove\|rtag\|status\|tag'
                          \ start='update'
                          \ end='$'
                          \ contains=cvsrcOption,cvsrcString,cvsrcNumber
                          \ keepend

syn match   cvsrcOption   contained display '-\a\+'

hi def link cvsrcString   String
hi def link cvsrcNumber   Number
hi def link cvsrcCommand  Keyword
hi def link cvsrcOption   Identifier

let b:current_syntax = "cvsrc"

let &cpo = s:cpo_save
unlet s:cpo_save
