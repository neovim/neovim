" Vim syntax file
" Language:     Mathematica
" Maintainer:   steve layland <layland@wolfram.com>
" Last Change:  2012 Feb 03 by Thilo Six
"               2024 May 24 by Riley Bruins <ribru17@gmail.com> (remove 'commentstring')
" Source:       http://members.wri.com/layland/vim/syntax/mma.vim
"               http://vim.sourceforge.net/scripts/script.php?script_id=1273
" Id:           $Id: mma.vim,v 1.4 2006/04/14 20:40:38 vimboss Exp $
" NOTE:
"
" Empty .m files will automatically be presumed as Matlab files
" unless you have the following in your .vimrc:
"
"       let filetype_m="mma"
"
" I also recommend setting the default 'Comment' highlighting to something
" other than the color used for 'Function', since both are plentiful in
" most mathematica files, and they are often the same color (when using
" background=dark).
"
" Credits:
" o  Original Mathematica syntax version written by
"    Wolfgang Waltenberger <wwalten@ben.tuwien.ac.at>
" o  Some ideas like the CommentStar,CommentTitle were adapted
"    from the Java vim syntax file by Claudio Fleiner.  Thanks!
" o  Everything else written by steve <layland@wolfram.com>
"
" Bugs:
" o  Vim 6.1 didn't really have support for character classes
"    of other named character classes.  For example, [\a\d]
"    didn't work.  Therefore, a lot of this code uses explicit
"    character classes instead: [0-9a-zA-Z]
"
" TODO:
"   folding
"   fix nesting
"   finish populating popular symbols

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Group Definitions:
syntax cluster mmaNotes contains=mmaTodo,mmaFixme
syntax cluster mmaComments contains=mmaComment,mmaFunctionComment,mmaItem,mmaFunctionTitle,mmaCommentStar
syntax cluster mmaCommentStrings contains=mmaLooseQuote,mmaCommentString,mmaUnicode
syntax cluster mmaStrings contains=@mmaCommentStrings,mmaString
syntax cluster mmaTop contains=mmaOperator,mmaGenericFunction,mmaPureFunction,mmaVariable

" Predefined Constants:
"   to list all predefined Symbols would be too insane...
"   it's probably smarter to define a select few, and get the rest from
"   context if absolutely necessary.
"   TODO - populate this with other often used Symbols

" standard fixed symbols:
syntax keyword mmaVariable True False None Automatic All Null C General

" mathematical constants:
syntax keyword mmaVariable Pi I E Infinity ComplexInfinity Indeterminate GoldenRatio EulerGamma Degree Catalan Khinchin Glaisher

" stream data / atomic heads:
syntax keyword mmaVariable Byte Character Expression Number Real String Word EndOfFile Integer Symbol

" sets:
syntax keyword mmaVariable Integers Complexes Reals Booleans Rationals

" character classes:
syntax keyword mmaPattern DigitCharacter LetterCharacter WhitespaceCharacter WordCharacter EndOfString StartOfString EndOfLine StartOfLine WordBoundary

" SelectionMove directions/units:
syntax keyword mmaVariable Next Previous After Before Character Word Expression TextLine CellContents Cell CellGroup EvaluationCell ButtonCell GeneratedCell Notebook
syntax keyword mmaVariable CellTags CellStyle CellLabel

" TableForm positions:
syntax keyword mmaVariable Above Below Left Right

" colors:
syntax keyword mmaVariable Black Blue Brown Cyan Gray Green Magenta Orange Pink Purple Red White Yellow

" function attributes
syntax keyword mmaVariable Protected Listable OneIdentity Orderless Flat Constant NumericFunction Locked ReadProtected HoldFirst HoldRest HoldAll HoldAllComplete SequenceHold NHoldFirst NHoldRest NHoldAll Temporary Stub

" Comment Sections:
"   this:
"   :that:
syntax match mmaItem "\%(^[( |*\t]*\)\@<=\%(:\+\|\w\)\w\+\%( \w\+\)\{0,3}:" contained contains=@mmaNotes

" Comment Keywords:
syntax keyword mmaTodo TODO NOTE HEY contained
syntax match mmaTodo "X\{3,}" contained
syntax keyword mmaFixme FIX[ME] FIXTHIS BROKEN contained
syntax match mmaFixme "BUG\%( *\#\=[0-9]\+\)\=" contained
" yay pirates...
syntax match mmaFixme "\%(Y\=A\+R\+G\+\|GRR\+\|CR\+A\+P\+\)\%(!\+\)\=" contained

" EmPHAsis:
" this unnecessary, but whatever :)
syntax match mmaemPHAsis "\%(^\|\s\)\([_/]\)[a-zA-Z0-9]\+\%([- \t':]\+[a-zA-Z0-9]\+\)*\1\%(\s\|$\)" contained contains=mmaemPHAsis
syntax match mmaemPHAsis "\%(^\|\s\)(\@<!\*[a-zA-Z0-9]\+\%([- \t':]\+[a-zA-Z0-9]\+\)*)\@!\*\%(\s\|$\)" contained contains=mmaemPHAsis

" Regular Comments:
"   (* *)
"   allow nesting (* (* *) *) even though the frontend
"   won't always like it.
syntax region mmaComment start=+(\*+ end=+\*)+ skipempty contains=@mmaNotes,mmaItem,@mmaCommentStrings,mmaemPHAsis,mmaComment

" Function Comments:
"   just like a normal comment except the first sentence is Special ala Java
"   (** *)
"   TODO - fix this for nesting, or not...
syntax region mmaFunctionComment start="(\*\*\+" end="\*\+)" contains=@mmaNotes,mmaItem,mmaFunctionTitle,@mmaCommentStrings,mmaemPHAsis,mmaComment
syntax region mmaFunctionTitle contained matchgroup=mmaFunctionComment start="\%((\*\*[ *]*\)" matchgroup=mmaFunctionTitle keepend end=".[.!-]\=\s*$" end="[.!-][ \t\r<&]"me=e-1 end="\%(\*\+)\)\@=" contained contains=@mmaNotes,mmaItem,mmaCommentStar

" catch remaining (**********)'s
syntax match mmaComment "(\*\*\+)"
" catch preceding *
syntax match mmaCommentStar "^\s*\*\+" contained

" Variables:
"   Dollar sign variables
syntax match mmaVariable "\$\a\+[0-9a-zA-Z$]*"

"   Preceding and Following Contexts
syntax match mmaVariable "`[a-zA-Z$]\+[0-9a-zA-Z$]*" contains=mmaVariable
syntax match mmaVariable "[a-zA-Z$]\+[0-9a-zA-Z$]*`" contains=mmaVariable

" Strings:
"   "string"
"   'string' is not accepted (until literal strings are supported!)
syntax region mmaString start=+\\\@<!"+ skip=+\\\@<!\\\%(\\\\\)*"+ end=+"+
syntax region mmaCommentString oneline start=+\\\@<!"+ skip=+\\\@<!\\\%(\\\\\)*"+ end=+"+ contained


" Patterns:
"   Each pattern marker below can be Blank[] (_), BlankSequence[] (__)
"   or BlankNullSequence[] (___).  Most examples below can also be
"   combined, for example Pattern tests with Default values.
"
"   _Head                   Anonymous patterns
"   name_Head
"   name:(_Head|_Head2)     Named patterns
"
"   _Head : val
"   name:_Head:val          Default values
"
"   _Head?testQ,
"   _Head?(test[#]&)        Pattern tests
"
"   name_Head/;test[name]   Conditionals
"
"   _Head:.                 Predefined Default
"
"   .. ...                  Pattern Repeat

syntax match mmaPatternError "\%(_\{4,}\|)\s*&\s*)\@!\)" contained

"pattern name:
syntax match mmaPattern "[A-Za-z0-9`]\+\s*:\+[=>]\@!" contains=mmaOperator
"pattern default:
syntax match mmaPattern ": *[^ ,]\+[\], ]\@=" contains=@mmaCommentStrings,@mmaTop,mmaOperator
"pattern head/test:
syntax match mmaPattern "[A-Za-z0-9`]*_\+\%(\a\+\)\=\%(?([^)]\+)\|?[^\]},]\+\)\=" contains=@mmaTop,@mmaCommentStrings,mmaPatternError

" Operators:
"   /: ^= ^:=   UpValue
"   /;          Conditional
"   := =        DownValue
"   == === ||
"   != =!= &&   Logic
"   >= <= < >
"   += -= *=
"   /= ++ --    Math
"   ^*
"   -> :>       Rules
"   @@ @@@      Apply
"   /@ //@      Map
"   /. //.      Replace
"   // @        Function application
"   <> ~~       String/Pattern join
"   ~           infix operator
"   . :         Pattern operators
syntax match mmaOperator "\%(@\{1,3}\|//[.@]\=\)"
syntax match mmaOperator "\%(/[;:@.]\=\|\^\=:\==\)"
syntax match mmaOperator "\%([-:=]\=>\|<=\=\)"
"syntax match mmaOperator "\%(++\=\|--\=\|[/+-*]=\|[^*]\)"
syntax match mmaOperator "[*+=^.:?-]"
syntax match mmaOperator "\%(\~\~\=\)"
syntax match mmaOperator "\%(=\{2,3}\|=\=!=\|||\=\|&&\|!\)" contains=ALLBUT,mmaPureFunction

" Symbol Tags:
"   "SymbolName::item"
"syntax match mmaSymbol "`\=[a-zA-Z$]\+[0-9a-zA-Z$]*\%(`\%([a-zA-Z$]\+[0-9a-zA-Z$]*\)\=\)*" contained
syntax match mmaMessage "`\=\([a-zA-Z$]\+[0-9a-zA-Z$]*\)\%(`\%([a-zA-Z$]\+[0-9a-zA-Z$]*\)\=\)*::\a\+" contains=mmaMessageType
syntax match mmaMessageType "::\a\+"hs=s+2 contained

" Pure Functions:
syntax match mmaPureFunction "#\%(#\|\d\+\)\="
syntax match mmaPureFunction "&"

" Named Functions:
" Since everything is pretty much a function, get this straight
" from context
syntax match mmaGenericFunction "[A-Za-z0-9`]\+\s*\%([@[]\|/:\|/\=/@\)\@=" contains=mmaOperator
syntax match mmaGenericFunction "\~\s*[^~]\+\s*\~"hs=s+1,he=e-1 contains=mmaOperator,mmaBoring
syntax match mmaGenericFunction "//\s*[A-Za-z0-9`]\+"hs=s+2 contains=mmaOperator

" Numbers:
syntax match mmaNumber "\<\%(\d\+\.\=\d*\|\d*\.\=\d\+\)\>"
syntax match mmaNumber "`\d\+\%(\d\@!\.\|\>\)"

" Special Characters:
"   \[Name]     named character
"   \ooo        octal
"   \.xx        2 digit hex
"   \:xxxx      4 digit hex (multibyte unicode)
syntax match mmaUnicode "\\\[\w\+\d*\]"
syntax match mmaUnicode "\\\%(\x\{3}\|\.\x\{2}\|:\x\{4}\)"

" Syntax Errors:
syntax match mmaError "\*)" containedin=ALLBUT,@mmaComments,@mmaStrings
syntax match mmaError "\%([/]{3,}\|[&:|+*?~-]\{3,}\|[.=]\{4,}\|_\@<=\.\{2,}\|`\{2,}\)" containedin=ALLBUT,@mmaComments,@mmaStrings

" Punctuation:
" things that shouldn't really be highlighted, or highlighted
" in they're own group if you _really_ want. :)
"  ( ) { }
" TODO - use Delimiter group?
syntax match mmaBoring "[(){}]" contained

" ------------------------------------
"    future explorations...
" ------------------------------------
" Function Arguments:
"   anything between brackets []
"   (fold)
"syntax region mmaArgument start="\[" end="\]" containedin=ALLBUT,@mmaComments,@mmaStrings transparent fold

" Lists:
"   (fold)
"syntax region mmaLists start="{" end="}" containedin=ALLBUT,@mmaComments,@mmaStrings transparent fold

" Regions:
"   (fold)
"syntax region mmaRegion start="(\*\+[^<]*<!--[^>]*\*\+)" end="--> \*)" containedin=ALLBUT,@mmaStrings transparent fold keepend

" show fold text
"set foldtext=MmaFoldText()

"function MmaFoldText()
"    let line = getline(v:foldstart)
"
"    let lines = v:foldend-v:foldstart+1
"
"    let sub = substitute(line, '(\*\+|\*\+)|[-*_]\+', '', 'g')
"
"    if match(line, '(\*') != -1
"        let lines = lines.' line comment'
"    else
"        let lines = lines.' lines'
"    endif
"
"    return v:folddashes.' '.lines.' '.sub
"endf

"this is slow for computing folds, but it does so accurately
syntax sync fromstart

" but this seems to do alright for non fold syntax coloring.
" for folding, however, it doesn't get the nesting right.
" TODO - find sync group for multiline modules? ick...

" sync multi line comments
"syntax sync match syncComments groupthere NONE "\*)"
"syntax sync match syncComments groupthere mmaComment "(\*"

"set foldmethod=syntax
"set foldnestmax=1
"set foldminlines=15


" NOTE - the following links are not guaranteed to
" look good under all colorschemes.  You might need to
" :so $VIMRUNTIME/syntax/hitest.vim and tweak these to
" look good in yours


hi def link mmaComment           Comment
hi def link mmaCommentStar       Comment
hi def link mmaFunctionComment   Comment
hi def link mmaLooseQuote        Comment
hi def link mmaGenericFunction   Function
hi def link mmaVariable          Identifier
"    hi def link mmaSymbol            Identifier
hi def link mmaOperator          Operator
hi def link mmaPatternOp         Operator
hi def link mmaPureFunction      Operator
hi def link mmaString            String
hi def link mmaCommentString     String
hi def link mmaUnicode           String
hi def link mmaMessage           Type
hi def link mmaNumber            Type
hi def link mmaPattern           Type
hi def link mmaError             Error
hi def link mmaFixme             Error
hi def link mmaPatternError      Error
hi def link mmaTodo              Todo
hi def link mmaemPHAsis          Special
hi def link mmaFunctionTitle     Special
hi def link mmaMessageType       Special
hi def link mmaItem              Preproc


let b:current_syntax = "mma"

let &cpo = s:cpo_save
unlet s:cpo_save
