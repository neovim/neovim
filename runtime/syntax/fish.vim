" Vim syntax file
" Language:     fish
" Maintainer:   Nicholas Boyle (github.com/nickeb96)
" Repository:   https://github.com/nickeb96/fish.vim
" Last Change:  February 1, 2023

if exists("b:current_syntax")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim


" Statements
syn cluster fishStatement contains=fishKeywordAndOr,fishNot,fishSelectStatement,fishKeyword,fishKeywordIf,fishCommand,fishVariable

syn keyword fishKeywordAndOr and or nextgroup=fishNot,fishSelectStatement,fishKeyword,fishKeywordIf,fishCommand
hi def link fishKeywordAndOr fishOperator

syn keyword fishNot not skipwhite nextgroup=fishSelectStatement,fishKeyword,fishKeywordIf,fishCommand
syn match   fishNot /!/ skipwhite nextgroup=fishSelectStatement,fishKeyword,fishKeywordIf,fishCommand
hi def link fishNot fishOperator

syn keyword fishSelectStatement command builtin skipwhite nextgroup=fishKeyword,fishKeywordIf,fishCommand,fishOption
hi def link fishSelectStatement fishKeyword

syn keyword fishKeyword end skipwhite nextgroup=@fishTerminator

syn keyword fishKeywordIf if skipwhite nextgroup=@fishStatement
syn keyword fishKeyword else skipwhite nextgroup=fishKeywordIf,fishSemicolon
hi def link fishKeywordIf fishKeyword

syn keyword fishKeyword switch skipwhite nextgroup=@fishArgument
syn keyword fishKeyword case skipwhite nextgroup=@fishArgument

syn keyword fishKeyword while skipwhite nextgroup=@fishStatement

syn keyword fishKeyword for skipwhite nextgroup=fishForVariable
syn match   fishForVariable /[[:alnum:]_]\+/ contained skipwhite nextgroup=fishKeywordIn
syn keyword fishKeywordIn in contained skipwhite nextgroup=@fishArgument
hi def link fishForVariable fishParameter
hi def link fishKeywordIn fishKeyword

syn keyword fishKeyword _ abbr argparse begin bg bind block break breakpoint cd commandline
    \ complete continue count disown echo emit eval exec exit false fg function functions
    \ history jobs math printf pwd random read realpath return set set_color source status
    \ string test time true type ulimit wait
    \ skipwhite nextgroup=@fishNext
syn match   fishKeyword /\<contains\>/ skipwhite nextgroup=@fishNext

syn match   fishCommand /[[:alnum:]_\/[][[:alnum:]+._-]*/ skipwhite nextgroup=@fishNext


" Internally Nested Arguments

syn cluster fishSubscriptArgs contains=fishInnerVariable,fishIndexNum,fishIndexRange,fishInnerCommandSub

syn match   fishInnerVariable /\$\+[[:alnum:]_]\+/ contained
syn match   fishInnerVariable /\$\+[[:alnum:]_]\+\[/me=e-1,he=e-1 contained nextgroup=fishInnerSubscript
hi def link fishInnerVariable fishVariable

syn region  fishInnerSubscript matchgroup=fishVariable start=/\[/ end=/]/ contained
    \ keepend contains=@fishSubscriptArgs
hi def link fishInnerSubscript fishSubscript

syn match   fishIndexNum /[+-]?[[:digit:]]\+/ contained
hi def link fishIndexNum fishParameter

syn match   fishIndexRange /\.\./ contained
hi def link fishIndexRange fishParameter

syn region  fishInnerCommandSub matchgroup=fishOperator start=/(/ start=/\$(/ end=/)/ contained
    \ contains=@fishStatement
hi def link fishInnerCommandSub fishCommandSub

syn region  fishQuotedCommandSub matchgroup=fishOperator start=/\$(/ end=/)/ contained
    \ contains=@fishStatement
hi def link fishQuotedCommandSub fishCommandSub

syn match   fishBraceExpansionComma /,/ contained
hi def link fishBraceExpansionComma fishOperator

syn match   fishBracedParameter '[[:alnum:]\u5b\u5d@:=+.%/!_-]\+' contained contains=fishInnerPathGlob
hi def link fishBracedParameter fishParameter

syn region  fishBracedQuote start=/'/ skip=/\\'/ end=/'/ contained
    \ contains=fishEscapedEscape,fishEscapedSQuote
syn region  fishBracedQuote start=/"/ skip=/\\"/ end=/"/ contained
    \ contains=fishEscapedEscape,fishEscapedDQuote,fishEscapedDollar,fishInnerVariable,fishInnerCommandSub
hi def link fishBracedQuote fishQuote


" Arguments

syn cluster fishArgument contains=fishParameter,fishOption,fishVariable,fishPathGlob,fishBraceExpansion,fishQuote,fishCharacter,fishCommandSub,fishRedirection,fishSelfPid

syn match   fishParameter '[[:alnum:]\u5b\u5d@:=+.,%/!_-]\+' contained skipwhite nextgroup=@fishNext

syn match   fishOption /-[[:alnum:]=_-]*/ contained skipwhite nextgroup=@fishNext

syn match   fishPathGlob /\(\~\|*\|?\)/ contained skipwhite nextgroup=@fishNext

syn region  fishBraceExpansion matchgroup=fishOperator start=/{/ end=/}/ contained
    \ contains=fishBraceExpansionComma,fishInnerVariable,fishInnerCommandSub,fishBracedParameter,fishBracedQuote
    \ skipwhite nextgroup=@fishNext

syn match   fishVariable /\$\+[[:alnum:]_]\+/ skipwhite nextgroup=@fishNext
syn match   fishVariable /\$\+[[:alnum:]_]\+\[/me=e-1,he=e-1 nextgroup=fishSubscript

syn region  fishSubscript matchgroup=fishVariable start=/\[/ end=/]/ contained
    \ keepend contains=@fishSubscriptArgs
    \ skipwhite nextgroup=@fishNext

syn region  fishCommandSub matchgroup=fishOperator start=/(/ start=/\$(/ end=/)/ contained
    \ contains=@fishStatement
    \ skipwhite nextgroup=@fishNext

syn region  fishQuote start=/'/ skip=/\\'/ end=/'/ contained
    \ contains=fishEscapedEscape,fishEscapedSQuote
    \ skipwhite nextgroup=@fishNext
syn region  fishQuote start=/"/ skip=/\\"/ end=/"/ contained
    \ contains=fishEscapedEscape,fishEscapedDQuote,fishEscapedDollar,fishInnerVariable,fishQuotedCommandSub
    \ skipwhite nextgroup=@fishNext

syn match   fishEscapedEscape /\\\\/ contained
syn match   fishEscapedSQuote /\\'/ contained
syn match   fishEscapedDQuote /\\"/ contained
syn match   fishEscapedDollar /\\\$/ contained
hi def link fishEscapedEscape fishCharacter
hi def link fishEscapedSQuote fishCharacter
hi def link fishEscapedDQuote fishCharacter
hi def link fishEscapedDollar fishCharacter

syn match   fishCharacter /\\[0-7]\{1,3}/                          contained skipwhite nextgroup=@fishNext
syn match   fishCharacter /\\u[0-9a-fA-F]\{4}/                     contained skipwhite nextgroup=@fishNext
syn match   fishCharacter /\\U[0-9a-fA-F]\{8}/                     contained skipwhite nextgroup=@fishNext
syn match   fishCharacter /\\x[0-7][0-9a-fA-F]\|\\x[0-9a-fA-F]/    contained skipwhite nextgroup=@fishNext
syn match   fishCharacter /\\X[0-9a-fA-F]\{1,2}/                   contained skipwhite nextgroup=@fishNext
syn match   fishCharacter /\\[abcefnrtv[\](){}<>\\*?~%#$|&;'" ]/   contained skipwhite nextgroup=@fishNext

syn match   fishRedirection /</ contained skipwhite nextgroup=fishRedirectionTarget
syn match   fishRedirection /[0-9&]\?>[>?]\?/ contained skipwhite nextgroup=fishRedirectionTarget
syn match   fishRedirection /[0-9&]\?>&[0-9-]/ contained skipwhite nextgroup=@fishNext

syn match   fishRedirectionTarget /[[:alnum:]$~*?{,}"'\/._-]\+/ contained contains=fishInnerVariable skipwhite nextgroup=@fishNext
hi def link fishRedirectionTarget fishRedirection

syn match fishSelfPid /%self\>/ contained nextgroup=@fishNext
hi def link fishSelfPid fishOperator


" Terminators

syn cluster fishTerminator contains=fishPipe,fishBackgroundJob,fishSemicolon,fishSymbolicAndOr

syn match   fishPipe /\(1>\|2>\|&\)\?|/ contained skipwhite nextgroup=@fishStatement
hi def link fishPipe fishEnd

syn match   fishBackgroundJob /&$/ contained skipwhite nextgroup=@fishStatement
syn match   fishBackgroundJob /&[^<>&|]/me=s+1,he=s+1 contained skipwhite nextgroup=@fishStatement
hi def link fishBackgroundJob fishEnd

syn match   fishSemicolon /;/ skipwhite nextgroup=@fishStatement
hi def link fishSemicolon fishEnd

syn match   fishSymbolicAndOr /\(&&\|||\)/ contained skipwhite skipempty nextgroup=@fishStatement
hi def link fishSymbolicAndOr fishOperator


" Other

syn cluster fishNext contains=fishEscapedNl,@fishArgument,@fishTerminator

syn match   fishEscapedNl /\\$/ skipnl skipwhite contained nextgroup=@fishNext

syn match   fishComment /#.*/ contains=fishTodo,@Spell

syn keyword fishTodo TODO contained



syn sync minlines=200
syn sync maxlines=300


" Intermediate highlight groups matching $fish_color_* variables

hi def link fishCommand                 fish_color_command
hi def link fishComment                 fish_color_comment
hi def link fishEnd                     fish_color_end
hi def link fishCharacter               fish_color_escape
hi def link fishKeyword                 fish_color_keyword
hi def link fishEscapedNl               fish_color_normal
hi def link fishOperator                fish_color_operator
hi def link fishVariable                fish_color_operator
hi def link fishInnerVariable           fish_color_operator
hi def link fishPathGlob                fish_color_operator
hi def link fishOption                  fish_color_option
hi def link fishParameter               fish_color_param
hi def link fishQuote                   fish_color_quote
hi def link fishRedirection             fish_color_redirection


" Default highlight groups 

hi def link fish_color_param        Normal
hi def link fish_color_normal       Normal
hi def link fish_color_option       Normal
hi def link fish_color_command      Function
hi def link fish_color_keyword      Keyword
hi def link fish_color_end          Delimiter
hi def link fish_color_operator     Operator
hi def link fish_color_redirection  Type
hi def link fish_color_quote        String
hi def link fish_color_escape       Character
hi def link fish_color_comment      Comment

hi def link fishTodo                Todo


let b:current_syntax = 'fish'

let &cpo = s:cpo_save
unlet s:cpo_save
