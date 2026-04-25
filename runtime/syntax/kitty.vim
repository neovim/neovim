" Vim syntax file
" Language:          Kitty configuration files
" Maintainer:        MD. Mouinul Hossain Shawon <mdmouinulhossainshawon [at] gmail.com>
" Last Change:       Tue Sep 16 19:10:59 +06 2025

if exists("b:current_syntax")
  finish
endif

syn sync fromstart

" Option """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Format: `<option_name> ...`<

syn match kittyString /\S\+/ contains=kittyAlpha contained
syn match kittyNumber /[+\-*\/]\{0,1}[0-9.]\+/ contained
syn match kittyAlpha /@[0-9.]\+/ contained
syn match kittyColor /#[0-9a-fA-F]\{3,6}/ nextgroup=kittyAlpha contained
syn keyword kittyBoolean contained yes no
syn keyword kittyConstant contained none auto monospace bold italic ratio always never

syn match kittyFlag /[+-]\{1,2}[a-zA-Z0-9-_]\+/ contained
syn match kittyParameter /-\{1,2}[a-zA-Z0-9-]\+=\S\+/ contained

syn cluster kittyPrimitive contains=kittyNumber,kittyBoolean,kittyConstant,kittyColor,kittyString,kittyFlag,kittyParameter,kittyAlpha

syn region kittyOption start="^\w" skip="[\n\r][ \t]*\\" end="[\r\n]" contains=kittyOptionName
syn match kittyOptionName /\w\+/ nextgroup=kittyOptionValue skipwhite contained
syn region kittyOptionValue start="\S" skip="[\r\n][ \t]*\\" end="\ze[\r\n]" contains=@kittyPrimitive contained

" Keyboard shortcut """""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Format: `map <keys> <action>?`

syn match kittyKey /[^ \t\r\n+>]\+/ contained
syn match kittyCtrl /\<\(ctrl\|control\)\>\|\^/ contained
syn match kittyAlt /\<\(alt\|opt\|option\)\>\|⌥/ contained
syn match kittyShift /\<\(shift\)\>\|⇧/ contained
syn match kittySuper /\<\(cmd\|super\|command\)\>\|⌘/ contained

syn match kittyAnd /+/ contained
syn match kittyWith />/ contained

syn region kittyMap start="^\s*map" skip="[\r\n][ \t]*\\" end="[\r\n]" contains=kittyMapName,kittyMapValue

syn keyword kittyMapName nextgroup=kittyMapValue skipwhite contained map
syn region kittyMapValue start="\S" skip="[\r\n][ \t]*\\" end="\ze[\r\n]" contains=kittyMapSeq,kittyMapAction contained

syn region kittyMapAction start="\S" skip="[\r\n][ \t]*\\" end="\ze[\r\n]" contains=@kittyPrimitive contained
syn region kittyMapSeq start="\S" end="\ze\s\|^\ze[ \t]*\\" nextgroup=kittyMapAction,kittyMouseMapType skipwhite contains=kittyCtrl,kittyAlt,kittyShift,kittySuper,kittyAnd,kittyWith,kittyKey contained

" Mouse shortcut """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Format: `mouse_map <keys> <type> <grabbed> <action>?`

syn region kittyMouseMap start="^\s*mouse_map" skip="[\r\n][ \t]*\\" end="[\r\n]" contains=kittyMouseMapName,kittyMouseMapValue

syn keyword kittyMouseMapName nextgroup=kittyMouseMapValue contained mouse_map
syn region kittyMouseMapValue start="\S" skip="[\r\n][ \t]*\\" end="\ze[\r\n]" contains=kittyMapSeq,kittyMouseMapType,kittyMouseMapGrabbed contained

syn region kittyMouseMapAction start="\S" skip="[\r\n][ \t]*\\" end="\ze[\r\n]" contains=@kittyPrimitive contained

syn keyword kittyMouseMapType nextgroup=kittyMouseMapGrabbed skipwhite contained press release doublepress triplepress click doubleclick
syn match kittyMouseMapGrabbed /\(grabbed\|ungrabbed\)\%(,\(grabbed\|ungrabbed\)\)\?/ nextgroup=kittyMouseMapAction skipwhite contained

" Kitty modifier """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Format: `kitty_mod <keys>`

syn region kittyMod start="^\s*kitty_mod" end="[\r\n]" contains=kittyModName,kittyMapSeq

syn keyword kittyModName nextgroup=kittyMapSeq contained kitty_mod

" Comment """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Format: `# <content>``

syn match kittyComment /^#.*$/

" Line continuation """""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Allows continuing lines by adding `\` at the start of a line.
" May have leading spaces & tabs.

syn match kittyLineContinue /^[ \t]*\\[ \t]*/ containedin=kittyOptionValue,kittyMap,kittyMapAction,kittyMouseMap,kittyMouseMapValue contained

" Highlight groups """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""

hi link kittyString String
hi link kittyNumber Number
hi link kittyAlpha Type
hi link kittyColor Constant
hi link kittyBoolean Boolean
hi link kittyConstant Constant

hi link kittyFlag Constant
hi link kittyParameter Special

hi link kittyOptionName Keyword
hi link kittyModName Keyword

hi link kittyKey Special
hi link kittyCtrl Constant
hi link kittyAlt Constant
hi link kittyShift Constant
hi link kittySuper Constant

hi link kittyAnd Operator
hi link kittyWith Operator

hi link kittyMapName Function

hi link kittyMouseMapName Function
hi link kittyMouseMapType Type
hi link kittyMouseMapGrabbed Constant

hi link kittyComment Comment
hi link kittyLineContinue Comment

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let b:current_syntax = "kitty"

