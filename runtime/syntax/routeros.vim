" Vim syntax file
" Language:        MikroTik RouterOS Script
" Maintainer:      zainin <z@wintr.dev>
" Original Author: ndbjorne @ MikroTik forums
" Last Change:     2021 Nov 14

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

syn iskeyword @,48-57,-

" comments
syn match   routerosComment      /^\s*\zs#.*/

" options submenus: /interface ether1 etc
syn match   routerosSubMenu      "\([a-z]\)\@<!/[a-zA-Z0-9-]*"

" variables are matched by looking at strings ending with "=", e.g. var=
syn match   routerosVariable     "[a-zA-Z0-9-/]*\(=\)\@="
syn match   routerosVariable     "$[a-zA-Z0-9-]*"

" colored for clarity
syn match   routerosDelimiter    "[,=]"
" match slash in CIDR notation (1.2.3.4/24, 2001:db8::/48, ::1/128)
syn match   routerosDelimiter    "\(\x\|:\)\@<=\/\(\d\)\@="
" dash in IP ranges
syn match   routerosDelimiter    "\(\x\|:\)\@<=-\(\x\|:\)\@="

" match service names after "set", like in original routeros syntax
syn match   routerosService      "\(set\)\@<=\s\(api-ssl\|api\|dns\|ftp\|http\|https\|pim\|ntp\|smb\|ssh\|telnet\|winbox\|www\|www-ssl\)"

" colors various interfaces
syn match   routerosInterface    "bridge\d\+\|ether\d\+\|wlan\d\+\|pppoe-\(out\|in\)\d\+"

syn keyword routerosBoolean      yes no true false

syn keyword routerosConditional  if

" operators
syn match   routerosOperator     " \zs[-+*<>=!~^&.,]\ze "
syn match   routerosOperator     "[<>!]="
syn match   routerosOperator     "<<\|>>"
syn match   routerosOperator     "[+-]\d\@="

syn keyword routerosOperator     and or in

" commands
syn keyword routerosCommands     beep delay put len typeof pick log time set find environment
syn keyword routerosCommands     terminal error parse resolve toarray tobool toid toip toip6
syn keyword routerosCommands     tonum tostr totime add remove enable disable where get print
syn keyword routerosCommands     export edit find append as-value brief detail count-only file
syn keyword routerosCommands     follow follow-only from interval terse value-list without-paging
syn keyword routerosCommands     return

" variable types
syn keyword routerosType         global local

" loop keywords
syn keyword routerosRepeat       do while for foreach

syn match   routerosSpecial      "[():[\]{|}]"

syn match   routerosLineContinuation "\\$"

syn match   routerosEscape       "\\["\\nrt$?_abfv]" contained display
syn match   routerosEscape       "\\\x\x"            contained display

syn region  routerosString       start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=routerosEscape,routerosLineContinuation

hi link routerosComment              Comment
hi link routerosSubMenu              Function
hi link routerosVariable             Identifier
hi link routerosDelimiter            Operator
hi link routerosEscape               Special
hi link routerosService              Type
hi link routerosInterface            Type
hi link routerosBoolean              Boolean
hi link routerosConditional          Conditional
hi link routerosOperator             Operator
hi link routerosCommands             Operator
hi link routerosType                 Type
hi link routerosRepeat               Repeat
hi link routerosSpecial              Delimiter
hi link routerosString               String
hi link routerosLineContinuation     Special

let b:current_syntax = "routeros"
