" Vim syntax file
" Language:    Debian changelog files
" Maintainer:  Debian Vim Maintainers
" Former Maintainers: Gerfried Fuchs <alfie@ist.org>
"                     Wichert Akkerman <wakkerma@debian.org>
" Last Change: 2021 Oct 19
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/master/syntax/debchangelog.vim

" Standard syntax initialization
if exists('b:current_syntax')
  finish
endif

" Case doesn't matter for us
syn case ignore

let s:urgency='urgency=\(low\|medium\|high\|emergency\|critical\)\( [^[:space:],][^,]*\)\='
let s:binNMU='binary-only=yes'

let s:cpo = &cpo
set cpo-=C
let s:supported = [
      \ 'oldstable', 'stable', 'testing', 'unstable', 'experimental',
      \ 'jessie', 'stretch', 'buster', 'bullseye', 'bookworm',
      \ 'trixie', 'sid', 'rc-buggy',
      \
      \ 'trusty', 'xenial', 'bionic', 'focal', 'hirsute', 'impish', 'jammy',
      \ 'devel'
      \ ]
let s:unsupported = [
      \ 'frozen', 'buzz', 'rex', 'bo', 'hamm', 'slink', 'potato',
      \ 'woody', 'sarge', 'etch', 'lenny', 'squeeze', 'wheezy',
      \
      \ 'warty', 'hoary', 'breezy', 'dapper', 'edgy', 'feisty',
      \ 'gutsy', 'hardy', 'intrepid', 'jaunty', 'karmic', 'lucid',
      \ 'maverick', 'natty', 'oneiric', 'precise', 'quantal', 'raring', 'saucy',
      \ 'utopic', 'vivid', 'wily', 'yakkety', 'zesty', 'artful', 'cosmic',
      \ 'disco', 'eoan', 'groovy'
      \ ]
let &cpo=s:cpo

" Define some common expressions we can use later on
syn match debchangelogName	contained "^[[:alnum:]][[:alnum:].+-]\+ "
exe 'syn match debchangelogFirstKV	contained "; \('.s:urgency.'\|'.s:binNMU.'\)"'
exe 'syn match debchangelogOtherKV	contained ", \('.s:urgency.'\|'.s:binNMU.'\)"'
exe 'syn match debchangelogTarget	contained "\%( \%('.join(s:supported, '\|').'\)\>[-[:alnum:]]*\)\+"'
exe 'syn match debchangelogUnsupportedTarget	contained "\%( \%('.join(s:unsupported, '\|').'\)\>[-[:alnum:]]*\)\+"'
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
hi def link debchangelogUnsupportedTarget  Identifier
hi def link debchangelogUnreleased WarningMsg
hi def link debchangelogEmail   Special

let b:current_syntax = 'debchangelog'

" vim: ts=8 sw=2
