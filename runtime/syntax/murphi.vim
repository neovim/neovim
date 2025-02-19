" Vim syntax file
" Language: Murphi model checking language
" Maintainer: Matthew Fernandez <matthew.fernandez@gmail.com>
" Last Change: 2019 Aug 27
" Version: 2
" Remark: Originally authored by Diego Ongaro <ongaro@cs.stanford.edu> 

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Keywords are case insensitive.
" Keep these in alphabetical order.
syntax case ignore
syn keyword murphiKeyword       alias
syn keyword murphiStructure     array
syn keyword murphiKeyword       assert
syn keyword murphiKeyword       begin
syn keyword murphiType          boolean
syn keyword murphiKeyword       by
syn keyword murphiLabel         case
syn keyword murphiKeyword       clear
syn keyword murphiLabel         const
syn keyword murphiRepeat        do
syn keyword murphiConditional   else
syn keyword murphiConditional   elsif
syn keyword murphiKeyword       end
syn keyword murphiKeyword       endalias
syn keyword murphiRepeat        endexists
syn keyword murphiRepeat        endfor
syn keyword murphiRepeat        endforall
syn keyword murphiKeyword       endfunction
syn keyword murphiConditional   endif
syn keyword murphiKeyword       endprocedure
syn keyword murphiStructure     endrecord
syn keyword murphiKeyword       endrule
syn keyword murphiKeyword       endruleset
syn keyword murphiKeyword       endstartstate
syn keyword murphiConditional   endswitch
syn keyword murphiRepeat        endwhile
syn keyword murphiStructure     enum
syn keyword murphiKeyword       error
syn keyword murphiRepeat        exists
syn keyword murphiBoolean       false
syn keyword murphiRepeat        for
syn keyword murphiRepeat        forall
syn keyword murphiKeyword       function
syn keyword murphiConditional   if
syn keyword murphiKeyword       in
syn keyword murphiKeyword       interleaved
syn keyword murphiLabel         invariant
syn keyword murphiFunction      ismember
syn keyword murphiFunction      isundefined
syn keyword murphiKeyword       log
syn keyword murphiStructure     of
syn keyword murphiType          multiset
syn keyword murphiFunction      multisetadd
syn keyword murphiFunction      multisetcount
syn keyword murphiFunction      multisetremove
syn keyword murphiFunction      multisetremovepred
syn keyword murphiKeyword       procedure
syn keyword murphiKeyword       program
syn keyword murphiKeyword       put
syn keyword murphiStructure     record
syn keyword murphiKeyword       return
syn keyword murphiLabel         rule
syn keyword murphiLabel         ruleset
syn keyword murphiType          scalarset
syn keyword murphiLabel         startstate
syn keyword murphiConditional   switch
syn keyword murphiConditional   then
syn keyword murphiRepeat        to
syn keyword murphiKeyword       traceuntil
syn keyword murphiBoolean       true
syn keyword murphiLabel         type
syn keyword murphiKeyword       undefine
syn keyword murphiStructure     union
syn keyword murphiLabel         var
syn keyword murphiRepeat        while

syn keyword murphiTodo contained todo xxx fixme
syntax case match

" Integers.
syn match murphiNumber "\<\d\+\>"

" Operators and special characters.
syn match murphiOperator "[\+\-\*\/%&|=!<>:\?]\|\."
syn match murphiDelimiter "\(:=\@!\|[;,]\)"
syn match murphiSpecial "[()\[\]]"

" Double equal sign is a common error: use one equal sign for equality testing.
syn match murphiError "==[^>]"he=e-1
" Double && and || are errors.
syn match murphiError "&&\|||"

" Strings. This is defined so late so that it overrides previous matches.
syn region murphiString start=+"+ end=+"+

" Comments. This is defined so late so that it overrides previous matches.
syn region murphiComment start="--" end="$" contains=murphiTodo
syn region murphiComment start="/\*" end="\*/" contains=murphiTodo

" Link the rules to some groups.
hi def link murphiComment        Comment
hi def link murphiString         String
hi def link murphiNumber         Number
hi def link murphiBoolean        Boolean
hi def link murphiIdentifier     Identifier
hi def link murphiFunction       Function
hi def link murphiStatement      Statement
hi def link murphiConditional    Conditional
hi def link murphiRepeat         Repeat
hi def link murphiLabel          Label
hi def link murphiOperator       Operator
hi def link murphiKeyword        Keyword
hi def link murphiType           Type
hi def link murphiStructure      Structure
hi def link murphiSpecial        Special
hi def link murphiDelimiter      Delimiter
hi def link murphiError          Error
hi def link murphiTodo           Todo

let b:current_syntax = "murphi"
