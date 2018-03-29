" Vim syntax file
" Language:             aliases(5) local alias database file
" Previous Maintainer:  Nikolai Weibull <nikolai@bitwi.se>
" Latest Revision:      2008-04-14

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword mailaliasesTodo         contained TODO FIXME XXX NOTE

syn region  mailaliasesComment      display oneline start='^\s*#' end='$'
                                    \ contains=mailaliasesTodo,@Spell

syn match   mailaliasesBegin        display '^'
                                    \ nextgroup=mailaliasesName,
                                    \ mailaliasesComment

syn match   mailaliasesName         contained '[[:alnum:]\._-]\+'
                                    \ nextgroup=mailaliasesColon

syn region  mailaliasesName         contained oneline start=+"+
                                    \ skip=+\\\\\|\\"+ end=+"+
                                    \ nextgroup=mailaliasesColon

syn match   mailaliasesColon        contained ':'
                                    \ nextgroup=@mailaliasesValue
                                    \ skipwhite skipnl

syn cluster mailaliasesValue        contains=mailaliasesValueAddress,
                                    \ mailaliasesValueFile,
                                    \ mailaliasesValueCommand,
                                    \ mailaliasesValueInclude

syn match   mailaliasesValueAddress contained '[^ \t/|,]\+'
                                    \ nextgroup=mailaliasesValueSep
                                    \ skipwhite skipnl

syn match   mailaliasesValueFile    contained '/[^,]*'
                                    \ nextgroup=mailaliasesValueSep
                                    \ skipwhite skipnl

syn match   mailaliasesValueCommand contained '|[^,]*'
                                    \ nextgroup=mailaliasesValueSep
                                    \ skipwhite skipnl

syn match   mailaliasesValueInclude contained ':include:[^,]*'
                                    \ nextgroup=mailaliasesValueSep
                                    \ skipwhite skipnl

syn match   mailaliasesValueSep     contained ','
                                    \ nextgroup=@mailaliasesValue
                                    \ skipwhite skipnl

hi def link mailaliasesTodo         Todo
hi def link mailaliasesComment      Comment
hi def link mailaliasesName         Identifier
hi def link mailaliasesColon        Delimiter
hi def link mailaliasesValueAddress String
hi def link mailaliasesValueFile    String
hi def link mailaliasesValueCommand String
hi def link mailaliasesValueInclude PreProc
hi def link mailaliasesValueSep     Delimiter

let b:current_syntax = "mailaliases"

let &cpo = s:cpo_save
unlet s:cpo_save
