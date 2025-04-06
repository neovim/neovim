" Vim syntax file
" Language: Valgrind Memory Debugger Output
" Maintainer: Roger Luethi <rl@hellgate.ch>
" Program URL: http://devel-home.kde.org/~sewardj/
" Last Change: 2019 Jul 24
"
" Notes: mostly based on strace.vim and xml.vim
"
" Contributors: Christoph Gysin <christoph.gysin@gmail.com>

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif
let s:keepcpo= &cpo
set cpo&vim

" Lines can be long with demangled c++ functions.
setlocal synmaxcol=8000

syn case match
syn sync minlines=50

syn match valgrindSpecLine "^[+-]\{2}\d\+[+-]\{2}.*$"

syn region valgrindRegion
	\ start=+^==\z(\d\+\)== \w.*$+
	\ skip=+^==\z1==\( \|    .*\|  \S.*\)$+
	\ end=+^+
	\ fold
	\ keepend
	\ contains=valgrindPidChunk,valgrindLine

syn region valgrindPidChunk
	\ start=+^==\zs+
	\ end=+\ze==+
	\ contained
	\ contains=valgrindPid0,valgrindPid1,valgrindPid2,valgrindPid3,valgrindPid4,valgrindPid5,valgrindPid6,valgrindPid7,valgrindPid8,valgrindPid9
	\ keepend

syn match valgrindPid0 "\d\+0=" contained
syn match valgrindPid1 "\d\+1=" contained
syn match valgrindPid2 "\d\+2=" contained
syn match valgrindPid3 "\d\+3=" contained
syn match valgrindPid4 "\d\+4=" contained
syn match valgrindPid5 "\d\+5=" contained
syn match valgrindPid6 "\d\+6=" contained
syn match valgrindPid7 "\d\+7=" contained
syn match valgrindPid8 "\d\+8=" contained
syn match valgrindPid9 "\d\+9=" contained

syn region valgrindLine
	\ start=+\(^==\d\+== \)\@<=+
	\ end=+$+
	\ keepend
	\ contained
	\ contains=valgrindOptions,valgrindMsg,valgrindLoc

syn match valgrindOptions "[ ]\{3}-.*$" contained

syn match valgrindMsg "\S.*$" contained
	\ contains=valgrindError,valgrindNote,valgrindSummary
syn match valgrindError "\(Invalid\|\d\+ errors\|.* definitely lost\).*$" contained
syn match valgrindNote ".*still reachable.*" contained
syn match valgrindSummary ".*SUMMARY:" contained

syn match valgrindLoc "\s\+\(by\|at\|Address\).*$" contained
	\ contains=valgrindAt,valgrindAddr,valgrindFunc,valgrindBin,valgrindSrc
syn match valgrindAt "at\s\@=" contained
syn match valgrindAddr "\W\zs0x\x\+" contained

syn match valgrindFunc ": \zs\h[a-zA-Z0-9_:\[\]()<>&*+\-,=%!|^ @.]*\ze([^)]*)$" contained
syn match valgrindBin "(\(with\)\=in \zs\S\+)\@=" contained
syn match valgrindSrc "(\zs[^)]*:\d\+)\@=" contained

" Define the default highlighting

hi def link valgrindSpecLine	Type
"hi def link valgrindRegion	Special

hi def link valgrindPid0	Special
hi def link valgrindPid1	Comment
hi def link valgrindPid2	Type
hi def link valgrindPid3	Constant
hi def link valgrindPid4	Number
hi def link valgrindPid5	Identifier
hi def link valgrindPid6	Statement
hi def link valgrindPid7	Error
hi def link valgrindPid8	LineNr
hi def link valgrindPid9	Normal
"hi def link valgrindLine	Special

hi def link valgrindOptions	Type
"hi def link valgrindMsg	Special
"hi def link valgrindLoc	Special

hi def link valgrindError	Special
hi def link valgrindNote	Comment
hi def link valgrindSummary	Type

hi def link valgrindAt		Special
hi def link valgrindAddr	Number
hi def link valgrindFunc	Type
hi def link valgrindBin		Comment
hi def link valgrindSrc		Statement

let b:current_syntax = "valgrind"

let &cpo = s:keepcpo
unlet s:keepcpo
