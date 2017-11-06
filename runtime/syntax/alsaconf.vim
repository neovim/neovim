" Vim syntax file
" Language:             alsaconf(8) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword alsoconfTodo        contained FIXME TODO XXX NOTE

syn region  alsaconfComment     display oneline
                                \ start='#' end='$'
                                \ contains=alsaconfTodo,@Spell

syn match   alsaconfSpecialChar contained display '\\[ntvbrf]'
syn match   alsaconfSpecialChar contained display '\\\o\+'

syn region  alsaconfString      start=+"+ skip=+\\$+ end=+"\|$+
                                \ contains=alsaconfSpecialChar

syn match   alsaconfSpecial     contained display 'confdir:'

syn region  alsaconfPreProc     start='<' end='>' contains=alsaconfSpecial

syn match   alsaconfMode        display '[+?!-]'

syn keyword alsaconfKeyword     card default device errors files func strings
syn keyword alsaconfKeyword     subdevice type vars

syn match   alsaconfVariables   display '@\(hooks\|func\|args\)'

hi def link alsoconfTodo        Todo
hi def link alsaconfComment     Comment
hi def link alsaconfSpecialChar SpecialChar
hi def link alsaconfString      String
hi def link alsaconfSpecial     Special
hi def link alsaconfPreProc     PreProc
hi def link alsaconfMode        Special
hi def link alsaconfKeyword     Keyword
hi def link alsaconfVariables   Identifier

let b:current_syntax = "alsaconf"

let &cpo = s:cpo_save
unlet s:cpo_save
