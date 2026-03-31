" Vim syntax file
" Language:	graphql
" Maintainer:	Jon Parise <jon@indelible.org>
" Filenames:	*.graphql *.graphqls *.gql
" URL:		https://github.com/jparise/vim-graphql
" License:	MIT <https://opensource.org/license/mit>
" Last Change:	2024 Dec 21

if !exists('main_syntax')
  if exists('b:current_syntax')
    finish
  endif
  let main_syntax = 'graphql'
endif

syn case match

syn match graphqlComment    "#.*$" contains=@Spell

syn match graphqlOperator   "=" display
syn match graphqlOperator   "!" display
syn match graphqlOperator   "|" display
syn match graphqlOperator   "&" display
syn match graphqlOperator   "\M..." display

syn keyword graphqlBoolean  true false
syn keyword graphqlNull     null
syn match   graphqlNumber   "-\=\<\%(0\|[1-9]\d*\)\%(\.\d\+\)\=\%([eE][-+]\=\d\+\)\=\>" display
syn region  graphqlString   start=+"+  skip=+\\\\\|\\"+  end=+"\|$+
syn region  graphqlString   start=+"""+ skip=+\\"""+ end=+"""+

syn keyword graphqlKeyword repeatable nextgroup=graphqlKeyword skipwhite
syn keyword graphqlKeyword on nextgroup=graphqlType,graphqlDirectiveLocation skipwhite

syn keyword graphqlStructure enum scalar type union nextgroup=graphqlType skipwhite
syn keyword graphqlStructure input interface subscription nextgroup=graphqlType skipwhite
syn keyword graphqlStructure implements nextgroup=graphqlType skipwhite
syn keyword graphqlStructure query mutation fragment nextgroup=graphqlName skipwhite
syn keyword graphqlStructure directive nextgroup=graphqlDirective skipwhite
syn keyword graphqlStructure extend nextgroup=graphqlStructure skipwhite
syn keyword graphqlStructure schema nextgroup=graphqlFold skipwhite

syn match graphqlDirective  "\<@\h\w*\>"   display
syn match graphqlVariable   "\<\$\h\w*\>"  display
syn match graphqlName       "\<\h\w*\>"    display
syn match graphqlType       "\<_*\u\w*\>"  display

" https://spec.graphql.org/October2021/#ExecutableDirectiveLocation
syn keyword graphqlDirectiveLocation QUERY MUTATION SUBSCRIPTION FIELD
syn keyword graphqlDirectiveLocation FRAGMENT_DEFINITION FRAGMENT_SPREAD
syn keyword graphqlDirectiveLocation INLINE_FRAGMENT VARIABLE_DEFINITION
" https://spec.graphql.org/October2021/#TypeSystemDirectiveLocation
syn keyword graphqlDirectiveLocation SCHEMA SCALAR OBJECT FIELD_DEFINITION
syn keyword graphqlDirectiveLocation ARGUMENT_DEFINITION INTERFACE UNION
syn keyword graphqlDirectiveLocation ENUM ENUM_VALUE INPUT_OBJECT
syn keyword graphqlDirectiveLocation INPUT_FIELD_DEFINITION

syn keyword graphqlMetaFields __schema __type __typename

syn region  graphqlFold matchgroup=graphqlBraces start="{" end="}" transparent fold contains=ALLBUT,graphqlStructure
syn region  graphqlList matchgroup=graphqlBraces start="\[" end="]" transparent contains=ALLBUT,graphqlDirective,graphqlStructure

if main_syntax ==# 'graphql'
  syn sync minlines=500
endif

hi def link graphqlComment          Comment
hi def link graphqlOperator         Operator

hi def link graphqlBraces           Delimiter

hi def link graphqlBoolean          Boolean
hi def link graphqlNull             Keyword
hi def link graphqlNumber           Number
hi def link graphqlString           String

hi def link graphqlDirective        PreProc
hi def link graphqlDirectiveLocation Special
hi def link graphqlName             Identifier
hi def link graphqlMetaFields       Special
hi def link graphqlKeyword          Keyword
hi def link graphqlStructure        Structure
hi def link graphqlType             Type
hi def link graphqlVariable         Identifier

let b:current_syntax = 'graphql'

if main_syntax ==# 'graphql'
  unlet main_syntax
endif
