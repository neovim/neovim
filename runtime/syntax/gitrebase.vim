" Vim syntax file
" Language:	git rebase --interactive
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Filenames:	git-rebase-todo
" Last Change:	2019 Dec 06

if exists("b:current_syntax")
  finish
endif

syn case match

syn match   gitrebaseHash   "\v<\x{7,}>"                               contained
syn match   gitrebaseCommit "\v<\x{7,}>"    nextgroup=gitrebaseSummary skipwhite
syn match   gitrebasePick   "\v^p%(ick)=>"   nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseReword "\v^r%(eword)=>" nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseEdit   "\v^e%(dit)=>"   nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseSquash "\v^s%(quash)=>" nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseFixup  "\v^f%(ixup)=>"  nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseExec   "\v^%(x|exec)>" nextgroup=gitrebaseCommand skipwhite
syn match   gitrebaseBreak  "\v^b%(reak)=>"
syn match   gitrebaseDrop   "\v^d%(rop)=>"   nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseNoop   "\v^noop>"
syn match   gitrebaseMerge  "\v^m(erge)=>"   nextgroup=gitrebaseMergeOption,gitrebaseName skipwhite
syn match   gitrebaseLabel  "\v^l(abel)=>"   nextgroup=gitrebaseName skipwhite
syn match   gitrebaseReset  "\v^(t|reset)=>" nextgroup=gitrebaseName skipwhite
syn match   gitrebaseSummary ".*"               contains=gitrebaseHash contained
syn match   gitrebaseCommand ".*"                                      contained
syn match   gitrebaseComment "^\s*#.*"             contains=gitrebaseHash
syn match   gitrebaseSquashError "\v%^%(s%(quash)=>|f%(ixup)=>)" nextgroup=gitrebaseCommit skipwhite
syn match   gitrebaseMergeOption "\v-[Cc]>"  nextgroup=gitrebaseMergeCommit skipwhite contained
syn match   gitrebaseMergeCommit "\v<\x{7,}>"  nextgroup=gitrebaseName skipwhite contained
syn match   gitrebaseName        "\v[^[:space:].*?i:^~/-]\S+" nextgroup=gitrebaseMergeComment skipwhite contained
syn match   gitrebaseMergeComment "#"  nextgroup=gitrebaseSummary skipwhite contained

hi def link gitrebaseCommit         gitrebaseHash
hi def link gitrebaseHash           Identifier
hi def link gitrebasePick           Type
hi def link gitrebaseReword         Conditional
hi def link gitrebaseEdit           PreProc
hi def link gitrebaseSquash         Statement
hi def link gitrebaseFixup          Repeat
hi def link gitrebaseExec           Operator
hi def link gitrebaseBreak          Macro
hi def link gitrebaseDrop           Comment
hi def link gitrebaseNoop           Comment
hi def link gitrebaseMerge          Exception
hi def link gitrebaseLabel          Label
hi def link gitrebaseReset          Keyword
hi def link gitrebaseSummary        String
hi def link gitrebaseComment        Comment
hi def link gitrebaseSquashError    Error
hi def link gitrebaseMergeCommit    gitrebaseCommit
hi def link gitrebaseMergeComment   gitrebaseComment
hi def link gitrebaseName           Tag

let b:current_syntax = "gitrebase"
