" Vim syntax file
" Language:         udev(8) rules file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-12-18

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" TODO: Line continuations.

syn keyword udevrulesTodo       contained TODO FIXME XXX NOTE

syn region  udevrulesComment    display oneline start='^\s*#' end='$'
                                \ contains=udevrulesTodo,@Spell

syn keyword udevrulesRuleKey    ACTION DEVPATH KERNEL SUBSYSTEM KERNELS
                                \ SUBSYSTEMS DRIVERS RESULT
                                \ nextgroup=udevrulesRuleTest
                                \ skipwhite

syn keyword udevrulesRuleKey    ATTRS nextgroup=udevrulesAttrsPath

syn region  udevrulesAttrsPath  display transparent
                                \ matchgroup=udevrulesDelimiter start='{'
                                \ matchgroup=udevrulesDelimiter end='}'
                                \ contains=udevrulesPath
                                \ nextgroup=udevrulesRuleTest
                                \ skipwhite

syn keyword udevrulesRuleKey    ENV nextgroup=udevrulesEnvVar

syn region  udevrulesEnvVar     display transparent
                                \ matchgroup=udevrulesDelimiter start='{'
                                \ matchgroup=udevrulesDelimiter end='}'
                                \ contains=udevrulesVariable
                                \ nextgroup=udevrulesRuleTest,udevrulesRuleEq
                                \ skipwhite

syn keyword udevrulesRuleKey    PROGRAM RESULT
                                \ nextgroup=udevrulesEStringTest,udevrulesEStringEq
                                \ skipwhite

syn keyword udevrulesAssignKey  NAME SYMLINK OWNER GROUP RUN
                                \ nextgroup=udevrulesEStringEq
                                \ skipwhite

syn keyword udevrulesAssignKey  MODE LABEL GOTO WAIT_FOR_SYSFS
                                \ nextgroup=udevrulesRuleEq
                                \ skipwhite

syn keyword udevrulesAssignKey  ATTR nextgroup=udevrulesAttrsPath

syn region  udevrulesAttrKey    display transparent
                                \ matchgroup=udevrulesDelimiter start='{'
                                \ matchgroup=udevrulesDelimiter end='}'
                                \ contains=udevrulesKey
                                \ nextgroup=udevrulesRuleEq
                                \ skipwhite

syn keyword udevrulesAssignKey  IMPORT nextgroup=udevrulesImport,
                                \ udevrulesEStringEq
                                \ skipwhite

syn region  udevrulesImport     display transparent
                                \ matchgroup=udevrulesDelimiter start='{'
                                \ matchgroup=udevrulesDelimiter end='}'
                                \ contains=udevrulesImportType
                                \ nextgroup=udevrulesEStringEq
                                \ skipwhite

syn keyword udevrulesImportType program file parent

syn keyword udevrulesAssignKey  OPTIONS
                                \ nextgroup=udevrulesOptionsEq

syn match   udevrulesPath       contained display '[^}]\+'

syn match   udevrulesVariable   contained display '[^}]\+'

syn match   udevrulesRuleTest   contained display '[=!:]='
                                \ nextgroup=udevrulesString skipwhite

syn match   udevrulesEStringTest contained display '[=!+:]='
                                \ nextgroup=udevrulesEString skipwhite

syn match   udevrulesRuleEq     contained display '+=\|=\ze[^=]'
                                \ nextgroup=udevrulesString skipwhite

syn match   udevrulesEStringEq  contained '+=\|=\ze[^=]'
                                \ nextgroup=udevrulesEString skipwhite

syn match   udevrulesOptionsEq  contained '+=\|=\ze[^=]'
                                \ nextgroup=udevrulesOptions skipwhite

syn region  udevrulesEString    contained display oneline start=+"+ end=+"+
                                \ contains=udevrulesStrEscapes,udevrulesStrVars

syn match   udevrulesStrEscapes contained '%[knpbMmcPrN%]'

" TODO: This can actually stand alone (without {…}), so add a nextgroup here.
syn region  udevrulesStrEscapes contained start='%c{' end='}'
                                \ contains=udevrulesStrNumber

syn region  udevrulesStrEscapes contained start='%s{' end='}'
                                \ contains=udevrulesPath

syn region  udevrulesStrEscapes contained start='%E{' end='}'
                                \ contains=udevrulesVariable

syn match   udevrulesStrNumber  contained '\d\++\='

syn match   udevrulesStrVars    contained display '$\%(kernel\|number\|devpath\|id\|major\|minor\|result\|parent\|root\|tempnode\)\>'

syn region  udevrulesStrVars    contained start='$attr{' end='}'
                                \ contains=udevrulesPath

syn region  udevrulesStrVars    contained start='$env{' end='}'
                                \ contains=udevrulesVariable

syn match   udevrulesStrVars    contained display '\$\$'

syn region  udevrulesString     contained display oneline start=+"+ end=+"+
                                \ contains=udevrulesPattern

syn match   udevrulesPattern    contained '[*?]'
syn region  udevrulesPattern    contained start='\[!\=' end='\]'
                                \ contains=udevrulesPatRange

syn match   udevrulesPatRange   contained '[^[-]-[^]-]'

syn region  udevrulesOptions    contained display oneline start=+"+ end=+"+
                                \ contains=udevrulesOption,udevrulesOptionSep

syn keyword udevrulesOption     contained last_rule ignore_device ignore_remove
                                \ all_partitions

syn match   udevrulesOptionSep  contained ','

hi def link udevrulesTodo       Todo
hi def link udevrulesComment    Comment
hi def link udevrulesRuleKey    Keyword
hi def link udevrulesDelimiter  Delimiter
hi def link udevrulesAssignKey  Identifier
hi def link udevrulesPath       Identifier
hi def link udevrulesVariable   Identifier
hi def link udevrulesAttrKey    Identifier
" XXX: setting this to Operator makes for extremely intense highlighting.
hi def link udevrulesEq         Normal
hi def link udevrulesRuleEq     udevrulesEq
hi def link udevrulesEStringEq  udevrulesEq
hi def link udevrulesOptionsEq  udevrulesEq
hi def link udevrulesEString    udevrulesString
hi def link udevrulesStrEscapes SpecialChar
hi def link udevrulesStrNumber  Number
hi def link udevrulesStrVars    Identifier
hi def link udevrulesString     String
hi def link udevrulesPattern    SpecialChar
hi def link udevrulesPatRange   SpecialChar
hi def link udevrulesOptions    udevrulesString
hi def link udevrulesOption     Type
hi def link udevrulesOptionSep  Delimiter
hi def link udevrulesImportType Type

let b:current_syntax = "udevrules"

let &cpo = s:cpo_save
unlet s:cpo_save
