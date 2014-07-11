" Vim syntax file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2009-05-25

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

if exists("g:kconfig_syntax_heavy")

syn match   kconfigBegin              '^' nextgroup=kconfigKeyword
                                      \ skipwhite

syn keyword kconfigTodo               contained TODO FIXME XXX NOTE

syn match   kconfigComment            display '#.*$' contains=kconfigTodo

syn keyword kconfigKeyword            config nextgroup=kconfigSymbol
                                      \ skipwhite

syn keyword kconfigKeyword            menuconfig nextgroup=kconfigSymbol
                                      \ skipwhite

syn keyword kconfigKeyword            comment menu mainmenu
                                      \ nextgroup=kconfigKeywordPrompt
                                      \ skipwhite

syn keyword kconfigKeyword            choice
                                      \ nextgroup=@kconfigConfigOptions
                                      \ skipwhite skipnl

syn keyword kconfigKeyword            endmenu endchoice

syn keyword kconfigPreProc            source
                                      \ nextgroup=kconfigPath
                                      \ skipwhite

" TODO: This is a hack.  The who .*Expr stuff should really be generated so
" that we can reuse it for various nextgroups.
syn keyword kconfigConditional        if endif
                                      \ nextgroup=@kconfigConfigOptionIfExpr
                                      \ skipwhite

syn match   kconfigKeywordPrompt      '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigPath               '"[^"\\]*\%(\\.[^"\\]*\)*"\|\S\+'
                                      \ contained

syn match   kconfigSymbol             '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptions
                                      \ skipwhite skipnl

" FIXME: There is – probably – no reason to cluster these instead of just
" defining them in the same group.
syn cluster kconfigConfigOptions      contains=kconfigTypeDefinition,
                                      \        kconfigInputPrompt,
                                      \        kconfigDefaultValue,
                                      \        kconfigDependencies,
                                      \        kconfigReverseDependencies,
                                      \        kconfigNumericalRanges,
                                      \        kconfigHelpText,
                                      \        kconfigDefBool,
                                      \        kconfigOptional

syn keyword kconfigTypeDefinition     bool boolean tristate string hex int
                                      \ contained
                                      \ nextgroup=kconfigTypeDefPrompt,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigTypeDefPrompt      '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigTypeDefPrompt      "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn keyword kconfigInputPrompt        prompt
                                      \ contained
                                      \ nextgroup=kconfigPromptPrompt
                                      \ skipwhite

syn match   kconfigPromptPrompt       '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigPromptPrompt       "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn keyword   kconfigDefaultValue     default
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionExpr
                                      \ skipwhite

syn match   kconfigDependencies       'depends on\|requires'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionIfExpr
                                      \ skipwhite

syn keyword kconfigReverseDependencies select
                                      \ contained
                                      \ nextgroup=@kconfigRevDepSymbol
                                      \ skipwhite

syn cluster kconfigRevDepSymbol       contains=kconfigRevDepCSymbol,
                                      \        kconfigRevDepNCSymbol

syn match   kconfigRevDepCSymbol      '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigRevDepCSymbol      "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigRevDepNCSymbol     '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn keyword kconfigNumericalRanges    range
                                      \ contained
                                      \ nextgroup=@kconfigRangeSymbol
                                      \ skipwhite

syn cluster kconfigRangeSymbol        contains=kconfigRangeCSymbol,
                                      \        kconfigRangeNCSymbol

syn match   kconfigRangeCSymbol       '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=@kconfigRangeSymbol2
                                      \ skipwhite skipnl

syn match   kconfigRangeCSymbol       "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=@kconfigRangeSymbol2
                                      \ skipwhite skipnl

syn match   kconfigRangeNCSymbol      '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=@kconfigRangeSymbol2
                                      \ skipwhite skipnl

syn cluster kconfigRangeSymbol2       contains=kconfigRangeCSymbol2,
                                      \        kconfigRangeNCSymbol2

syn match   kconfigRangeCSymbol2      "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigRangeNCSymbol2     '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn region  kconfigHelpText           contained
      \ matchgroup=kconfigConfigOption
      \ start='\%(help\|---help---\)\ze\s*\n\z(\s\+\)'
      \ skip='^$'
      \ end='^\z1\@!'
      \ nextgroup=@kconfigConfigOptions
      \ skipwhite skipnl

" XXX: Undocumented
syn keyword kconfigDefBool            def_bool
                                      \ contained
                                      \ nextgroup=@kconfigDefBoolSymbol
                                      \ skipwhite

syn cluster kconfigDefBoolSymbol      contains=kconfigDefBoolCSymbol,
                                      \        kconfigDefBoolNCSymbol

syn match   kconfigDefBoolCSymbol     '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigDefBoolCSymbol     "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigDefBoolNCSymbol    '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

" XXX: This is actually only a valid option for “choice”, but treating it
" specially would require a lot of extra groups.
syn keyword kconfigOptional           optional
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptions
                                      \ skipwhite skipnl

syn keyword kconfigConfigOptionIf     if
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionIfExpr
                                      \ skipwhite

syn cluster kconfigConfigOptionIfExpr contains=@kconfigConfOptIfExprSym,
                                      \        kconfigConfOptIfExprNeg,
                                      \        kconfigConfOptIfExprGroup

syn cluster kconfigConfOptIfExprSym   contains=kconfigConfOptIfExprCSym,
                                      \        kconfigConfOptIfExprNCSym

syn match   kconfigConfOptIfExprCSym  '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptions,
                                      \           kconfigConfOptIfExprAnd,
                                      \           kconfigConfOptIfExprOr,
                                      \           kconfigConfOptIfExprEq,
                                      \           kconfigConfOptIfExprNEq
                                      \ skipwhite skipnl

syn match   kconfigConfOptIfExprCSym  "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptions,
                                      \           kconfigConfOptIfExprAnd,
                                      \           kconfigConfOptIfExprOr,
                                      \           kconfigConfOptIfExprEq,
                                      \           kconfigConfOptIfExprNEq
                                      \ skipwhite skipnl

syn match   kconfigConfOptIfExprNCSym '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptions,
                                      \           kconfigConfOptIfExprAnd,
                                      \           kconfigConfOptIfExprOr,
                                      \           kconfigConfOptIfExprEq,
                                      \           kconfigConfOptIfExprNEq
                                      \ skipwhite skipnl

syn cluster kconfigConfOptIfExprSym2  contains=kconfigConfOptIfExprCSym2,
                                      \        kconfigConfOptIfExprNCSym2

syn match   kconfigConfOptIfExprEq    '='
                                      \ contained
                                      \ nextgroup=@kconfigConfOptIfExprSym2
                                      \ skipwhite

syn match   kconfigConfOptIfExprNEq   '!='
                                      \ contained
                                      \ nextgroup=@kconfigConfOptIfExprSym2
                                      \ skipwhite

syn match   kconfigConfOptIfExprCSym2 "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptions,
                                      \           kconfigConfOptIfExprAnd,
                                      \           kconfigConfOptIfExprOr
                                      \ skipwhite skipnl

syn match   kconfigConfOptIfExprNCSym2 '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptions,
                                      \           kconfigConfOptIfExprAnd,
                                      \           kconfigConfOptIfExprOr
                                      \ skipwhite skipnl

syn match   kconfigConfOptIfExprNeg   '!'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionIfExpr
                                      \ skipwhite

syn match   kconfigConfOptIfExprAnd   '&&'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionIfExpr
                                      \ skipwhite

syn match   kconfigConfOptIfExprOr    '||'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionIfExpr
                                      \ skipwhite

syn match   kconfigConfOptIfExprGroup '('
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionIfGExp
                                      \ skipwhite

" TODO: hm, this kind of recursion doesn't work right.  We need another set of
" expressions that have kconfigConfigOPtionIfGExp as nextgroup and a matcher
" for '(' that sets it all off.
syn cluster kconfigConfigOptionIfGExp contains=@kconfigConfOptIfGExpSym,
                                      \        kconfigConfOptIfGExpNeg,
                                      \        kconfigConfOptIfExprGroup

syn cluster kconfigConfOptIfGExpSym   contains=kconfigConfOptIfGExpCSym,
                                      \        kconfigConfOptIfGExpNCSym

syn match   kconfigConfOptIfGExpCSym  '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=@kconfigConfigIf,
                                      \           kconfigConfOptIfGExpAnd,
                                      \           kconfigConfOptIfGExpOr,
                                      \           kconfigConfOptIfGExpEq,
                                      \           kconfigConfOptIfGExpNEq
                                      \ skipwhite skipnl

syn match   kconfigConfOptIfGExpCSym  "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=@kconfigConfigIf,
                                      \           kconfigConfOptIfGExpAnd,
                                      \           kconfigConfOptIfGExpOr,
                                      \           kconfigConfOptIfGExpEq,
                                      \           kconfigConfOptIfGExpNEq
                                      \ skipwhite skipnl

syn match   kconfigConfOptIfGExpNCSym '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=kconfigConfOptIfExprGrpE,
                                      \           kconfigConfOptIfGExpAnd,
                                      \           kconfigConfOptIfGExpOr,
                                      \           kconfigConfOptIfGExpEq,
                                      \           kconfigConfOptIfGExpNEq
                                      \ skipwhite skipnl

syn cluster kconfigConfOptIfGExpSym2  contains=kconfigConfOptIfGExpCSym2,
                                      \        kconfigConfOptIfGExpNCSym2

syn match   kconfigConfOptIfGExpEq    '='
                                      \ contained
                                      \ nextgroup=@kconfigConfOptIfGExpSym2
                                      \ skipwhite

syn match   kconfigConfOptIfGExpNEq   '!='
                                      \ contained
                                      \ nextgroup=@kconfigConfOptIfGExpSym2
                                      \ skipwhite

syn match   kconfigConfOptIfGExpCSym2 '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=kconfigConfOptIfExprGrpE,
                                      \           kconfigConfOptIfGExpAnd,
                                      \           kconfigConfOptIfGExpOr
                                      \ skipwhite skipnl

syn match   kconfigConfOptIfGExpCSym2 "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfOptIfExprGrpE,
                                      \           kconfigConfOptIfGExpAnd,
                                      \           kconfigConfOptIfGExpOr
                                      \ skipwhite skipnl

syn match   kconfigConfOptIfGExpNCSym2 '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=kconfigConfOptIfExprGrpE,
                                      \           kconfigConfOptIfGExpAnd,
                                      \           kconfigConfOptIfGExpOr
                                      \ skipwhite skipnl

syn match   kconfigConfOptIfGExpNeg   '!'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionIfGExp
                                      \ skipwhite

syn match   kconfigConfOptIfGExpAnd   '&&'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionIfGExp
                                      \ skipwhite

syn match   kconfigConfOptIfGExpOr    '||'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionIfGExp
                                      \ skipwhite

syn match   kconfigConfOptIfExprGrpE  ')'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptions,
                                      \           kconfigConfOptIfExprAnd,
                                      \           kconfigConfOptIfExprOr
                                      \ skipwhite skipnl


syn cluster kconfigConfigOptionExpr   contains=@kconfigConfOptExprSym,
                                      \        kconfigConfOptExprNeg,
                                      \        kconfigConfOptExprGroup

syn cluster kconfigConfOptExprSym     contains=kconfigConfOptExprCSym,
                                      \        kconfigConfOptExprNCSym

syn match   kconfigConfOptExprCSym    '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           kconfigConfOptExprAnd,
                                      \           kconfigConfOptExprOr,
                                      \           kconfigConfOptExprEq,
                                      \           kconfigConfOptExprNEq,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigConfOptExprCSym    "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           kconfigConfOptExprAnd,
                                      \           kconfigConfOptExprOr,
                                      \           kconfigConfOptExprEq,
                                      \           kconfigConfOptExprNEq,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigConfOptExprNCSym   '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           kconfigConfOptExprAnd,
                                      \           kconfigConfOptExprOr,
                                      \           kconfigConfOptExprEq,
                                      \           kconfigConfOptExprNEq,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn cluster kconfigConfOptExprSym2    contains=kconfigConfOptExprCSym2,
                                      \        kconfigConfOptExprNCSym2

syn match   kconfigConfOptExprEq      '='
                                      \ contained
                                      \ nextgroup=@kconfigConfOptExprSym2
                                      \ skipwhite

syn match   kconfigConfOptExprNEq     '!='
                                      \ contained
                                      \ nextgroup=@kconfigConfOptExprSym2
                                      \ skipwhite

syn match   kconfigConfOptExprCSym2   '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           kconfigConfOptExprAnd,
                                      \           kconfigConfOptExprOr,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigConfOptExprCSym2   "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           kconfigConfOptExprAnd,
                                      \           kconfigConfOptExprOr,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigConfOptExprNCSym2  '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           kconfigConfOptExprAnd,
                                      \           kconfigConfOptExprOr,
                                      \           @kconfigConfigOptions
                                      \ skipwhite skipnl

syn match   kconfigConfOptExprNeg     '!'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionExpr
                                      \ skipwhite

syn match   kconfigConfOptExprAnd     '&&'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionExpr
                                      \ skipwhite

syn match   kconfigConfOptExprOr      '||'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionExpr
                                      \ skipwhite

syn match   kconfigConfOptExprGroup   '('
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionGExp
                                      \ skipwhite

syn cluster kconfigConfigOptionGExp   contains=@kconfigConfOptGExpSym,
                                      \        kconfigConfOptGExpNeg,
                                      \        kconfigConfOptGExpGroup

syn cluster kconfigConfOptGExpSym     contains=kconfigConfOptGExpCSym,
                                      \        kconfigConfOptGExpNCSym

syn match   kconfigConfOptGExpCSym    '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=kconfigConfOptExprGrpE,
                                      \           kconfigConfOptGExpAnd,
                                      \           kconfigConfOptGExpOr,
                                      \           kconfigConfOptGExpEq,
                                      \           kconfigConfOptGExpNEq
                                      \ skipwhite skipnl

syn match   kconfigConfOptGExpCSym    "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfOptExprGrpE,
                                      \           kconfigConfOptGExpAnd,
                                      \           kconfigConfOptGExpOr,
                                      \           kconfigConfOptGExpEq,
                                      \           kconfigConfOptGExpNEq
                                      \ skipwhite skipnl

syn match   kconfigConfOptGExpNCSym   '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=kconfigConfOptExprGrpE,
                                      \           kconfigConfOptGExpAnd,
                                      \           kconfigConfOptGExpOr,
                                      \           kconfigConfOptGExpEq,
                                      \           kconfigConfOptGExpNEq
                                      \ skipwhite skipnl

syn cluster kconfigConfOptGExpSym2    contains=kconfigConfOptGExpCSym2,
                                      \        kconfigConfOptGExpNCSym2

syn match   kconfigConfOptGExpEq      '='
                                      \ contained
                                      \ nextgroup=@kconfigConfOptGExpSym2
                                      \ skipwhite

syn match   kconfigConfOptGExpNEq     '!='
                                      \ contained
                                      \ nextgroup=@kconfigConfOptGExpSym2
                                      \ skipwhite

syn match   kconfigConfOptGExpCSym2   '"[^"\\]*\%(\\.[^"\\]*\)*"'
                                      \ contained
                                      \ nextgroup=kconfigConfOptExprGrpE,
                                      \           kconfigConfOptGExpAnd,
                                      \           kconfigConfOptGExpOr
                                      \ skipwhite skipnl

syn match   kconfigConfOptGExpCSym2   "'[^'\\]*\%(\\.[^'\\]*\)*'"
                                      \ contained
                                      \ nextgroup=kconfigConfOptExprGrpE,
                                      \           kconfigConfOptGExpAnd,
                                      \           kconfigConfOptGExpOr
                                      \ skipwhite skipnl

syn match   kconfigConfOptGExpNCSym2  '\<\k\+\>'
                                      \ contained
                                      \ nextgroup=kconfigConfOptExprGrpE,
                                      \           kconfigConfOptGExpAnd,
                                      \           kconfigConfOptGExpOr
                                      \ skipwhite skipnl

syn match   kconfigConfOptGExpNeg     '!'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionGExp
                                      \ skipwhite

syn match   kconfigConfOptGExpAnd     '&&'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionGExp
                                      \ skipwhite

syn match   kconfigConfOptGExpOr      '||'
                                      \ contained
                                      \ nextgroup=@kconfigConfigOptionGExp
                                      \ skipwhite

syn match   kconfigConfOptExprGrpE    ')'
                                      \ contained
                                      \ nextgroup=kconfigConfigOptionIf,
                                      \           kconfigConfOptExprAnd,
                                      \           kconfigConfOptExprOr
                                      \ skipwhite skipnl

syn sync minlines=50

hi def link kconfigTodo                 Todo
hi def link kconfigComment              Comment
hi def link kconfigKeyword              Keyword
hi def link kconfigPreProc              PreProc
hi def link kconfigConditional          Conditional
hi def link kconfigPrompt               String
hi def link kconfigKeywordPrompt        kconfigPrompt
hi def link kconfigPath                 String
hi def link kconfigSymbol               String
hi def link kconfigConstantSymbol       Constant
hi def link kconfigConfigOption         Type
hi def link kconfigTypeDefinition       kconfigConfigOption
hi def link kconfigTypeDefPrompt        kconfigPrompt
hi def link kconfigInputPrompt          kconfigConfigOption
hi def link kconfigPromptPrompt         kconfigPrompt
hi def link kconfigDefaultValue         kconfigConfigOption
hi def link kconfigDependencies         kconfigConfigOption
hi def link kconfigReverseDependencies  kconfigConfigOption
hi def link kconfigRevDepCSymbol        kconfigConstantSymbol
hi def link kconfigRevDepNCSymbol       kconfigSymbol
hi def link kconfigNumericalRanges      kconfigConfigOption
hi def link kconfigRangeCSymbol         kconfigConstantSymbol
hi def link kconfigRangeNCSymbol        kconfigSymbol
hi def link kconfigRangeCSymbol2        kconfigConstantSymbol
hi def link kconfigRangeNCSymbol2       kconfigSymbol
hi def link kconfigHelpText             Normal
hi def link kconfigDefBool              kconfigConfigOption
hi def link kconfigDefBoolCSymbol       kconfigConstantSymbol
hi def link kconfigDefBoolNCSymbol      kconfigSymbol
hi def link kconfigOptional             kconfigConfigOption
hi def link kconfigConfigOptionIf       Conditional
hi def link kconfigConfOptIfExprCSym    kconfigConstantSymbol
hi def link kconfigConfOptIfExprNCSym   kconfigSymbol
hi def link kconfigOperator             Operator
hi def link kconfigConfOptIfExprEq      kconfigOperator
hi def link kconfigConfOptIfExprNEq     kconfigOperator
hi def link kconfigConfOptIfExprCSym2   kconfigConstantSymbol
hi def link kconfigConfOptIfExprNCSym2  kconfigSymbol
hi def link kconfigConfOptIfExprNeg     kconfigOperator
hi def link kconfigConfOptIfExprAnd     kconfigOperator
hi def link kconfigConfOptIfExprOr      kconfigOperator
hi def link kconfigDelimiter            Delimiter
hi def link kconfigConfOptIfExprGroup   kconfigDelimiter
hi def link kconfigConfOptIfGExpCSym    kconfigConstantSymbol
hi def link kconfigConfOptIfGExpNCSym   kconfigSymbol
hi def link kconfigConfOptIfGExpEq      kconfigOperator
hi def link kconfigConfOptIfGExpNEq     kconfigOperator
hi def link kconfigConfOptIfGExpCSym2   kconfigConstantSymbol
hi def link kconfigConfOptIfGExpNCSym2  kconfigSymbol
hi def link kconfigConfOptIfGExpNeg     kconfigOperator
hi def link kconfigConfOptIfGExpAnd     kconfigOperator
hi def link kconfigConfOptIfGExpOr      kconfigOperator
hi def link kconfigConfOptIfExprGrpE    kconfigDelimiter
hi def link kconfigConfOptExprCSym      kconfigConstantSymbol
hi def link kconfigConfOptExprNCSym     kconfigSymbol
hi def link kconfigConfOptExprEq        kconfigOperator
hi def link kconfigConfOptExprNEq       kconfigOperator
hi def link kconfigConfOptExprCSym2     kconfigConstantSymbol
hi def link kconfigConfOptExprNCSym2    kconfigSymbol
hi def link kconfigConfOptExprNeg       kconfigOperator
hi def link kconfigConfOptExprAnd       kconfigOperator
hi def link kconfigConfOptExprOr        kconfigOperator
hi def link kconfigConfOptExprGroup     kconfigDelimiter
hi def link kconfigConfOptGExpCSym      kconfigConstantSymbol
hi def link kconfigConfOptGExpNCSym     kconfigSymbol
hi def link kconfigConfOptGExpEq        kconfigOperator
hi def link kconfigConfOptGExpNEq       kconfigOperator
hi def link kconfigConfOptGExpCSym2     kconfigConstantSymbol
hi def link kconfigConfOptGExpNCSym2    kconfigSymbol
hi def link kconfigConfOptGExpNeg       kconfigOperator
hi def link kconfigConfOptGExpAnd       kconfigOperator
hi def link kconfigConfOptGExpOr        kconfigOperator
hi def link kconfigConfOptExprGrpE      kconfigConfOptIfExprGroup

else

syn keyword kconfigTodo               contained TODO FIXME XXX NOTE

syn match   kconfigComment            display '#.*$' contains=kconfigTodo

syn keyword kconfigKeyword            config menuconfig comment mainmenu

syn keyword kconfigConditional        menu endmenu choice endchoice if endif

syn keyword kconfigPreProc            source
                                      \ nextgroup=kconfigPath
                                      \ skipwhite

syn keyword kconfigTriState           y m n

syn match   kconfigSpecialChar        contained '\\.'
syn match   kconfigSpecialChar        '\\$'

syn region  kconfigPath               matchgroup=kconfigPath
                                      \ start=+"+ skip=+\\\\\|\\\"+ end=+"+
                                      \ contains=kconfigSpecialChar

syn region  kconfigPath               matchgroup=kconfigPath
                                      \ start=+'+ skip=+\\\\\|\\\'+ end=+'+
                                      \ contains=kconfigSpecialChar

syn match   kconfigPath               '\S\+'
                                      \ contained

syn region  kconfigString             matchgroup=kconfigString
                                      \ start=+"+ skip=+\\\\\|\\\"+ end=+"+
                                      \ contains=kconfigSpecialChar

syn region  kconfigString             matchgroup=kconfigString
                                      \ start=+'+ skip=+\\\\\|\\\'+ end=+'+
                                      \ contains=kconfigSpecialChar

syn keyword kconfigType               bool boolean tristate string hex int

syn keyword kconfigOption             prompt default requires select range
                                      \ optional
syn match   kconfigOption             'depends\%( on\)\='

syn keyword kconfigMacro              def_bool def_tristate

syn region  kconfigHelpText
      \ matchgroup=kconfigOption
      \ start='\%(help\|---help---\)\ze\s*\n\z(\s\+\)'
      \ skip='^$'
      \ end='^\z1\@!'

syn sync    match kconfigSyncHelp     grouphere kconfigHelpText 'help\|---help---'

hi def link kconfigTodo         Todo
hi def link kconfigComment      Comment
hi def link kconfigKeyword      Keyword
hi def link kconfigConditional  Conditional
hi def link kconfigPreProc      PreProc
hi def link kconfigTriState     Boolean
hi def link kconfigSpecialChar  SpecialChar
hi def link kconfigPath         String
hi def link kconfigString       String
hi def link kconfigType         Type
hi def link kconfigOption       Identifier
hi def link kconfigHelpText     Normal
hi def link kconfigmacro        Macro

endif

let b:current_syntax = "kconfig"

let &cpo = s:cpo_save
unlet s:cpo_save
