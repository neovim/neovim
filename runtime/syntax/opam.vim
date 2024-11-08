" Vim syntax file
" Language:    opam - OCaml package manager
" Maintainer:  Markus Mottl        <markus.mottl@gmail.com>
" URL:         https://github.com/ocaml/vim-ocaml
" Last Change:
"              2020 Dec 31 - Added header (Markus Mottl)

if exists("b:current_syntax")
  finish
endif

" need %{vars}%
" env: [[CAML_LD_LIBRARY_PATH = "%{lib}%/stublibs"]]
syn iskeyword a-z,A-Z,-
syn keyword opamKeyword1 author
syn keyword opamKeyword1 authors
syn keyword opamKeyword1 available
syn keyword opamKeyword1 bug-reports
syn keyword opamKeyword1 build
syn keyword opamKeyword1 build-env
syn keyword opamKeyword1 conflict-class
syn keyword opamKeyword1 conflicts
syn keyword opamKeyword1 depends
syn keyword opamKeyword1 depexts
syn keyword opamKeyword1 depopts
syn keyword opamKeyword1 description
syn keyword opamKeyword1 dev-repo
syn keyword opamKeyword1 doc
syn keyword opamKeyword1 extra-files
syn keyword opamKeyword1 features
syn keyword opamKeyword1 flags
syn keyword opamKeyword1 homepage
syn keyword opamKeyword1 install
syn keyword opamKeyword1 libraries
syn keyword opamKeyword1 license
syn keyword opamKeyword1 maintainer
syn keyword opamKeyword1 messages
syn keyword opamKeyword1 name
syn keyword opamKeyword1 opam-version
syn keyword opamKeyword1 patches
syn keyword opamKeyword1 pin-depends
syn keyword opamKeyword1 post-messages
syn keyword opamKeyword1 remove
syn keyword opamKeyword1 run-test
syn keyword opamKeyword1 setenv
syn keyword opamKeyword1 substs
syn keyword opamKeyword1 synopsis
syn keyword opamKeyword1 syntax
syn keyword opamKeyword1 tags
syn keyword opamKeyword1 version

syn keyword opamTodo FIXME NOTE NOTES TODO XXX contained
syn match opamComment "#.*$" contains=opamTodo,@Spell
syn match opamOperator ">\|<\|=\|<=\|>="

syn match opamUnclosedInterpolate "%{[^ "]*" contained
syn match opamInterpolate         "%{[^ "]\+}%" contained
syn region opamString start=/"/ end=/"/ contains=opamInterpolate,OpamUnclosedInterpolate
syn region opamSeq start=/\[/ end=/\]/ contains=ALLBUT,opamKeyword1
syn region opamExp start=/{/ end=/}/ contains=ALLBUT,opamKeyword1

hi link opamKeyword1 Keyword

hi link opamString String
hi link opamExp Function
hi link opamSeq Statement
hi link opamOperator Operator
hi link opamComment Comment
hi link opamInterpolate Identifier
hi link opamUnclosedInterpolate Error

let b:current_syntax = "opam"

" vim: ts=2 sw=2
