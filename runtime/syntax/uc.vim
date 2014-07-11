" Vim syntax file
" Language:	UnrealScript
" Maintainer:	Mark Ferrell <major@chaoticdreams.org>
" URL:		ftp://ftp.chaoticdreams.org/pub/ut/vim/uc.vim
" Credits:	Based on the java.vim syntax file by Claudio Fleiner
" Last change:	2003 May 31

" Please check :help uc.vim for comments on some of the options available.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" some characters that cannot be in a UnrealScript program (outside a string)
syn match ucError "[\\@`]"
syn match ucError "<<<\|\.\.\|=>\|<>\|||=\|&&=\|[^-]->\|\*\/"

" we define it here so that included files can test for it
if !exists("main_syntax")
  let main_syntax='uc'
endif

syntax case ignore

" keyword definitions
syn keyword ucBranch	      break continue
syn keyword ucConditional     if else switch
syn keyword ucRepeat	      while for do foreach
syn keyword ucBoolean	      true false
syn keyword ucConstant	      null
syn keyword ucOperator	      new instanceof
syn keyword ucType	      boolean char byte short int long float double
syn keyword ucType	      void Pawn sound state auto exec function ipaddr
syn keyword ucType	      ELightType actor ammo defaultproperties bool
syn keyword ucType	      native noexport var out vector name local string
syn keyword ucType	      event
syn keyword ucStatement       return
syn keyword ucStorageClass    static synchronized transient volatile final
syn keyword ucMethodDecl      synchronized throws

" UnrealScript defines classes in sorta fscked up fashion
syn match   ucClassDecl       "^[Cc]lass[\s$]*\S*[\s$]*expands[\s$]*\S*;" contains=ucSpecial,ucSpecialChar,ucClassKeys
syn keyword ucClassKeys	      class expands extends
syn match   ucExternal	      "^\#exec.*" contains=ucCommentString,ucNumber
syn keyword ucScopeDecl       public protected private abstract

" UnrealScript Functions
syn match   ucFuncDef	      "^.*function\s*[\(]*" contains=ucType,ucStorageClass
syn match   ucEventDef	      "^.*event\s*[\(]*" contains=ucType,ucStorageClass
syn match   ucClassLabel      "[a-zA-Z0-9]*\'[a-zA-Z0-9]*\'" contains=ucCharacter

syn region  ucLabelRegion     transparent matchgroup=ucLabel start="\<case\>" matchgroup=NONE end=":" contains=ucNumber
syn match   ucUserLabel       "^\s*[_$a-zA-Z][_$a-zA-Z0-9_]*\s*:"he=e-1 contains=ucLabel
syn keyword ucLabel	      default

" The following cluster contains all java groups except the contained ones
syn cluster ucTop contains=ucExternal,ucError,ucError,ucBranch,ucLabelRegion,ucLabel,ucConditional,ucRepeat,ucBoolean,ucConstant,ucTypedef,ucOperator,ucType,ucType,ucStatement,ucStorageClass,ucMethodDecl,ucClassDecl,ucClassDecl,ucClassDecl,ucScopeDecl,ucError,ucError2,ucUserLabel,ucClassLabel

" Comments
syn keyword ucTodo	       contained TODO FIXME XXX
syn region  ucCommentString    contained start=+"+ end=+"+ end=+\*/+me=s-1,he=s-1 contains=ucSpecial,ucCommentStar,ucSpecialChar
syn region  ucComment2String   contained start=+"+  end=+$\|"+  contains=ucSpecial,ucSpecialChar
syn match   ucCommentCharacter contained "'\\[^']\{1,6\}'" contains=ucSpecialChar
syn match   ucCommentCharacter contained "'\\''" contains=ucSpecialChar
syn match   ucCommentCharacter contained "'[^\\]'"
syn region  ucComment	       start="/\*"  end="\*/" contains=ucCommentString,ucCommentCharacter,ucNumber,ucTodo
syn match   ucCommentStar      contained "^\s*\*[^/]"me=e-1
syn match   ucCommentStar      contained "^\s*\*$"
syn match   ucLineComment      "//.*" contains=ucComment2String,ucCommentCharacter,ucNumber,ucTodo
hi link ucCommentString ucString
hi link ucComment2String ucString
hi link ucCommentCharacter ucCharacter

syn cluster ucTop add=ucComment,ucLineComment

" match the special comment /**/
syn match   ucComment	       "/\*\*/"

" Strings and constants
syn match   ucSpecialError     contained "\\."
"syn match   ucSpecialCharError contained "[^']"
syn match   ucSpecialChar      contained "\\\([4-9]\d\|[0-3]\d\d\|[\"\\'ntbrf]\|u\x\{4\}\)"
syn region  ucString	       start=+"+ end=+"+  contains=ucSpecialChar,ucSpecialError
syn match   ucStringError      +"\([^"\\]\|\\.\)*$+
syn match   ucCharacter        "'[^']*'" contains=ucSpecialChar,ucSpecialCharError
syn match   ucCharacter        "'\\''" contains=ucSpecialChar
syn match   ucCharacter        "'[^\\]'"
syn match   ucNumber	       "\<\(0[0-7]*\|0[xX]\x\+\|\d\+\)[lL]\=\>"
syn match   ucNumber	       "\(\<\d\+\.\d*\|\.\d\+\)\([eE][-+]\=\d\+\)\=[fFdD]\="
syn match   ucNumber	       "\<\d\+[eE][-+]\=\d\+[fFdD]\=\>"
syn match   ucNumber	       "\<\d\+\([eE][-+]\=\d\+\)\=[fFdD]\>"

" unicode characters
syn match   ucSpecial "\\u\d\{4\}"

syn cluster ucTop add=ucString,ucCharacter,ucNumber,ucSpecial,ucStringError

" catch errors caused by wrong parenthesis
syn region  ucParen	       transparent start="(" end=")" contains=@ucTop,ucParen
syn match   ucParenError       ")"
hi link     ucParenError       ucError

if !exists("uc_minlines")
  let uc_minlines = 10
endif
exec "syn sync ccomment ucComment minlines=" . uc_minlines

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_uc_syntax_inits")
  if version < 508
    let did_uc_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink ucFuncDef			Conditional
  HiLink ucEventDef			Conditional
  HiLink ucBraces			Function
  HiLink ucBranch			Conditional
  HiLink ucLabel			Label
  HiLink ucUserLabel			Label
  HiLink ucConditional			Conditional
  HiLink ucRepeat			Repeat
  HiLink ucStorageClass			StorageClass
  HiLink ucMethodDecl			ucStorageClass
  HiLink ucClassDecl			ucStorageClass
  HiLink ucScopeDecl			ucStorageClass
  HiLink ucBoolean			Boolean
  HiLink ucSpecial			Special
  HiLink ucSpecialError			Error
  HiLink ucSpecialCharError		Error
  HiLink ucString			String
  HiLink ucCharacter			Character
  HiLink ucSpecialChar			SpecialChar
  HiLink ucNumber			Number
  HiLink ucError			Error
  HiLink ucStringError			Error
  HiLink ucStatement			Statement
  HiLink ucOperator			Operator
  HiLink ucOverLoaded			Operator
  HiLink ucComment			Comment
  HiLink ucDocComment			Comment
  HiLink ucLineComment			Comment
  HiLink ucConstant			ucBoolean
  HiLink ucTypedef			Typedef
  HiLink ucTodo				Todo

  HiLink ucCommentTitle			SpecialComment
  HiLink ucDocTags			Special
  HiLink ucDocParam			Function
  HiLink ucCommentStar			ucComment

  HiLink ucType				Type
  HiLink ucExternal			Include

  HiLink ucClassKeys			Conditional
  HiLink ucClassLabel			Conditional

  HiLink htmlComment			Special
  HiLink htmlCommentPart		Special

  delcommand HiLink
endif

let b:current_syntax = "uc"

if main_syntax == 'uc'
  unlet main_syntax
endif

" vim: ts=8
