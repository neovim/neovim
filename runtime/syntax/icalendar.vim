" Vim syntax file
" Language:             iCalendar
" Maintainer:           Anakin Childerhose <anakin@childerhose.ca>
" Latest Change:        2026 Sept 22
" License:              Vim (see :h license)

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syntax sync minlines=150

" component delineating content lines {{{
"
"  BEGIN:VCALENDAR
"  ^^^^^ icalendarComponentBegin
"       ^ icalendarComponentSeparator
"        ^^^^^^^^^ icalendarComponentType
"  END:VCALENDAR
"  ^^^ icalendarComponentEnd
"     ^ icalendarComponentSeparator
"      ^^^^^^^^^ icalendarComponentType
"
" Line folding in these lines is technically valid but rare so it is ignored to
" keep the following lines simpler
syntax keyword icalendarComponentBegin BEGIN nextgroup=icalendarComponentSeparator
syntax keyword icalendarComponentEnd END nextgroup=icalendarComponentSeparator
syntax match icalendarComponentSeparator ":" contained nextgroup=icalendarComponentType
syntax match icalendarComponentType "\w\+" contained
" component delineating content lines }}}


" property content lines {{{
"
"  TRIGGER;RELATED=START:-PT10M
"  ^^^^^^^ icalendarPropertyName
"         ^ icalendarParamSeparator
"          ^^^^^^^ icalendarPropertyParamName
"                 ^ icalendarParamEquals
"                  ^^^^^ icalendarPropertyParamValue
"                       ^ icalendarPropertySeparator
"                        ^^^^^^ icalendarPropertyValue
"
" Line folding can occur between any two characters so practically every match
" needs to support possible folds

let s:fold = '\n[ \t]'
let s:prop_chars = '[A-Za-z0-9-]'
let s:name_regex = $'\({s:prop_chars}\|{s:fold}\)*'
let s:safe_chars = '[^";:,]'

execute $'syntax match icalendarPropertyName "^{s:name_regex}" nextgroup=icalendarParamSeparator,icalendarPropertySeparator'
execute $'syntax match icalendarParamSeparator ";\({s:fold}\)*" contained nextgroup=icalendarPropertyParamName'
execute $'syntax match icalendarPropertyParamName "{s:name_regex}" contained nextgroup=icalendarParamEquals'
execute $'syntax match icalendarParamEquals "=\({s:fold}\)*" contained nextgroup=icalendarPropertyParamValue'
" collect safe chars and folds
execute $'syntax match icalendarPropertyParamValue "\({s:safe_chars}\|{s:fold}\)\+" contained nextgroup=icalendarParamSeparator,icalendarPropertySeparator'
" unsafe chars need to be quoted:
" if a value starts with a double quote, ", collect all characters upto the next
" double quote, [^"]*, including newlines, \_ followed by zero or more folds
execute $'syntax match icalendarPropertyParamValue "\"\_[^\"]*\"\({s:fold}\)*" contained nextgroup=icalendarParamSeparator,icalendarPropertySeparator'
execute $'syntax match icalendarPropertySeparator ":\({s:fold}\)*" contained nextgroup=icalendarPropertyValue'
execute $'syntax match icalendarPropertyValue "\([^\n]\|{s:fold}\)*" contained'
" property content lines }}}


" recurring rules {{{
"
"  RRULE:FREQ=YEARLY;WKST=MO;INTERVAL=1;BYMONTH=3;BYDAY=2SU
"  ^^^^^ icalendarRrule
"       ^ icalendarRruleSeparator
"        ^^^^ icalendarRruleParamName
"            ^ icalendarRruleEquals
"             ^^^^^^ icalendarRruleParamValue
"                   ^ icalendarRruleParamSeparator
"
let s:rrule_chars = '[A-Za-z0-9-+,]'

syntax keyword icalendarRrule RRULE nextgroup=icalendarRruleSeparator
execute $'syntax match icalendarRruleSeparator ":\({s:fold}\)*" contained nextgroup=icalendarRruleParamName'
execute $'syntax match icalendarRruleParamName "{s:name_regex}" contained nextgroup=icalendarRruleEquals'
execute $'syntax match icalendarRruleEquals "=\({s:fold}\)*" contained nextgroup=icalendarRruleParamValue'
execute $'syntax match icalendarRruleParamValue "\({s:rrule_chars}\|{s:fold}\)\+" contained nextgroup=icalendarRruleParamSeparator'
execute $'syntax match icalendarRruleParamSeparator ";\({s:fold}\)*" contained nextgroup=icalendarRruleParamName'
" recurring rules }}}

highlight default link icalendarComponentBegin Structure
highlight default link icalendarComponentEnd Structure
highlight default link icalendarComponentSeparator Operator
highlight default link icalendarComponentType Type

highlight default link icalendarPropertyName Identifier
highlight default link icalendarParamSeparator Operator
highlight default link icalendarPropertyParamName Type
highlight default link icalendarParamEquals Operator
highlight default link icalendarPropertyParamValue String
highlight default link icalendarPropertySeparator Operator
highlight default link icalendarPropertyValue Constant

highlight default link icalendarRrule Identifier
highlight default link icalendarRruleSeparator Operator
highlight default link icalendarRruleParamName Type
highlight default link icalendarRruleEquals Operator
highlight default link icalendarRruleParamValue String
highlight default link icalendarRruleParamSeparator Operator

let b:current_syntax = "icalendar"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: fdm=marker
