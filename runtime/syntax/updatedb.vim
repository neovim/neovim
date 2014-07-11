" Vim syntax file
" Language:         updatedb.conf(5) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2009-05-25

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword updatedbTodo    contained TODO FIXME XXX NOTE

syn region  updatedbComment display oneline start='^\s*#' end='$'
                            \ contains=updatedbTodo,@Spell

syn match   updatedbBegin   display '^'
                            \ nextgroup=updatedbName,updatedbComment skipwhite

syn keyword updatedbName    contained
                            \ PRUNEFS
                            \ PRUNENAMES
                            \ PRUNEPATHS
                            \ PRUNE_BIND_MOUNTS
                            \ nextgroup=updatedbNameEq

syn match   updatedbNameEq  contained display '=' nextgroup=updatedbValue

syn region  updatedbValue   contained display oneline start='"' end='"'

hi def link updatedbTodo    Todo
hi def link updatedbComment Comment
hi def link updatedbName    Identifier
hi def link updatedbNameEq  Operator
hi def link updatedbValue   String

let b:current_syntax = "updatedb"

let &cpo = s:cpo_save
unlet s:cpo_save
