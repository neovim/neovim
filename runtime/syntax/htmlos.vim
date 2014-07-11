" Vim syntax file
" Language:	HTML/OS by Aestiva
" Maintainer:	Jason Rust <jrust@westmont.edu>
" URL:		http://www.rustyparts.com/vim/syntax/htmlos.vim
" Info:		http://www.rustyparts.com/scripts.php
" Last Change:	2003 May 11
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'htmlos'
endif

if version < 600
  so <sfile>:p:h/html.vim
else
  runtime! syntax/html.vim
  unlet b:current_syntax
endif

syn cluster htmlPreproc add=htmlosRegion

syn case ignore

" Function names
syn keyword	htmlosFunctions	expand sleep getlink version system ascii getascii syslock sysunlock cr lf clean postprep listtorow split listtocol coltolist rowtolist tabletolist	contained
syn keyword	htmlosFunctions	cut \display cutall cutx cutallx length reverse lower upper proper repeat left right middle trim trimleft trimright count countx locate locatex replace replacex replaceall replaceallx paste pasteleft pasteleftx pasteleftall pasteleftallx pasteright pasterightall pasterightallx chopleft chopleftx chopright choprightx format concat	contained
syn keyword	htmlosFunctions	goto exitgoto	contained
syn keyword	htmlosFunctions	layout cols rows row items getitem putitem switchitems gettable delrow delrows delcol delcols append  merge fillcol fillrow filltable pastetable getcol getrow fillindexcol insindexcol dups nodups maxtable mintable maxcol mincol maxrow minrow avetable avecol averow mediantable mediancol medianrow producttable productcol productrow sumtable sumcol sumrow sumsqrtable sumsqrcol sumsqrrow reversecols reverserows switchcols switchrows inscols insrows insfillcol sortcol reversesortcol sortcoln reversesortcoln sortrow sortrown reversesortrow reversesortrown getcoleq getcoleqn getcolnoteq getcolany getcolbegin getcolnotany getcolnotbegin getcolge getcolgt getcolle getcollt getcolgen getcolgtn getcollen getcoltn getcolend getcolnotend getrowend getrownotend getcolin getcolnotin getcolinbegin getcolnotinbegin getcolinend getcolnotinend getrowin getrownotin getrowinbegin getrownotinbegin getrowinend getrownotinend	contained
syn keyword	htmlosFunctions	dbcreate dbadd dbedit dbdelete dbsearch dbsearchsort dbget dbgetsort dbstatus dbindex dbimport dbfill dbexport dbsort dbgetrec dbremove dbpurge dbfind dbfindsort dbunique dbcopy dbmove dbkill dbtransfer dbpoke dbsearchx dbgetx	contained
syn keyword	htmlosFunctions	syshtmlosname sysstartname sysfixfile fileinfo filelist fileindex domainname page browser regdomain username usernum getenv httpheader copy file ts row sysls syscp sysmv sysmd sysrd filepush filepushlink dirname	contained
syn keyword	htmlosFunctions	mail to address subject netmail netmailopen netmailclose mailfilelist netweb netwebresults webpush netsockopen netsockread netsockwrite netsockclose	contained
syn keyword	htmlosFunctions today time systime now yesterday tomorrow getday getmonth getyear getminute getweekday getweeknum getyearday getdate gettime getamorpm gethour addhours addminutes adddays timebetween timetill timefrom datetill datefrom mixedtimebetween mixeddatetill mixedtimetill mixedtimefrom mixeddatefrom nextdaybyweekfromdate nextdaybyweekfromtoday nextdaybymonthfromdate nextdaybymonthfromtoday nextdaybyyearfromdate nextdaybyyearfromtoday offsetdaybyweekfromdate offsetdaybyweekfromtoday offsetdaybymonthfromdate offsetdaybymonthfromtoday	contained
syn keyword	htmlosFunctions isprivate ispublic isfile isdir isblank iserror iserror iseven isodd istrue isfalse islogical istext istag isnumber isinteger isdate istableeq istableeqx istableeqn isfuture ispast istoday isweekday isweekend issamedate iseq isnoteq isge isle ismod10 isvalidstring	contained
syn keyword	htmlosFunctions celtof celtokel ftocel ftokel keltocel keltof cmtoin intocm fttom mtoft fttomile miletoft kmtomile miletokm mtoyd ydtom galtoltr ltrtogal ltrtoqt qttoltr gtooz oztog kgtolb lbtokg mttoton tontomt	contained
syn keyword	htmlosFunctions max min abs sign inverse square sqrt cube roundsig round ceiling roundup floor rounddown roundeven rounddowneven roundupeven roundodd roundupodd rounddownodd random factorial summand fibonacci remainder mod radians degrees cos sin tan cotan secant cosecant acos asin atan exp power power10 ln log10 log sinh cosh tanh	contained
syn keyword	htmlosFunctions xmldelete xmldeletex xmldeleteattr xmldeleteattrx xmledit xmleditx xmleditvalue xmleditvaluex xmleditattr xmleditattrx xmlinsertbefore xmlinsertbeforex smlinsertafter xmlinsertafterx xmlinsertattr xmlinsertattrx smlget xmlgetx xmlgetvalue xmlgetvaluex xmlgetattrvalue xmlgetattrvaluex xmlgetrec xmlgetrecx xmlgetrecattrvalue xmlgetrecattrvaluex xmlchopleftbefore xmlchopleftbeforex xmlchoprightbefore xmlchoprightbeforex xmlchopleftafter xmlchopleftafterx xmlchoprightafter xmlchoprightafterx xmllocatebefore xmllocatebeforex xmllocateafter xmllocateafterx	contained

" Type
syn keyword	htmlosType	int str dol flt dat grp	contained

" StorageClass
syn keyword	htmlosStorageClass	locals	contained

" Operator
syn match	htmlosOperator	"[-=+/\*!]"	contained
syn match	htmlosRelation	"[~]"	contained
syn match	htmlosRelation	"[=~][&!]"	contained
syn match	htmlosRelation	"[!=<>]="	contained
syn match	htmlosRelation	"[<>]"	contained

" Comment
syn region	htmlosComment	start="#" end="/#"	contained

" Conditional
syn keyword	htmlosConditional	if then /if to else elif	contained
syn keyword	htmlosConditional	and or nand nor xor not	contained
" Repeat
syn keyword	htmlosRepeat	while do /while for /for	contained

" Keyword
syn keyword	htmlosKeyword	name value step do rowname colname rownum	contained

" Repeat
syn keyword	htmlosLabel	case matched /case switch	contained

" Statement
syn keyword	htmlosStatement     break exit return continue	contained

" Identifier
syn match	htmlosIdentifier	"\h\w*[\.]*\w*"	contained

" Special identifier
syn match	htmlosSpecialIdentifier	"[\$@]"	contained

" Define
syn keyword	htmlosDefine	function overlay	contained

" Boolean
syn keyword	htmlosBoolean	true false	contained

" String
syn region	htmlosStringDouble	keepend matchgroup=None start=+"+ end=+"+ contained
syn region	htmlosStringSingle	keepend matchgroup=None start=+'+ end=+'+ contained

" Number
syn match htmlosNumber	"-\=\<\d\+\>"	contained

" Float
syn match htmlosFloat	"\(-\=\<\d+\|-\=\)\.\d\+\>"	contained

" Error
syn match htmlosError	"ERROR"	contained

" Parent
syn match     htmlosParent       "[({[\]})]"     contained

" Todo
syn keyword	htmlosTodo TODO Todo todo	contained

syn cluster	htmlosInside	contains=htmlosComment,htmlosFunctions,htmlosIdentifier,htmlosSpecialIdentifier,htmlosConditional,htmlosRepeat,htmlosLabel,htmlosStatement,htmlosOperator,htmlosRelation,htmlosStringSingle,htmlosStringDouble,htmlosNumber,htmlosFloat,htmlosError,htmlosKeyword,htmlosType,htmlosBoolean,htmlosParent

syn cluster	htmlosTop	contains=@htmlosInside,htmlosDefine,htmlosError,htmlosStorageClass

syn region	 htmlosRegion	keepend matchgroup=Delimiter start="<<" skip=+".\{-}?>.\{-}"\|'.\{-}?>.\{-}'\|/\*.\{-}?>.\{-}\*/+ end=">>" contains=@htmlosTop
syn region	 htmlosRegion	keepend matchgroup=Delimiter start="\[\[" skip=+".\{-}?>.\{-}"\|'.\{-}?>.\{-}'\|/\*.\{-}?>.\{-}\*/+ end="\]\]" contains=@htmlosTop


" sync
if exists("htmlos_minlines")
  exec "syn sync minlines=" . htmlos_minlines
else
  syn sync minlines=100
endif

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_htmlos_syn_inits")
  if version < 508
    let did_htmlos_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default methods for highlighting.  Can be overridden later
  HiLink	 htmlosSpecialIdentifier	Operator
  HiLink	 htmlosIdentifier	Identifier
  HiLink	 htmlosStorageClass	StorageClass
  HiLink	 htmlosComment	Comment
  HiLink	 htmlosBoolean	Boolean
  HiLink	 htmlosStringSingle	String
  HiLink	 htmlosStringDouble	String
  HiLink	 htmlosNumber	Number
  HiLink	 htmlosFloat	Float
  HiLink	 htmlosFunctions	Function
  HiLink	 htmlosRepeat	Repeat
  HiLink	 htmlosConditional	Conditional
  HiLink	 htmlosLabel	Label
  HiLink	 htmlosStatement	Statement
  HiLink	 htmlosKeyword	Statement
  HiLink	 htmlosType	Type
  HiLink	 htmlosDefine	Define
  HiLink	 htmlosParent	Delimiter
  HiLink	 htmlosError	Error
  HiLink	 htmlosTodo	Todo
  HiLink	htmlosOperator	Operator
  HiLink	htmlosRelation	Operator

  delcommand HiLink
endif
let b:current_syntax = "htmlos"

if main_syntax == 'htmlos'
  unlet main_syntax
endif

" vim: ts=8 sw=2
