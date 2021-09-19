" Vim syntax file
" Language:    OPAM - OCaml package manager
" Maintainer:  Markus Mottl        <markus.mottl@gmail.com>
" URL:         https://github.com/ocaml/vim-ocaml
" Last Change:
"              2020 Dec 31 - Added header (Markus Mottl)

if exists("b:current_syntax")
  finish
endif

" need %{vars}%
" env: [[CAML_LD_LIBRARY_PATH = "%{lib}%/stublibs"]]
syn keyword opamKeyword1 remove depends pin-depends depopts conflicts env packages patches version maintainer tags license homepage authors doc install author available name depexts substs synopsis description
syn match opamKeyword2 "\v(bug-reports|post-messages|ocaml-version|opam-version|dev-repo|build-test|build-doc|build)"

syn keyword opamTodo FIXME NOTE NOTES TODO XXX contained
syn match opamComment "#.*$" contains=opamTodo,@Spell
syn match opamOperator ">\|<\|=\|<=\|>="

syn region opamInterpolate start=/%{/ end=/}%/ contained
syn region opamString start=/"/ end=/"/ contains=opamInterpolate
syn region opamSeq start=/\[/ end=/\]/ contains=ALLBUT,opamKeyword1,opamKeyword2
syn region opamExp start=/{/ end=/}/ contains=ALLBUT,opamKeyword1,opamKeyword2

hi link opamKeyword1 Keyword
hi link opamKeyword2 Keyword

hi link opamString String
hi link opamExp Function
hi link opamSeq Statement
hi link opamOperator Operator
hi link opamComment Comment
hi link opamInterpolate Identifier

let b:current_syntax = "opam"

" vim: ts=2 sw=2
