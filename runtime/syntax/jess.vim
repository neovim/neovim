" Vim syntax file
" Language:	Jess
" Maintainer:	Paul Baleme <pbaleme@mail.com>
" Last change:	September 14, 2000
" Based on lisp.vim by : Dr. Charles E. Campbell, Jr.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

setlocal iskeyword=42,43,45,47-58,60-62,64-90,97-122,_

" Lists
syn match	jessSymbol	![^()'`,"; \t]\+!	contained
syn match	jessBarSymbol	!|..\{-}|!		contained
syn region	jessList matchgroup=Delimiter start="(" skip="|.\{-}|" matchgroup=Delimiter end=")" contains=jessAtom,jessBQList,jessConcat,jessDeclaration,jessList,jessNumber,jessSymbol,jessSpecial,jessFunc,jessKey,jessAtomMark,jessString,jessComment,jessBarSymbol,jessAtomBarSymbol,jessVar
syn region	jessBQList	matchgroup=PreProc   start="`("	skip="|.\{-}|" matchgroup=PreProc   end=")" contains=jessAtom,jessBQList,jessConcat,jessDeclaration,jessList,jessNumber,jessSpecial,jessSymbol,jessFunc,jessKey,jessVar,jessAtomMark,jessString,jessComment,jessBarSymbol,jessAtomBarSymbol

" Atoms
syn match	jessAtomMark	"'"
syn match	jessAtom	"'("me=e-1	contains=jessAtomMark	nextgroup=jessAtomList
syn match	jessAtom	"'[^ \t()]\+"	contains=jessAtomMark
syn match	jessAtomBarSymbol	!'|..\{-}|!	contains=jessAtomMark
syn region	jessAtom	start=+'"+	skip=+\\"+ end=+"+
syn region	jessAtomList	matchgroup=Special start="("	skip="|.\{-}|" matchgroup=Special end=")"	contained contains=jessAtomList,jessAtomNmbr0,jessString,jessComment,jessAtomBarSymbol
syn match	jessAtomNmbr	"\<[0-9]\+"			contained

" Standard jess Functions and Macros
syn keyword jessFunc    *   +   **	-   /   <   >   <=  >=  <>  =
syn keyword jessFunc    long	    longp
syn keyword jessFunc    abs	    agenda	      and
syn keyword jessFunc    assert	    assert-string       bag
syn keyword jessFunc    batch	    bind	      bit-and
syn keyword jessFunc    bit-not	    bit-or	      bload
syn keyword jessFunc    bsave	    build	      call
syn keyword jessFunc    clear	    clear-storage       close
syn keyword jessFunc    complement$     context	      count-query-results
syn keyword jessFunc    create$
syn keyword jessFunc    delete$	    div
syn keyword jessFunc    do-backward-chaining	      e
syn keyword jessFunc    engine	    eq	      eq*
syn keyword jessFunc    eval	    evenp	      exit
syn keyword jessFunc    exp	    explode$	      external-addressp
syn keyword jessFunc    fact-slot-value facts	      fetch
syn keyword jessFunc    first$	    float	      floatp
syn keyword jessFunc    foreach	    format	      gensym*
syn keyword jessFunc    get	    get-fact-duplication
syn keyword jessFunc    get-member	    get-multithreaded-io
syn keyword jessFunc    get-reset-globals	      get-salience-evaluation
syn keyword jessFunc    halt	    if	      implode$
syn keyword jessFunc    import	    insert$	      integer
syn keyword jessFunc    integerp	    intersection$       jess-version-number
syn keyword jessFunc    jess-version-string	      length$
syn keyword jessFunc    lexemep	    list-function$      load-facts
syn keyword jessFunc    load-function   load-package	      log
syn keyword jessFunc    log10	    lowcase	      matches
syn keyword jessFunc    max	    member$	      min
syn keyword jessFunc    mod	    modify	      multifieldp
syn keyword jessFunc    neq	    new	      not
syn keyword jessFunc    nth$	    numberp	      oddp
syn keyword jessFunc    open	    or	      pi
syn keyword jessFunc    ppdeffunction   ppdefglobal	      ddpefrule
syn keyword jessFunc    printout	    random	      read
syn keyword jessFunc    readline	    replace$	      reset
syn keyword jessFunc    rest$	    retract	      retract-string
syn keyword jessFunc    return	    round	      rules
syn keyword jessFunc    run	    run-query	      run-until-halt
syn keyword jessFunc    save-facts	    set	      set-fact-duplication
syn keyword jessFunc    set-factory     set-member	      set-multithreaded-io
syn keyword jessFunc    set-node-index-hash	      set-reset-globals
syn keyword jessFunc    set-salience-evaluation	      set-strategy
syn keyword jessFunc    setgen	    show-deffacts       show-deftemplates
syn keyword jessFunc    show-jess-listeners	      socket
syn keyword jessFunc    sqrt	    store	      str-cat
syn keyword jessFunc    str-compare     str-index	      str-length
syn keyword jessFunc    stringp	    sub-string	      subseq$
syn keyword jessFunc    subsetp	    sym-cat	      symbolp
syn keyword jessFunc    system	    throw	      time
syn keyword jessFunc    try	    undefadvice	      undefinstance
syn keyword jessFunc    undefrule	    union$	      unwatch
syn keyword jessFunc    upcase	    view	      watch
syn keyword jessFunc    while
syn match   jessFunc	"\<c[ad]\+r\>"

" jess Keywords (modifiers)
syn keyword jessKey	    defglobal	  deffunction	    defrule
syn keyword jessKey	    deffacts
syn keyword jessKey	    defadvice	  defclass	    definstance

" Standard jess Variables
syn region	jessVar	start="?"	end="[^a-zA-Z0-9]"me=e-1

" Strings
syn region	jessString	start=+"+	skip=+\\"+ end=+"+

" Shared with Declarations, Macros, Functions
"syn keyword	jessDeclaration

syn match	jessNumber	"[0-9]\+"

syn match	jessSpecial	"\*[a-zA-Z_][a-zA-Z_0-9-]*\*"
syn match	jessSpecial	!#|[^()'`,"; \t]\+|#!
syn match	jessSpecial	!#x[0-9a-fA-F]\+!
syn match	jessSpecial	!#o[0-7]\+!
syn match	jessSpecial	!#b[01]\+!
syn match	jessSpecial	!#\\[ -\~]!
syn match	jessSpecial	!#[':][^()'`,"; \t]\+!
syn match	jessSpecial	!#([^()'`,"; \t]\+)!

syn match	jessConcat	"\s\.\s"
syntax match	jessParenError	")"

" Comments
syn match	jessComment	";.*$"

" synchronization
syn sync lines=100

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link jessAtomNmbr	jessNumber
hi def link jessAtomMark	jessMark

hi def link jessAtom		Identifier
hi def link jessAtomBarSymbol	Special
hi def link jessBarSymbol	Special
hi def link jessComment	Comment
hi def link jessConcat	Statement
hi def link jessDeclaration	Statement
hi def link jessFunc		Statement
hi def link jessKey		Type
hi def link jessMark		Delimiter
hi def link jessNumber	Number
hi def link jessParenError	Error
hi def link jessSpecial	Type
hi def link jessString	String
hi def link jessVar		Identifier


let b:current_syntax = "jess"

" vim: ts=18
