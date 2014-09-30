" Vim syntax file
" Language:    PROLOG
" Maintainers: Thomas Koehler <jean-luc@picard.franken.de>
" Last Change: 2013 May 23
" URL:         http://gott-gehabt.de/800_wer_wir_sind/thomas/Homepage/Computer/vim/syntax/prolog.vim

" There are two sets of highlighting in here:
" If the "prolog_highlighting_clean" variable exists, it is rather sparse.
" Otherwise you get more highlighting.

" Quit when a syntax file was already loaded
if version < 600
   syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Prolog is case sensitive.
syn case match

" Very simple highlighting for comments, clause heads and
" character codes.  It respects prolog strings and atoms.

syn region   prologCComment start=+/\*+ end=+\*/+
syn match    prologComment  +%.*+

syn keyword  prologKeyword  module meta_predicate multifile dynamic
syn match    prologCharCode +0'\\\=.+
syn region   prologString   start=+"+ skip=+\\\\\|\\"+ end=+"+
syn region   prologAtom     start=+'+ skip=+\\\\\|\\'+ end=+'+
syn region   prologClause   matchgroup=prologClauseHead start=+^\s*[a-z]\w*+ matchgroup=Normal end=+\.\s\|\.$+ contains=ALLBUT,prologClause

if !exists("prolog_highlighting_clean")

  " some keywords
  " some common predicates are also highlighted as keywords
  " is there a better solution?
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

  syn match   prologOperator "=\\=\|=:=\|\\==\|=<\|==\|>=\|\\=\|\\+\|<\|>\|="
  syn match   prologAsIs     "===\|\\===\|<=\|=>"

  syn match   prologNumber            "\<[0123456789]*\>'\@!"
  syn match   prologCommentError      "\*/"
  syn match   prologSpecialCharacter  ";"
  syn match   prologSpecialCharacter  "!"
  syn match   prologSpecialCharacter  ":-"
  syn match   prologSpecialCharacter  "-->"
  syn match   prologQuestion          "?-.*\."  contains=prologNumber


endif

syn sync maxlines=50


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_prolog_syn_inits")
  if version < 508
    let did_prolog_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default highlighting.
  HiLink prologComment          Comment
  HiLink prologCComment         Comment
  HiLink prologCharCode         Special

  if exists ("prolog_highlighting_clean")

    HiLink prologKeyword        Statement
    HiLink prologClauseHead     Statement
    HiLink prologClause Normal

  else

    HiLink prologKeyword        Keyword
    HiLink prologClauseHead     Constant
    HiLink prologClause Normal
    HiLink prologQuestion       PreProc
    HiLink prologSpecialCharacter Special
    HiLink prologNumber         Number
    HiLink prologAsIs           Normal
    HiLink prologCommentError   Error
    HiLink prologAtom           String
    HiLink prologString         String
    HiLink prologOperator       Operator

  endif

  delcommand HiLink
endif

let b:current_syntax = "prolog"

" vim: ts=8
