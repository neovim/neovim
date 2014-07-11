" Vim syntax file
" Language:         udev(8) permissions file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   udevpermBegin       display '^' nextgroup=udevpermDevice

syn match   udevpermDevice      contained display '[^:]\+'
                                \ contains=udevpermPattern
                                \ nextgroup=udevpermUserColon

syn match   udevpermPattern     contained '[*?]'
syn region  udevpermPattern     contained start='\[!\=' end='\]'
                                \ contains=udevpermPatRange

syn match   udevpermPatRange    contained '[^[-]-[^]-]'

syn match   udevpermUserColon   contained display ':'
                                \ nextgroup=udevpermUser

syn match   udevpermUser        contained display '[^:]\+'
                                \ nextgroup=udevpermGroupColon

syn match   udevpermGroupColon  contained display ':'
                                \ nextgroup=udevpermGroup

syn match   udevpermGroup       contained display '[^:]\+'
                                \ nextgroup=udevpermPermColon

syn match   udevpermPermColon   contained display ':'
                                \ nextgroup=udevpermPerm

syn match   udevpermPerm        contained display '\<0\=\o\+\>'
                                \ contains=udevpermOctalZero

syn match   udevpermOctalZero   contained display '\<0'
syn match   udevpermOctalError  contained display '\<0\o*[89]\d*\>'

syn keyword udevpermTodo        contained TODO FIXME XXX NOTE

syn region  udevpermComment     display oneline start='^\s*#' end='$'
                                \ contains=udevpermTodo,@Spell

hi def link udevpermTodo        Todo
hi def link udevpermComment     Comment
hi def link udevpermDevice      String
hi def link udevpermPattern     SpecialChar
hi def link udevpermPatRange    udevpermPattern
hi def link udevpermColon       Normal
hi def link udevpermUserColon   udevpermColon
hi def link udevpermUser        Identifier
hi def link udevpermGroupColon  udevpermColon
hi def link udevpermGroup       Type
hi def link udevpermPermColon   udevpermColon
hi def link udevpermPerm        Number
hi def link udevpermOctalZero   PreProc
hi def link udevpermOctalError  Error

let b:current_syntax = "udevperm"

let &cpo = s:cpo_save
unlet s:cpo_save
