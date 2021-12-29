" Vim syntax file
" Language:     S-expressions as used in Sexplib
" Filenames:    *.sexp
" Maintainers:  Markus Mottl      <markus.mottl@gmail.com>
" URL:          https://github.com/ocaml/vim-ocaml
" Last Change:  2020 Dec 31 - Updated header for Vim contribution (MM)
"               2017 Apr 11 - Improved matching of negative numbers (MM)
"               2012 Jun 20 - Fixed a block comment highlighting bug (MM)

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax") && b:current_syntax == "sexplib"
  finish
endif

" Sexplib is case sensitive.
syn case match

" Comments
syn keyword  sexplibTodo contained TODO FIXME XXX NOTE
syn region   sexplibBlockComment matchgroup=sexplibComment start="#|" matchgroup=sexplibComment end="|#" contains=ALLBUT,sexplibQuotedAtom,sexplibUnquotedAtom,sexplibEncl,sexplibComment
syn match    sexplibSexpComment "#;" skipwhite skipempty nextgroup=sexplibQuotedAtomComment,sexplibUnquotedAtomComment,sexplibListComment,sexplibComment
syn region   sexplibQuotedAtomComment start=+"+ skip=+\\\\\|\\"+ end=+"+ contained
syn match    sexplibUnquotedAtomComment /\([^;()" \t#|]\|#[^;()" \t|]\||[^;()" \t#]\)[^;()" \t]*/ contained
syn region   sexplibListComment matchgroup=sexplibComment start="(" matchgroup=sexplibComment end=")" contained contains=ALLBUT,sexplibEncl,sexplibString,sexplibQuotedAtom,sexplibUnquotedAtom,sexplibTodo,sexplibNumber,sexplibFloat
syn match    sexplibComment ";.*" contains=sexplibTodo

" Atoms
syn match    sexplibUnquotedAtom /\([^;()" \t#|]\|#[^;()" \t|]\||[^;()" \t#]\)[^;()" \t]*/
syn region   sexplibQuotedAtom    start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match    sexplibNumber        "-\=\<\d\(_\|\d\)*[l|L|n]\?\>"
syn match    sexplibNumber        "-\=\<0[x|X]\(\x\|_\)\+[l|L|n]\?\>"
syn match    sexplibNumber        "-\=\<0[o|O]\(\o\|_\)\+[l|L|n]\?\>"
syn match    sexplibNumber        "-\=\<0[b|B]\([01]\|_\)\+[l|L|n]\?\>"
syn match    sexplibFloat         "-\=\<\d\(_\|\d\)*\.\?\(_\|\d\)*\([eE][-+]\=\d\(_\|\d\)*\)\=\>"

" Lists
syn region   sexplibEncl transparent matchgroup=sexplibEncl start="(" matchgroup=sexplibEncl end=")" contains=ALLBUT,sexplibParenErr

" Errors
syn match    sexplibUnquotedAtomErr /\([^;()" \t#|]\|#[^;()" \t|]\||[^;()" \t#]\)[^;()" \t]*\(#|\||#\)[^;()" \t]*/
syn match    sexplibParenErr ")"

" Synchronization
syn sync minlines=50
syn sync maxlines=500

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_sexplib_syntax_inits")
  if version < 508
    let did_sexplib_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink sexplibParenErr            Error
  HiLink sexplibUnquotedAtomErr     Error

  HiLink sexplibComment             Comment
  HiLink sexplibSexpComment         Comment
  HiLink sexplibQuotedAtomComment   Include
  HiLink sexplibUnquotedAtomComment Comment
  HiLink sexplibBlockComment        Comment
  HiLink sexplibListComment         Comment

  HiLink sexplibBoolean             Boolean
  HiLink sexplibCharacter           Character
  HiLink sexplibNumber              Number
  HiLink sexplibFloat               Float
  HiLink sexplibUnquotedAtom        Identifier
  HiLink sexplibEncl                Identifier
  HiLink sexplibQuotedAtom          Keyword

  HiLink sexplibTodo                Todo

  HiLink sexplibEncl                Keyword

  delcommand HiLink
endif

let b:current_syntax = "sexplib"

" vim: ts=8
