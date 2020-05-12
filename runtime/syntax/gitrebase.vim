" Vim syntax file
" Language:	git rebase --interactive
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Filenames:	git-rebase-todo
" Last Change:	2016 Aug 29

if exists("b:current_syntax")
  finish
endif

syn case match

syn match   gitrebaseHash   "\v<\x{7,40}>"                             contained
syn match   gitrebaseCommit "\v<\x{7,40}>"  nextgroup=gitrebaseSummary skipwhite
syn match   gitrebasePick   "\v^p%(ick)=>"   nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseReword "\v^r%(eword)=>" nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseEdit   "\v^e%(dit)=>"   nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseSquash "\v^s%(quash)=>" nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseFixup  "\v^f%(ixup)=>"  nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseExec   "\v^%(x|exec)>" nextgroup=gitrebaseCommand skipwhite
syn match   gitrebaseDrop   "\v^d%(rop)=>"   nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseSummary ".*"               contains=gitrebaseHash contained
syn match   gitrebaseCommand ".*"                                      contained
syn match   gitrebaseComment "^#.*"             contains=gitrebaseHash
syn match   gitrebaseSquashError "\v%^%(s%(quash)=>|f%(ixup)=>)" nextgroup=gitrebaseCommit skipwhite

hi def link gitrebaseCommit         gitrebaseHash
hi def link gitrebaseHash           Identifier
hi def link gitrebasePick           Statement
hi def link gitrebaseReword         Number
hi def link gitrebaseEdit           PreProc
hi def link gitrebaseSquash         Type
hi def link gitrebaseFixup          Special
hi def link gitrebaseExec           Function
hi def link gitrebaseDrop           Comment
hi def link gitrebaseSummary        String
hi def link gitrebaseComment        Comment
hi def link gitrebaseSquashError    Error

let b:current_syntax = "gitrebase"
