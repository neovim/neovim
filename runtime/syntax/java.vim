" Vim syntax file
" Language:		Java
" Maintainer:		Aliaksei Budavei <0x000c70 AT gmail DOT com>
" Former Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" Repository:		https://github.com/zzzyxwvut/java-vim.git
" Last Change:		2024 Apr 28

" Please check :help java.vim for comments on some of the options available.

" quit when a syntax file was already loaded
if !exists("main_syntax")
  if exists("b:current_syntax")
    finish
  endif
  " we define it here so that included files can test for it
  let main_syntax='java'
  syn region javaFold start="{" end="}" transparent fold
endif

let s:cpo_save = &cpo
set cpo&vim

" Admit the ASCII dollar sign to keyword characters (JLS-17, §3.8):
execute printf('syntax iskeyword %s,$', &l:iskeyword)

" some characters that cannot be in a java program (outside a string)
syn match javaError "[\\@`]"
syn match javaError "<<<\|\.\.\|=>\|||=\|&&=\|\*\/"

" use separate name so that it can be deleted in javacc.vim
syn match   javaError2 "#\|=<"
hi def link javaError2 javaError

" Keywords (JLS-17, §3.9):
syn keyword javaExternal	native package
syn match   javaExternal	"\<import\>\%(\s\+static\>\)\="
syn keyword javaError		goto const
syn keyword javaConditional	if else switch
syn keyword javaRepeat		while for do
syn keyword javaBoolean		true false
syn keyword javaConstant	null
syn keyword javaTypedef		this super
syn keyword javaOperator	new instanceof
syn match   javaOperator	"\<var\>\%(\s*(\)\@!"
" Since the yield statement, which could take a parenthesised operand,
" and _qualified_ yield methods get along within the switch block
" (JLS-17, §3.8), it seems futile to make a region definition for this
" block; instead look for the _yield_ word alone, and if found,
" backtrack (arbitrarily) 80 bytes, at most, on the matched line and,
" if necessary, on the line before that (h: \@<=), trying to match
" neither a method reference nor a qualified method invocation.
syn match   javaOperator	"\%(\%(::\|\.\)[[:space:]\n]*\)\@80<!\<yield\>"
syn keyword javaType		boolean char byte short int long float double
syn keyword javaType		void
syn keyword javaStatement	return
syn keyword javaStorageClass	static synchronized transient volatile strictfp serializable
syn keyword javaExceptions	throw try catch finally
syn keyword javaAssert		assert
syn keyword javaMethodDecl	throws
" Differentiate a "MyClass.class" literal from the keyword "class".
syn match   javaTypedef		"\.\s*\<class\>"ms=s+1
syn keyword javaClassDecl	enum extends implements interface
syn match   javaClassDecl	"\<permits\>\%(\s*(\)\@!"
syn match   javaClassDecl	"\<record\>\%(\s*(\)\@!"
syn match   javaClassDecl	"^class\>"
syn match   javaClassDecl	"[^.]\s*\<class\>"ms=s+1
syn match   javaAnnotation	"@\%(\K\k*\.\)*\K\k*\>"
syn match   javaClassDecl	"@interface\>"
syn keyword javaBranch		break continue nextgroup=javaUserLabelRef skipwhite
syn match   javaUserLabelRef	"\k\+" contained
syn match   javaVarArg		"\.\.\."
syn keyword javaScopeDecl	public protected private
syn keyword javaConceptKind	abstract final
syn match   javaConceptKind	"\<non-sealed\>"
syn match   javaConceptKind	"\<sealed\>\%(\s*(\)\@!"
syn match   javaConceptKind	"\<default\>\%(\s*\%(:\|->\)\)\@!"

" Note that a "module-info" file will be recognised with an arbitrary
" file extension (or no extension at all) so that more than one such
" declaration for the same Java module can be maintained for modular
" testing in a project without attendant confusion for IDEs, with the
" ".java\=" extension used for a production version and an arbitrary
" extension used for a testing version.
let s:module_info_cur_buf = fnamemodify(bufname("%"), ":t") =~ '^module-info\%(\.class\>\)\@!'
let s:selectable_regexp_engine = !(v:version < 704)
lockvar s:selectable_regexp_engine s:module_info_cur_buf

" Java modules (since Java 9, for "module-info.java" file).
if s:module_info_cur_buf
  syn keyword javaModuleStorageClass	module transitive
  syn keyword javaModuleStmt		open requires exports opens uses provides
  syn keyword javaModuleExternal	to with
  syn cluster javaTop add=javaModuleStorageClass,javaModuleStmt,javaModuleExternal
endif

if exists("java_highlight_java_lang_ids")
  let java_highlight_all=1
endif
if exists("java_highlight_all")  || exists("java_highlight_java")  || exists("java_highlight_java_lang")
  " java.lang.*
  "
  " The keywords of javaR_JavaLang, javaC_JavaLang, javaE_JavaLang,
  " and javaX_JavaLang are sub-grouped according to the Java version
  " of their introduction, and sub-group keywords (that is, class
  " names) are arranged in alphabetical order, so that future newer
  " keywords can be pre-sorted and appended without disturbing
  " the current keyword placement. The below _match_es follow suit.

  syn keyword javaR_JavaLang ArithmeticException ArrayIndexOutOfBoundsException ArrayStoreException ClassCastException IllegalArgumentException IllegalMonitorStateException IllegalThreadStateException IndexOutOfBoundsException NegativeArraySizeException NullPointerException NumberFormatException RuntimeException SecurityException StringIndexOutOfBoundsException IllegalStateException UnsupportedOperationException EnumConstantNotPresentException TypeNotPresentException IllegalCallerException LayerInstantiationException WrongThreadException MatchException
  syn cluster javaTop add=javaR_JavaLang
  syn cluster javaClasses add=javaR_JavaLang
  hi def link javaR_JavaLang javaR_Java
  " Member enumerations:
  syn match   javaC_JavaLang "\%(\<Thread\.\)\@<=\<State\>"
  syn match   javaC_JavaLang "\%(\<Character\.\)\@<=\<UnicodeScript\>"
  syn match   javaC_JavaLang "\%(\<ProcessBuilder\.Redirect\.\)\@<=\<Type\>"
  syn match   javaC_JavaLang "\%(\<StackWalker\.\)\@<=\<Option\>"
  syn match   javaC_JavaLang "\%(\<System\.Logger\.\)\@<=\<Level\>"
  " Member classes:
  syn match   javaC_JavaLang "\%(\<Character\.\)\@<=\<Subset\>"
  syn match   javaC_JavaLang "\%(\<Character\.\)\@<=\<UnicodeBlock\>"
  syn match   javaC_JavaLang "\%(\<ProcessBuilder\.\)\@<=\<Redirect\>"
  syn match   javaC_JavaLang "\%(\<ModuleLayer\.\)\@<=\<Controller\>"
  syn match   javaC_JavaLang "\%(\<Runtime\.\)\@<=\<Version\>"
  syn match   javaC_JavaLang "\%(\<System\.\)\@<=\<LoggerFinder\>"
  syn match   javaC_JavaLang "\%(\<Enum\.\)\@<=\<EnumDesc\>"
  syn keyword javaC_JavaLang Boolean Character Class ClassLoader Compiler Double Float Integer Long Math Number Object Process Runtime SecurityManager String StringBuffer Thread ThreadGroup Byte Short Void InheritableThreadLocal Package RuntimePermission ThreadLocal StrictMath StackTraceElement Enum ProcessBuilder StringBuilder ClassValue Module ModuleLayer StackWalker Record
  syn match   javaC_JavaLang "\<System\>"	" See javaDebug.
  " As of JDK 21, java.lang.Compiler is no more (deprecated in JDK 9).
  syn keyword javaLangDeprecated Compiler
  syn cluster javaTop add=javaC_JavaLang
  syn cluster javaClasses add=javaC_JavaLang
  hi def link javaC_JavaLang javaC_Java
  syn keyword javaE_JavaLang AbstractMethodError ClassCircularityError ClassFormatError Error IllegalAccessError IncompatibleClassChangeError InstantiationError InternalError LinkageError NoClassDefFoundError NoSuchFieldError NoSuchMethodError OutOfMemoryError StackOverflowError ThreadDeath UnknownError UnsatisfiedLinkError VerifyError VirtualMachineError ExceptionInInitializerError UnsupportedClassVersionError AssertionError BootstrapMethodError
  syn cluster javaTop add=javaE_JavaLang
  syn cluster javaClasses add=javaE_JavaLang
  hi def link javaE_JavaLang javaE_Java
  syn keyword javaX_JavaLang ClassNotFoundException CloneNotSupportedException Exception IllegalAccessException InstantiationException InterruptedException NoSuchMethodException Throwable NoSuchFieldException ReflectiveOperationException
  syn cluster javaTop add=javaX_JavaLang
  syn cluster javaClasses add=javaX_JavaLang
  hi def link javaX_JavaLang javaX_Java

  hi def link javaR_Java javaR_
  hi def link javaC_Java javaC_
  hi def link javaE_Java javaE_
  hi def link javaX_Java javaX_
  hi def link javaX_		     javaExceptions
  hi def link javaR_		     javaExceptions
  hi def link javaE_		     javaExceptions
  hi def link javaC_		     javaConstant

  syn keyword javaLangObject clone equals finalize getClass hashCode
  syn keyword javaLangObject notify notifyAll toString wait
  hi def link javaLangObject		     javaConstant
  syn cluster javaTop add=javaLangObject
endif

if filereadable(expand("<sfile>:p:h")."/javaid.vim")
  source <sfile>:p:h/javaid.vim
endif

if exists("java_space_errors")
  if !exists("java_no_trail_space_error")
    syn match	javaSpaceError	"\s\+$"
  endif
  if !exists("java_no_tab_space_error")
    syn match	javaSpaceError	" \+\t"me=e-1
  endif
endif

syn match   javaUserLabel	"^\s*\<\K\k*\>\%(\<default\>\)\@<!\s*:"he=e-1
syn region  javaLabelRegion	transparent matchgroup=javaLabel start="\<case\>" matchgroup=NONE end=":\|->" contains=javaLabelCastType,javaLabelNumber,javaCharacter,javaString,javaConstant,@javaClasses,javaLabelDefault,javaLabelVarType,javaLabelWhenClause
syn region  javaLabelRegion	transparent matchgroup=javaLabel start="\<default\>\%(\s*\%(:\|->\)\)\@=" matchgroup=NONE end=":\|->" oneline
" Consider grouped _default_ _case_ labels, i.e.
" case null, default ->
" case null: default:
syn keyword javaLabelDefault	contained default
syn keyword javaLabelVarType	contained var
syn keyword javaLabelCastType	contained char byte short int
" Allow for the contingency of the enclosing region not being able to
" _keep_ its _end_, e.g. case ':':.
syn region  javaLabelWhenClause	contained transparent matchgroup=javaLabel start="\<when\>" matchgroup=NONE end=":"me=e-1 end="->"me=e-2 contains=TOP,javaExternal
syn match   javaLabelNumber	contained "\<0\>[lL]\@!"
syn match   javaLabelNumber	contained "\<\%(0\%([xX]\x\%(_*\x\)*\|_*\o\%(_*\o\)*\|[bB][01]\%(_*[01]\)*\)\|[1-9]\%(_*\d\)*\)\>[lL]\@!"
hi def link javaLabelDefault	javaLabel
hi def link javaLabelVarType	javaOperator
hi def link javaLabelNumber	javaNumber
hi def link javaLabelCastType	javaType

" highlighting C++ keywords as errors removed, too many people find it
" annoying.  Was: if !exists("java_allow_cpp_keywords")

" The following cluster contains all java groups except the contained ones
syn cluster javaTop add=javaExternal,javaError,javaBranch,javaLabelRegion,javaConditional,javaRepeat,javaBoolean,javaConstant,javaTypedef,javaOperator,javaType,javaStatement,javaStorageClass,javaAssert,javaExceptions,javaMethodDecl,javaClassDecl,javaScopeDecl,javaConceptKind,javaError2,javaUserLabel,javaLangObject,javaAnnotation,javaVarArg


" Comments
syn keyword javaTodo		 contained TODO FIXME XXX

if exists("java_comment_strings")
  syn region  javaCommentString    contained start=+"+ end=+"+ end=+$+ end=+\*/+me=s-1,he=s-1 contains=javaSpecial,javaCommentStar,javaSpecialChar,@Spell
  syn region  javaCommentString    contained start=+"""[ \t\x0c\r]*$+hs=e+1 end=+"""+he=s-1 contains=javaSpecial,javaCommentStar,javaSpecialChar,@Spell,javaSpecialError,javaTextBlockError
  syn region  javaComment2String   contained start=+"+ end=+$\|"+ contains=javaSpecial,javaSpecialChar,@Spell
  syn match   javaCommentCharacter contained "'\\[^']\{1,6\}'" contains=javaSpecialChar
  syn match   javaCommentCharacter contained "'\\''" contains=javaSpecialChar
  syn match   javaCommentCharacter contained "'[^\\]'"
  syn cluster javaCommentSpecial add=javaCommentString,javaCommentCharacter,javaNumber,javaStrTempl
  syn cluster javaCommentSpecial2 add=javaComment2String,javaCommentCharacter,javaNumber,javaStrTempl
endif

syn region  javaComment		matchgroup=javaCommentStart start="/\*" end="\*/" contains=@javaCommentSpecial,javaTodo,javaCommentError,javaSpaceError,@Spell
syn match   javaCommentStar	 contained "^\s*\*[^/]"me=e-1
syn match   javaCommentStar	 contained "^\s*\*$"
syn match   javaLineComment	"//.*" contains=@javaCommentSpecial2,javaTodo,javaCommentMarkupTag,javaSpaceError,@Spell
syn match   javaCommentMarkupTag contained "@\%(end\|highlight\|link\|replace\|start\)\>" nextgroup=javaCommentMarkupTagAttr,javaSpaceError skipwhite
syn match   javaCommentMarkupTagAttr contained "\<region\>" nextgroup=javaCommentMarkupTagAttr,javaSpaceError skipwhite
syn region  javaCommentMarkupTagAttr contained transparent matchgroup=htmlArg start=/\<\%(re\%(gex\|gion\|placement\)\|substring\|t\%(arget\|ype\)\)\%(\s*=\)\@=/ matchgroup=htmlString end=/\%(=\s*\)\@<=\%("[^"]\+"\|'[^']\+'\|\%([.-]\|\k\)\+\)/ nextgroup=javaCommentMarkupTagAttr,javaSpaceError skipwhite oneline
hi def link javaCommentMarkupTagAttr htmlArg
hi def link javaCommentString javaString
hi def link javaComment2String javaString
hi def link javaCommentCharacter javaCharacter
syn match   javaCommentError contained "/\*"me=e-1 display
hi def link javaCommentError javaError
hi def link javaCommentStart javaComment

syn cluster javaTop add=javaComment,javaLineComment

if !exists("java_ignore_javadoc") && main_syntax != 'jsp'
  syntax case ignore
  " syntax coloring for javadoc comments (HTML)
  syntax include @javaHtml syntax/html.vim
  unlet b:current_syntax
  " HTML enables spell checking for all text that is not in a syntax item. This
  " is wrong for Java (all identifiers would be spell-checked), so it's undone
  " here.
  syntax spell default

  syn region javaDocComment	start="/\*\*" end="\*/" keepend contains=javaCommentTitle,@javaHtml,javaDocTags,javaDocSeeTag,javaDocCodeTag,javaDocSnippetTag,javaTodo,javaCommentError,javaSpaceError,@Spell
  syn region javaCommentTitle	contained matchgroup=javaDocComment start="/\*\*" matchgroup=javaCommentTitle end="\.$" end="\.[ \t\r]\@=" end="\%(^\s*\**\s*\)\@<=@"me=s-2,he=s-1 end="\*/"me=s-1,he=s-1 contains=@javaHtml,javaCommentStar,javaTodo,javaCommentError,javaSpaceError,@Spell,javaDocTags,javaDocSeeTag,javaDocCodeTag,javaDocSnippetTag
  syn region javaCommentTitle	contained matchgroup=javaDocComment start="/\*\*\s*\r\=\n\=\s*\**\s*\%({@return\>\)\@=" matchgroup=javaCommentTitle end="}\%(\s*\.*\)*" contains=@javaHtml,javaCommentStar,javaTodo,javaCommentError,javaSpaceError,@Spell,javaDocTags,javaDocSeeTag,javaDocCodeTag,javaDocSnippetTag
  syn region javaDocTags	contained start="{@\%(li\%(teral\|nk\%(plain\)\=\)\|inherit[Dd]oc\|doc[rR]oot\|value\)\>" end="}"
  syn match  javaDocTags	contained "@\%(param\|exception\|throws\|since\)\s\+\S\+" contains=javaDocParam
  syn match  javaDocParam	contained "\s\S\+"
  syn match  javaDocTags	contained "@\%(version\|author\|return\|deprecated\|serial\%(Field\|Data\)\=\)\>"
  syn region javaDocSeeTag	contained matchgroup=javaDocTags start="@see\s\+" matchgroup=NONE end="\_."re=e-1 contains=javaDocSeeTagParam
  syn match  javaDocSeeTagParam	contained @"\_[^"]\+"\|<a\s\+\_.\{-}</a>\|\%(\k\|\.\)*\%(#\k\+\%((\_[^)]*)\)\=\)\=@ contains=@javaHtml extend
  syn region javaCodeSkipBlock	contained transparent start="{\%(@code\>\)\@!" end="}" contains=javaCodeSkipBlock,javaDocCodeTag
  syn region javaDocCodeTag	contained start="{@code\>" end="}" contains=javaDocCodeTag,javaCodeSkipBlock
  syn region javaDocSnippetTagAttr contained transparent matchgroup=htmlArg start=/\<\%(class\|file\|id\|lang\|region\)\%(\s*=\)\@=/ matchgroup=htmlString end=/:$/ end=/\%(=\s*\)\@<=\%("[^"]\+"\|'[^']\+'\|\%([.\\/-]\|\k\)\+\)/ nextgroup=javaDocSnippetTagAttr skipwhite skipnl
  syn region javaSnippetSkipBlock contained transparent start="{\%(@snippet\>\)\@!" end="}" contains=javaSnippetSkipBlock,javaDocSnippetTag,javaCommentMarkupTag
  syn region javaDocSnippetTag	contained start="{@snippet\>" end="}" contains=javaDocSnippetTag,javaSnippetSkipBlock,javaDocSnippetTagAttr,javaCommentMarkupTag
  syntax case match
endif

" match the special comment /**/
syn match   javaComment		 "/\*\*/"

" Strings and constants
syn match   javaSpecialError	 contained "\\."
syn match   javaSpecialCharError contained "[^']"
" Escape Sequences (JLS-17, §3.10.7):
syn match   javaSpecialChar	 contained "\\\%(u\x\x\x\x\|[0-3]\o\o\|\o\o\=\|[bstnfr"'\\]\)"
syn region  javaString		start=+"+ end=+"+ end=+$+ contains=javaSpecialChar,javaSpecialError,@Spell
syn region  javaString		start=+"""[ \t\x0c\r]*$+hs=e+1 end=+"""+he=s-1 contains=javaSpecialChar,javaSpecialError,javaTextBlockError,@Spell
syn match   javaTextBlockError	+"""\s*"""+
syn region  javaStrTemplEmbExp	 contained matchgroup=javaStrTempl start="\\{" end="}" contains=TOP
syn region  javaStrTempl	 start=+\%(\.[[:space:]\n]*\)\@<="+ end=+"+ contains=javaStrTemplEmbExp,javaSpecialChar,javaSpecialError,@Spell
syn region  javaStrTempl	 start=+\%(\.[[:space:]\n]*\)\@<="""[ \t\x0c\r]*$+hs=e+1 end=+"""+he=s-1 contains=javaStrTemplEmbExp,javaSpecialChar,javaSpecialError,javaTextBlockError,@Spell
" The next line is commented out, it can cause a crash for a long line
"syn match   javaStringError	  +"\%([^"\\]\|\\.\)*$+
syn match   javaCharacter	 "'[^']*'" contains=javaSpecialChar,javaSpecialCharError
syn match   javaCharacter	 "'\\''" contains=javaSpecialChar
syn match   javaCharacter	 "'[^\\]'"
" Integer literals (JLS-17, §3.10.1):
syn keyword javaNumber		 0 0l 0L
syn match   javaNumber		 "\<\%(0\%([xX]\x\%(_*\x\)*\|_*\o\%(_*\o\)*\|[bB][01]\%(_*[01]\)*\)\|[1-9]\%(_*\d\)*\)[lL]\=\>"
" Decimal floating-point literals (JLS-17, §3.10.2):
" Against "\<\d\+\>\.":
syn match   javaNumber		 "\<\d\%(_*\d\)*\."
syn match   javaNumber		 "\%(\<\d\%(_*\d\)*\.\%(\d\%(_*\d\)*\)\=\|\.\d\%(_*\d\)*\)\%([eE][-+]\=\d\%(_*\d\)*\)\=[fFdD]\=\>"
syn match   javaNumber		 "\<\d\%(_*\d\)*[eE][-+]\=\d\%(_*\d\)*[fFdD]\=\>"
syn match   javaNumber		 "\<\d\%(_*\d\)*\%([eE][-+]\=\d\%(_*\d\)*\)\=[fFdD]\>"
" Hexadecimal floating-point literals (JLS-17, §3.10.2):
syn match   javaNumber		 "\<0[xX]\%(\x\%(_*\x\)*\.\=\|\%(\x\%(_*\x\)*\)\=\.\x\%(_*\x\)*\)[pP][-+]\=\d\%(_*\d\)*[fFdD]\=\>"

" Unicode characters
syn match   javaSpecial "\\u\x\x\x\x"

syn cluster javaTop add=javaString,javaStrTempl,javaCharacter,javaNumber,javaSpecial,javaStringError,javaTextBlockError

" Method declarations (JLS-17, §8.4.3, §8.4.4, §9.4).
if exists("java_highlight_functions")
  syn cluster javaFuncParams contains=javaAnnotation,@javaClasses,javaType,javaVarArg,javaComment,javaLineComment

  if java_highlight_functions =~# '^indent[1-8]\=$'
    let s:last = java_highlight_functions[-1 :]
    let s:indent = s:last != 't' ? repeat("\x20", s:last) : "\t"
    syn cluster javaFuncParams add=javaScopeDecl,javaConceptKind,javaStorageClass,javaExternal
    " Try to not match other type members, initialiser blocks, enum
    " constants (JLS-17, §8.9.1), and constructors (JLS-17, §8.1.7):
    " at any _conventional_ indentation, skip over all fields with
    " "[^=]*", all records with "\<record\s", and let the "*Skip*"
    " definitions take care of constructor declarations and enum
    " constants (with no support for @Foo(value = "bar")).
    exec 'syn region javaFuncDef start=+^' . s:indent . '\%(<[^>]\+>\+\s\+\|\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)\+\)\=\%(\<\K\k*\>\.\)*\K\k*\>[^=]*\%(\<record\)\@6<!\s\K\k*\s*(+ end=+)+ contains=@javaFuncParams'
    " As long as package-private constructors cannot be matched with
    " javaFuncDef, do not look with javaConstructorSkipDeclarator for
    " them.
    exec 'syn match javaConstructorSkipDeclarator transparent +^' . s:indent . '\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)*p\%(ublic\|rotected\|rivate\)\s\+\%(<[^>]\+>\+\s\+\)\=\K\k*\s*\ze(+ contains=javaAnnotation,javaScopeDecl'
    exec 'syn match javaEnumSkipArgumentativeConstant transparent +^' . s:indent . '\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)*\K\k*\s*\ze(+ contains=javaAnnotation'
    unlet s:indent s:last
  else
    " This is the "style" variant (:help ft-java-syntax).
    syn cluster javaFuncParams add=javaScopeDecl,javaConceptKind,javaStorageClass,javaExternal

    " Match arbitrarily indented camelCasedName method declarations.
    " Match: [@ɐ] [abstract] [<α, β>] Τʬ[<γ>][[][]] μʭʭ(/* ... */);

    if s:selectable_regexp_engine
      " Request the new regexp engine for [:upper:] and [:lower:].
      syn region javaFuncDef start=/\%#=2^\s\+\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)*\%(p\%(ublic\|rotected\|rivate\)\s\+\)\=\%(\%(abstract\|default\)\s\+\|\%(\%(final\|\%(native\|strictfp\)\|s\%(tatic\|ynchronized\)\)\s\+\)*\)\=\%(<.*[[:space:]-]\@1<!>\s\+\)\=\%(void\|\%(b\%(oolean\|yte\)\|char\|short\|int\|long\|float\|double\|\%(\<\K\k*\>\.\)*\<[$_[:upper:]]\k*\>\%(<[^(){}]*[[:space:]-]\@1<!>\)\=\)\%(\[\]\)*\)\s\+\<[$_[:lower:]]\k*\>\s*(/ end=/)/ skip=/\/\*.\{-}\*\/\|\/\/.*$/ contains=@javaFuncParams
    else
      " XXX: \C\<[^a-z0-9]\k*\> rejects "type", but matches "τύπος".
      " XXX: \C\<[^A-Z0-9]\k*\> rejects "Method", but matches "Μέθοδος".
      syn region javaFuncDef start=/^\s\+\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)*\%(p\%(ublic\|rotected\|rivate\)\s\+\)\=\%(\%(abstract\|default\)\s\+\|\%(\%(final\|\%(native\|strictfp\)\|s\%(tatic\|ynchronized\)\)\s\+\)*\)\=\%(<.*[[:space:]-]\@1<!>\s\+\)\=\%(void\|\%(b\%(oolean\|yte\)\|char\|short\|int\|long\|float\|double\|\%(\<\K\k*\>\.\)*\<[^a-z0-9]\k*\>\%(<[^(){}]*[[:space:]-]\@1<!>\)\=\)\%(\[\]\)*\)\s\+\<[^A-Z0-9]\k*\>\s*(/ end=/)/ skip=/\/\*.\{-}\*\/\|\/\/.*$/ contains=@javaFuncParams
    endif
  endif

  syn match   javaLambdaDef "\<\K\k*\>\%(\<default\>\)\@<!\s*->"
  syn match  javaBraces  "[{}]"
  syn cluster javaTop add=javaFuncDef,javaBraces,javaLambdaDef
endif

if exists("java_highlight_debug")
  " Strings and constants
  syn match   javaDebugSpecial		contained "\\\%(u\x\x\x\x\|[0-3]\o\o\|\o\o\=\|[bstnfr"'\\]\)"
  syn region  javaDebugString		contained start=+"+  end=+"+  contains=javaDebugSpecial
  syn region  javaDebugString		contained start=+"""[ \t\x0c\r]*$+hs=e+1 end=+"""+he=s-1 contains=javaDebugSpecial,javaDebugTextBlockError
  " The highlight groups of java{StrTempl,Debug{,Paren,StrTempl}}\,
  " share one colour by default. Do not conflate unrelated parens.
  syn region  javaDebugStrTemplEmbExp	contained matchgroup=javaDebugStrTempl start="\\{" end="}" contains=javaComment,javaLineComment,javaDebug\%(Paren\)\@!.*
  syn region  javaDebugStrTempl		contained start=+\%(\.[[:space:]\n]*\)\@<="+ end=+"+ contains=javaDebugStrTemplEmbExp,javaDebugSpecial
  syn region  javaDebugStrTempl		contained start=+\%(\.[[:space:]\n]*\)\@<="""[ \t\x0c\r]*$+hs=e+1 end=+"""+he=s-1 contains=javaDebugStrTemplEmbExp,javaDebugSpecial,javaDebugTextBlockError
  " The next line is commented out, it can cause a crash for a long line
" syn match   javaDebugStringError	contained +"\%([^"\\]\|\\.\)*$+
  syn match   javaDebugTextBlockError	contained +"""\s*"""+
  syn match   javaDebugCharacter	contained "'[^\\]'"
  syn match   javaDebugSpecialCharacter contained "'\\.'"
  syn match   javaDebugSpecialCharacter contained "'\\''"
  syn keyword javaDebugNumber		contained 0 0l 0L
  syn match   javaDebugNumber		contained "\<\d\%(_*\d\)*\."
  syn match   javaDebugNumber		contained "\<\%(0\%([xX]\x\%(_*\x\)*\|_*\o\%(_*\o\)*\|[bB][01]\%(_*[01]\)*\)\|[1-9]\%(_*\d\)*\)[lL]\=\>"
  syn match   javaDebugNumber		contained "\%(\<\d\%(_*\d\)*\.\%(\d\%(_*\d\)*\)\=\|\.\d\%(_*\d\)*\)\%([eE][-+]\=\d\%(_*\d\)*\)\=[fFdD]\=\>"
  syn match   javaDebugNumber		contained "\<\d\%(_*\d\)*[eE][-+]\=\d\%(_*\d\)*[fFdD]\=\>"
  syn match   javaDebugNumber		contained "\<\d\%(_*\d\)*\%([eE][-+]\=\d\%(_*\d\)*\)\=[fFdD]\>"
  syn match   javaDebugNumber		contained "\<0[xX]\%(\x\%(_*\x\)*\.\=\|\%(\x\%(_*\x\)*\)\=\.\x\%(_*\x\)*\)[pP][-+]\=\d\%(_*\d\)*[fFdD]\=\>"
  syn keyword javaDebugBoolean		contained true false
  syn keyword javaDebugType		contained null this super
  syn region javaDebugParen  start=+(+ end=+)+ contained contains=javaDebug.*,javaDebugParen

  " To make this work, define the highlighting for these groups.
  syn match javaDebug "\<System\.\%(out\|err\)\.print\%(ln\)\=\s*("me=e-1 contains=javaDebug.* nextgroup=javaDebugParen
" FIXME: What API does "p" belong to?
" syn match javaDebug "\<p\s*("me=e-1 contains=javaDebug.* nextgroup=javaDebugParen
  syn match javaDebug "\<\K\k*\.printStackTrace\s*("me=e-1 contains=javaDebug.* nextgroup=javaDebugParen
" FIXME: What API do "trace*" belong to?
" syn match javaDebug "\<trace[SL]\=\s*("me=e-1 contains=javaDebug.* nextgroup=javaDebugParen

  syn cluster javaTop add=javaDebug

  hi def link javaDebug		 Debug
  hi def link javaDebugString		 DebugString
  hi def link javaDebugStrTempl		 Macro
  hi def link javaDebugStringError	 javaError
  hi def link javaDebugTextBlockError	 javaDebugStringError
  hi def link javaDebugType		 DebugType
  hi def link javaDebugBoolean		 DebugBoolean
  hi def link javaDebugNumber		 Debug
  hi def link javaDebugSpecial		 DebugSpecial
  hi def link javaDebugSpecialCharacter DebugSpecial
  hi def link javaDebugCharacter	 DebugString
  hi def link javaDebugParen		 Debug

  hi def link DebugString		 String
  hi def link DebugSpecial		 Special
  hi def link DebugBoolean		 Boolean
  hi def link DebugType		 Type
endif

if exists("java_mark_braces_in_parens_as_errors")
  syn match javaInParen		 contained "[{}]"
  hi def link javaInParen	javaError
  syn cluster javaTop add=javaInParen
endif

" catch errors caused by wrong parenthesis
syn region  javaParenT	transparent matchgroup=javaParen  start="(" end=")" contains=@javaTop,javaParenT1
syn region  javaParenT1 transparent matchgroup=javaParen1 start="(" end=")" contains=@javaTop,javaParenT2 contained
syn region  javaParenT2 transparent matchgroup=javaParen2 start="(" end=")" contains=@javaTop,javaParenT  contained
syn match   javaParenError	 ")"
" catch errors caused by wrong square parenthesis
syn region  javaParenT	transparent matchgroup=javaParen  start="\[" end="\]" contains=@javaTop,javaParenT1
syn region  javaParenT1 transparent matchgroup=javaParen1 start="\[" end="\]" contains=@javaTop,javaParenT2 contained
syn region  javaParenT2 transparent matchgroup=javaParen2 start="\[" end="\]" contains=@javaTop,javaParenT  contained
syn match   javaParenError	 "\]"

hi def link javaParenError	javaError

if exists("java_highlight_functions")
  " Make ()-matching definitions after the parenthesis error catcher.
  syn match javaLambdaDef "\k\@4<!(\%(\k\|[[:space:]<>?\[\]@,.]\)*)\s*->"
endif

if !exists("java_minlines")
  let java_minlines = 10
endif

" Note that variations of a /*/ balanced comment, e.g., /*/*/, /*//*/,
" /* /*/, /*  /*/, etc., may have their rightmost /*/ part accepted
" as a comment start by ':syntax sync ccomment'; consider alternatives
" to make synchronisation start further towards file's beginning by
" bumping up g:java_minlines or issuing ':syntax sync fromstart' or
" preferring &foldmethod set to 'syntax'.
exec "syn sync ccomment javaComment minlines=" . java_minlines

" The default highlighting.
hi def link javaLambdaDef		Function
hi def link javaFuncDef		Function
hi def link javaVarArg			Function
hi def link javaBraces			Function
hi def link javaBranch			Conditional
hi def link javaUserLabelRef		javaUserLabel
hi def link javaLabel			Label
hi def link javaUserLabel		Label
hi def link javaConditional		Conditional
hi def link javaRepeat			Repeat
hi def link javaExceptions		Exception
hi def link javaAssert			Statement
hi def link javaStorageClass		StorageClass
hi def link javaMethodDecl		javaStorageClass
hi def link javaClassDecl		javaStorageClass
hi def link javaScopeDecl		javaStorageClass
hi def link javaConceptKind		NonText

hi def link javaBoolean		Boolean
hi def link javaSpecial		Special
hi def link javaSpecialError		Error
hi def link javaSpecialCharError	Error
hi def link javaString			String
hi def link javaStrTempl		Macro
hi def link javaCharacter		Character
hi def link javaSpecialChar		SpecialChar
hi def link javaNumber			Number
hi def link javaError			Error
hi def link javaStringError		Error
hi def link javaTextBlockError		javaStringError
hi def link javaStatement		Statement
hi def link javaOperator		Operator
hi def link javaComment		Comment
hi def link javaDocComment		Comment
hi def link javaLineComment		Comment
hi def link javaConstant		Constant
hi def link javaTypedef		Typedef
hi def link javaTodo			Todo
hi def link javaAnnotation		PreProc

hi def link javaCommentTitle		SpecialComment
hi def link javaDocTags		Special
hi def link javaDocCodeTag		Special
hi def link javaDocSnippetTag		Special
hi def link javaDocParam		Function
hi def link javaDocSeeTagParam		Function
hi def link javaCommentStar		javaComment

hi def link javaType			Type
hi def link javaExternal		Include

hi def link htmlComment		Special
hi def link htmlCommentPart		Special
hi def link htmlArg			Type
hi def link htmlString			String
hi def link javaSpaceError		Error

if s:module_info_cur_buf
  hi def link javaModuleStorageClass	StorageClass
  hi def link javaModuleStmt		Statement
  hi def link javaModuleExternal	Include
endif

let b:current_syntax = "java"

if main_syntax == 'java'
  unlet main_syntax
endif

let b:spell_options = "contained"
let &cpo = s:cpo_save
unlet s:selectable_regexp_engine s:module_info_cur_buf s:cpo_save

" vim: ts=8
