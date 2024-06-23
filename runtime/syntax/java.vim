" Vim syntax file
" Language:		Java
" Maintainer:		Aliaksei Budavei <0x000c70 AT gmail DOT com>
" Former Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" Repository:		https://github.com/zzzyxwvut/java-vim.git
" Last Change:		2024 Jun 22

" Please check :help java.vim for comments on some of the options available.

" quit when a syntax file was already loaded
if !exists("main_syntax")
  if exists("b:current_syntax")
    finish
  endif
  " we define it here so that included files can test for it
  let main_syntax='java'
endif

let s:cpo_save = &cpo
set cpo&vim

"""" STRIVE TO REMAIN COMPATIBLE FOR AT LEAST VIM 7.0.
let s:ff = {}

function! s:ff.LeftConstant(x, y) abort
  return a:x
endfunction

function! s:ff.RightConstant(x, y) abort
  return a:y
endfunction

if !exists("*s:ReportOnce")
  function s:ReportOnce(message) abort
    echomsg 'syntax/java.vim: ' . a:message
  endfunction
else
  function! s:ReportOnce(dummy)
  endfunction
endif

function! JavaSyntaxFoldTextExpr() abort
  return getline(v:foldstart) !~ '/\*\+\s*$'
    \ ? foldtext()
    \ : printf('+-%s%3d lines: ',
	  \ v:folddashes,
	  \ (v:foldend - v:foldstart + 1)) .
	\ getline(v:foldstart + 1)
endfunction

" E120 for "fdt=s:JavaSyntaxFoldTextExpr()" before v8.2.3900.
setlocal foldtext=JavaSyntaxFoldTextExpr()

" Admit the ASCII dollar sign to keyword characters (JLS-17, §3.8):
try
  exec 'syntax iskeyword ' . &l:iskeyword . ',$'
catch /\<E410:/
  call s:ReportOnce(v:exception)
  setlocal iskeyword+=$
endtry

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
try
  syn match   javaOperator	"\%(\%(::\|\.\)[[:space:]\n]*\)\@80<!\<yield\>"
  let s:ff.Peek = s:ff.LeftConstant
catch /\<E59:/
  call s:ReportOnce(v:exception)
  syn match   javaOperator	"\%(\%(::\|\.\)[[:space:]\n]*\)\@<!\<yield\>"
  let s:ff.Peek = s:ff.RightConstant
endtry

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
syn region  javaAnnotation	transparent matchgroup=javaAnnotationStart start=/@\%(\K\k*\.\)*\K\k*(/ end=/)/ skip=/\/\*.\{-}\*\/\|\/\/.*$/ contains=javaAnnotation,javaParenT,javaBlock,javaString,javaBoolean,javaNumber,javaTypedef,javaComment,javaLineComment
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
lockvar s:module_info_cur_buf

if !(v:version < 704)
  " Request the new regexp engine for [:upper:] and [:lower:].
  let [s:ff.Engine, s:ff.UpperCase, s:ff.LowerCase] = repeat([s:ff.LeftConstant], 3)
else
  " XXX: \C\<[^a-z0-9]\k*\> rejects "type", but matches "τύπος".
  " XXX: \C\<[^A-Z0-9]\k*\> rejects "Method", but matches "Μέθοδος".
  let [s:ff.Engine, s:ff.UpperCase, s:ff.LowerCase] = repeat([s:ff.RightConstant], 3)
endif

if exists("java_highlight_signature")
  let [s:ff.PeekTo, s:ff.PeekFrom, s:ff.GroupArgs] = repeat([s:ff.LeftConstant], 3)
else
  let [s:ff.PeekTo, s:ff.PeekFrom, s:ff.GroupArgs] = repeat([s:ff.RightConstant], 3)
endif

" Java modules (since Java 9, for "module-info.java" file).
if s:module_info_cur_buf
  syn keyword javaModuleStorageClass	module transitive
  syn keyword javaModuleStmt		open requires exports opens uses provides
  syn keyword javaModuleExternal	to with
endif

" Fancy parameterised types (JLS-17, §4.5).
"
" Note that false positives may elsewhere occur whenever an identifier
" is butted against a less-than operator.  Cf. (X<Y) and (X < Y).
if exists("java_highlight_generics")
  syn keyword javaWildcardBound contained extends super

  " Parameterised types are delegated to javaGenerics (s:ctx.gsg) and
  " are not matched with javaTypeArgument.
  exec 'syn match javaTypeArgument contained "' . s:ff.Engine('\%#=2', '') . '?\|\%(\<\%(b\%(oolean\|yte\)\|char\|short\|int\|long\|float\|double\)\[\]\|\%(\<\K\k*\>\.\)*\<' . s:ff.UpperCase('[$_[:upper:]]', '[^a-z0-9]') . '\k*\>\)\%(\[\]\)*"'

  for s:ctx in [{'dsg': 'javaDimExpr', 'gsg': 'javaGenerics', 'ghg': 'javaGenericsC1', 'csg': 'javaGenericsX', 'c': ''},
      \ {'dsg': 'javaDimExprX', 'gsg': 'javaGenericsX', 'ghg': 'javaGenericsC2', 'csg': 'javaGenerics', 'c': ' contained'}]
    " Consider array creation expressions of reifiable types.
    exec 'syn region ' . s:ctx.dsg . ' contained transparent matchgroup=' . s:ctx.ghg . ' start="\[" end="\]" nextgroup=' . s:ctx.dsg . ' skipwhite skipnl'
    exec 'syn region ' . s:ctx.gsg . s:ctx.c . ' transparent matchgroup=' . s:ctx.ghg . ' start=/' . s:ff.Engine('\%#=2', '') . '\%(\<\K\k*\>\.\)*\<' . s:ff.UpperCase('[$_[:upper:]]', '[^a-z0-9]') . '\k*\><\%([[:space:]\n]*\%([?@]\|\<\%(b\%(oolean\|yte\)\|char\|short\|int\|long\|float\|double\)\[\]\|\%(\<\K\k*\>\.\)*\<' . s:ff.UpperCase('[$_[:upper:]]', '[^a-z0-9]') . '\k*\>\)\)\@=/ end=/>/ contains=' . s:ctx.csg . ',javaAnnotation,javaTypeArgument,javaWildcardBound,javaType,@javaClasses nextgroup=' . s:ctx.dsg . ' skipwhite skipnl'
  endfor

  unlet s:ctx
  hi def link javaWildcardBound Question
  hi def link javaGenericsC1 javaFuncDef
  hi def link javaGenericsC2 javaType
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
  syn cluster javaClasses add=javaR_JavaLang
  hi def link javaR_JavaLang javaR_Java
  " Member enumerations:
  exec 'syn match javaC_JavaLang "\%(\<Thread\.\)\@' . s:ff.Peek('7', '') . '<=\<State\>"'
  exec 'syn match javaC_JavaLang "\%(\<Character\.\)\@' . s:ff.Peek('10', '') . '<=\<UnicodeScript\>"'
  exec 'syn match javaC_JavaLang "\%(\<ProcessBuilder\.Redirect\.\)\@' . s:ff.Peek('24', '') . '<=\<Type\>"'
  exec 'syn match javaC_JavaLang "\%(\<StackWalker\.\)\@' . s:ff.Peek('12', '') . '<=\<Option\>"'
  exec 'syn match javaC_JavaLang "\%(\<System\.Logger\.\)\@' . s:ff.Peek('14', '') . '<=\<Level\>"'
  " Member classes:
  exec 'syn match javaC_JavaLang "\%(\<Character\.\)\@' . s:ff.Peek('10', '') . '<=\<Subset\>"'
  exec 'syn match javaC_JavaLang "\%(\<Character\.\)\@' . s:ff.Peek('10', '') . '<=\<UnicodeBlock\>"'
  exec 'syn match javaC_JavaLang "\%(\<ProcessBuilder\.\)\@' . s:ff.Peek('15', '') . '<=\<Redirect\>"'
  exec 'syn match javaC_JavaLang "\%(\<ModuleLayer\.\)\@' . s:ff.Peek('12', '') . '<=\<Controller\>"'
  exec 'syn match javaC_JavaLang "\%(\<Runtime\.\)\@' . s:ff.Peek('8', '') . '<=\<Version\>"'
  exec 'syn match javaC_JavaLang "\%(\<System\.\)\@' . s:ff.Peek('7', '') . '<=\<LoggerFinder\>"'
  syn keyword javaC_JavaLang Boolean Character ClassLoader Compiler Double Float Integer Long Math Number Object Process Runtime SecurityManager String StringBuffer Thread ThreadGroup Byte Short Void Package RuntimePermission StrictMath StackTraceElement ProcessBuilder StringBuilder Module ModuleLayer StackWalker Record
  syn match   javaC_JavaLang "\<System\>"	" See javaDebug.

  if !exists("java_highlight_generics")
    " The non-interface parameterised names of java.lang members.
    exec 'syn match javaC_JavaLang "\%(\<Enum\.\)\@' . s:ff.Peek('5', '') . '<=\<EnumDesc\>"'
    syn keyword javaC_JavaLang Class InheritableThreadLocal ThreadLocal Enum ClassValue
  endif

  " As of JDK 21, java.lang.Compiler is no more (deprecated in JDK 9).
  syn keyword javaLangDeprecated Compiler
  syn cluster javaClasses add=javaC_JavaLang
  hi def link javaC_JavaLang javaC_Java
  syn keyword javaE_JavaLang AbstractMethodError ClassCircularityError ClassFormatError Error IllegalAccessError IncompatibleClassChangeError InstantiationError InternalError LinkageError NoClassDefFoundError NoSuchFieldError NoSuchMethodError OutOfMemoryError StackOverflowError ThreadDeath UnknownError UnsatisfiedLinkError VerifyError VirtualMachineError ExceptionInInitializerError UnsupportedClassVersionError AssertionError BootstrapMethodError
  syn cluster javaClasses add=javaE_JavaLang
  hi def link javaE_JavaLang javaE_Java
  syn keyword javaX_JavaLang ClassNotFoundException CloneNotSupportedException Exception IllegalAccessException InstantiationException InterruptedException NoSuchMethodException Throwable NoSuchFieldException ReflectiveOperationException
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

  syn keyword javaLangObject getClass notify notifyAll wait

  " Lower the syntax priority of overridable java.lang.Object method
  " names for zero-width matching (define g:java_highlight_signature
  " and see their base declarations for java.lang.Object):
  syn match javaLangObject "\<clone\>"
  syn match javaLangObject "\<equals\>"
  syn match javaLangObject "\<finalize\>"
  syn match javaLangObject "\<hashCode\>"
  syn match javaLangObject "\<toString\>"
  hi def link javaLangObject javaConstant
endif

if filereadable(expand("<sfile>:p:h") . "/javaid.vim")
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

exec 'syn match javaUserLabel "^\s*\<\K\k*\>\%(\<default\>\)\@' . s:ff.Peek('7', '') . '<!\s*:"he=e-1'
syn region  javaLabelRegion	transparent matchgroup=javaLabel start="\<case\>" matchgroup=NONE end=":\|->" contains=javaLabelCastType,javaLabelNumber,javaCharacter,javaString,javaConstant,@javaClasses,javaGenerics,javaLabelDefault,javaLabelVarType,javaLabelWhenClause
syn region  javaLabelRegion	transparent matchgroup=javaLabel start="\<default\>\%(\s*\%(:\|->\)\)\@=" matchgroup=NONE end=":\|->" oneline
" Consider grouped _default_ _case_ labels, i.e.
" case null, default ->
" case null: default:
syn keyword javaLabelDefault	contained default
syn keyword javaLabelVarType	contained var
syn keyword javaLabelCastType	contained char byte short int
" Allow for the contingency of the enclosing region not being able to
" _keep_ its _end_, e.g. case ':':.
syn region  javaLabelWhenClause	contained transparent matchgroup=javaLabel start="\<when\>" matchgroup=NONE end=":"me=e-1 end="->"me=e-2 contains=TOP,javaExternal,javaLambdaDef
syn match   javaLabelNumber	contained "\<0\>[lL]\@!"
syn match   javaLabelNumber	contained "\<\%(0\%([xX]\x\%(_*\x\)*\|_*\o\%(_*\o\)*\|[bB][01]\%(_*[01]\)*\)\|[1-9]\%(_*\d\)*\)\>[lL]\@!"
hi def link javaLabelDefault	javaLabel
hi def link javaLabelVarType	javaOperator
hi def link javaLabelNumber	javaNumber
hi def link javaLabelCastType	javaType

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

syn region  javaComment		 matchgroup=javaCommentStart start="/\*" end="\*/" contains=@javaCommentSpecial,javaTodo,javaCommentError,javaSpaceError,@Spell fold
syn match   javaCommentStar	 contained "^\s*\*[^/]"me=e-1
syn match   javaCommentStar	 contained "^\s*\*$"
syn match   javaLineComment	"//.*" contains=@javaCommentSpecial2,javaTodo,javaCommentMarkupTag,javaSpaceError,@Spell
syn match   javaCommentMarkupTag contained "@\%(end\|highlight\|link\|replace\|start\)\>" nextgroup=javaCommentMarkupTagAttr,javaSpaceError skipwhite
syn match   javaCommentMarkupTagAttr contained "\<region\>" nextgroup=javaCommentMarkupTagAttr,javaSpaceError skipwhite
exec 'syn region javaCommentMarkupTagAttr contained transparent matchgroup=htmlArg start=/\<\%(re\%(gex\|gion\|placement\)\|substring\|t\%(arget\|ype\)\)\%(\s*=\)\@=/ matchgroup=htmlString end=/\%(=\s*\)\@' . s:ff.Peek('80', '') . '<=\%("[^"]\+"\|' . "\x27[^\x27]\\+\x27" . '\|\%([.-]\|\k\)\+\)/ nextgroup=javaCommentMarkupTagAttr,javaSpaceError skipwhite oneline'
hi def link javaCommentMarkupTagAttr htmlArg
hi def link javaCommentString javaString
hi def link javaComment2String javaString
hi def link javaCommentCharacter javaCharacter
syn match   javaCommentError contained "/\*"me=e-1 display
hi def link javaCommentError javaError
hi def link javaCommentStart javaComment

if !exists("java_ignore_javadoc") && main_syntax != 'jsp'
  syntax case ignore

  " Include HTML syntax coloring for Javadoc comments.
  syntax include @javaHtml syntax/html.vim
  unlet b:current_syntax

  " HTML enables spell checking for all text that is not in a syntax
  " item (:syntax spell toplevel); instead, limit spell checking to
  " items matchable with syntax groups containing the @Spell cluster.
  try
    syntax spell default
  catch /\<E390:/
    call s:ReportOnce(v:exception)
  endtry

  syn region javaDocComment	start="/\*\*" end="\*/" keepend contains=javaCommentTitle,@javaHtml,javaDocTags,javaDocSeeTag,javaDocCodeTag,javaDocSnippetTag,javaTodo,javaCommentError,javaSpaceError,@Spell fold
  exec 'syn region javaCommentTitle contained matchgroup=javaDocComment start="/\*\*" matchgroup=javaCommentTitle end="\.$" end="\.[ \t\r]\@=" end="\%(^\s*\**\s*\)\@' . s:ff.Peek('80', '') . '<=@"me=s-2,he=s-1 end="\*/"me=s-1,he=s-1 contains=@javaHtml,javaCommentStar,javaTodo,javaCommentError,javaSpaceError,@Spell,javaDocTags,javaDocSeeTag,javaDocCodeTag,javaDocSnippetTag'
  syn region javaCommentTitle	contained matchgroup=javaDocComment start="/\*\*\s*\r\=\n\=\s*\**\s*\%({@return\>\)\@=" matchgroup=javaCommentTitle end="}\%(\s*\.*\)*" contains=@javaHtml,javaCommentStar,javaTodo,javaCommentError,javaSpaceError,@Spell,javaDocTags,javaDocSeeTag,javaDocCodeTag,javaDocSnippetTag
  syn region javaDocTags	contained start="{@\%(li\%(teral\|nk\%(plain\)\=\)\|inherit[Dd]oc\|doc[rR]oot\|value\)\>" end="}"
  syn match  javaDocTags	contained "@\%(param\|exception\|throws\|since\)\s\+\S\+" contains=javaDocParam
  syn match  javaDocParam	contained "\s\S\+"
  syn match  javaDocTags	contained "@\%(version\|author\|return\|deprecated\|serial\%(Field\|Data\)\=\)\>"
  syn region javaDocSeeTag	contained matchgroup=javaDocTags start="@see\s\+" matchgroup=NONE end="\_."re=e-1 contains=javaDocSeeTagParam
  syn match  javaDocSeeTagParam	contained @"\_[^"]\+"\|<a\s\+\_.\{-}</a>\|\%(\k\|\.\)*\%(#\k\+\%((\_[^)]*)\)\=\)\=@ contains=@javaHtml extend
  syn region javaCodeSkipBlock	contained transparent start="{\%(@code\>\)\@!" end="}" contains=javaCodeSkipBlock,javaDocCodeTag
  syn region javaDocCodeTag	contained start="{@code\>" end="}" contains=javaDocCodeTag,javaCodeSkipBlock
  exec 'syn region javaDocSnippetTagAttr contained transparent matchgroup=htmlArg start=/\<\%(class\|file\|id\|lang\|region\)\%(\s*=\)\@=/ matchgroup=htmlString end=/:$/ end=/\%(=\s*\)\@' . s:ff.Peek('80', '') . '<=\%("[^"]\+"\|' . "\x27[^\x27]\\+\x27" . '\|\%([.\\/-]\|\k\)\+\)/ nextgroup=javaDocSnippetTagAttr skipwhite skipnl'
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
exec 'syn region javaStrTempl start=+\%(\.[[:space:]\n]*\)\@' . s:ff.Peek('80', '') . '<="+ end=+"+ contains=javaStrTemplEmbExp,javaSpecialChar,javaSpecialError,@Spell'
exec 'syn region javaStrTempl start=+\%(\.[[:space:]\n]*\)\@' . s:ff.Peek('80', '') . '<="""[ \t\x0c\r]*$+hs=e+1 end=+"""+he=s-1 contains=javaStrTemplEmbExp,javaSpecialChar,javaSpecialError,javaTextBlockError,@Spell'
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

" Method declarations (JLS-17, §8.4.3, §8.4.4, §9.4).
if exists("java_highlight_functions")
  syn cluster javaFuncParams contains=javaAnnotation,@javaClasses,javaGenerics,javaType,javaVarArg,javaComment,javaLineComment

  if exists("java_highlight_signature")
    syn keyword javaParamModifier contained final
    syn cluster javaFuncParams add=javaParamModifier
    hi def link javaParamModifier javaConceptKind
    hi def link javaFuncDefStart javaFuncDef
  else
    syn cluster javaFuncParams add=javaScopeDecl,javaConceptKind,javaStorageClass,javaExternal
  endif

  if java_highlight_functions =~# '^indent[1-8]\=$'
    let s:last = java_highlight_functions[-1 :]
    let s:indent = s:last != 't' ? repeat("\x20", s:last) : "\t"
    " Try to not match other type members, initialiser blocks, enum
    " constants (JLS-17, §8.9.1), and constructors (JLS-17, §8.1.7):
    " at any _conventional_ indentation, skip over all fields with
    " "[^=]*", all records with "\<record\s", and let the "*Skip*"
    " definitions take care of constructor declarations and enum
    " constants (with no support for @Foo(value = "bar")).  Also,
    " reject inlined declarations with "[^{]" for signature.
    exec 'syn region javaFuncDef ' . s:ff.GroupArgs('transparent matchgroup=javaFuncDefStart', '') . ' start=/' . s:ff.PeekTo('\%(', '') . '^' . s:indent . '\%(<[^>]\+>\+\s\+\|\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)\+\)\=\%(\<\K\k*\>\.\)*\K\k*\>[^={]*\%(\<record\)\@' . s:ff.Peek('6', '') . '<!\s' . s:ff.PeekFrom('\)\@' . s:ff.Peek('80', '') . '<=', '') . '\K\k*\s*(/ end=/)/ contains=@javaFuncParams'
    " As long as package-private constructors cannot be matched with
    " javaFuncDef, do not look with javaConstructorSkipDeclarator for
    " them.
    exec 'syn match javaConstructorSkipDeclarator transparent /^' . s:indent . '\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)*p\%(ublic\|rotected\|rivate\)\s\+\%(<[^>]\+>\+\s\+\)\=\K\k*\s*\ze(/ contains=javaAnnotation,javaScopeDecl,javaClassDecl,javaTypedef,javaGenerics'
    " With a zero-width span for signature applicable on demand to
    " javaFuncDef, make related adjustments:
    " (1) Claim all enum constants of a line as a unit.
    exec 'syn match javaEnumSkipConstant contained transparent /^' . s:indent . '\%(\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)*\K\k*\s*\%((.*)\)\=\s*[,;({]\s*\)\+/ contains=@javaEnumConstants'
    " (2) Define a syntax group for top level enumerations and tell
    " apart their constants from method declarations.
    exec 'syn region javaTopEnumDeclaration transparent start=/\%(^\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)*\%(p\%(ublic\|rotected\|rivate\)\s\+\)\=\%(strictfp\s\+\)\=\<enum\_s\+\)\@' . s:ff.Peek('80', '') . '<=\K\k*\%(\_s\+implements\_s.\+\)\=\_s*{/ end=/}/ contains=@javaTop,javaEnumSkipConstant'
    " (3) Define a base variant of javaParenT without using @javaTop
    " in order to not include javaFuncDef.
    syn region javaParenE transparent matchgroup=javaParen start="(" end=")" contains=@javaEnumConstants,javaInParen
    syn region javaParenE transparent matchgroup=javaParen start="\[" end="\]" contains=@javaEnumConstants
    syn cluster javaEnumConstants contains=TOP,javaTopEnumDeclaration,javaFuncDef,javaParenT
    unlet s:indent s:last
  else
    " This is the "style" variant (:help ft-java-syntax).

    " Match arbitrarily indented camelCasedName method declarations.
    " Match: [@ɐ] [abstract] [<α, β>] Τʬ[<γ>][[][]] μʭʭ(/* ... */);
    exec 'syn region javaFuncDef ' . s:ff.GroupArgs('transparent matchgroup=javaFuncDefStart', '') . ' start=/' . s:ff.Engine('\%#=2', '') . s:ff.PeekTo('\%(', '') . '^\s\+\%(\%(@\%(\K\k*\.\)*\K\k*\>\)\s\+\)*\%(p\%(ublic\|rotected\|rivate\)\s\+\)\=\%(\%(abstract\|default\)\s\+\|\%(\%(final\|\%(native\|strictfp\)\|s\%(tatic\|ynchronized\)\)\s\+\)*\)\=\%(<.*[[:space:]-]\@' . s:ff.Peek('1', '') . '<!>\s\+\)\=\%(void\|\%(b\%(oolean\|yte\)\|char\|short\|int\|long\|float\|double\|\%(\<\K\k*\>\.\)*\<' . s:ff.UpperCase('[$_[:upper:]]', '[^a-z0-9]') . '\k*\>\%(<[^(){}]*[[:space:]-]\@' . s:ff.Peek('1', '') . '<!>\)\=\)\%(\[\]\)*\)\s\+' . s:ff.PeekFrom('\)\@' . s:ff.Peek('80', '') . '<=', '') . '\<' . s:ff.LowerCase('[$_[:lower:]]', '[^A-Z0-9]') . '\k*\>\s*(/ end=/)/ skip=/\/\*.\{-}\*\/\|\/\/.*$/ contains=@javaFuncParams'
  endif
endif

if exists("java_highlight_debug")
  " Strings and constants
  syn match   javaDebugSpecial		contained "\\\%(u\x\x\x\x\|[0-3]\o\o\|\o\o\=\|[bstnfr"'\\]\)"
  syn region  javaDebugString		contained start=+"+  end=+"+  contains=javaDebugSpecial
  syn region  javaDebugString		contained start=+"""[ \t\x0c\r]*$+hs=e+1 end=+"""+he=s-1 contains=javaDebugSpecial,javaDebugTextBlockError
  " The highlight groups of java{StrTempl,Debug{,Paren,StrTempl}}\,
  " share one colour by default. Do not conflate unrelated parens.
  syn region  javaDebugStrTemplEmbExp	contained matchgroup=javaDebugStrTempl start="\\{" end="}" contains=javaComment,javaLineComment,javaDebug\%(Paren\)\@!.*
  exec 'syn region javaDebugStrTempl contained start=+\%(\.[[:space:]\n]*\)\@' . s:ff.Peek('80', '') . '<="+ end=+"+ contains=javaDebugStrTemplEmbExp,javaDebugSpecial'
  exec 'syn region javaDebugStrTempl contained start=+\%(\.[[:space:]\n]*\)\@' . s:ff.Peek('80', '') . '<="""[ \t\x0c\r]*$+hs=e+1 end=+"""+he=s-1 contains=javaDebugStrTemplEmbExp,javaDebugSpecial,javaDebugTextBlockError'
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

  hi def link javaDebug		 Debug
  hi def link javaDebugString		 DebugString
  hi def link javaDebugStrTempl		 Macro
  hi def link javaDebugTextBlockError	 Error
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

" Try not to fold top-level-type bodies under assumption that there is
" but one such body.
exec 'syn region javaBlock transparent start="\%(^\|^\S[^:]\+\)\@' . s:ff.Peek('120', '') . '<!{" end="}" fold'

if exists("java_mark_braces_in_parens_as_errors")
  syn match javaInParen contained "[{}]"
  hi def link javaInParen javaError
endif

" catch errors caused by wrong parenthesis
syn region  javaParenT	transparent matchgroup=javaParen  start="(" end=")" contains=@javaTop,javaInParen,javaParenT1
syn region  javaParenT1 transparent matchgroup=javaParen1 start="(" end=")" contains=@javaTop,javaInParen,javaParenT2 contained
syn region  javaParenT2 transparent matchgroup=javaParen2 start="(" end=")" contains=@javaTop,javaInParen,javaParenT contained
syn match   javaParenError	 ")"
" catch errors caused by wrong square parenthesis
syn region  javaParenT	transparent matchgroup=javaParen  start="\[" end="\]" contains=@javaTop,javaParenT1
syn region  javaParenT1 transparent matchgroup=javaParen1 start="\[" end="\]" contains=@javaTop,javaParenT2 contained
syn region  javaParenT2 transparent matchgroup=javaParen2 start="\[" end="\]" contains=@javaTop,javaParenT  contained
syn match   javaParenError	 "\]"

hi def link javaParenError	javaError

" Lambda expressions (JLS-17, §15.27).
if exists("java_highlight_functions")
  if exists("java_highlight_signature")
    let s:ff.LambdaDef = s:ff.LeftConstant
  else
    let s:ff.LambdaDef = s:ff.RightConstant
  endif

  " Make ()-matching definitions after the parenthesis error catcher.
  "
  " Note that here and elsewhere a single-line token is used for \z,
  " with other tokens repeated as necessary, to overcome the lack of
  " support for multi-line matching with \z.
  "
  " Match: ([@A [@B ...] final] var a[, var b, ...]) ->
  "	| ([@A [@B ...] final] T[<α>][[][]] a[, T b, ...]) ->
  " There is no recognition of expressions interspersed with comments
  " or of expressions whose parameterised parameter types are written
  " across multiple lines.
  exec 'syn ' . s:ff.LambdaDef('region javaLambdaDef transparent matchgroup=javaLambdaDefStart start=/', 'match javaLambdaDef "') . '\k\@' . s:ff.Peek('4', '') . '<!(' . s:ff.LambdaDef('\%(', '') . '[[:space:]\n]*\%(\%(@\%(\K\k*\.\)*\K\k*\>\%((\_.\{-1,})\)\{-,1}[[:space:]\n]\+\)*\%(final[[:space:]\n]\+\)\=\%(\<\K\k*\>\.\)*\<\K\k*\>\%(<[^(){}]*[[:space:]-]\@' . s:ff.Peek('1', '') . '<!>\)\=\%(\%(\%(\[\]\)\+\|\.\.\.\)\)\=[[:space:]\n]\+\<\K\k*\>\%(\[\]\)*\%(,[[:space:]\n]*\)\=\)\+)[[:space:]\n]*' . s:ff.LambdaDef('\z(->\)\)\@=/ end=/)[[:space:]\n]*\z1/', '->"') . ' contains=javaAnnotation,javaParamModifier,javaLambdaVarType,javaType,@javaClasses,javaGenerics,javaVarArg'
  " Match: () ->
  "	| (a[, b, ...]) ->
  exec 'syn ' . s:ff.LambdaDef('region javaLambdaDef transparent matchgroup=javaLambdaDefStart start=/', 'match javaLambdaDef "') . '\k\@' . s:ff.Peek('4', '') . '<!(' . s:ff.LambdaDef('\%(', '') . '[[:space:]\n]*\%(\<\K\k*\>\%(,[[:space:]\n]*\)\=\)*)[[:space:]\n]*' . s:ff.LambdaDef('\z(->\)\)\@=/ end=/)[[:space:]\n]*\z1/', '->"')
  " Match: a ->
  exec 'syn ' . s:ff.LambdaDef('region javaLambdaDef transparent start=/', 'match javaLambdaDef "') . '\<\K\k*\>\%(\<default\>\)\@' . s:ff.Peek('7', '') . '<!' . s:ff.LambdaDef('\%([[:space:]\n]*\z(->\)\)\@=/ matchgroup=javaLambdaDefStart end=/\z1/', '[[:space:]\n]*->"')

  syn keyword javaParamModifier contained final
  hi def link javaParamModifier javaConceptKind
  syn keyword javaLambdaVarType contained var
  hi def link javaLambdaVarType javaOperator
endif

" The @javaTop cluster comprises non-contained Java syntax groups.
" Note that the syntax file "aidl.vim" relies on its availability.
syn cluster javaTop contains=TOP,javaTopEnumDeclaration

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
hi def link javaLambdaDefStart		Function
hi def link javaFuncDef			Function
hi def link javaVarArg			Function
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
hi def link javaTextBlockError		Error
hi def link javaStatement		Statement
hi def link javaOperator		Operator
hi def link javaComment		Comment
hi def link javaDocComment		Comment
hi def link javaLineComment		Comment
hi def link javaConstant		Constant
hi def link javaTypedef		Typedef
hi def link javaTodo			Todo
hi def link javaAnnotation		PreProc
hi def link javaAnnotationStart		javaAnnotation

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
unlet s:module_info_cur_buf s:ff s:cpo_save

" See ":help vim9-mix".
if !has("vim9script")
  finish
endif

def! s:JavaSyntaxFoldTextExpr(): string
  return getline(v:foldstart) !~ '/\*\+\s*$'
    ? foldtext()
    : printf('+-%s%3d lines: ',
	  v:folddashes,
	  (v:foldend - v:foldstart + 1)) ..
	getline(v:foldstart + 1)
enddef

setlocal foldtext=s:JavaSyntaxFoldTextExpr()
delfunction! g:JavaSyntaxFoldTextExpr
" vim: sw=2 ts=8 noet sta
