" Language:    Dune buildsystem
" Maintainer:  Markus Mottl        <markus.mottl@gmail.com>
"              Anton Kochkov       <anton.kochkov@gmail.com>
" URL:         https://github.com/ocaml/vim-ocaml
" Last Change:
"              2023 Aug 28 - Added undo_ftplugin (Vim Project)
"              2018 Nov 03 - Added commentstring (Markus Mottl)
"              2017 Sep 06 - Initial version (Etienne Millon)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin=1

set lisp

" Comment string
setl commentstring=;\ %s
setl comments=:;

setl iskeyword+=#,?,.,/

let b:undo_ftplugin = "setl lisp< cms< com< isk<"
