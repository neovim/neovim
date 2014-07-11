" Vim syntax file
" Language:         sysctl.conf(5) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2011-05-02

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   sysctlBegin   display '^'
                          \ nextgroup=sysctlToken,sysctlComment skipwhite

syn match   sysctlToken   contained display '[^=]\+'
                          \ nextgroup=sysctlTokenEq skipwhite

syn match   sysctlTokenEq contained display '=' nextgroup=sysctlValue skipwhite

syn region  sysctlValue   contained display oneline
                          \ matchgroup=sysctlValue start='\S'
                          \ matchgroup=Normal end='\s*$'

syn keyword sysctlTodo    contained TODO FIXME XXX NOTE

syn region  sysctlComment display oneline start='^\s*[#;]' end='$'
                          \ contains=sysctlTodo,@Spell

hi def link sysctlTodo    Todo
hi def link sysctlComment Comment
hi def link sysctlToken   Identifier
hi def link sysctlTokenEq Operator
hi def link sysctlValue   String

let b:current_syntax = "sysctl"

let &cpo = s:cpo_save
unlet s:cpo_save
