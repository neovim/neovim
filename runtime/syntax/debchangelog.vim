" Vim syntax file
" Language:    Debian changelog files
" Maintainer:  Debian Vim Maintainers <pkg-vim-maintainers@lists.alioth.debian.org>
" Former Maintainers: Gerfried Fuchs <alfie@ist.org>
"                     Wichert Akkerman <wakkerma@debian.org>
" Last Change: 2016 Nov 12
" URL: https://anonscm.debian.org/cgit/pkg-vim/vim.git/plain/runtime/syntax/debchangelog.vim

" Standard syntax initialization
if exists("b:current_syntax")
  finish
endif

" Case doesn't matter for us
syn case ignore

let urgency='urgency=\(low\|medium\|high\|critical\)\( [^[:space:],][^,]*\)\='
let binNMU='binary-only=yes'

" Define some common expressions we can use later on
syn match debchangelogName	contained "^[[:alnum:]][[:alnum:].+-]\+ "
exe 'syn match debchangelogFirstKV	contained "; \('.urgency.'\|'.binNMU.'\)"'
exe 'syn match debchangelogOtherKV	contained ", \('.urgency.'\|'.binNMU.'\)"'
syn match debchangelogTarget	contained "\v %(frozen|unstable|sid|%(testing|%(old)=stable)%(-proposed-updates|-security)=|experimental|squeeze-%(backports%(-sloppy)=|volatile|lts|security)|wheezy-%(backports%(-sloppy)=|security)|jessie%(-backports|-security)=|stretch|%(devel|precise|trusty|vivid|wily|xenial|yakkety|zesty)%(-%(security|proposed|updates|backports|commercial|partner))=)+"
syn match debchangelogVersion	contained "(.\{-})"
syn match debchangelogCloses	contained "closes:\_s*\(bug\)\=#\=\_s\=\d\+\(,\_s*\(bug\)\=#\=\_s\=\d\+\)*"
syn match debchangelogLP	contained "\clp:\s\+#\d\+\(,\s*#\d\+\)*"
syn match debchangelogEmail	contained "[_=[:alnum:].+-]\+@[[:alnum:]./\-]\+"
syn match debchangelogEmail	contained "<.\{-}>"

" Define the entries that make up the changelog
syn region debchangelogHeader start="^[^ ]" end="$" contains=debchangelogName,debchangelogFirstKV,debchangelogOtherKV,debchangelogTarget,debchangelogVersion,debchangelogBinNMU oneline
syn region debchangelogFooter start="^ [^ ]" end="$" contains=debchangelogEmail oneline
syn region debchangelogEntry start="^  " end="$" contains=debchangelogCloses,debchangelogLP oneline

" Associate our matches and regions with pretty colours
hi def link debchangelogHeader  Error
hi def link debchangelogFooter  Identifier
hi def link debchangelogEntry   Normal
hi def link debchangelogCloses  Statement
hi def link debchangelogLP      Statement
hi def link debchangelogFirstKV Identifier
hi def link debchangelogOtherKV Identifier
hi def link debchangelogName    Comment
hi def link debchangelogVersion Identifier
hi def link debchangelogTarget  Identifier
hi def link debchangelogEmail   Special

let b:current_syntax = "debchangelog"

" vim: ts=8 sw=2
