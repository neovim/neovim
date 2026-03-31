" Vim syntax file
" Language:             a2ps(1) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword a2psPreProc       Include
                              \ nextgroup=a2psKeywordColon

syn keyword a2psMacro         UserOption
                              \ nextgroup=a2psKeywordColon

syn keyword a2psKeyword       LibraryPath AppendLibraryPath PrependLibraryPath
                              \ Options Medium Printer UnknownPrinter
                              \ DefaultPrinter OutputFirstLine
                              \ PageLabelFormat Delegation FileCommand
                              \ nextgroup=a2psKeywordColon

syn match   a2psKeywordColon  contained display ':'

syn keyword a2psKeyword       Variable nextgroup=a2psVariableColon

syn match   a2psVariableColon contained display ':'
                              \ nextgroup=a2psVariable skipwhite

syn match   a2psVariable      contained display '[^ \t:(){}]\+'
                              \ contains=a2psVarPrefix

syn match   a2psVarPrefix     contained display
                              \ '\<\%(del\|pro\|ps\|pl\|toc\|user\|\)\ze\.'

syn match   a2psLineCont      display '\\$'

syn match   a2psSubst         display '$\%(-\=.\=\d\+\)\=\h\d\='
syn match   a2psSubst         display '#[?!]\=\w\d\='
syn match   a2psSubst         display '#{[^}]\+}'

syn region  a2psString        display oneline start=+'+ end=+'+
                              \ contains=a2psSubst

syn region  a2psString        display oneline start=+"+ end=+"+
                              \ contains=a2psSubst

syn keyword a2psTodo          contained TODO FIXME XXX NOTE

syn region  a2psComment       display oneline start='^\s*#' end='$'
                              \ contains=a2psTodo,@Spell

hi def link a2psTodo          Todo
hi def link a2psComment       Comment
hi def link a2psPreProc       PreProc
hi def link a2psMacro         Macro
hi def link a2psKeyword       Keyword
hi def link a2psKeywordColon  Delimiter
hi def link a2psVariableColon Delimiter
hi def link a2psVariable      Identifier
hi def link a2psVarPrefix     Type
hi def link a2psLineCont      Special
hi def link a2psSubst         PreProc
hi def link a2psString        String

let b:current_syntax = "a2ps"

let &cpo = s:cpo_save
unlet s:cpo_save
