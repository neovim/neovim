" Vim syntax file
" Language:	Microsoft VBScript Web Content (ASP)
" Maintainer:	Devin Weaver <ktohg@tritarget.com> (non-functional)
" URL:		http://tritarget.com/pub/vim/syntax/aspvbs.vim (broken)
" Last Change:	2006 Jun 19
" 		by Dan Casey
" Version:	$Revision: 1.3 $
" Thanks to Jay-Jay <vim@jay-jay.net> for a syntax sync hack, hungarian
" notation, and extra highlighting.
" Thanks to patrick dehne <patrick@steidle.net> for the folding code.
" Thanks to Dean Hall <hall@apt7.com> for testing the use of classes in
" VBScripts which I've been too scared to do.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'aspvbs'
endif

runtime! syntax/html.vim
unlet b:current_syntax

syn cluster htmlPreProc add=AspVBScriptInsideHtmlTags


" Colored variable names, if written in hungarian notation
hi def AspVBSVariableSimple   term=standout  ctermfg=3  guifg=#99ee99
hi def AspVBSVariableComplex  term=standout  ctermfg=3  guifg=#ee9900
syn match AspVBSVariableSimple  contained "\<\(bln\|byt\|dtm\=\|dbl\|int\|str\)\u\w*"
syn match AspVBSVariableComplex contained "\<\(arr\|ary\|obj\)\u\w*"


" Functions and methods that are in VB but will cause errors in an ASP page
" This is helpful if you're porting VB code to ASP
" I removed (Count, Item) because these are common variable names in AspVBScript
syn keyword AspVBSError contained Val Str CVar CVDate DoEvents GoSub Return GoTo
syn keyword AspVBSError contained Stop LinkExecute Add Type LinkPoke
syn keyword AspVBSError contained LinkRequest LinkSend Declare Optional Sleep
syn keyword AspVBSError contained ParamArray Static Erl TypeOf Like LSet RSet Mid StrConv
" It may seem that most of these can fit into a keyword clause but keyword takes
" priority over all so I can't get the multi-word matches
syn match AspVBSError contained "\<Def[a-zA-Z0-9_]\+\>"
syn match AspVBSError contained "^\s*Open\s\+"
syn match AspVBSError contained "Debug\.[a-zA-Z0-9_]*"
syn match AspVBSError contained "^\s*[a-zA-Z0-9_]\+:"
syn match AspVBSError contained "[a-zA-Z0-9_]\+![a-zA-Z0-9_]\+"
syn match AspVBSError contained "^\s*#.*$"
syn match AspVBSError contained "\<As\s\+[a-zA-Z0-9_]*"
syn match AspVBSError contained "\<End\>\|\<Exit\>"
syn match AspVBSError contained "\<On\s\+Error\>\|\<On\>\|\<Error\>\|\<Resume\s\+Next\>\|\<Resume\>"
syn match AspVBSError contained "\<Option\s\+\(Base\|Compare\|Private\s\+Module\)\>"
" This one I want 'cause I always seem to mis-spell it.
syn match AspVBSError contained "Respon\?ce\.\S*"
syn match AspVBSError contained "Respose\.\S*"
" When I looked up the VBScript syntax it mentioned that Property Get/Set/Let
" statements are illegal, however, I have received reports that they do work.
" So I commented it out for now.
" syn match AspVBSError contained "\<Property\s\+\(Get\|Let\|Set\)\>"

" AspVBScript Reserved Words.
syn match AspVBSStatement contained "\<On\s\+Error\s\+\(Resume\s\+Next\|goto\s\+0\)\>\|\<Next\>"
syn match AspVBSStatement contained "\<End\s\+\(If\|For\|Select\|Class\|Function\|Sub\|With\|Property\)\>"
syn match AspVBSStatement contained "\<Exit\s\+\(Do\|For\|Sub\|Function\)\>"
syn match AspVBSStatement contained "\<Exit\s\+\(Do\|For\|Sub\|Function\|Property\)\>"
syn match AspVBSStatement contained "\<Option\s\+Explicit\>"
syn match AspVBSStatement contained "\<For\s\+Each\>\|\<For\>"
syn match AspVBSStatement contained "\<Set\>"
syn keyword AspVBSStatement contained Call Class Const Default Dim Do Loop Erase And
syn keyword AspVBSStatement contained Function If Then Else ElseIf Or
syn keyword AspVBSStatement contained Private Public Randomize ReDim
syn keyword AspVBSStatement contained Select Case Sub While With Wend Not

" AspVBScript Functions
syn keyword AspVBSFunction contained Abs Array Asc Atn CBool CByte CCur CDate CDbl
syn keyword AspVBSFunction contained Chr CInt CLng Cos CreateObject CSng CStr Date
syn keyword AspVBSFunction contained DateAdd DateDiff DatePart DateSerial DateValue
syn keyword AspVBSFunction contained Date Day Exp Filter Fix FormatCurrency
syn keyword AspVBSFunction contained FormatDateTime FormatNumber FormatPercent
syn keyword AspVBSFunction contained GetObject Hex Hour InputBox InStr InStrRev Int
syn keyword AspVBSFunction contained IsArray IsDate IsEmpty IsNull IsNumeric
syn keyword AspVBSFunction contained IsObject Join LBound LCase Left Len LoadPicture
syn keyword AspVBSFunction contained Log LTrim Mid Minute Month MonthName MsgBox Now
syn keyword AspVBSFunction contained Oct Replace RGB Right Rnd Round RTrim
syn keyword AspVBSFunction contained ScriptEngine ScriptEngineBuildVersion
syn keyword AspVBSFunction contained ScriptEngineMajorVersion
syn keyword AspVBSFunction contained ScriptEngineMinorVersion Second Sgn Sin Space
syn keyword AspVBSFunction contained Split Sqr StrComp StrReverse String Tan Time Timer
syn keyword AspVBSFunction contained TimeSerial TimeValue Trim TypeName UBound UCase
syn keyword AspVBSFunction contained VarType Weekday WeekdayName Year

" AspVBScript Methods
syn keyword AspVBSMethods contained Add AddFolders BuildPath Clear Close Copy
syn keyword AspVBSMethods contained CopyFile CopyFolder CreateFolder CreateTextFile
syn keyword AspVBSMethods contained Delete DeleteFile DeleteFolder DriveExists
syn keyword AspVBSMethods contained Exists FileExists FolderExists
syn keyword AspVBSMethods contained GetAbsolutePathName GetBaseName GetDrive
syn keyword AspVBSMethods contained GetDriveName GetExtensionName GetFile
syn keyword AspVBSMethods contained GetFileName GetFolder GetParentFolderName
syn keyword AspVBSMethods contained GetSpecialFolder GetTempName Items Keys Move
syn keyword AspVBSMethods contained MoveFile MoveFolder OpenAsTextStream
syn keyword AspVBSMethods contained OpenTextFile Raise Read ReadAll ReadLine Remove
syn keyword AspVBSMethods contained RemoveAll Skip SkipLine Write WriteBlankLines
syn keyword AspVBSMethods contained WriteLine
syn match AspVBSMethods contained "Response\.\w*"
" Colorize boolean constants:
syn keyword AspVBSMethods contained true false

" AspVBScript Number Contstants
" Integer number, or floating point number without a dot.
syn match  AspVBSNumber	contained	"\<\d\+\>"
" Floating point number, with dot
syn match  AspVBSNumber	contained	"\<\d\+\.\d*\>"
" Floating point number, starting with a dot
syn match  AspVBSNumber	contained	"\.\d\+\>"

" String and Character Contstants
" removed (skip=+\\\\\|\\"+) because VB doesn't have backslash escaping in
" strings (or does it?)
syn region  AspVBSString	contained	  start=+"+  end=+"+ keepend

" AspVBScript Comments
syn region  AspVBSComment	contained start="^REM\s\|\sREM\s" end="$" contains=AspVBSTodo keepend
syn region  AspVBSComment   contained start="^'\|\s'"   end="$" contains=AspVBSTodo keepend
" misc. Commenting Stuff
syn keyword AspVBSTodo contained	TODO FIXME

" Cosmetic syntax errors commanly found in VB but not in AspVBScript
" AspVBScript doesn't use line numbers
syn region  AspVBSError	contained start="^\d" end="\s" keepend
" AspVBScript also doesn't have type defining variables
syn match   AspVBSError  contained "[a-zA-Z0-9_][\$&!#]"ms=s+1
" Since 'a%' is a VB variable with a type and in AspVBScript you can have 'a%>'
" I have to make a special case so 'a%>' won't show as an error.
syn match   AspVBSError  contained "[a-zA-Z0-9_]%\($\|[^>]\)"ms=s+1

" Top Cluster
syn cluster AspVBScriptTop contains=AspVBSStatement,AspVBSFunction,AspVBSMethods,AspVBSNumber,AspVBSString,AspVBSComment,AspVBSError,AspVBSVariableSimple,AspVBSVariableComplex

" Folding
syn region AspVBSFold start="^\s*\(class\)\s\+.*$" end="^\s*end\s\+\(class\)\>.*$" fold contained transparent keepend
syn region AspVBSFold start="^\s*\(private\|public\)\=\(\s\+default\)\=\s\+\(sub\|function\)\s\+.*$" end="^\s*end\s\+\(function\|sub\)\>.*$" fold contained transparent keepend

" Define AspVBScript delimeters
" <%= func("string_with_%>_in_it") %> This is illegal in ASP syntax.
syn region  AspVBScriptInsideHtmlTags keepend matchgroup=Delimiter start=+<%=\=+ end=+%>+ contains=@AspVBScriptTop, AspVBSFold
syn region  AspVBScriptInsideHtmlTags keepend matchgroup=Delimiter start=+<script\s\+language="\=vbscript"\=[^>]*\s\+runatserver[^>]*>+ end=+</script>+ contains=@AspVBScriptTop


" Synchronization
" syn sync match AspVBSSyncGroup grouphere AspVBScriptInsideHtmlTags "<%"
" This is a kludge so the HTML will sync properly
syn sync match htmlHighlight grouphere htmlTag "%>"



" Define the default highlighting.
" Only when an item doesn't have highlighting yet

"hi def link AspVBScript		Special
hi def link AspVBSLineNumber	Comment
hi def link AspVBSNumber		Number
hi def link AspVBSError		Error
hi def link AspVBSStatement	Statement
hi def link AspVBSString		String
hi def link AspVBSComment		Comment
hi def link AspVBSTodo		Todo
hi def link AspVBSFunction		Identifier
hi def link AspVBSMethods		PreProc
hi def link AspVBSEvents		Special
hi def link AspVBSTypeSpecifier	Type


let b:current_syntax = "aspvbs"

if main_syntax == 'aspvbs'
  unlet main_syntax
endif

" vim: ts=8:sw=2:sts=0:noet
