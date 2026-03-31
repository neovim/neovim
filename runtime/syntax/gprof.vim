" Vim syntax file
" Language: Syntax for Gprof Output
" Maintainer: Dominique Pelle <dominique.pelle@gmail.com>
" Last Change: 2021 Sep 19

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

syn spell notoplevel
syn case match
syn sync minlines=100

" Flat profile
syn match gprofFlatProfileTitle
  \ "^Flat profile:$" 
syn region gprofFlatProfileHeader 
  \ start="^Each sample counts as.*"
  \ end="^ time.*name\s*$"
syn region gprofFlatProfileTrailer
  \ start="^\s*%\s\+the percentage of the total running time.*"
  \ end="^\s*the gprof listing if it were to be printed\."

" Call graph
syn match gprofCallGraphTitle "Call graph (explanation follows)"
syn region gprofCallGraphHeader
  \ start="^granularity: each sample hit covers.*"
  \ end="^\s*index % time\s\+self\s\+children\s\+called\s\+name$"
syn match gprofCallGraphFunction "\<\(\d\+\.\d\+\s\+\)\{3}\([0-9+]\+\)\?\s\+[a-zA-Z_<].*\ze\["
syn match gprofCallGraphSeparator "^-\+$"
syn region gprofCallGraphTrailer
  \ start="This table describes the call tree of the program"
  \ end="^\s*the cycle\.$"

" Index
syn region gprofIndex
  \ start="^Index by function name$"
  \ end="\%$"

syn match gprofIndexFunctionTitle "^Index by function name$"

syn match gprofNumbers "^\s*[0-9 ./+]\+"
syn match gprofFunctionIndex "\[\d\+\]"
syn match gprofSpecial "<\(spontaneous\|cycle \d\+\)>"

hi def link gprofFlatProfileTitle      Title
hi def link gprofFlatProfileHeader     Comment
hi def link gprofFlatProfileFunction   Number
hi def link gprofFlatProfileTrailer    Comment

hi def link gprofCallGraphTitle        Title
hi def link gprofCallGraphHeader       Comment
hi def link gprofFlatProfileFunction   Number
hi def link gprofCallGraphFunction     Special
hi def link gprofCallGraphTrailer      Comment
hi def link gprofCallGraphSeparator    Label

hi def link gprofFunctionIndex         Label
hi def link gprofSpecial               SpecialKey
hi def link gprofNumbers               Number

hi def link gprofIndexFunctionTitle Title

let b:current_syntax = "gprof"

let &cpo = s:keepcpo
unlet s:keepcpo
