" Vim syntax file
" Language:	LifeLines (v 3.0.62) <http://lifelines.sourceforge.net>
" Maintainer:	Patrick Texier <p.texier@orsennes.com>
" Location:	<http://patrick.texier.free.fr/vim/syntax/lifelines.vim>
" Last Change:	2010 May 7

" option to highlight error obsolete statements
" add the following line to your .vimrc file :
" let lifelines_deprecated = 1

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" A bunch of useful LifeLines keywords 3.0.62

syn keyword	lifelinesDecl		char_encoding require option include
syn keyword	lifelinesStatement	set
syn keyword	lifelinesUser		getindi geindiset getfam getint getstr choosechild
syn keyword	lifelinesUser		chooseindi choosespouse choosesubset menuchoose
syn keyword	lifelinesUser		choosefam 
syn keyword	lifelinesProc		proc func return call
syn keyword	lifelinesInclude	include
syn keyword	lifelinesDef		global
syn keyword	lifelinesConditional	if else elsif switch
syn keyword	lifelinesRepeat		continue break while
syn keyword	lifelinesLogical	and or not eq ne lt gt le ge strcmp eqstr nestr
syn keyword	lifelinesArithm		add sub mul div mod exp neg incr decr
syn keyword	lifelinesArithm		cos sin tan arccos arcsin arctan
syn keyword	lifelinesArithm		deg2dms dms2deg spdist
syn keyword	lifelinesIndi		name fullname surname givens trimname birth
syn keyword	lifelinesIndi		death burial baptism
syn keyword	lifelinesIndi		father mother nextsib prevsib sex male female
syn keyword	lifelinesIndi		pn nspouses nfamilies parents title key
syn keyword	lifelinesIndi		soundex inode root indi firstindi nextindi
syn keyword	lifelinesIndi		previndi spouses families forindi indiset
syn keyword	lifelinesIndi		addtoset deletefromset  union intersect
syn keyword	lifelinesIndi		difference parentset childset spouseset siblingset
syn keyword	lifelinesIndi		ancestorset descendentset descendantset uniqueset
syn keyword	lifelinesIndi		namesort keysort valuesort genindiset getindiset
syn keyword	lifelinesIndi		forindiset lastindi writeindi
syn keyword	lifelinesIndi		inset
syn keyword	lifelinesFam		marriage husband wife nchildren firstchild
syn keyword	lifelinesFam		lastchild fnode fam firstfam nextfam lastfam
syn keyword	lifelinesFam		prevfam children forfam writefam
syn keyword	lifelinesFam		fathers mothers Parents
syn keyword	lifelinesList		list empty length enqueue dequeue requeue
syn keyword	lifelinesList		push pop setel getel forlist inlist dup clear
syn keyword	lifelinesTable		table insert lookup
syn keyword	lifelinesGedcom		xref tag value parent child sibling savenode
syn keyword	lifelinesGedcom		fornodes traverse createnode addnode 
syn keyword	lifelinesGedcom		detachnode foreven fornotes forothr forsour
syn keyword	lifelinesGedcom		reference dereference getrecord
syn keyword	lifelinesGedcom		gengedcomstrong 
syn keyword	lifelinesFunct		date place year long short gettoday dayformat
syn keyword	lifelinesFunct		monthformat dateformat extractdate eraformat
syn keyword	lifelinesFunct		complexdate complexformat complexpic datepic
syn keyword	lifelinesFunct		extractnames extractplaces extracttokens lower
syn keyword	lifelinesFunct		yearformat
syn keyword	lifelinesFunct		upper capitalize trim rjustify 
syn keyword 	lifelinesFunct		concat strconcat strlen substring index
syn keyword	lifelinesFunct		titlecase gettext
syn keyword	lifelinesFunct		d card ord alpha roman strsoundex strtoint
syn keyword	lifelinesFunct		atoi linemode pagemod col row pos pageout nl
syn keyword	lifelinesFunct		sp qt newfile outfile copyfile print lock unlock test
syn keyword	lifelinesFunct		database version system stddate program
syn keyword	lifelinesFunct		pvalue pagemode level extractdatestr debug
syn keyword	lifelinesFunct		f float int free getcol getproperty heapused
syn keyword 	lifelinesFunct		sort rsort
syn keyword	lifelinesFunct		deleteel
syn keyword	lifelinesFunct		bytecode convertcode setlocale
" New dates functions (since 3.0.51)
syn keyword	lifelinesFunct		jd2date date2jd dayofweek setdate

" options to highlight as error obsolete statements
" please read ll-reportmanual.

if exists("lifelines_deprecated")
	syn keyword lifelinesError	getintmsg getindimsg getstrmsg
	syn keyword lifelinesError	gengedcom gengedcomweak deletenode
	syn keyword lifelinesError	save strsave
	syn keyword lifelinesError	lengthset
	if version >= 700
		let g:omni_syntax_group_exclude_lifelines = 'lifelinesError'
	endif
else
	syn keyword lifelinesUser	getintmsg getindimsg getstrmsg
	syn keyword lifelinesGedcom	gengedcom gengedcomweak deletenode
	syn keyword lifelinesFunct	save strsave
	syn keyword lifelinesIndi	lengthset
endif

syn region	lifelinesString	start=+L\="+ skip=+\\\\\|\\"+ end=+"+ contains=lifelinesSpecial

syn match	lifelinesSpecial	"\\\(\\\|\(n\|t\)\)" contained

syn keyword	lifelinesTodo		contained TODO FIXME XXX
syn region	lifelinesComment	start="/\*"  end="\*/" contains=lifelinesTodo

" integers
syn match	lifelinesNumber	"-\=\<\d\+\>"
"floats, with dot
syn match	lifelinesNumber	"-\=\<\d\+\.\d*\>"
"floats, starting with a dot
syn match	lifelinesNumber	"-\=\.\d\+\>"

" folding using {}
if version >= 600
	syn region lifelinesFoldBlock	start="{" end="}" transparent fold
endif

"catch errors caused by wrong parenthesis
"adapted from original c.vim written by Bram Moolenaar

syn cluster	lifelinesParenGroup	contains=lifelinesParenError
syn region	lifelinesParen		transparent start='(' end=')' contains=ALLBUT,@lifelinesParenGroup
syn match	lifelinesParenError	")"
syn match	lifelinesErrInParen	contained "[{}]"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet

if version >= 508 || !exists("did_lifelines_syn_inits")
  if version < 508
    let did_lifelines_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink lifelinesConditional	Conditional
  HiLink lifelinesArithm	Operator
  HiLink lifelinesLogical	Conditional
  HiLink lifelinesInclude	Include
  HiLink lifelinesComment	Comment
  HiLink lifelinesStatement	Statement
  HiLink lifelinesUser		Statement
  HiLink lifelinesFunct		Statement
  HiLink lifelinesTable		Statement
  HiLink lifelinesGedcom	Statement
  HiLink lifelinesList		Statement
  HiLink lifelinesRepeat	Repeat
  HiLink lifelinesFam		Statement
  HiLink lifelinesIndi		Statement
  HiLink lifelinesProc		Statement
  HiLink lifelinesDef		Statement
  HiLink lifelinesString	String
  HiLink lifelinesSpecial	Special
  HiLink lifelinesNumber	Number
  HiLink lifelinesParenError	Error
  HiLink lifelinesErrInParen	Error
  HiLink lifelinesError		Error
  HiLink lifelinesTodo		Todo
  HiLink lifelinesDecl		PreProc

  delcommand HiLink
endif

let b:current_syntax = "lifelines"

" vim: ts=8 sw=4
