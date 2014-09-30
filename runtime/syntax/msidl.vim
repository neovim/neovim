" Vim syntax file
" Language:     MS IDL (Microsoft dialect of Interface Description Language)
" Maintainer:   Vadim Zeitlin <vadim@wxwindows.org>
" Last Change:  2012 Feb 12 by Thilo Six

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Misc basic
syn match   msidlId		"[a-zA-Z][a-zA-Z0-9_]*"
syn match   msidlUUID		"{\?[[:xdigit:]]\{8}-\([[:xdigit:]]\{4}-\)\{3}[[:xdigit:]]\{12}}\?"
syn region  msidlString		start=/"/  skip=/\\\(\\\\\)*"/	end=/"/
syn match   msidlLiteral	"\d\+\(\.\d*\)\="
syn match   msidlLiteral	"\.\d\+"
syn match   msidlSpecial	contained "[]\[{}:]"

" Comments
syn keyword msidlTodo		contained TODO FIXME XXX
syn region  msidlComment	start="/\*"  end="\*/" contains=msidlTodo
syn match   msidlComment	"//.*" contains=msidlTodo
syn match   msidlCommentError	"\*/"

" C style Preprocessor
syn region  msidlIncluded	contained start=+"+  skip=+\\\(\\\\\)*"+  end=+"+
syn match   msidlIncluded	contained "<[^>]*>"
syn match   msidlInclude	"^[ \t]*#[ \t]*include\>[ \t]*["<]" contains=msidlIncluded,msidlString
syn region  msidlPreCondit	start="^[ \t]*#[ \t]*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)"  skip="\\$"	end="$" contains=msidlComment,msidlCommentError
syn region  msidlDefine		start="^[ \t]*#[ \t]*\(define\>\|undef\>\)" skip="\\$" end="$" contains=msidlLiteral, msidlString

" Attributes
syn keyword msidlAttribute      contained in out propget propput propputref retval
syn keyword msidlAttribute      contained aggregatable appobject binadable coclass control custom default defaultbind defaultcollelem defaultvalue defaultvtable dispinterface displaybind dual entry helpcontext helpfile helpstring helpstringdll hidden id immediatebind lcid library licensed nonbrowsable noncreatable nonextensible oleautomation optional object public readonly requestedit restricted source string uidefault usesgetlasterror vararg version
syn match   msidlAttribute      /uuid(.*)/he=s+4 contains=msidlUUID
syn match   msidlAttribute      /helpstring(.*)/he=s+10 contains=msidlString
syn region  msidlAttributes     start="\[" end="]" keepend contains=msidlSpecial,msidlString,msidlAttribute,msidlComment,msidlCommentError

" Keywords
syn keyword msidlEnum		enum
syn keyword msidlImport		import importlib
syn keyword msidlStruct		interface library coclass
syn keyword msidlTypedef	typedef

" Types
syn keyword msidlStandardType   byte char double float hyper int long short void wchar_t
syn keyword msidlStandardType   BOOL BSTR HRESULT VARIANT VARIANT_BOOL
syn region  msidlSafeArray      start="SAFEARRAY(" end=")" contains=msidlStandardType

syn sync lines=50

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_msidl_syntax_inits")
  if version < 508
    let did_msidl_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink msidlInclude		Include
  HiLink msidlPreProc		PreProc
  HiLink msidlPreCondit		PreCondit
  HiLink msidlDefine		Macro
  HiLink msidlIncluded		String
  HiLink msidlString		String
  HiLink msidlComment		Comment
  HiLink msidlTodo		Todo
  HiLink msidlSpecial		SpecialChar
  HiLink msidlLiteral		Number
  HiLink msidlUUID		Number

  HiLink msidlImport		Include
  HiLink msidlEnum		StorageClass
  HiLink msidlStruct		Structure
  HiLink msidlTypedef		Typedef
  HiLink msidlAttribute		StorageClass

  HiLink msidlStandardType	Type
  HiLink msidlSafeArray		Type

  delcommand HiLink
endif

let b:current_syntax = "msidl"

let &cpo = s:cpo_save
unlet s:cpo_save
" vi: set ts=8 sw=4:
