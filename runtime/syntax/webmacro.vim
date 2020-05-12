" WebMacro syntax file
" Language:     WebMacro
" Maintainer:   Claudio Fleiner <claudio@fleiner.com>
" URL:		http://www.fleiner.com/vim/syntax/webmacro.vim
" Last Change:  2003 May 11

" webmacro is a nice little language that you should
" check out if you use java servlets.
" webmacro: http://www.webmacro.org

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if !exists("main_syntax")
  " quit when a syntax file was already loaded
  if exists("b:current_syntax")
    finish
  endif
  let main_syntax = 'webmacro'
endif


runtime! syntax/html.vim
unlet b:current_syntax

syn cluster htmlPreProc add=webmacroIf,webmacroUse,webmacroBraces,webmacroParse,webmacroInclude,webmacroSet,webmacroForeach,webmacroComment

syn match webmacroVariable "\$[a-zA-Z0-9.()]*;\="
syn match webmacroNumber "[-+]\=\d\+[lL]\=" contained
syn keyword webmacroBoolean true false contained
syn match webmacroSpecial "\\." contained
syn region  webmacroString   contained start=+"+ end=+"+ contains=webmacroSpecial,webmacroVariable
syn region  webmacroString   contained start=+'+ end=+'+ contains=webmacroSpecial,webmacroVariable
syn region webmacroList contained matchgroup=Structure start="\[" matchgroup=Structure end="\]" contains=webmacroString,webmacroVariable,webmacroNumber,webmacroBoolean,webmacroList

syn region webmacroIf start="#if" start="#else" end="{"me=e-1 contains=webmacroVariable,webmacroNumber,webmacroString,webmacroBoolean,webmacroList nextgroup=webmacroBraces
syn region webmacroForeach start="#foreach" end="{"me=e-1 contains=webmacroVariable,webmacroNumber,webmacroString,webmacroBoolean,webmacroList nextgroup=webmacroBraces
syn match webmacroSet "#set .*$" contains=webmacroVariable,webmacroNumber,webmacroNumber,webmacroBoolean,webmacroString,webmacroList
syn match webmacroInclude "#include .*$" contains=webmacroVariable,webmacroNumber,webmacroNumber,webmacroBoolean,webmacroString,webmacroList
syn match webmacroParse "#parse .*$" contains=webmacroVariable,webmacroNumber,webmacroNumber,webmacroBoolean,webmacroString,webmacroList
syn region webmacroUse matchgroup=PreProc start="#use .*" matchgroup=PreProc end="^-.*" contains=webmacroHash,@HtmlTop
syn region webmacroBraces matchgroup=Structure start="{" matchgroup=Structure end="}" contained transparent
syn match webmacroBracesError "[{}]"
syn match webmacroComment "##.*$"
syn match webmacroHash "[#{}\$]" contained

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link webmacroComment CommentTitle
hi def link webmacroVariable PreProc
hi def link webmacroIf webmacroStatement
hi def link webmacroForeach webmacroStatement
hi def link webmacroSet webmacroStatement
hi def link webmacroInclude webmacroStatement
hi def link webmacroParse webmacroStatement
hi def link webmacroStatement Function
hi def link webmacroNumber Number
hi def link webmacroBoolean Boolean
hi def link webmacroSpecial Special
hi def link webmacroString String
hi def link webmacroBracesError Error

let b:current_syntax = "webmacro"

if main_syntax == 'webmacro'
  unlet main_syntax
endif
