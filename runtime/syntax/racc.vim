" Vim default file
" Language:         Racc input file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2008-06-22

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword raccTodo        contained TODO FIXME XXX NOTE

syn region  raccComment     start='/\*' end='\*/'
                            \ contains=raccTodo,@Spell
syn region  raccComment     display oneline start='#' end='$'
                            \ contains=raccTodo,@Spell

syn region  raccClass       transparent matchgroup=raccKeyword
                            \ start='\<class\>' end='\<rule\>'he=e-4
                            \ contains=raccComment,raccPrecedence,
                            \ raccTokenDecl,raccExpect,raccOptions,raccConvert,
                            \ raccStart,

syn region  raccPrecedence  transparent matchgroup=raccKeyword
                            \ start='\<prechigh\>' end='\<preclow\>'
                            \ contains=raccComment,raccPrecSpec

syn keyword raccPrecSpec    contained nonassoc left right
                            \ nextgroup=raccPrecToken,raccPrecString skipwhite
                            \ skipnl

syn match   raccPrecToken   contained '\<\u[A-Z0-9_]*\>'
                            \ nextgroup=raccPrecToken,raccPrecString skipwhite
                            \ skipnl

syn region  raccPrecString  matchgroup=raccPrecString start=+"+
                            \ skip=+\\\\\|\\"+ end=+"+
                            \ contains=raccSpecial
                            \ nextgroup=raccPrecToken,raccPrecString skipwhite
                            \ skipnl
syn region  raccPrecString  matchgroup=raccPrecString start=+'+
                            \ skip=+\\\\\|\\'+ end=+'+ contains=raccSpecial
                            \ nextgroup=raccPrecToken,raccPrecString skipwhite
                            \ skipnl

syn keyword raccTokenDecl   contained token
                            \ nextgroup=raccTokenR skipwhite skipnl

syn match   raccTokenR      contained '\<\u[A-Z0-9_]*\>'
                            \ nextgroup=raccTokenR skipwhite skipnl

syn keyword raccExpect      contained expect
                            \ nextgroup=raccNumber skipwhite skipnl

syn match   raccNumber      contained '\<\d\+\>'

syn keyword raccOptions     contained options
                            \ nextgroup=raccOptionsR skipwhite skipnl

syn keyword raccOptionsR    contained omit_action_call result_var
                            \ nextgroup=raccOptionsR skipwhite skipnl

syn region  raccConvert     transparent contained matchgroup=raccKeyword
                            \ start='\<convert\>' end='\<end\>'
                            \ contains=raccComment,raccConvToken skipwhite
                            \ skipnl

syn match   raccConvToken   contained '\<\u[A-Z0-9_]*\>'
                            \ nextgroup=raccString skipwhite skipnl

syn keyword raccStart       contained start
                            \ nextgroup=raccTargetS skipwhite skipnl

syn match   raccTargetS     contained '\<\l[a-z0-9_]*\>'

syn match   raccSpecial     contained '\\["'\\]'

syn region  raccString      start=+"+ skip=+\\\\\|\\"+ end=+"+
                            \ contains=raccSpecial
syn region  raccString      start=+'+ skip=+\\\\\|\\'+ end=+'+
                            \ contains=raccSpecial

syn region  raccRules       transparent matchgroup=raccKeyword start='\<rule\>'
                            \ end='\<end\>' contains=raccComment,raccString,
                            \ raccNumber,raccToken,raccTarget,raccDelimiter,
                            \ raccAction

syn match   raccTarget      contained '\<\l[a-z0-9_]*\>'

syn match   raccDelimiter   contained '[:|]'

syn match   raccToken       contained '\<\u[A-Z0-9_]*\>'

syn include @raccRuby       syntax/ruby.vim

syn region  raccAction      transparent matchgroup=raccDelimiter
                            \ start='{' end='}' contains=@raccRuby

syn region  raccHeader      transparent matchgroup=raccPreProc
                            \ start='^---- header.*' end='^----'he=e-4
                            \ contains=@raccRuby

syn region  raccInner       transparent matchgroup=raccPreProc
                            \ start='^---- inner.*' end='^----'he=e-4
                            \ contains=@raccRuby

syn region  raccFooter      transparent matchgroup=raccPreProc
                            \ start='^---- footer.*' end='^----'he=e-4
                            \ contains=@raccRuby

syn sync    match raccSyncHeader    grouphere raccHeader '^---- header'
syn sync    match raccSyncInner     grouphere raccInner '^---- inner'
syn sync    match raccSyncFooter    grouphere raccFooter '^---- footer'

hi def link raccTodo        Todo
hi def link raccComment     Comment
hi def link raccPrecSpec    Type
hi def link raccPrecToken   raccToken
hi def link raccPrecString  raccString
hi def link raccTokenDecl   Keyword
hi def link raccToken       Identifier
hi def link raccTokenR      raccToken
hi def link raccExpect      Keyword
hi def link raccNumber      Number
hi def link raccOptions     Keyword
hi def link raccOptionsR    Identifier
hi def link raccConvToken   raccToken
hi def link raccStart       Keyword
hi def link raccTargetS     Type
hi def link raccSpecial     special
hi def link raccString      String
hi def link raccTarget      Type
hi def link raccDelimiter   Delimiter
hi def link raccPreProc     PreProc
hi def link raccKeyword     Keyword

let b:current_syntax = "racc"

let &cpo = s:cpo_save
unlet s:cpo_save
