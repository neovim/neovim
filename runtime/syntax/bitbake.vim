" Vim syntax file
" Language:     BitBake bb/bbclasses/inc
" Author:       Chris Larson <kergoth@handhelds.org>
"               Ricardo Salveti <rsalveti@rsalveti.net>
" Copyright:    Copyright (C) 2004  Chris Larson <kergoth@handhelds.org>
"               Copyright (C) 2008  Ricardo Salveti <rsalveti@rsalveti.net>
" Last Change:  2022 Jul 25
" 2025 Oct 13 by Vim project: update multiline function syntax #18565
"
" This file is licensed under the MIT license, see COPYING.MIT in
" this source distribution for the terms.
"
" Syntax highlighting for bb, bbclasses and inc files.
"
" It's an entirely new type, just has specific syntax in shell and python code

if v:version < 600
    finish
endif
if exists("b:current_syntax")
    finish
endif

syn include @python syntax/python.vim
unlet! b:current_syntax

" BitBake syntax

" Matching case
syn case match

" Indicates the error when nothing is matched
syn match bbUnmatched           "."

" Comments
syn cluster bbCommentGroup      contains=bbTodo,@Spell
syn keyword bbTodo              COMBAK FIXME TODO XXX contained
syn match bbComment             "#.*$" contains=@bbCommentGroup

" String helpers
syn match bbQuote               +['"]+ contained 
syn match bbDelimiter           "[(){}=]" contained
syn match bbArrayBrackets       "[\[\]]" contained

" BitBake strings
syn match bbContinue            "\\$"
syn region bbString             matchgroup=bbQuote start=+"+ skip=+\\$+ end=+"+ contained contains=bbTodo,bbContinue,bbVarDeref,bbVarPyValue,@Spell
syn region bbString             matchgroup=bbQuote start=+'+ skip=+\\$+ end=+'+ contained contains=bbTodo,bbContinue,bbVarDeref,bbVarPyValue,@Spell

" Vars definition
syn match bbExport            "^export" nextgroup=bbIdentifier skipwhite
syn keyword bbExportFlag        export contained nextgroup=bbIdentifier skipwhite
syn match bbIdentifier          "[a-zA-Z0-9\-_\.\/\+]\+" display contained
syn match bbVarDeref            "${[a-zA-Z0-9\-_:\.\/\+]\+}" contained
syn match bbVarEq               "\(:=\|+=\|=+\|\.=\|=\.\|?=\|??=\|=\)" contained nextgroup=bbVarValue
syn match bbVarDef              "^\(export\s*\)\?\([a-zA-Z0-9\-_\.\/\+][${}a-zA-Z0-9\-_:\.\/\+]*\)\s*\(:=\|+=\|=+\|\.=\|=\.\|?=\|??=\|=\)\@=" contains=bbExportFlag,bbIdentifier,bbOverrideOperator,bbVarDeref nextgroup=bbVarEq
syn match bbVarValue            ".*$" contained contains=bbString,bbVarDeref,bbVarPyValue
syn region bbVarPyValue         start=+${@+ skip=+\\$+ end=+}+ contained contains=@python

" Vars metadata flags
syn match bbVarFlagDef          "^\([a-zA-Z0-9\-_\.]\+\)\(\[[a-zA-Z0-9\-_\.+]\+\]\)\@=" contains=bbIdentifier nextgroup=bbVarFlagFlag
syn region bbVarFlagFlag        matchgroup=bbArrayBrackets start="\[" end="\]\s*\(:=\|=\|.=\|=.|+=\|=+\|?=\)\@=" contained contains=bbIdentifier nextgroup=bbVarEq

" Includes and requires
syn keyword bbInclude           inherit include require contained 
syn match bbIncludeRest         ".*$" contained contains=bbString,bbVarDeref
syn match bbIncludeLine         "^\(inherit\|include\|require\)\s\+" contains=bbInclude nextgroup=bbIncludeRest

" Add taks and similar
syn keyword bbStatement         addtask deltask addhandler after before EXPORT_FUNCTIONS contained
syn match bbStatementRest       ".*$" skipwhite contained contains=bbStatement
syn match bbStatementLine       "^\(addtask\|deltask\|addhandler\|after\|before\|EXPORT_FUNCTIONS\)\s\+" contains=bbStatement nextgroup=bbStatementRest

" OE Important Functions
syn keyword bbOEFunctions       do_fetch do_unpack do_patch do_configure do_compile do_stage do_install do_package contained

" Generic Functions
syn match bbFunction            "\h[0-9A-Za-z_\-\.]*" display contained contains=bbOEFunctions

syn keyword bbOverrideOperator  append prepend remove contained

" BitBake shell metadata
syn include @shell syntax/sh.vim
unlet! b:current_syntax

syn keyword bbShFakeRootFlag    fakeroot contained
syn match bbShFuncDef           "^\(fakeroot\s*\)\?\([\.0-9A-Za-z_:${}\-\.]\+\)\(python\)\@<!\(\s*()\s*\)\({\)\@=" contains=bbShFakeRootFlag,bbFunction,bbOverrideOperator,bbVarDeref,bbDelimiter nextgroup=bbShFuncRegion skipwhite
syn region bbShFuncRegion       matchgroup=bbDelimiter start="{\s*$" end="^}\s*$" contained contains=@shell

" Python value inside shell functions
syn region shDeref         start=+${@+ skip=+\\$+ excludenl end=+}+ contained contains=@python

" BitBake python metadata
syn keyword bbPyFlag            python contained
syn match bbPyFuncDef           "^\(fakeroot\s*\)\?\(python\)\(\s\+[0-9A-Za-z_:${}\-\.]\+\)\?\(\s*()\s*\)\({\)\@=" contains=bbShFakeRootFlag,bbPyFlag,bbFunction,bbOverrideOperator,bbVarDeref,bbDelimiter nextgroup=bbPyFuncRegion skipwhite
syn region bbPyFuncRegion       matchgroup=bbDelimiter start="{\s*$" end="^}\s*$" contained contains=@python

" BitBake 'def'd python functions
syn keyword bbPyDef             def contained
syn region bbPyDefRegion        start='^\(def\s\+\)\([0-9A-Za-z_-]\+\)\(\s*(\_.*)\s*\):\s*$' end='^\(\s\|$\)\@!' contains=@python

" Highlighting Definitions
hi def link bbUnmatched         Error
hi def link bbInclude           Include
hi def link bbTodo              Todo
hi def link bbComment           Comment
hi def link bbQuote             String
hi def link bbString            String
hi def link bbDelimiter         Keyword
hi def link bbArrayBrackets     Statement
hi def link bbContinue          Special
hi def link bbExport            Type
hi def link bbExportFlag        Type
hi def link bbIdentifier	    Identifier
hi def link bbVarDeref          PreProc
hi def link bbVarDef            Identifier
hi def link bbVarValue          String
hi def link bbShFakeRootFlag    Type
hi def link bbFunction          Function
hi def link bbPyFlag            Type
hi def link bbPyDef             Statement
hi def link bbStatement         Statement
hi def link bbStatementRest     Identifier
hi def link bbOEFunctions       Special
hi def link bbVarPyValue        PreProc
hi def link bbOverrideOperator  Operator

let b:current_syntax = "bitbake"
