" Language:    Dune buildsystem
" Maintainer:  Markus Mottl        <markus.mottl@gmail.com>
"              Anton Kochkov       <anton.kochkov@gmail.com>
" URL:         https://github.com/rgrinberg/vim-ocaml
" Last Change:
"              2019 Feb 27 - Add newer keywords to the syntax (Simon Cruanes)
"              2018 May 8 - Check current_syntax (Kawahara Satoru)
"              2018 Mar 29 - Extend jbuild syntax with more keywords (Petter A. Urkedal)
"              2017 Sep 6 - Initial version (Etienne Millon)

if exists("b:current_syntax")
    finish
endif

set syntax=lisp
syn case match

" The syn-iskeyword setting lacks #,? from the iskeyword setting here.
" Clearing it avoids maintaining keyword characters in multiple places.
syn iskeyword clear

syn keyword lispDecl jbuild_version library executable executables rule ocamllex ocamlyacc menhir alias install

syn keyword lispKey name public_name synopsis modules libraries wrapped
syn keyword lispKey preprocess preprocessor_deps optional c_names cxx_names
syn keyword lispKey install_c_headers modes no_dynlink self_build_stubs_archive
syn keyword lispKey ppx_runtime_libraries virtual_deps js_of_ocaml link_flags
syn keyword lispKey javascript_files flags ocamlc_flags ocamlopt_flags pps staged_pps
syn keyword lispKey library_flags c_flags c_library_flags kind package action
syn keyword lispKey deps targets locks fallback
syn keyword lispKey inline_tests tests names

syn keyword lispAtom true false

syn keyword lispFunc cat chdir copy# diff? echo run setenv
syn keyword lispFunc ignore-stdout ignore-stderr ignore-outputs
syn keyword lispFunc with-stdout-to with-stderr-to with-outputs-to
syn keyword lispFunc write-file system bash

syn cluster lispBaseListCluster add=duneVar
syn match duneVar '\${[@<^]}' containedin=lispSymbol
syn match duneVar '\${\k\+\(:\k\+\)\?}' containedin=lispSymbol

hi def link duneVar Identifier

let b:current_syntax = "dune"
