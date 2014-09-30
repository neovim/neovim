" Vim syntax file
" Language:	SDL
" Maintainer:	Michael Piefel <entwurf@piefel.de>
" Last Change:	2 May 2001

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

if !exists("sdl_2000")
    syntax case ignore
endif

" A bunch of useful SDL keywords
syn keyword sdlStatement	task else nextstate
syn keyword sdlStatement	in out with from interface
syn keyword sdlStatement	to via env and use
syn keyword sdlStatement	process procedure block system service type
syn keyword sdlStatement	endprocess endprocedure endblock endsystem
syn keyword sdlStatement	package endpackage connection endconnection
syn keyword sdlStatement	channel endchannel connect
syn keyword sdlStatement	synonym dcl signal gate timer signallist signalset
syn keyword sdlStatement	create output set reset call
syn keyword sdlStatement	operators literals
syn keyword sdlStatement	active alternative any as atleast constants
syn keyword sdlStatement	default endalternative endmacro endoperator
syn keyword sdlStatement	endselect endsubstructure external
syn keyword sdlStatement	if then fi for import macro macrodefinition
syn keyword sdlStatement	macroid mod nameclass nodelay not operator or
syn keyword sdlStatement	parent provided referenced rem
syn keyword sdlStatement	select spelling substructure xor
syn keyword sdlNewState		state endstate
syn keyword sdlInput		input start stop return none save priority
syn keyword sdlConditional	decision enddecision join
syn keyword sdlVirtual		virtual redefined finalized adding inherits
syn keyword sdlExported		remote exported export

if !exists("sdl_no_96")
    syn keyword sdlStatement	all axioms constant endgenerator endrefinement endservice
    syn keyword sdlStatement	error fpar generator literal map noequality ordering
    syn keyword sdlStatement	refinement returns revealed reverse service signalroute
    syn keyword sdlStatement	view viewed
    syn keyword sdlExported	imported
endif

if exists("sdl_2000")
    syn keyword sdlStatement	abstract aggregation association break choice composition
    syn keyword sdlStatement	continue endmethod handle method
    syn keyword sdlStatement	ordered private protected public
    syn keyword sdlException	exceptionhandler endexceptionhandler onexception
    syn keyword sdlException	catch new raise
    " The same in uppercase
    syn keyword sdlStatement	TASK ELSE NEXTSTATE
    syn keyword sdlStatement	IN OUT WITH FROM INTERFACE
    syn keyword sdlStatement	TO VIA ENV AND USE
    syn keyword sdlStatement	PROCESS PROCEDURE BLOCK SYSTEM SERVICE TYPE
    syn keyword sdlStatement	ENDPROCESS ENDPROCEDURE ENDBLOCK ENDSYSTEM
    syn keyword sdlStatement	PACKAGE ENDPACKAGE CONNECTION ENDCONNECTION
    syn keyword sdlStatement	CHANNEL ENDCHANNEL CONNECT
    syn keyword sdlStatement	SYNONYM DCL SIGNAL GATE TIMER SIGNALLIST SIGNALSET
    syn keyword sdlStatement	CREATE OUTPUT SET RESET CALL
    syn keyword sdlStatement	OPERATORS LITERALS
    syn keyword sdlStatement	ACTIVE ALTERNATIVE ANY AS ATLEAST CONSTANTS
    syn keyword sdlStatement	DEFAULT ENDALTERNATIVE ENDMACRO ENDOPERATOR
    syn keyword sdlStatement	ENDSELECT ENDSUBSTRUCTURE EXTERNAL
    syn keyword sdlStatement	IF THEN FI FOR IMPORT MACRO MACRODEFINITION
    syn keyword sdlStatement	MACROID MOD NAMECLASS NODELAY NOT OPERATOR OR
    syn keyword sdlStatement	PARENT PROVIDED REFERENCED REM
    syn keyword sdlStatement	SELECT SPELLING SUBSTRUCTURE XOR
    syn keyword sdlNewState	STATE ENDSTATE
    syn keyword sdlInput	INPUT START STOP RETURN NONE SAVE PRIORITY
    syn keyword sdlConditional	DECISION ENDDECISION JOIN
    syn keyword sdlVirtual	VIRTUAL REDEFINED FINALIZED ADDING INHERITS
    syn keyword sdlExported	REMOTE EXPORTED EXPORT

    syn keyword sdlStatement	ABSTRACT AGGREGATION ASSOCIATION BREAK CHOICE COMPOSITION
    syn keyword sdlStatement	CONTINUE ENDMETHOD ENDOBJECT ENDVALUE HANDLE METHOD OBJECT
    syn keyword sdlStatement	ORDERED PRIVATE PROTECTED PUBLIC
    syn keyword sdlException	EXCEPTIONHANDLER ENDEXCEPTIONHANDLER ONEXCEPTION
    syn keyword sdlException	CATCH NEW RAISE
endif

" String and Character contstants
" Highlight special characters (those which have a backslash) differently
syn match   sdlSpecial		contained "\\\d\d\d\|\\."
syn region  sdlString		start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=cSpecial
syn region  sdlString		start=+'+  skip=+''+  end=+'+

" No, this doesn't happen, I just wanted to scare you. SDL really allows all
" these characters for identifiers; fortunately, keywords manage without them.
" set iskeyword=@,48-57,_,192-214,216-246,248-255,-

syn region sdlComment		start="/\*"  end="\*/"
syn region sdlComment		start="comment"  end=";"
syn region sdlComment		start="--" end="--\|$"
syn match  sdlCommentError	"\*/"

syn keyword sdlOperator		present
syn keyword sdlType		integer real natural duration pid boolean time
syn keyword sdlType		character charstring ia5string
syn keyword sdlType		self now sender offspring
syn keyword sdlStructure	asntype endasntype syntype endsyntype struct

if !exists("sdl_no_96")
    syn keyword sdlStructure	newtype endnewtype
endif

if exists("sdl_2000")
    syn keyword sdlStructure	object endobject value endvalue
    " The same in uppercase
    syn keyword sdlStructure	OBJECT ENDOBJECT VALUE ENDVALUE
    syn keyword sdlOperator	PRESENT
    syn keyword sdlType		INTEGER NATURAL DURATION PID BOOLEAN TIME
    syn keyword sdlType		CHARSTRING IA5STRING
    syn keyword sdlType		SELF NOW SENDER OFFSPRING
    syn keyword sdlStructure	ASNTYPE ENDASNTYPE SYNTYPE ENDSYNTYPE STRUCT
endif

" ASN.1 in SDL
syn case match
syn keyword sdlType		SET OF BOOLEAN INTEGER REAL BIT OCTET
syn keyword sdlType		SEQUENCE CHOICE
syn keyword sdlType		STRING OBJECT IDENTIFIER NULL

syn sync ccomment sdlComment

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_sdl_syn_inits")
    if version < 508
	let did_sdl_syn_inits = 1
	command -nargs=+ HiLink hi link <args>
	command -nargs=+ Hi     hi <args>
    else
	command -nargs=+ HiLink hi def link <args>
	command -nargs=+ Hi     hi def <args>
    endif

    HiLink  sdlException	Label
    HiLink  sdlConditional	sdlStatement
    HiLink  sdlVirtual		sdlStatement
    HiLink  sdlExported		sdlFlag
    HiLink  sdlCommentError	sdlError
    HiLink  sdlOperator		Operator
    HiLink  sdlStructure	sdlType
    Hi	    sdlStatement	term=bold ctermfg=4 guifg=Blue
    Hi	    sdlFlag		term=bold ctermfg=4 guifg=Blue gui=italic
    Hi	    sdlNewState		term=italic ctermfg=2 guifg=Magenta gui=underline
    Hi	    sdlInput		term=bold guifg=Red
    HiLink  sdlType		Type
    HiLink  sdlString		String
    HiLink  sdlComment		Comment
    HiLink  sdlSpecial		Special
    HiLink  sdlError		Error

    delcommand HiLink
    delcommand Hi
endif

let b:current_syntax = "sdl"

" vim: ts=8
