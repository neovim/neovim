" Vim syntax file
" Language:    Debian changelog files
" Maintainer:  Debian Vim Maintainers <pkg-vim-maintainers@lists.alioth.debian.org>
" Former Maintainers: Gerfried Fuchs <alfie@ist.org>
"                     Wichert Akkerman <wakkerma@debian.org>
" Last Change: 2015 Oct 24
" URL: https://anonscm.debian.org/cgit/pkg-vim/vim.git/plain/runtime/syntax/debchangelog.vim

" Standard syntax initialization
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
syn match debchangelogTarget	contained "\v %(frozen|unstable|sid|%(testing|%(old)=stable)%(-proposed-updates|-security)=|experimental|squeeze-%(backports%(-sloppy)=|volatile|lts|security)|wheezy-%(backports%(-sloppy)=|security)|jessie%(-backports|-security)=|stretch|%(devel|precise|trusty|vivid|wily|xenial)%(-%(security|proposed|updates|backports|commercial|partner))=)+"
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
if version >= 508 || !exists("did_debchangelog_syn_inits")
  if version < 508
    let did_debchangelog_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink debchangelogHeader		Error
  HiLink debchangelogFooter		Identifier
  HiLink debchangelogEntry		Normal
  HiLink debchangelogCloses		Statement
  HiLink debchangelogLP			Statement
  HiLink debchangelogFirstKV		Identifier
  HiLink debchangelogOtherKV		Identifier
  HiLink debchangelogName		Comment
  HiLink debchangelogVersion		Identifier
  HiLink debchangelogTarget		Identifier
  HiLink debchangelogEmail		Special

  delcommand HiLink
endif

let b:current_syntax = "debchangelog"

" vim: ts=8 sw=2
