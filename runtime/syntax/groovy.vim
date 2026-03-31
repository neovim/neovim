" Vim syntax file
" Language:	Groovy
" Original Author:	Alessio Pace <billy.corgan AT tiscali.it>
" Maintainer:	Tobias Rapp <yahuxo+vim AT mailbox.org>
" Version: 	0.1.18
" URL:	  http://www.vim.org/scripts/script.php?script_id=945
" Last Change:	2021 Feb 03

" THE ORIGINAL AUTHOR'S NOTES:
"
" This is my very first vim script, I hope to have
" done it the right way.
"
" I must directly or indirectly thank the author of java.vim and ruby.vim:
" I copied from them most of the stuff :-)
"
" Relies on html.vim

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
"
" HOWTO USE IT (INSTALL) when not part of the distribution:
"
" 1) copy the file in the (global or user's $HOME/.vim/syntax/) syntax folder
"
" 2) add this line to recognize groovy files by filename extension:
"
" au BufNewFile,BufRead *.groovy  setf groovy
" in the global vim filetype.vim file or inside $HOME/.vim/filetype.vim
"
" 3) add this part to recognize by content groovy script (no extension needed :-)
"
"  if did_filetype()
"    finish
"  endif
"  if getline(1) =~ '^#!.*[/\\]groovy\>'
"    setf groovy
"  endif
"
"  in the global scripts.vim file or in $HOME/.vim/scripts.vim
"
" 4) open/write a .groovy file or a groovy script :-)
"
" Let me know if you like it or send me patches, so that I can improve it
" when I have time

" quit when a syntax file was already loaded
if !exists("main_syntax")
  if exists("b:current_syntax")
    finish
  endif
  " we define it here so that included files can test for it
  let main_syntax='groovy'
endif

let s:cpo_save = &cpo
set cpo&vim

" ##########################
" Java stuff taken from java.vim
" some characters that cannot be in a groovy program (outside a string)
" syn match groovyError "[\\@`]"
"syn match groovyError "<<<\|\.\.\|=>\|<>\|||=\|&&=\|[^-]->\|\*\/"
"syn match groovyOK "\.\.\."

" keyword definitions
syn keyword groovyExternal        native package
syn match groovyExternal          "\<import\>\(\s\+static\>\)\?"
syn keyword groovyError           goto const
syn keyword groovyConditional     if else switch
syn keyword groovyRepeat          while for do
syn keyword groovyBoolean         true false
syn keyword groovyConstant        null
syn keyword groovyTypedef         this super
syn keyword groovyOperator        new instanceof
syn keyword groovyType            boolean char byte short int long float double
syn keyword groovyType            void
syn keyword groovyType		  Integer Double Date Boolean Float String Array Vector List
syn keyword groovyStatement       return
syn keyword groovyStorageClass    static synchronized transient volatile final strictfp serializable
syn keyword groovyExceptions      throw try catch finally
syn keyword groovyAssert          assert
syn keyword groovyMethodDecl      synchronized throws
syn keyword groovyClassDecl       extends implements interface
" to differentiate the keyword class from MyClass.class we use a match here
syn match   groovyTypedef         "\.\s*\<class\>"ms=s+1
syn keyword groovyClassDecl         enum
syn match   groovyClassDecl       "^class\>"
syn match   groovyClassDecl       "[^.]\s*\<class\>"ms=s+1
syn keyword groovyBranch          break continue nextgroup=groovyUserLabelRef skipwhite
syn match   groovyUserLabelRef    "\k\+" contained
syn keyword groovyScopeDecl       public protected private abstract


if exists("groovy_highlight_groovy_lang_ids") || exists("groovy_highlight_groovy_lang") || exists("groovy_highlight_all")
  " groovy.lang.*
  syn keyword groovyLangClass  Closure MetaMethod GroovyObject

  syn match groovyJavaLangClass "\<System\>"
  syn keyword groovyJavaLangClass  Cloneable Comparable Runnable Serializable Boolean Byte Class Object
  syn keyword groovyJavaLangClass  Character CharSequence ClassLoader Compiler
  " syn keyword groovyJavaLangClass  Integer Double Float Long
  syn keyword groovyJavaLangClass  InheritableThreadLocal Math Number Object Package Process
  syn keyword groovyJavaLangClass  Runtime RuntimePermission InheritableThreadLocal
  syn keyword groovyJavaLangClass  SecurityManager Short StrictMath StackTraceElement
  syn keyword groovyJavaLangClass  StringBuffer Thread ThreadGroup
  syn keyword groovyJavaLangClass  ThreadLocal Throwable Void ArithmeticException
  syn keyword groovyJavaLangClass  ArrayIndexOutOfBoundsException AssertionError
  syn keyword groovyJavaLangClass  ArrayStoreException ClassCastException
  syn keyword groovyJavaLangClass  ClassNotFoundException
  syn keyword groovyJavaLangClass  CloneNotSupportedException Exception
  syn keyword groovyJavaLangClass  IllegalAccessException
  syn keyword groovyJavaLangClass  IllegalArgumentException
  syn keyword groovyJavaLangClass  IllegalMonitorStateException
  syn keyword groovyJavaLangClass  IllegalStateException
  syn keyword groovyJavaLangClass  IllegalThreadStateException
  syn keyword groovyJavaLangClass  IndexOutOfBoundsException
  syn keyword groovyJavaLangClass  InstantiationException InterruptedException
  syn keyword groovyJavaLangClass  NegativeArraySizeException NoSuchFieldException
  syn keyword groovyJavaLangClass  NoSuchMethodException NullPointerException
  syn keyword groovyJavaLangClass  NumberFormatException RuntimeException
  syn keyword groovyJavaLangClass  SecurityException StringIndexOutOfBoundsException
  syn keyword groovyJavaLangClass  UnsupportedOperationException
  syn keyword groovyJavaLangClass  AbstractMethodError ClassCircularityError
  syn keyword groovyJavaLangClass  ClassFormatError Error ExceptionInInitializerError
  syn keyword groovyJavaLangClass  IllegalAccessError InstantiationError
  syn keyword groovyJavaLangClass  IncompatibleClassChangeError InternalError
  syn keyword groovyJavaLangClass  LinkageError NoClassDefFoundError
  syn keyword groovyJavaLangClass  NoSuchFieldError NoSuchMethodError
  syn keyword groovyJavaLangClass  OutOfMemoryError StackOverflowError
  syn keyword groovyJavaLangClass  ThreadDeath UnknownError UnsatisfiedLinkError
  syn keyword groovyJavaLangClass  UnsupportedClassVersionError VerifyError
  syn keyword groovyJavaLangClass  VirtualMachineError

  syn keyword groovyJavaLangObject clone equals finalize getClass hashCode
  syn keyword groovyJavaLangObject notify notifyAll toString wait

  hi def link groovyLangClass                   groovyConstant
  hi def link groovyJavaLangClass               groovyExternal
  hi def link groovyJavaLangObject              groovyConstant
  syn cluster groovyTop add=groovyJavaLangObject,groovyJavaLangClass,groovyLangClass
  syn cluster groovyClasses add=groovyJavaLangClass,groovyLangClass
endif


" Groovy stuff
syn match groovyOperator "\.\."
syn match groovyOperator "<\{2,3}"
syn match groovyOperator ">\{2,3}"
syn match groovyOperator "->"
syn match groovyLineComment       '^\%1l#!.*'  " Shebang line
syn match groovyExceptions        "\<Exception\>\|\<[A-Z]\{1,}[a-zA-Z0-9]*Exception\>"

" Groovy JDK stuff
syn keyword groovyJDKBuiltin    as def in
syn keyword groovyJDKOperOverl  div minus plus abs round power multiply
syn keyword groovyJDKMethods 	each call inject sort print println
syn keyword groovyJDKMethods    getAt putAt size push pop toList getText writeLine eachLine readLines
syn keyword groovyJDKMethods    withReader withStream withWriter withPrintWriter write read leftShift
syn keyword groovyJDKMethods    withWriterAppend readBytes splitEachLine
syn keyword groovyJDKMethods    newInputStream newOutputStream newPrintWriter newReader newWriter
syn keyword groovyJDKMethods    compareTo next previous isCase
syn keyword groovyJDKMethods    times step toInteger upto any collect dump every find findAll grep
syn keyword groovyJDKMethods    inspect invokeMethods join
syn keyword groovyJDKMethods    getErr getIn getOut waitForOrKill
syn keyword groovyJDKMethods    count tokenize asList flatten immutable intersect reverse reverseEach
syn keyword groovyJDKMethods    subMap append asWritable eachByte eachLine eachFile
syn cluster groovyTop add=groovyJDKBuiltin,groovyJDKOperOverl,groovyJDKMethods

" no useful I think, so I comment it..
"if filereadable(expand("<sfile>:p:h")."/groovyid.vim")
 " source <sfile>:p:h/groovyid.vim
"endif

if exists("groovy_space_errors")
  if !exists("groovy_no_trail_space_error")
    syn match   groovySpaceError  "\s\+$"
  endif
  if !exists("groovy_no_tab_space_error")
    syn match   groovySpaceError  " \+\t"me=e-1
  endif
endif

" it is a better case construct than java.vim to match groovy syntax
syn region  groovyLabelRegion     transparent matchgroup=groovyLabel start="\<case\>" matchgroup=NONE end=":\|$" contains=groovyNumber,groovyString,groovyLangClass,groovyJavaLangClass
syn match   groovyUserLabel       "^\s*[_$a-zA-Z][_$a-zA-Z0-9_]*\s*:"he=e-1 contains=groovyLabel
syn keyword groovyLabel           default

if !exists("groovy_allow_cpp_keywords")
  syn keyword groovyError auto delete extern friend inline redeclared
  syn keyword groovyError register signed sizeof struct template typedef union
  syn keyword groovyError unsigned operator
endif

" The following cluster contains all groovy groups except the contained ones
syn cluster groovyTop add=groovyExternal,groovyError,groovyError,groovyBranch,groovyLabelRegion,groovyLabel,groovyConditional,groovyRepeat,groovyBoolean,groovyConstant,groovyTypedef,groovyOperator,groovyType,groovyType,groovyStatement,groovyStorageClass,groovyAssert,groovyExceptions,groovyMethodDecl,groovyClassDecl,groovyClassDecl,groovyClassDecl,groovyScopeDecl,groovyError,groovyError2,groovyUserLabel,groovyLangObject


" Comments
syn keyword groovyTodo             contained TODO FIXME XXX
if exists("groovy_comment_strings")
  syn region  groovyCommentString    contained start=+"+ end=+"+ end=+$+ end=+\*/+me=s-1,he=s-1 contains=groovySpecial,groovyCommentStar,groovySpecialChar,@Spell
  syn region  groovyComment2String   contained start=+"+  end=+$\|"+  contains=groovySpecial,groovySpecialChar,@Spell
  syn match   groovyCommentCharacter contained "'\\[^']\{1,6\}'" contains=groovySpecialChar
  syn match   groovyCommentCharacter contained "'\\''" contains=groovySpecialChar
  syn match   groovyCommentCharacter contained "'[^\\]'"
  syn cluster groovyCommentSpecial add=groovyCommentString,groovyCommentCharacter,groovyNumber
  syn cluster groovyCommentSpecial2 add=groovyComment2String,groovyCommentCharacter,groovyNumber
endif
syn region  groovyComment          start="/\*"  end="\*/" contains=@groovyCommentSpecial,groovyTodo,@Spell
syn match   groovyCommentStar      contained "^\s*\*[^/]"me=e-1
syn match   groovyCommentStar      contained "^\s*\*$"
syn match   groovyLineComment      "//.*" contains=@groovyCommentSpecial2,groovyTodo,@Spell
hi def link groovyCommentString groovyString
hi def link groovyComment2String groovyString
hi def link groovyCommentCharacter groovyCharacter

syn cluster groovyTop add=groovyComment,groovyLineComment

if !exists("groovy_ignore_groovydoc") && main_syntax != 'jsp'
  syntax case ignore
  " syntax coloring for groovydoc comments (HTML)
  " syntax include @groovyHtml <sfile>:p:h/html.vim
   syntax include @groovyHtml runtime! syntax/html.vim
  unlet b:current_syntax
  syntax spell default  " added by Bram
  syn region  groovyDocComment    start="/\*\*"  end="\*/" keepend contains=groovyCommentTitle,@groovyHtml,groovyDocTags,groovyTodo,@Spell
  syn region  groovyCommentTitle  contained matchgroup=groovyDocComment start="/\*\*"   matchgroup=groovyCommentTitle keepend end="\.$" end="\.[ \t\r<&]"me=e-1 end="[^{]@"me=s-2,he=s-1 end="\*/"me=s-1,he=s-1 contains=@groovyHtml,groovyCommentStar,groovyTodo,@Spell,groovyDocTags

  syn region groovyDocTags  contained start="{@\(link\|linkplain\|inherit[Dd]oc\|doc[rR]oot\|value\)" end="}"
  syn match  groovyDocTags  contained "@\(see\|param\|exception\|throws\|since\)\s\+\S\+" contains=groovyDocParam
  syn match  groovyDocParam contained "\s\S\+"
  syn match  groovyDocTags  contained "@\(version\|author\|return\|deprecated\|serial\|serialField\|serialData\)\>"
  syntax case match
endif

" match the special comment /**/
syn match   groovyComment          "/\*\*/"

" Strings and constants
syn match   groovySpecialError     contained "\\."
syn match   groovySpecialCharError contained "[^']"
syn match   groovySpecialChar      contained "\\\([4-9]\d\|[0-3]\d\d\|[\"\\'ntbrf]\|u\x\{4\}\|\$\)"
syn match   groovyRegexChar        contained "\\."
syn region  groovyString          start=+"+ end=+"+ end=+$+ contains=groovySpecialChar,groovySpecialError,@Spell,groovyELExpr
syn region  groovyString          start=+'+ end=+'+ end=+$+ contains=groovySpecialChar,groovySpecialError,@Spell
syn region  groovyString          start=+"""+ end=+"""+ contains=groovySpecialChar,groovySpecialError,@Spell,groovyELExpr
syn region  groovyString          start=+'''+ end=+'''+ contains=groovySpecialChar,groovySpecialError,@Spell
if exists("groovy_regex_strings")
  " regex strings interfere with the division operator and thus are disabled
  " by default
  syn region groovyString         start='/[^/*]' end='/' contains=groovySpecialChar,groovyRegexChar,groovyELExpr
endif
" syn region groovyELExpr start=+${+ end=+}+ keepend contained
syn match groovyELExpr /\${.\{-}}/ contained
" Fix: force use of the NFA regexp engine (2), see GitHub issue #7280
syn match groovyELExpr /\%#=2\$[a-zA-Z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u00FF\u0100-\uFFFE_][a-zA-Z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u00FF\u0100-\uFFFE0-9_.]*/ contained
hi def link groovyELExpr Identifier

" TODO: better matching. I am waiting to understand how it really works in groovy
" syn region  groovyClosureParamsBraces          start=+|+ end=+|+ contains=groovyClosureParams
" syn match groovyClosureParams	"[ a-zA-Z0-9_*]\+" contained
" hi def link groovyClosureParams Identifier

" next line disabled, it can cause a crash for a long line
"syn match   groovyStringError      +"\([^"\\]\|\\.\)*$+

" disabled: in groovy strings or characters are written the same
" syn match   groovyCharacter        "'[^']*'" contains=groovySpecialChar,groovySpecialCharError
" syn match   groovyCharacter        "'\\''" contains=groovySpecialChar
" syn match   groovyCharacter        "'[^\\]'"
syn match   groovyNumber           "\<\(0[0-7]*\|0[xX]\x\+\|\d\+\)[lL]\=\>"
syn match   groovyNumber           "\(\<\d\+\.\d*\|\.\d\+\)\([eE][-+]\=\d\+\)\=[fFdD]\="
syn match   groovyNumber           "\<\d\+[eE][-+]\=\d\+[fFdD]\=\>"
syn match   groovyNumber           "\<\d\+\([eE][-+]\=\d\+\)\=[fFdD]\>"

" unicode characters
syn match   groovySpecial "\\u\d\{4\}"

syn cluster groovyTop add=groovyString,groovyCharacter,groovyNumber,groovySpecial,groovyStringError

if exists("groovy_highlight_functions")
  if groovy_highlight_functions == "indent"
    syn match  groovyFuncDef "^\(\t\| \{8\}\)[_$a-zA-Z][_$a-zA-Z0-9_. \[\]]*([^-+*/()]*)" contains=groovyScopeDecl,groovyType,groovyStorageClass,@groovyClasses
    syn region groovyFuncDef start=+^\(\t\| \{8\}\)[$_a-zA-Z][$_a-zA-Z0-9_. \[\]]*([^-+*/()]*,\s*+ end=+)+ contains=groovyScopeDecl,groovyType,groovyStorageClass,@groovyClasses
    syn match  groovyFuncDef "^  [$_a-zA-Z][$_a-zA-Z0-9_. \[\]]*([^-+*/()]*)" contains=groovyScopeDecl,groovyType,groovyStorageClass,@groovyClasses
    syn region groovyFuncDef start=+^  [$_a-zA-Z][$_a-zA-Z0-9_. \[\]]*([^-+*/()]*,\s*+ end=+)+ contains=groovyScopeDecl,groovyType,groovyStorageClass,@groovyClasses
  else
    " This line catches method declarations at any indentation>0, but it assumes
    " two things:
    "   1. class names are always capitalized (ie: Button)
    "   2. method names are never capitalized (except constructors, of course)
    syn region groovyFuncDef start=+^\s\+\(\(public\|protected\|private\|static\|abstract\|final\|native\|synchronized\)\s\+\)*\(\(void\|boolean\|char\|byte\|short\|int\|long\|float\|double\|\([A-Za-z_][A-Za-z0-9_$]*\.\)*[A-Z][A-Za-z0-9_$]*\)\(<[^>]*>\)\=\(\[\]\)*\s\+[a-z][A-Za-z0-9_$]*\|[A-Z][A-Za-z0-9_$]*\)\s*([^0-9]+ end=+)+ contains=groovyScopeDecl,groovyType,groovyStorageClass,groovyComment,groovyLineComment,@groovyClasses
  endif
  syn match  groovyBraces  "[{}]"
  syn cluster groovyTop add=groovyFuncDef,groovyBraces
endif

if exists("groovy_highlight_debug")

  " Strings and constants
  syn match   groovyDebugSpecial          contained "\\\d\d\d\|\\."
  syn region  groovyDebugString           contained start=+"+  end=+"+  contains=groovyDebugSpecial
  syn match   groovyDebugStringError      +"\([^"\\]\|\\.\)*$+
  syn match   groovyDebugCharacter        contained "'[^\\]'"
  syn match   groovyDebugSpecialCharacter contained "'\\.'"
  syn match   groovyDebugSpecialCharacter contained "'\\''"
  syn match   groovyDebugNumber           contained "\<\(0[0-7]*\|0[xX]\x\+\|\d\+\)[lL]\=\>"
  syn match   groovyDebugNumber           contained "\(\<\d\+\.\d*\|\.\d\+\)\([eE][-+]\=\d\+\)\=[fFdD]\="
  syn match   groovyDebugNumber           contained "\<\d\+[eE][-+]\=\d\+[fFdD]\=\>"
  syn match   groovyDebugNumber           contained "\<\d\+\([eE][-+]\=\d\+\)\=[fFdD]\>"
  syn keyword groovyDebugBoolean          contained true false
  syn keyword groovyDebugType             contained null this super
  syn region groovyDebugParen  start=+(+ end=+)+ contained contains=groovyDebug.*,groovyDebugParen

  " to make this work you must define the highlighting for these groups
  syn match groovyDebug "\<System\.\(out\|err\)\.print\(ln\)*\s*("me=e-1 contains=groovyDebug.* nextgroup=groovyDebugParen
  syn match groovyDebug "\<p\s*("me=e-1 contains=groovyDebug.* nextgroup=groovyDebugParen
  syn match groovyDebug "[A-Za-z][a-zA-Z0-9_]*\.printStackTrace\s*("me=e-1 contains=groovyDebug.* nextgroup=groovyDebugParen
  syn match groovyDebug "\<trace[SL]\=\s*("me=e-1 contains=groovyDebug.* nextgroup=groovyDebugParen

  syn cluster groovyTop add=groovyDebug

  hi def link groovyDebug                 Debug
  hi def link groovyDebugString           DebugString
  hi def link groovyDebugStringError      groovyError
  hi def link groovyDebugType             DebugType
  hi def link groovyDebugBoolean          DebugBoolean
  hi def link groovyDebugNumber           Debug
  hi def link groovyDebugSpecial          DebugSpecial
  hi def link groovyDebugSpecialCharacter DebugSpecial
  hi def link groovyDebugCharacter        DebugString
  hi def link groovyDebugParen            Debug

  hi def link DebugString               String
  hi def link DebugSpecial              Special
  hi def link DebugBoolean              Boolean
  hi def link DebugType                 Type
endif

" Match all Exception classes
syn match groovyExceptions        "\<Exception\>\|\<[A-Z]\{1,}[a-zA-Z0-9]*Exception\>"


if !exists("groovy_minlines")
  let groovy_minlines = 10
endif
exec "syn sync ccomment groovyComment minlines=" . groovy_minlines


" ###################
" Groovy stuff
" syn match groovyOperator		"|[ ,a-zA-Z0-9_*]\+|"

" All groovy valid tokens
" syn match groovyTokens ";\|,\|<=>\|<>\|:\|:=\|>\|>=\|=\|==\|<\|<=\|!=\|/\|/=\|\.\.|\.\.\.\|\~=\|\~=="
" syn match groovyTokens "\*=\|&\|&=\|\*\|->\|\~\|+\|-\|/\|?\|<<<\|>>>\|<<\|>>"

" Must put explicit these ones because groovy.vim mark them as errors otherwise
" syn match groovyTokens "<=>\|<>\|==\~"
"syn cluster groovyTop add=groovyTokens

" Mark these as operators

" Highlight brackets
" syn match  groovyBraces		"[{}]"
" syn match  groovyBraces		"[\[\]]"
" syn match  groovyBraces		"[\|]"

if exists("groovy_mark_braces_in_parens_as_errors")
  syn match groovyInParen          contained "[{}]"
  hi def link groovyInParen        groovyError
  syn cluster groovyTop add=groovyInParen
endif

" catch errors caused by wrong parenthesis
syn region  groovyParenT  transparent matchgroup=groovyParen  start="("  end=")" contains=@groovyTop,groovyParenT1
syn region  groovyParenT1 transparent matchgroup=groovyParen1 start="(" end=")" contains=@groovyTop,groovyParenT2 contained
syn region  groovyParenT2 transparent matchgroup=groovyParen2 start="(" end=")" contains=@groovyTop,groovyParenT  contained
syn match   groovyParenError       ")"
hi def link groovyParenError       groovyError

" catch errors caused by wrong square parenthesis
syn region  groovyParenT  transparent matchgroup=groovyParen  start="\["  end="\]" contains=@groovyTop,groovyParenT1
syn region  groovyParenT1 transparent matchgroup=groovyParen1 start="\[" end="\]" contains=@groovyTop,groovyParenT2 contained
syn region  groovyParenT2 transparent matchgroup=groovyParen2 start="\[" end="\]" contains=@groovyTop,groovyParenT  contained
syn match   groovyParenError       "\]"

" ###############################
" java.vim default highlighting
hi def link groovyFuncDef		Function
hi def link groovyBraces		Function
hi def link groovyBranch		Conditional
hi def link groovyUserLabelRef	groovyUserLabel
hi def link groovyLabel		Label
hi def link groovyUserLabel		Label
hi def link groovyConditional	Conditional
hi def link groovyRepeat		Repeat
hi def link groovyExceptions		Exception
hi def link groovyAssert 		Statement
hi def link groovyStorageClass	StorageClass
hi def link groovyMethodDecl		groovyStorageClass
hi def link groovyClassDecl		groovyStorageClass
hi def link groovyScopeDecl		groovyStorageClass
hi def link groovyBoolean		Boolean
hi def link groovySpecial		Special
hi def link groovySpecialError	Error
hi def link groovySpecialCharError	Error
hi def link groovyString		String
hi def link groovyRegexChar		String
hi def link groovyCharacter		Character
hi def link groovySpecialChar	SpecialChar
hi def link groovyNumber		Number
hi def link groovyError		Error
hi def link groovyStringError	Error
hi def link groovyStatement		Statement
hi def link groovyOperator		Operator
hi def link groovyComment		Comment
hi def link groovyDocComment		Comment
hi def link groovyLineComment	Comment
hi def link groovyConstant		Constant
hi def link groovyTypedef		Typedef
hi def link groovyTodo		Todo

hi def link groovyCommentTitle	SpecialComment
hi def link groovyDocTags		Special
hi def link groovyDocParam		Function
hi def link groovyCommentStar	groovyComment

hi def link groovyType		Type
hi def link groovyExternal		Include

hi def link htmlComment		Special
hi def link htmlCommentPart		Special
hi def link groovySpaceError		Error
hi def link groovyJDKBuiltin         Special
hi def link groovyJDKOperOverl       Operator
hi def link groovyJDKMethods         Function


let b:current_syntax = "groovy"
if main_syntax == 'groovy'
  unlet main_syntax
endif

let b:spell_options="contained"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
