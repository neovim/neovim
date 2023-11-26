" Vim syntax file
" Language:    Debian changelog files
" Maintainer:  Debian Vim Maintainers
" Former Maintainers: Gerfried Fuchs <alfie@ist.org>
"                     Wichert Akkerman <wakkerma@debian.org>
" Last Change: 2023 Oct 11
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/debchangelog.vim

" Standard syntax initialization
if exists('b:current_syntax')
  finish
endif

" Case doesn't matter for us
syn case ignore

let s:urgency='urgency=\(low\|medium\|high\|emergency\|critical\)\( [^[:space:],][^,]*\)\='
let s:binNMU='binary-only=yes'

" Include Debian versioning information
runtime! syntax/shared/debversions.vim

exe 'syn match debchangelogTarget	contained "\%( \%('.join(g:debSharedSupportedVersions, '\|').'\)\>[-[:alnum:]]*\)\+"'
exe 'syn match debchangelogUnsupportedTarget	contained "\%( \%('.join(g:debSharedUnsupportedVersions, '\|').'\)\>[-[:alnum:]]*\)\+"'

unlet g:debSharedSupportedVersions
unlet g:debSharedUnsupportedVersions

" Define some common expressions we can use later on
syn match debchangelogName	contained "^[[:alnum:]][[:alnum:].+-]\+ "
exe 'syn match debchangelogFirstKV	contained "; \('.s:urgency.'\|'.s:binNMU.'\)"'
exe 'syn match debchangelogOtherKV	contained ", \('.s:urgency.'\|'.s:binNMU.'\)"'
syn match debchangelogUnreleased	contained / UNRELEASED/
syn match debchangelogVersion	contained "(.\{-})"
syn match debchangelogCloses	contained "closes:\_s*\(bug\)\=#\=\_s\=\d\+\(,\_s*\(bug\)\=#\=\_s\=\d\+\)*"
syn match debchangelogLP	contained "\clp:\s\+#\d\+\(,\s*#\d\+\)*"
syn match debchangelogEmail	contained "[_=[:alnum:].+-]\+@[[:alnum:]./\-]\+"
syn match debchangelogEmail	contained "<.\{-}>"

" Define the entries that make up the changelog
syn region debchangelogHeader start="^[^ ]" end="$" contains=debchangelogName,debchangelogFirstKV,debchangelogOtherKV,debchangelogTarget,debchangelogUnsupportedTarget,debchangelogUnreleased,debchangelogVersion,debchangelogBinNMU oneline
syn region debchangelogFooter start="^ [^ ]" end="$" contains=debchangelogEmail oneline
syn region debchangelogEntry start="^  " end="$" contains=debchangelogCloses,debchangelogLP oneline

" Associate our matches and regions with pretty colours
hi def link debchangelogHeader     Error
hi def link debchangelogFooter     Identifier
hi def link debchangelogEntry      Normal
hi def link debchangelogCloses     Statement
hi def link debchangelogLP         Statement
hi def link debchangelogFirstKV    Identifier
hi def link debchangelogOtherKV    Identifier
hi def link debchangelogName       Comment
hi def link debchangelogVersion    Identifier
hi def link debchangelogUnreleased WarningMsg
hi def link debchangelogEmail      Special
hi def link debchangelogTarget     Identifier
hi def link debchangelogUnsupportedTarget Identifier

let b:current_syntax = 'debchangelog'

" vim: ts=8 sw=2
