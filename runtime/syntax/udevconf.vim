" Vim syntax file
" Language:             udev(8) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword udevconfTodo        contained TODO FIXME XXX NOTE

syn region  udevconfComment     display oneline start='^\s*#' end='$'
                                \ contains=udevconfTodo,@Spell

syn match   udevconfBegin       display '^'
                                \ nextgroup=udevconfVariable,udevconfComment
                                \ skipwhite

syn keyword udevconfVariable    contained udev_root udev_db udev_rules udev_log
                                \ nextgroup=udevconfVariableEq

syn match   udevconfVariableEq  contained '[[:space:]=]'
                                \ nextgroup=udevconfString skipwhite

syn region  udevconfString      contained display oneline start=+"+ end=+"+

hi def link udevconfTodo        Todo
hi def link udevconfComment     Comment
hi def link udevconfVariable    Identifier
hi def link udevconfVariableEq  Operator
hi def link udevconfString      String

let b:current_syntax = "udevconf"

let &cpo = s:cpo_save
unlet s:cpo_save
