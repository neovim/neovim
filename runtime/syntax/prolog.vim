" Vim syntax file
" Language:    PROLOG
" Maintainer:  Anton Kochkov <anton.kochkov@gmail.com>
" Last Change: 2021 Jan 05

" There are two sets of highlighting in here:
" If the "prolog_highlighting_clean" variable exists, it is rather sparse.
" Otherwise you get more highlighting.
"
" You can also set the "prolog_highlighting_no_keyword" variable. If set,
" keywords will not be highlighted.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Prolog is case sensitive.
syn case match

" Very simple highlighting for comments, clause heads and
" character codes.  It respects prolog strings and atoms.

syn region   prologCComment start=+/\*+ end=+\*/+ contains=@Spell
syn match    prologComment  +%.*+ contains=@Spell

if !exists("prolog_highlighting_no_keyword")
  syn keyword  prologKeyword  module meta_predicate multifile dynamic
endif
syn match    prologCharCode +0'\\\=.+
syn region   prologString   start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell
syn region   prologAtom     start=+'+ skip=+\\\\\|\\'+ end=+'+
syn region   prologClause   matchgroup=prologClauseHead start=+^\s*[a-z]\w*+ matchgroup=Normal end=+\.\s\|\.$+ contains=ALLBUT,prologClause contains=@NoSpell

if !exists("prolog_highlighting_clean")

  " some keywords
  " some common predicates are also highlighted as keywords
  " is there a better solution?
  if !exists("prolog_highlighting_no_keyword")
    syn keyword prologKeyword   abolish current_output  peek_code
    syn keyword prologKeyword   append  current_predicate       put_byte
    syn keyword prologKeyword   arg     current_prolog_flag     put_char
    syn keyword prologKeyword   asserta fail    put_code
    syn keyword prologKeyword   assertz findall read
    syn keyword prologKeyword   at_end_of_stream        float   read_term
    syn keyword prologKeyword   atom    flush_output    repeat
    syn keyword prologKeyword   atom_chars      functor retract
    syn keyword prologKeyword   atom_codes      get_byte        set_input
    syn keyword prologKeyword   atom_concat     get_char        set_output
    syn keyword prologKeyword   atom_length     get_code        set_prolog_flag
    syn keyword prologKeyword   atomic  halt    set_stream_position
    syn keyword prologKeyword   bagof   integer setof
    syn keyword prologKeyword   call    is      stream_property
    syn keyword prologKeyword   catch   nl      sub_atom
    syn keyword prologKeyword   char_code       nonvar  throw
    syn keyword prologKeyword   char_conversion number  true
    syn keyword prologKeyword   clause  number_chars    unify_with_occurs_check
    syn keyword prologKeyword   close   number_codes    var
    syn keyword prologKeyword   compound        once    write
    syn keyword prologKeyword   copy_term       op      write_canonical
    syn keyword prologKeyword   current_char_conversion open    write_term
    syn keyword prologKeyword   current_input   peek_byte       writeq
    syn keyword prologKeyword   current_op      peek_char
  endif

  syn match   prologOperator "=\\=\|=:=\|\\==\|=<\|==\|>=\|\\=\|\\+\|=\.\.\|<\|>\|="
  syn match   prologAsIs     "===\|\\===\|<=\|=>"

  syn match   prologNumber            "\<\d*\>'\@!"
  syn match   prologNumber            "\<0[xX]\x*\>'\@!"
  syn match   prologCommentError      "\*/"
  syn match   prologSpecialCharacter  ";"
  syn match   prologSpecialCharacter  "!"
  syn match   prologSpecialCharacter  ":-"
  syn match   prologSpecialCharacter  "-->"
  syn match   prologQuestion          "?-.*\."  contains=prologNumber


endif

syn sync maxlines=50


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default highlighting.
hi def link prologComment          Comment
hi def link prologCComment         Comment
hi def link prologCharCode         Special

if exists ("prolog_highlighting_clean")

hi def link prologKeyword        Statement
hi def link prologClauseHead     Statement
hi def link prologClause Normal

else

hi def link prologKeyword        Keyword
hi def link prologClauseHead     Constant
hi def link prologClause Normal
hi def link prologQuestion       PreProc
hi def link prologSpecialCharacter Special
hi def link prologNumber         Number
hi def link prologAsIs           Normal
hi def link prologCommentError   Error
hi def link prologAtom           String
hi def link prologString         String
hi def link prologOperator       Operator

endif


let b:current_syntax = "prolog"

" vim: ts=8
