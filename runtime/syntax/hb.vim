" Vim syntax file
" Language:	Hyper Builder
" Maintainer:	Alejandro Forero Cuervo
" URL:		http://bachue.com/hb/vim/syntax/hb.vim
" Last Change:	2012 Jan 08 by Thilo Six

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Read the HTML syntax to start with
"syn include @HTMLStuff <sfile>:p:h/htmlhb.vim

"this would be nice but we are supposed not to do it
"set mps=<:>

"syn region  HBhtmlString contained start=+"+ end=+"+ contains=htmlSpecialChar
"syn region  HBhtmlString contained start=+'+ end=+'+ contains=htmlSpecialChar

"syn match   htmlValue    contained "=[\t ]*[^'" \t>][^ \t>]*"

syn match   htmlSpecialChar "&[^;]*;" contained

syn match   HBhtmlTagSk  contained "[A-Za-z]*"

syn match   HBhtmlTagS   contained "<\s*\(hb\s*\.\s*\(sec\|min\|hour\|day\|mon\|year\|input\|html\|time\|getcookie\|streql\|url-enc\)\|wall\s*\.\s*\(show\|info\|id\|new\|rm\|count\)\|auth\s*\.\s*\(chk\|add\|find\|user\)\|math\s*\.\s*exp\)\s*\([^.A-Za-z0-9]\|$\)" contains=HBhtmlTagSk transparent

syn match   HBhtmlTagN   contained "[A-Za-z0-9\/\-]\+"

syn match   HBhtmlTagB   contained "<\s*[A-Za-z0-9\/\-]\+\(\s*\.\s*[A-Za-z0-9\/\-]\+\)*" contains=HBhtmlTagS,HBhtmlTagN

syn region  HBhtmlTag contained start=+<+ end=+>+ contains=HBhtmlTagB,HBDirectiveError

syn match HBFileName ".*" contained

syn match HBDirectiveKeyword	":\s*\(include\|lib\|set\|out\)\s\+" contained

syn match HBDirectiveError	"^:.*$" contained

"syn match HBDirectiveBlockEnd "^:\s*$" contained

"syn match HBDirectiveOutHead "^:\s*out\s\+\S\+.*" contained contains=HBDirectiveKeyword,HBFileName

"syn match HBDirectiveSetHead "^:\s*set\s\+\S\+.*" contained contains=HBDirectiveKeyword,HBFileName

syn match HBInvalidLine "^.*$"

syn match HBDirectiveInclude "^:\s*include\s\+\S\+.*$" contains=HBFileName,HBDirectiveKeyword

syn match HBDirectiveLib "^:\s*lib\s\+\S\+.*$" contains=HBFileName,HBDirectiveKeyword

syn region HBText matchgroup=HBDirectiveKeyword start=/^:\(set\|out\)\s*\S\+.*$/ end=/^:\s*$/ contains=HBDirectiveError,htmlSpecialChar,HBhtmlTag keepend

"syn match HBLine "^:.*$" contains=HBDirectiveInclude,HBDirectiveLib,HBDirectiveError,HBDirectiveSet,HBDirectiveOut

syn match HBComment "^#.*$"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link HBhtmlString			 String
hi def link HBhtmlTagN			 Function
hi def link htmlSpecialChar		 String

hi def link HBInvalidLine Error
hi def link HBFoobar Comment
hi HBFileName guibg=lightgray guifg=black
hi def link HBDirectiveError Error
hi def link HBDirectiveBlockEnd HBDirectiveKeyword
hi HBDirectiveKeyword guibg=lightgray guifg=darkgreen
hi def link HBComment Comment
hi def link HBhtmlTagSk Statement


syn sync match Normal grouphere NONE "^:\s*$"
syn sync match Normal grouphere NONE "^:\s*lib\s\+[^ \t]\+$"
syn sync match Normal grouphere NONE "^:\s*include\s\+[^ \t]\+$"
"syn sync match Block  grouphere HBDirectiveSet "^#:\s*set\s\+[^ \t]\+"
"syn sync match Block  grouphere HBDirectiveOut "^#:\s*out\s\+[^ \t]\+"

let b:current_syntax = "hb"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
