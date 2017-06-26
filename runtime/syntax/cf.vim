" Vim syntax file
" Language:	CFML
" Maintainer:	Toby Woodwark (toby.woodwark+vim@gmail.com)
" Last Change:	2010-03-02
" Filenames:	*.cfc *.cfm
" Version:	Adobe ColdFusion 9
" Usage:	This file contains both syntax definitions
" 		and a list of known builtin tags, functions and keywords.
" 		Refs - 
" http://help.adobe.com/en_US/ColdFusion/9.0/Developing/WS8f0cc78011fffa71866534d11cdad96e4e-8000.html
" http://help.adobe.com/en_US/ColdFusion/9.0/CFMLRef/WSc3ff6d0ea77859461172e0811cbec17324-8000.html
" TODO: 
" 		Support the limited array literal and struct literal syntax in CF8+.
" 		Highlight namespaced tags fom cfimport.
" 		Complete CF9+ cfscript support.
" 		Railo support.
" Options:
"	d_noinclude_html - set to prevent HTML highlighting.	Use this if you are not working on HTML.

" Quit if a syntax file is already loaded.
if exists("b:current_syntax")
  finish
endif

if exists("d_noinclude_html")
  " Define alternatives to the HTML syntax file.

  " Copied from html.vim - the rules for matching a CF tag match	those for HTML/SGML.
  " CFML syntax is more permissive when it comes to superfluous <> chars.
  syn region	htmlString	contained start=+"+ end=+"+ contains=@htmlPreproc
  syn region	htmlString	contained start=+'+ end=+'+ contains=@htmlPreproc
  syn match	htmlValue	contained "=[\t ]*[^'" \t>][^ \t>]*"hs=s+1	contains=@htmlPreproc
  " Hacked htmlTag so that it only matches cf tags and not random <> chars.
  syn region	htmlEndTag	start=+</cf+	end=+>+ contains=htmlTagN,htmlTagError
  syn region	htmlTag		start=+<\s*cf[^/]+	end=+>+ contains=htmlTagN,htmlString,htmlArg,htmlValue,htmlTagError,@htmlPreproc,@htmlArgCluster
  syn match	htmlTagN	contained +<\s*[-a-zA-Z0-9]\++hs=s+1 contains=htmlTagName,@htmlTagNameCluster
  syn match	htmlTagN	contained +</\s*[-a-zA-Z0-9]\++hs=s+2 contains=htmlTagName,@htmlTagNameCluster
  syn match	htmlTagError	contained "[^>]<"ms=s+1
else
  " Use all the stuff from the HTML syntax file.
  " This means eg HTML comments are highlighted as comments, even if they include cf tags.
  runtime! syntax/html.vim
endif

syn sync	fromstart
syn sync	maxlines=200
syn case	ignore

" Scopes and keywords.
syn keyword	cfScope		contained cgi cffile cookie request caller this thistag
syn keyword	cfScope		contained cfcatch variables application server session client form url local
syn keyword	cfScope		contained arguments super cfhttp attributes error
syn keyword	cfBool		contained yes no true false

" Operator strings.
" ColdFusion <=7:
syn keyword	cfOperator		contained xor eqv and or lt le lte gt ge gte equal eq neq not is mod contains
syn match	cfOperatorMatch		contained "+" 
syn match	cfOperatorMatch		contained "\-"
syn match	cfOperatorMatch		contained "[\*\/\\\^\&][\+\-\*\/\\\^\&]\@!"
syn match	cfOperatorMatch		contained "\<\(not\_s\+\)\?equal\>"
syn match	cfOperatorMatch		contained "\<does\_s\+not\_s\+contain\>"
syn match	cfOperatorMatch		contained "\<\(greater\|less\)\_s\+than\(\_s\+or\_s\+equal\_s\+to\)\?\>"
" ColdFusion 8:
syn keyword	cfOperator		contained imp
syn match	cfOperatorMatch		contained "[?%:!]"
syn match	cfOperatorMatch		contained "[\+\-\*\/\&]=" 
syn match	cfOperatorMatch		contained "++"
syn match	cfOperatorMatch		contained "--"
syn match	cfOperatorMatch	 	contained "&&"
syn match	cfOperatorMatch	 	contained "||"

syn cluster	cfOperatorCluster	contains=cfOperator,cfOperatorMatch

" Custom tags called with the <cf_xxx> syntax.
syn match	cfCustomTagName		contained "\<cf_[a-zA-Z0-9_]\+\>"
" (TODO match	namespaced tags imported using cfimport, similarly.)

" Tag names.
" ColdFusion <=7:
syn keyword	cfTagName	contained cfabort cfapplet cfapplication cfargument cfassociate
syn keyword	cfTagName	contained cfbreak cfcache cfcalendar cfcase cfcatch
syn keyword	cfTagName	contained cfchart cfchartdata cfchartseries cfcol cfcollection
syn keyword	cfTagName	contained cfcomponent cfcontent cfcookie cfdefaultcase cfdirectory
syn keyword	cfTagName	contained cfdocument cfdocumentitem cfdocumentsection cfdump cfelse
syn keyword	cfTagName	contained cfelseif cferror cfexecute cfexit cffile cfflush cfform
syn keyword	cfTagName	contained cfformgroup cfformitem cfftp cffunction
syn keyword	cfTagName	contained cfgrid cfgridcolumn cfgridrow cfgridupdate cfheader
syn keyword	cfTagName	contained cfhtmlhead cfhttp cfhttpparam cfif cfimport
syn keyword	cfTagName	contained cfinclude cfindex cfinput cfinsert cfinvoke cfinvokeargument
syn keyword	cfTagName	contained cfldap cflocation cflock cflog cflogin cfloginuser cflogout
syn keyword	cfTagName	contained cfloop cfmail cfmailparam cfmailpart cfmodule
syn keyword	cfTagName	contained cfNTauthenticate cfobject cfobjectcache cfoutput cfparam
syn keyword	cfTagName	contained cfpop cfprocessingdirective cfprocparam cfprocresult
syn keyword	cfTagName	contained cfproperty cfquery cfqueryparam cfregistry cfreport
syn keyword	cfTagName	contained cfreportparam cfrethrow cfreturn cfsavecontent cfschedule
syn keyword	cfTagName	contained cfscript cfsearch cfselect cfservletparam cfset
syn keyword	cfTagName	contained cfsetting cfsilent cfslider cfstoredproc cfswitch cftable
syn keyword	cfTagName	contained cftextarea cftextinput cfthrow cftimer cftrace cftransaction
syn keyword	cfTagName	contained cftree cftreeitem cftry cfupdate cfwddx cfxml
" ColdFusion 8:
syn keyword	cfTagName	contained cfajaximport cfajaxproxy cfdbinfo cfdiv cfexchangecalendar
syn keyword	cfTagName	contained cfexchangeconnection cfexchangecontact cfexchangefilter 
syn keyword	cfTagName	contained cfexchangemail cfexchangetask cffeed
syn keyword	cfTagName	contained cfinterface cflayout cflayoutarea cfmenu cfmenuitem
syn keyword	cfTagName	contained cfpdf cfpdfform cfpdfformparam cfpdfparam cfpdfsubform cfpod
syn keyword	cfTagName	contained cfpresentation cfpresentationslide cfpresenter cfprint
syn keyword	cfTagName	contained cfsprydataset cfthread cftooltip cfwindow cfzip cfzipparam
" ColdFusion 9:
syn keyword	cfTagName	contained cfcontinue cffileupload cffinally
syn keyword	cfTagName	contained cfimage cfimap 
syn keyword	cfTagName	contained cfmap cfmapitem cfmediaplayer cfmessagebox
syn keyword	cfTagName	contained cfprocparam cfprogressbar
syn keyword	cfTagName	contained cfsharepoint cfspreadsheet

" Tag attributes.
" XXX Not updated for ColdFusion 8/9.
" These are becoming a headache to maintain, so might be removed.
syn keyword	cfArg		contained abort accept access accessible action addnewline addtoken
syn keyword	cfArg		contained agentname align appendkey appletsource application
syn keyword	cfArg		contained applicationtimeout applicationtoken archive
syn keyword	cfArg		contained argumentcollection arguments asciiextensionlist
syn keyword	cfArg		contained attachmentpath attributecollection attributes autowidth
syn keyword	cfArg		contained backgroundvisible basetag bcc bgcolor bind bindingname
syn keyword	cfArg		contained blockfactor body bold border branch cachedafter cachedwithin
syn keyword	cfArg		contained casesensitive category categorytree cc cfsqltype charset
syn keyword	cfArg		contained chartheight chartwidth checked class clientmanagement
syn keyword	cfArg		contained clientstorage codebase colheaderalign colheaderbold
syn keyword	cfArg		contained colheaderfont colheaderfontsize colheaderitalic colheaders
syn keyword	cfArg		contained colheadertextcolor collection colorlist colspacing columns
syn keyword	cfArg		contained completepath component condition connection contentid
syn keyword	cfArg		contained context contextbytes contexthighlightbegin
syn keyword	cfArg		contained contexthighlightend contextpassages cookiedomain criteria
syn keyword	cfArg		contained custom1 custom2 custom3 custom4 data dataalign
syn keyword	cfArg		contained databackgroundcolor datacollection datasource daynames
syn keyword	cfArg		contained dbname dbserver dbtype dbvarname debug default delete
syn keyword	cfArg		contained deletebutton deletefile delimiter delimiters description
syn keyword	cfArg		contained destination detail directory disabled display displayname
syn keyword	cfArg		contained disposition dn domain editable enablecab enablecfoutputonly
syn keyword	cfArg		contained enabled encoded encryption enctype enddate endrange endtime
syn keyword	cfArg		contained entry errorcode exception existing expand expires expireurl
syn keyword	cfArg		contained expression extendedinfo extends extensions external
syn keyword	cfArg		contained failifexists failto file filefield filename filter
syn keyword	cfArg		contained firstdayofweek firstrowasheaders fixnewline font fontbold
syn keyword	cfArg		contained fontembed fontitalic fontsize foregroundcolor format
syn keyword	cfArg		contained formfields formula from generateuniquefilenames getasbinary
syn keyword	cfArg		contained grid griddataalign gridlines groovecolor group
syn keyword	cfArg		contained groupcasesensitive header headeralign headerbold headerfont
syn keyword	cfArg		contained headerfontsize headeritalic headerlines headertextcolor
syn keyword	cfArg		contained height highlighthref hint href hrefkey hscroll hspace html
syn keyword	cfArg		contained htmltable id idletimeout img imgopen imgstyle index inline
syn keyword	cfArg		contained input insert insertbutton interval isolation italic item
syn keyword	cfArg		contained itemcolumn key keyonly label labelformat language list
syn keyword	cfArg		contained listgroups locale localfile log loginstorage lookandfeel
syn keyword	cfArg		contained mailerid mailto marginbottom marginleft marginright
syn keyword	cfArg		contained margintop markersize markerstyle mask max maxlength maxrows
syn keyword	cfArg		contained message messagenumber method mimeattach mimetype min mode
syn keyword	cfArg		contained modifytype monthnames multipart multiple name nameconflict
syn keyword	cfArg		contained namespace new newdirectory notsupported null numberformat
syn keyword	cfArg		contained object omit onblur onchange onclick onerror onfocus
syn keyword	cfArg		contained onkeydown onkeyup onload onmousedown onmouseup onreset
syn keyword	cfArg		contained onsubmit onvalidate operation orderby orientation output
syn keyword	cfArg		contained outputfile overwrite ownerpassword pageencoding pageheight
syn keyword	cfArg		contained pagetype pagewidth paintstyle param_1 param_2 param_3
syn keyword	cfArg		contained param_4 param_5 param_6 param_7 param_8 param_9 parent
syn keyword	cfArg		contained parrent passive passthrough password path pattern
syn keyword	cfArg		contained permissions picturebar pieslicestyle port porttypename
syn keyword	cfArg		contained prefix preloader preservedata previouscriteria procedure
syn keyword	cfArg		contained protocol provider providerdsn proxybypass proxypassword
syn keyword	cfArg		contained proxyport proxyserver proxyuser publish query queryasroot
syn keyword	cfArg		contained queryposition range rebind recurse redirect referral
syn keyword	cfArg		contained refreshlabel remotefile replyto report requesttimeout
syn keyword	cfArg		contained required reset resoleurl resolveurl result resultset
syn keyword	cfArg		contained retrycount returnasbinary returncode returntype
syn keyword	cfArg		contained returnvariable roles rotated rowheaderalign rowheaderbold
syn keyword	cfArg		contained rowheaderfont rowheaderfontsize rowheaderitalic rowheaders
syn keyword	cfArg		contained rowheadertextcolor rowheaderwidth rowheight scale scalefrom
syn keyword	cfArg		contained scaleto scope scriptprotect scriptsrc secure securitycontext
syn keyword	cfArg		contained select selectcolor selected selecteddate selectedindex
syn keyword	cfArg		contained selectmode separator seriescolor serieslabel seriesplacement
syn keyword	cfArg		contained server serviceport serviceportname sessionmanagement
syn keyword	cfArg		contained sessiontimeout setclientcookies setcookie setdomaincookies
syn keyword	cfArg		contained show3d showborder showdebugoutput showerror showlegend
syn keyword	cfArg		contained showmarkers showxgridlines showygridlines size skin sort
syn keyword	cfArg		contained sortascendingbutton sortcontrol sortdescendingbutton
syn keyword	cfArg		contained sortxaxis source spoolenable sql src srcfile start startdate
syn keyword	cfArg		contained startrange startrow starttime status statuscode statustext
syn keyword	cfArg		contained step stoponerror style subject suggestions
syn keyword	cfArg		contained suppresswhitespace tablename tableowner tablequalifier
syn keyword	cfArg		contained taglib target task template text textcolor textqualifier
syn keyword	cfArg		contained throwonerror throwonerror throwonfailure throwontimeout
syn keyword	cfArg		contained timeout timespan tipbgcolor tipstyle title to tooltip
syn keyword	cfArg		contained toplevelvariable transfermode type uid unit url urlpath
syn keyword	cfArg		contained useragent username userpassword usetimezoneinfo validate
syn keyword	cfArg		contained validateat value valuecolumn values valuesdelimiter
syn keyword	cfArg		contained valuesdisplay var variable vertical visible vscroll vspace
syn keyword	cfArg		contained webservice width wmode wraptext wsdlfile xaxistitle
syn keyword	cfArg		contained xaxistype xoffset yaxistitle yaxistype yoffset

" Functions.
" ColdFusion <=7:
syn keyword	cfFunctionName		contained ACos ASin Abs AddSOAPRequestHeader AddSOAPResponseHeader
syn keyword	cfFunctionName		contained ArrayAppend ArrayAvg ArrayClear ArrayDeleteAt ArrayInsertAt
syn keyword	cfFunctionName		contained ArrayIsEmpty ArrayLen ArrayMax ArrayMin ArrayNew
syn keyword	cfFunctionName		contained ArrayPrepend ArrayResize ArraySet ArraySort ArraySum
syn keyword	cfFunctionName		contained ArraySwap ArrayToList Asc Atn AuthenticatedContext
syn keyword	cfFunctionName		contained AuthenticatedUser BinaryDecode BinaryEncode BitAnd
syn keyword	cfFunctionName		contained BitMaskClear BitMaskRead BitMaskSet BitNot BitOr BitSHLN
syn keyword	cfFunctionName		contained BitSHRN BitXor CJustify Ceiling CharsetDecode CharsetEncode
syn keyword	cfFunctionName		contained Chr Compare CompareNoCase Cos CreateDate CreateDateTime
syn keyword	cfFunctionName		contained CreateODBCDate CreateODBCDateTime CreateODBCTime
syn keyword	cfFunctionName		contained CreateObject CreateTime CreateTimeSpan CreateUUID DE DateAdd
syn keyword	cfFunctionName		contained DateCompare DateConvert DateDiff DateFormat DatePart Day
syn keyword	cfFunctionName		contained DayOfWeek DayOfWeekAsString DayOfYear DaysInMonth DaysInYear
syn keyword	cfFunctionName		contained DecimalFormat DecrementValue Decrypt DecryptBinary
syn keyword	cfFunctionName		contained DeleteClientVariable DirectoryExists DollarFormat Duplicate
syn keyword	cfFunctionName		contained Encrypt EncryptBinary Evaluate Exp ExpandPath FileExists
syn keyword	cfFunctionName		contained Find FindNoCase FindOneOf FirstDayOfMonth Fix FormatBaseN
syn keyword	cfFunctionName		contained GenerateSecretKey GetAuthUser GetBaseTagData GetBaseTagList
syn keyword	cfFunctionName		contained GetBaseTemplatePath GetClientVariablesList GetContextRoot
syn keyword	cfFunctionName		contained GetCurrentTemplatePath GetDirectoryFromPath GetEncoding
syn keyword	cfFunctionName		contained GetException GetFileFromPath GetFunctionList
syn keyword	cfFunctionName		contained GetGatewayHelper GetHttpRequestData GetHttpTimeString
syn keyword	cfFunctionName		contained GetLocalHostIP
syn keyword	cfFunctionName		contained GetLocale GetLocaleDisplayName GetMetaData GetMetricData
syn keyword	cfFunctionName		contained GetPageContext GetProfileSections GetProfileString
syn keyword	cfFunctionName		contained GetSOAPRequest GetSOAPRequestHeader GetSOAPResponse
syn keyword	cfFunctionName		contained GetSOAPResponseHeader GetTempDirectory GetTempFile
syn keyword	cfFunctionName		contained GetTickCount GetTimeZoneInfo GetToken
syn keyword	cfFunctionName		contained HTMLCodeFormat HTMLEditFormat Hash Hour IIf IncrementValue
syn keyword	cfFunctionName		contained InputBaseN Insert Int IsArray IsAuthenticated IsAuthorized
syn keyword	cfFunctionName		contained IsBinary IsBoolean IsCustomFunction IsDate IsDebugMode
syn keyword	cfFunctionName		contained IsDefined
syn keyword	cfFunctionName		contained IsLeapYear IsLocalHost IsNumeric
syn keyword	cfFunctionName		contained IsNumericDate IsObject IsProtected IsQuery IsSOAPRequest
syn keyword	cfFunctionName		contained IsSimpleValue IsStruct IsUserInRole IsValid IsWDDX IsXML
syn keyword	cfFunctionName		contained IsXmlAttribute IsXmlDoc IsXmlElem IsXmlNode IsXmlRoot
syn keyword	cfFunctionName		contained JSStringFormat JavaCast LCase LJustify LSCurrencyFormat
syn keyword	cfFunctionName		contained LSDateFormat LSEuroCurrencyFormat LSIsCurrency LSIsDate
syn keyword	cfFunctionName		contained LSIsNumeric LSNumberFormat LSParseCurrency LSParseDateTime
syn keyword	cfFunctionName		contained LSParseEuroCurrency LSParseNumber LSTimeFormat LTrim Left
syn keyword	cfFunctionName		contained Len ListAppend ListChangeDelims ListContains
syn keyword	cfFunctionName		contained ListContainsNoCase ListDeleteAt ListFind ListFindNoCase
syn keyword	cfFunctionName		contained ListFirst ListGetAt ListInsertAt ListLast ListLen
syn keyword	cfFunctionName		contained ListPrepend ListQualify ListRest ListSetAt ListSort
syn keyword	cfFunctionName		contained ListToArray ListValueCount ListValueCountNoCase Log Log10
syn keyword	cfFunctionName		contained Max Mid Min Minute Month MonthAsString Now NumberFormat
syn keyword	cfFunctionName		contained ParagraphFormat ParseDateTime Pi
syn keyword	cfFunctionName		contained PreserveSingleQuotes Quarter QueryAddColumn QueryAddRow
syn keyword	cfFunctionName		contained QueryNew QuerySetCell QuotedValueList REFind REFindNoCase
syn keyword	cfFunctionName		contained REReplace REReplaceNoCase RJustify RTrim Rand RandRange
syn keyword	cfFunctionName		contained Randomize ReleaseComObject RemoveChars RepeatString Replace
syn keyword	cfFunctionName		contained ReplaceList ReplaceNoCase Reverse Right Round Second
syn keyword	cfFunctionName		contained SendGatewayMessage SetEncoding SetLocale SetProfileString
syn keyword	cfFunctionName		contained SetVariable Sgn Sin SpanExcluding SpanIncluding Sqr StripCR
syn keyword	cfFunctionName		contained StructAppend StructClear StructCopy StructCount StructDelete
syn keyword	cfFunctionName		contained StructFind StructFindKey StructFindValue StructGet
syn keyword	cfFunctionName		contained StructInsert StructIsEmpty StructKeyArray StructKeyExists
syn keyword	cfFunctionName		contained StructKeyList StructNew StructSort StructUpdate Tan
syn keyword	cfFunctionName		contained TimeFormat ToBase64 ToBinary ToScript ToString Trim UCase
syn keyword	cfFunctionName		contained URLDecode URLEncodedFormat URLSessionFormat Val ValueList
syn keyword	cfFunctionName		contained Week Wrap WriteOutput XmlChildPos XmlElemNew XmlFormat
syn keyword	cfFunctionName		contained XmlGetNodeType XmlNew XmlParse XmlSearch XmlTransform
syn keyword	cfFunctionName		contained XmlValidate Year YesNoFormat
" ColdFusion 8:
syn keyword	cfFunctionName		contained AjaxLink AjaxOnLoad ArrayIsDefined BinaryDecode BinaryEncode CharsetDecode CharsetEncode 
syn keyword	cfFunctionName		contained DecryptBinary DeserializeJSON DotNetToCFType EncryptBinary FileClose FileCopy FileDelete
syn keyword	cfFunctionName		contained FileIsEOF FileMove FileOpen FileRead FileReadBinary FileReadLine FileSetAccessMode FileSetAttribute
syn keyword	cfFunctionName		contained FileSetLastModified FileWrite GenerateSecretKey GetGatewayHelper GetAuthUser GetComponentMetaData
syn keyword	cfFunctionName		contained GetContextRoot GetEncoding GetFileInfo GetLocaleDisplayName GetLocalHostIP GetMetaData
syn keyword	cfFunctionName		contained GetPageContext GetPrinterInfo GetProfileSections GetReadableImageFormats GetSOAPRequest
syn keyword	cfFunctionName		contained GetSOAPRequestHeader GetSOAPResponse GetSOAPResponseHeader GetUserRoles GetWriteableImageFormats
syn keyword	cfFunctionName		contained ImageAddBorder ImageBlur ImageClearRect ImageCopy ImageCrop ImageDrawArc ImageDrawBeveledRect
syn keyword	cfFunctionName		contained ImageDrawCubicCurve ImageDrawPoint ImageDrawLine ImageDrawLines ImageDrawOval
syn keyword	cfFunctionName		contained ImageDrawQuadraticCurve ImageDrawRect ImageDrawRoundRect ImageDrawText ImageFlip ImageGetBlob
syn keyword	cfFunctionName		contained ImageGetBufferedImage ImageGetEXIFMetadata ImageGetEXIFTag ImageGetHeight ImageGetIPTCMetadata
syn keyword	cfFunctionName		contained ImageGetIPTCTag ImageGetWidth ImageGrayscale ImageInfo ImageNegative ImageNew ImageOverlay
syn keyword	cfFunctionName		contained ImagePaste ImageRead ImageReadBase64 ImageResize ImageRotate ImageRotateDrawingAxis ImageScaleToFit 
" ColdFusion 9:
syn keyword	cfFunctionName		contained ApplicationStop ArrayContains ArrayDelete ArrayFind ArrayFindNoCase IsSpreadsheetFile
syn keyword	cfFunctionName		contained IsSpreadsheetObject FileSkipBytes Location ObjectLoad SpreadsheetFormatColumn
syn keyword	cfFunctionName		contained SpreadsheetFormatColumns SpreadsheetFormatRow SpreadsheetFormatRows SpreadsheetGetCellComment
syn keyword	cfFunctionName		contained CacheGetAllIds CacheGetMetadata CacheGetProperties CacheGet CachePut ObjectSave ORMClearSession
syn keyword	cfFunctionName		contained ORMCloseSession ORMEvictQueries ORMEvictCollection SpreadsheetGetCellFormula SpreadsheetGetCellValue
syn keyword	cfFunctionName		contained SpreadsheetInfo SpreadsheetMergeCells SpreadsheetNew CacheRemove CacheSetProperties DirectoryCreate
syn keyword	cfFunctionName		contained DirectoryDelete DirectoryExists ORMEvictEntity ORMEvictQueries ORMExecuteQuery ORMFlush
syn keyword	cfFunctionName		contained ORMGetSession SpreadsheetRead SpreadsheetReadBinary SpreadsheetSetActiveSheetNumber
syn keyword	cfFunctionName		contained SpreadsheetSetCellComment SpreadsheetSetCellFormula DirectoryList DirectoryRename EntityDelete
syn keyword	cfFunctionName		contained EntityLoad EntityLoadByExample ORMGetSessionFactory ORMReload ObjectEquals SpreadsheetAddColumn
syn keyword	cfFunctionName		contained SpreadsheetAddFreezePane SpreadsheetSetCellValue SpreadsheetSetActiveSheet SpreadsheetSetFooter
syn keyword	cfFunctionName		contained SpreadsheetSetHeader SpreadsheetSetColumnWidth EntityLoadByPK EntityMerge EntityNew EntityReload
syn keyword	cfFunctionName		contained EntitySave SpreadsheetAddImage SpreadsheetAddInfo SpreadsheetAddRow SpreadsheetAddRows
syn keyword	cfFunctionName		contained SpreadsheetAddSplitPane SpreadsheetShiftColumns SpreadsheetShiftRows SpreadsheetSetRowHeight
syn keyword	cfFunctionName		contained SpreadsheetWrite Trace FileDelete FileSeek FileWriteLine GetFunctionCalledName GetVFSMetaData IsIPv6
syn keyword	cfFunctionName		contained IsNull SpreadsheetCreateSheet SpreadsheetDeleteColumn SpreadsheetDeleteColumns SpreadsheetDeleteRow
syn keyword	cfFunctionName		contained SpreadsheetDeleteRows SpreadsheetFormatCell TransactionCommit TransactionRollback
syn keyword	cfFunctionName		contained TransactionSetSavePoint ThreadTerminate ThreadJoin Throw Writedump Writelog 

" Deprecated or obsoleted tags and functions.
syn keyword	cfDeprecatedTag		contained cfauthenticate cfimpersonate cfgraph cfgraphdata
syn keyword	cfDeprecatedTag		contained cfservlet cfservletparam cftextinput
syn keyword	cfDeprecatedTag		contained cfinternaladminsecurity cfnewinternaladminsecurity
syn keyword	cfDeprecatedFunction	contained GetK2ServerDocCount GetK2ServerDocCountLimit GetTemplatePath
syn keyword	cfDeprecatedFunction	contained IsK2ServerABroker IsK2ServerDocCountExceeded IsK2ServerOnline
syn keyword	cfDeprecatedFunction	contained ParameterExists AuthenticatedContext AuthenticatedUser
syn keyword	cfDeprecatedFunction	contained isAuthenticated isAuthorized isProtected

" Add to the HTML clusters.
syn cluster	htmlTagNameCluster	add=cfTagName,cfCustomTagName,cfDeprecatedTag
syn cluster	htmlArgCluster		add=cfArg,cfHashRegion,cfScope
syn cluster	htmlPreproc		add=cfHashRegion

syn cluster	cfExpressionCluster	contains=cfFunctionName,cfScope,@cfOperatorCluster,cfScriptStringD,cfScriptStringS,cfScriptNumber,cfBool,cfComment

" Evaluation; skip strings ( this helps with cases like nested IIf() )
"		containedin to add to the TOP of cfOutputRegion.
syn region	cfHashRegion		start=+#+ skip=+"[^"]*"\|'[^']*'+ end=+#+ contained containedin=cfOutputRegion contains=@cfExpressionCluster,cfScriptParenError

" Hashmarks are significant inside cfoutput tags.
" cfoutput tags may be nested indefinitely.
syn region	cfOutputRegion		matchgroup=NONE transparent start=+<cfoutput>+ end=+</cfoutput>+ contains=TOP

" <cfset>, <cfif>, <cfelseif>, <cfreturn> are analogous to hashmarks (implicit
" evaluation) and have 'var'
syn region	cfSetRegion		start="<cfset\>" start="<cfreturn\>" start="<cfelseif\>" start="<cfif\>" end='>' keepend contains=@cfExpressionCluster,cfSetLHSRegion,cfSetTagEnd,cfScriptStatement
syn region	cfSetLHSRegion		contained start="<cfreturn" start="<cfelseif" start="<cfif" start="<cfset" end="." keepend contains=cfTagName,htmlTag
syn match	cfSetTagEnd		contained '>'

" CF comments: similar to SGML comments, but can be nested.
syn region	cfComment		start='<!---' end='--->' contains=cfCommentTodo,cfComment
syn keyword	cfCommentTodo		contained TODO FIXME XXX TBD WTF 

" CFscript 
" TODO better support for new component/function def syntax
" TODO better support for 'new'
" TODO highlight metadata (@ ...) inside comments.
syn match	cfScriptLineComment	contained "\/\/.*$" contains=cfCommentTodo
syn region	cfScriptComment		contained start="/\*"	end="\*/" contains=cfCommentTodo
syn match	cfScriptBraces		contained "[{}]"
syn keyword	cfScriptStatement	contained return var
" in CF, quotes are escaped by doubling
syn region	cfScriptStringD		contained start=+"+	skip=+\\\\\|""+	end=+"+	extend contains=@htmlPreproc,cfHashRegion
syn region	cfScriptStringS		contained start=+'+	skip=+\\\\\|''+	end=+'+	extend contains=@htmlPreproc,cfHashRegion
syn match	cfScriptNumber		contained "\<\d\+\>"
syn keyword	cfScriptConditional	contained if else
syn keyword	cfScriptRepeat		contained while for in
syn keyword	cfScriptBranch		contained break switch case default try catch continue finally
syn keyword	cfScriptKeyword		contained function
" argumentCollection is a special argument to function calls
syn keyword	cfScriptSpecial		contained argumentcollection
" ColdFusion 9:
syn keyword	cfScriptStatement	contained new import
" CFscript equivalents of some tags
syn keyword	cfScriptKeyword		contained abort component exit import include
syn keyword	cfScriptKeyword		contained interface param pageencoding property rethrow thread transaction
" function/component syntax
syn keyword	cfScriptSpecial		contained required extends


syn cluster	cfScriptCluster	contains=cfScriptParen,cfScriptLineComment,cfScriptComment,cfScriptStringD,cfScriptStringS,cfScriptFunction,cfScriptNumber,cfScriptRegexpString,cfScriptBoolean,cfScriptBraces,cfHashRegion,cfFunctionName,cfDeprecatedFunction,cfScope,@cfOperatorCluster,cfScriptConditional,cfScriptRepeat,cfScriptBranch,@cfExpressionCluster,cfScriptStatement,cfScriptSpecial,cfScriptKeyword

" Errors caused by wrong parenthesis; skip strings
syn region	cfScriptParen	contained transparent skip=+"[^"]*"\|'[^']*'+ start=+(+ end=+)+ contains=@cfScriptCluster
syn match	cfScrParenError	contained +)+

syn region	cfscriptBlock	matchgroup=NONE start="<cfscript>"	end="<\/cfscript>"me=s-1 keepend contains=@cfScriptCluster,cfscriptTag,cfScrParenError
syn region	cfscriptTag	contained start='<cfscript' end='>' keepend contains=cfTagName,htmlTag

" CFML
syn cluster	cfmlCluster	contains=cfComment,@htmlTagNameCluster,@htmlPreproc,cfSetRegion,cfscriptBlock,cfOutputRegion

" cfquery = sql syntax
if exists("b:current_syntax")
  unlet b:current_syntax
endif
syn include @cfSql $VIMRUNTIME/syntax/sql.vim
unlet b:current_syntax
syn region	cfqueryTag	contained start=+<cfquery+ end=+>+ keepend contains=cfTagName,htmlTag
syn region	cfSqlregion	start=+<cfquery\_[^>]*>+ keepend end=+</cfquery>+me=s-1 matchgroup=NONE contains=@cfSql,cfComment,@htmlTagNameCluster,cfqueryTag,cfHashRegion

" Define the highlighting.

if exists("d_noinclude_html")
  " The default html-style highlighting copied from html.vim.
  hi def link htmlTag		Function
  hi def link htmlEndTag		Identifier
  hi def link htmlArg		Type
  hi def link htmlTagName		htmlStatement
  hi def link htmlValue		String
  hi def link htmlPreProc		PreProc
  hi def link htmlString		String
  hi def link htmlStatement	Statement
  hi def link htmlValue		String
  hi def link htmlTagError		htmlError
  hi def link htmlError		Error
endif

hi def link cfTagName		Statement
hi def link cfCustomTagName	Statement
hi def link cfArg			Type
hi def link cfFunctionName		Function
hi def link cfHashRegion		PreProc
hi def link cfComment		Comment
hi def link cfCommentTodo		Todo
hi def link cfOperator		Operator
hi def link cfOperatorMatch	Operator
hi def link cfScope		Title
hi def link cfBool			Constant

hi def link cfscriptBlock		Special
hi def link cfscriptTag		htmlTag
hi def link cfSetRegion		PreProc
hi def link cfSetLHSRegion		htmlTag
hi def link cfSetTagEnd		htmlTag

hi def link cfScriptLineComment	Comment
hi def link cfScriptComment	Comment
hi def link cfScriptStringS	String
hi def link cfScriptStringD	String
hi def link cfScriptNumber		cfScriptValue
hi def link cfScriptConditional	Conditional
hi def link cfScriptRepeat		Repeat
hi def link cfScriptBranch		Conditional
hi def link cfScriptSpecial	Type
hi def link cfScriptStatement	Statement
hi def link cfScriptBraces		Function
hi def link cfScriptKeyword	Function
hi def link cfScriptError		Error
hi def link cfDeprecatedTag	Error
hi def link cfDeprecatedFunction	Error
hi def link cfScrParenError	cfScriptError

hi def link cfqueryTag		htmlTag

let b:current_syntax = "cf"

" vim: nowrap sw=2 ts=8 noet
