" Vim syntax file
" Language:	splint (C with lclint/splint Annotations)
" Maintainer:	Ralf Wildenhues <Ralf.Wildenhues@gmx.de>
" Splint Home:	http://www.splint.org/
" Last Change:	$Date: 2004/06/13 20:08:47 $
" $Revision: 1.1 $

" Note:		Splint annotated files are not detected by default.
"		If you want to use this file for highlighting C code,
"		please make sure splint.vim is sourced instead of c.vim,
"		for example by putting
"			/* vim: set filetype=splint : */
"		at the end of your code or something like
"			au! BufRead,BufNewFile *.c	setfiletype splint
"		in your vimrc file or filetype.vim


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Read the C syntax to start with
if version < 600
  so <sfile>:p:h/c.vim
else
  runtime! syntax/c.vim
endif


" FIXME: uses and changes several clusters defined in c.vim
"	so watch for changes there

" TODO: make a little more grammar explicit
"	match flags with hyphen and underscore notation
"	match flag expanded forms
"	accept other comment char than @

syn case match
" splint annotations (taken from 'splint -help annotations')
syn match   splintStateAnnot	contained "\(pre\|post\):\(only\|shared\|owned\|dependent\|observer\|exposed\|isnull\|notnull\)"
syn keyword splintSpecialAnnot  contained special
syn keyword splintSpecTag	contained uses sets defines allocated releases
syn keyword splintModifies	contained modifies
syn keyword splintRequires	contained requires ensures
syn keyword splintGlobals	contained globals
syn keyword splintGlobitem	contained internalState fileSystem
syn keyword splintGlobannot	contained undef killed
syn keyword splintWarning	contained warn

syn keyword splintModitem	contained internalState fileSystem nothing
syn keyword splintReqitem	contained MaxSet MaxRead result
syn keyword splintIter		contained iter yield
syn keyword splintConst		contained constant
syn keyword splintAlt		contained alt

syn keyword splintType		contained abstract concrete mutable immutable refcounted numabstract
syn keyword splintGlobalType	contained unchecked checkmod checked checkedstrict
syn keyword splintMemMgm	contained dependent keep killref only owned shared temp
syn keyword splintAlias		contained unique returned
syn keyword splintExposure	contained observer exposed
syn keyword splintDefState	contained out in partial reldef
syn keyword splintGlobState	contained undef killed
syn keyword splintNullState	contained null notnull relnull
syn keyword splintNullPred	contained truenull falsenull nullwhentrue falsewhennull
syn keyword splintExit		contained exits mayexit trueexit falseexit neverexit
syn keyword splintExec		contained noreturn maynotreturn noreturnwhentrue noreturnwhenfalse alwaysreturns
syn keyword splintSef		contained sef
syn keyword splintDecl		contained unused external
syn keyword splintCase		contained fallthrough
syn keyword splintBreak		contained innerbreak loopbreak switchbreak innercontinue
syn keyword splintUnreach	contained notreached
syn keyword splintSpecFunc	contained printflike scanflike messagelike

" TODO: make these region or match
syn keyword splintErrSupp	contained i ignore end t
syn match   splintErrSupp	contained "[it]\d\+\>"
syn keyword splintTypeAcc	contained access noaccess

syn keyword splintMacro		contained notfunction
syn match   splintSpecType	contained "\(\|unsigned\|signed\)integraltype"

" Flags taken from 'splint -help flags full' divided in local and global flags
"				 Local Flags:
syn keyword splintFlag contained abstract abstractcompare accessall accessczech accessczechoslovak
syn keyword splintFlag contained accessfile accessmodule accessslovak aliasunique allblock
syn keyword splintFlag contained allempty allglobs allimponly allmacros alwaysexits
syn keyword splintFlag contained annotationerror ansi89limits assignexpose badflag bitwisesigned
syn keyword splintFlag contained boolcompare boolfalse boolint boolops booltrue
syn keyword splintFlag contained booltype bounds boundscompacterrormessages boundsread boundswrite
syn keyword splintFlag contained branchstate bufferoverflow bufferoverflowhigh bugslimit casebreak
syn keyword splintFlag contained caseinsensitivefilenames castexpose castfcnptr charindex charint
syn keyword splintFlag contained charintliteral charunsignedchar checkedglobalias checkmodglobalias checkpost
syn keyword splintFlag contained checkstrictglobalias checkstrictglobs codeimponly commentchar commenterror
syn keyword splintFlag contained compdef compdestroy compmempass constmacros constprefix
syn keyword splintFlag contained constprefixexclude constuse continuecomment controlnestdepth cppnames
syn keyword splintFlag contained csvoverwrite czech czechconsts czechfcns czechmacros
syn keyword splintFlag contained czechoslovak czechoslovakconsts czechoslovakfcns czechoslovakmacros czechoslovaktypes
syn keyword splintFlag contained czechoslovakvars czechtypes czechvars debugfcnconstraint declundef
syn keyword splintFlag contained deepbreak deparrays dependenttrans distinctexternalnames distinctinternalnames
syn keyword splintFlag contained duplicatecases duplicatequals elseifcomplete emptyret enumindex
syn keyword splintFlag contained enumint enummembers enummemuse enumprefix enumprefixexclude
syn keyword splintFlag contained evalorder evalorderuncon exitarg exportany exportconst
syn keyword splintFlag contained exportfcn exportheader exportheadervar exportiter exportlocal
syn keyword splintFlag contained exportmacro exporttype exportvar exposetrans externalnamecaseinsensitive
syn keyword splintFlag contained externalnamelen externalprefix externalprefixexclude fcnderef fcnmacros
syn keyword splintFlag contained fcnpost fcnuse fielduse fileextensions filestaticprefix
syn keyword splintFlag contained filestaticprefixexclude firstcase fixedformalarray floatdouble forblock
syn keyword splintFlag contained forcehints forempty forloopexec formalarray formatcode
syn keyword splintFlag contained formatconst formattype forwarddecl freshtrans fullinitblock
syn keyword splintFlag contained globalias globalprefix globalprefixexclude globimponly globnoglobs
syn keyword splintFlag contained globs globsimpmodsnothing globstate globuse gnuextensions
syn keyword splintFlag contained grammar hasyield hints htmlfileformat ifblock
syn keyword splintFlag contained ifempty ignorequals ignoresigns immediatetrans impabstract
syn keyword splintFlag contained impcheckedglobs impcheckedspecglobs impcheckedstatics impcheckedstrictglobs impcheckedstrictspecglobs
syn keyword splintFlag contained impcheckedstrictstatics impcheckmodglobs impcheckmodinternals impcheckmodspecglobs impcheckmodstatics
syn keyword splintFlag contained impconj implementationoptional implictconstraint impouts imptype
syn keyword splintFlag contained includenest incompletetype incondefs incondefslib indentspaces
syn keyword splintFlag contained infloops infloopsuncon initallelements initsize internalglobs
syn keyword splintFlag contained internalglobsnoglobs internalnamecaseinsensitive internalnamelen internalnamelookalike iso99limits
syn keyword splintFlag contained isoreserved isoreservedinternal iterbalance iterloopexec iterprefix
syn keyword splintFlag contained iterprefixexclude iteryield its4low its4moderate its4mostrisky
syn keyword splintFlag contained its4risky its4veryrisky keep keeptrans kepttrans
syn keyword splintFlag contained legacy libmacros likelyboundsread likelyboundswrite likelybool
syn keyword splintFlag contained likelybounds limit linelen lintcomments localprefix
syn keyword splintFlag contained localprefixexclude locindentspaces longint longintegral longsignedintegral
syn keyword splintFlag contained longunsignedintegral longunsignedunsignedintegral loopexec looploopbreak looploopcontinue
syn keyword splintFlag contained loopswitchbreak macroassign macroconstdecl macrodecl macroempty
syn keyword splintFlag contained macrofcndecl macromatchname macroparams macroparens macroredef
syn keyword splintFlag contained macroreturn macrostmt macrounrecog macrovarprefix macrovarprefixexclude
syn keyword splintFlag contained maintype matchanyintegral matchfields mayaliasunique memchecks
syn keyword splintFlag contained memimp memtrans misplacedsharequal misscase modfilesys
syn keyword splintFlag contained modglobs modglobsnomods modglobsunchecked modinternalstrict modnomods
syn keyword splintFlag contained modobserver modobserveruncon mods modsimpnoglobs modstrictglobsnomods
syn keyword splintFlag contained moduncon modunconnomods modunspec multithreaded mustdefine
syn keyword splintFlag contained mustfree mustfreefresh mustfreeonly mustmod mustnotalias
syn keyword splintFlag contained mutrep namechecks needspec nestcomment nestedextern
syn keyword splintFlag contained newdecl newreftrans nextlinemacros noaccess nocomments
syn keyword splintFlag contained noeffect noeffectuncon noparams nopp noret
syn keyword splintFlag contained null nullassign nullderef nullinit nullpass
syn keyword splintFlag contained nullptrarith nullret nullstate nullterminated
syn keyword splintFlag contained numabstract numabstractcast numabstractindex numabstractlit numabstractprint
syn keyword splintFlag contained numenummembers numliteral numstructfields observertrans obviousloopexec
syn keyword splintFlag contained oldstyle onlytrans onlyunqglobaltrans orconstraint overload
syn keyword splintFlag contained ownedtrans paramimptemp paramuse parenfileformat partial
syn keyword splintFlag contained passunknown portability predassign predbool predboolint
syn keyword splintFlag contained predboolothers predboolptr preproc protoparammatch protoparamname
syn keyword splintFlag contained protoparamprefix protoparamprefixexclude ptrarith ptrcompare ptrnegate
syn keyword splintFlag contained quiet readonlystrings readonlytrans realcompare redecl
syn keyword splintFlag contained redef redundantconstraints redundantsharequal refcounttrans relaxquals
syn keyword splintFlag contained relaxtypes repeatunrecog repexpose retalias retexpose
syn keyword splintFlag contained retimponly retval retvalbool retvalint retvalother
syn keyword splintFlag contained sefparams sefuncon shadow sharedtrans shiftimplementation
syn keyword splintFlag contained shiftnegative shortint showallconjs showcolumn showconstraintlocation
syn keyword splintFlag contained showconstraintparens showdeephistory showfunc showloadloc showscan
syn keyword splintFlag contained showsourceloc showsummary sizeofformalarray sizeoftype skipisoheaders
syn keyword splintFlag contained skipposixheaders slashslashcomment slovak slovakconsts slovakfcns
syn keyword splintFlag contained slovakmacros slovaktypes slovakvars specglobimponly specimponly
syn keyword splintFlag contained specmacros specretimponly specstructimponly specundecl specundef
syn keyword splintFlag contained stackref statemerge statetransfer staticinittrans statictrans
syn keyword splintFlag contained strictbranchstate strictdestroy strictops strictusereleased stringliterallen
syn keyword splintFlag contained stringliteralnoroom stringliteralnoroomfinalnull stringliteralsmaller stringliteraltoolong structimponly
syn keyword splintFlag contained superuser switchloopbreak switchswitchbreak syntax sysdirerrors
syn keyword splintFlag contained sysdirexpandmacros sysunrecog tagprefix tagprefixexclude temptrans
syn keyword splintFlag contained tmpcomments toctou topuse trytorecover type
syn keyword splintFlag contained typeprefix typeprefixexclude typeuse uncheckedglobalias uncheckedmacroprefix
syn keyword splintFlag contained uncheckedmacroprefixexclude uniondef unixstandard unqualifiedinittrans unqualifiedtrans
syn keyword splintFlag contained unreachable unrecog unrecogcomments unrecogdirective unrecogflagcomments
syn keyword splintFlag contained unsignedcompare unusedspecial usedef usereleased usevarargs
syn keyword splintFlag contained varuse voidabstract warnflags warnlintcomments warnmissingglobs
syn keyword splintFlag contained warnmissingglobsnoglobs warnposixheaders warnrc warnsysfiles warnunixlib
syn keyword splintFlag contained warnuse whileblock whileempty whileloopexec zerobool
syn keyword splintFlag contained zeroptr
"				       Global Flags:
syn keyword splintGlobalFlag contained csv dump errorstream errorstreamstderr errorstreamstdout
syn keyword splintGlobalFlag contained expect f help i isolib
syn keyword splintGlobalFlag contained larchpath lclexpect lclimportdir lcs lh
syn keyword splintGlobalFlag contained load messagestream messagestreamstderr messagestreamstdout mts
syn keyword splintGlobalFlag contained neverinclude nof nolib posixlib posixstrictlib
syn keyword splintGlobalFlag contained showalluses singleinclude skipsysheaders stats streamoverwrite
syn keyword splintGlobalFlag contained strictlib supcounts sysdirs timedist tmpdir
syn keyword splintGlobalFlag contained unixlib unixstrictlib warningstream warningstreamstderr warningstreamstdout
syn keyword splintGlobalFlag contained whichlib
syn match   splintFlagExpr contained "[\+\-\=]" nextgroup=splintFlag,splintGlobalFlag

" detect missing /*@ and wrong */
syn match	splintAnnError	"@\*/"
syn cluster	cCommentGroup	add=splintAnnError
syn match	splintAnnError2	"[^@]\*/"hs=s+1 contained
syn region	splintAnnotation start="/\*@" end="@\*/" contains=@splintAnnotElem,cType keepend
syn match	splintShortAnn	"/\*@\*/"
syn cluster	splintAnnotElem	contains=splintStateAnnot,splintSpecialAnnot,splintSpecTag,splintModifies,splintRequires,splintGlobals,splintGlobitem,splintGlobannot,splintWarning,splintModitem,splintIter,splintConst,splintAlt,splintType,splintGlobalType,splintMemMgm,splintAlias,splintExposure,splintDefState,splintGlobState,splintNullState,splintNullPred,splintExit,splintExec,splintSef,splintDecl,splintCase,splintBreak,splintUnreach,splintSpecFunc,splintErrSupp,splintTypeAcc,splintMacro,splintSpecType,splintAnnError2,splintFlagExpr
syn cluster	splintAllStuff	contains=@splintAnnotElem,splintFlag,splintGlobalFlag
syn cluster	cParenGroup	add=@splintAllStuff
syn cluster	cPreProcGroup	add=@splintAllStuff
syn cluster	cMultiGroup	add=@splintAllStuff

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_splint_syntax_inits")
  if version < 508
    let did_splint_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink splintShortAnn		splintAnnotation
  HiLink splintAnnotation	Comment
  HiLink splintAnnError		splintError
  HiLink splintAnnError2	splintError
  HiLink splintFlag		SpecialComment
  HiLink splintGlobalFlag	splintError
  HiLink splintSpecialAnnot	splintAnnKey
  HiLink splintStateAnnot	splintAnnKey
  HiLink splintSpecTag		splintAnnKey
  HiLink splintModifies		splintAnnKey
  HiLink splintRequires		splintAnnKey
  HiLink splintGlobals		splintAnnKey
  HiLink splintGlobitem		Constant
  HiLink splintGlobannot	splintAnnKey
  HiLink splintWarning		splintAnnKey
  HiLink splintModitem		Constant
  HiLink splintIter		splintAnnKey
  HiLink splintConst		splintAnnKey
  HiLink splintAlt		splintAnnKey
  HiLink splintType		splintAnnKey
  HiLink splintGlobalType	splintAnnKey
  HiLink splintMemMgm		splintAnnKey
  HiLink splintAlias		splintAnnKey
  HiLink splintExposure		splintAnnKey
  HiLink splintDefState		splintAnnKey
  HiLink splintGlobState	splintAnnKey
  HiLink splintNullState	splintAnnKey
  HiLink splintNullPred		splintAnnKey
  HiLink splintExit		splintAnnKey
  HiLink splintExec		splintAnnKey
  HiLink splintSef		splintAnnKey
  HiLink splintDecl		splintAnnKey
  HiLink splintCase		splintAnnKey
  HiLink splintBreak		splintAnnKey
  HiLink splintUnreach		splintAnnKey
  HiLink splintSpecFunc		splintAnnKey
  HiLink splintErrSupp		splintAnnKey
  HiLink splintTypeAcc		splintAnnKey
  HiLink splintMacro		splintAnnKey
  HiLink splintSpecType		splintAnnKey
  HiLink splintAnnKey		Type
  HiLink splintError		Error

  delcommand HiLink
endif

let b:current_syntax = "splint"

" vim: ts=8
