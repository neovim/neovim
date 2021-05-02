" Language:    Dune buildsystem
" Maintainer:  Markus Mottl        <markus.mottl@gmail.com>
"              Anton Kochkov       <anton.kochkov@gmail.com>
" URL:         https://github.com/ocaml/vim-ocaml
" Last Change:
"              2018 Nov 3 - Added commentstring (Markus Mottl)
"              2017 Sep 6 - Initial version (Etienne Millon)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin=1

set lisp

" Comment string
setl commentstring=;\ %s
setl comments=:;

setl iskeyword+=#,?,.,/
