" Vim syntax file
" Language:    IDL (Interface Description Language)
" Created By:  Jody Goldberg
" Maintainer:  Michael Geddes <vim@frog.wheelycreek.net>
" Last Change:  2012 Jan 11


" This is an experiment.  IDL's structure is simple enough to permit a full
" grammar based approach to rather than using a few heuristics.  The result
" is large and somewhat repetitive but seems to work.

" There are some Microsoft extensions to idl files that are here.  Some of
" them are disabled by defining idl_no_ms_extensions.
"
" The more complex of the extensions are disabled by defining idl_no_extensions.
"
" History:
" 2.0: Michael's new version
" 2.1: Support for Vim 7 spell (Anduin Withers)
"

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
try
  set cpo&vim

  if exists("idlsyntax_showerror")
    syn match idlError +\S+ skipwhite skipempty nextgroup=idlError
  endif

  syn region idlCppQuote start='\<cpp_quote\s*(' end=')' contains=idlString

  " Misc basic
  syn match   idlId          contained "[a-zA-Z][a-zA-Z0-9_]*" skipwhite skipempty nextgroup=idlEnumComma,idlEnumNumber
  syn match   idlEnumComma   contained ","
  syn match   idlEnumNumber  contained "=" skipwhite skipempty nextgroup=idlString,idlLiteral
  syn match   idlSemiColon   contained ";"
  syn match   idlCommaArg    contained ","                      skipempty skipwhite nextgroup=idlSimpDecl
  syn region  idlArraySize1  contained start=:\[: end=:\]:      skipempty skipwhite nextgroup=idlArraySize1,idlError,idlSemiColon,idlCommaArg contains=idlArraySize1,idlLiteral
  syn match   idlSimpDecl    contained "[a-zA-Z][a-zA-Z0-9_]*"  skipempty skipwhite nextgroup=idlError,idlSemiColon,idlCommaArg,idlArraySize1
  syn region  idlString      contained start=+"+  skip=+\\\(\\\\\)*"+  end=+"+ contains=@Spell
  syn match   idlLiteral     contained "[1-9]\d*\(\.\d*\)\="
  syn match   idlLiteral     contained "0"
  syn match   idlLiteral     contained "\.\d\+"
  syn match   idlLiteral     contained "0x[0-9A-Fa-f]\+"
  syn match   idlLiteral     contained "0[0-7]\+"
  syn keyword idlLiteral     contained TRUE FALSE

  " Comments
  syn keyword idlTodo        contained TODO FIXME XXX
  syn region idlComment      start="/\*"  end="\*/" contains=idlTodo,@Spell
  syn match  idlComment      "//.*" contains=idlTodo,@Spell
  syn match  idlCommentError "\*/"

  " C style Preprocessor
  syn region idlIncluded    contained start=+"+  skip=+\\\(\\\\\)*"+  end=+"+
  syn match  idlIncluded    contained "<[^>]*>"
  syn match  idlInclude     "^[ \t]*#[ \t]*include\>[ \t]*["<]" contains=idlIncluded,idlString
  syn region idlPreCondit   start="^[ \t]*#[ \t]*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)"  skip="\\$"  end="$" contains=idlComment,idlCommentError
  syn region idlDefine      start="^[ \t]*#[ \t]*\(define\>\|undef\>\)" skip="\\$" end="$" contains=idlLiteral,idlString

  " Constants
  syn keyword idlConst    const                             skipempty skipwhite nextgroup=idlBaseType,idlBaseTypeInt

  " Attribute
  syn keyword idlROAttr   readonly                          skipempty skipwhite nextgroup=idlAttr
  syn keyword idlAttr     attribute                         skipempty skipwhite nextgroup=idlBaseTypeInt,idlBaseType

  " Types
  syn region  idlD4          contained start="<" end=">"    skipempty skipwhite nextgroup=idlSimpDecl contains=idlSeqType,idlBaseTypeInt,idlBaseType,idlLiteral
  syn keyword idlSeqType     contained sequence             skipempty skipwhite nextgroup=idlD4
  syn keyword idlBaseType    contained float double char boolean octet any skipempty skipwhite nextgroup=idlSimpDecl
  syn keyword idlBaseTypeInt contained short long           skipempty skipwhite nextgroup=idlSimpDecl
  syn keyword idlBaseType    contained unsigned             skipempty skipwhite nextgroup=idlBaseTypeInt
  syn region  idlD1          contained start="<" end=">"    skipempty skipwhite nextgroup=idlSimpDecl contains=idlString,idlLiteral
  syn keyword idlBaseType    contained string               skipempty skipwhite nextgroup=idlD1,idlSimpDecl
  syn match   idlBaseType    contained "[a-zA-Z0-9_]\+[ \t]*\(::[ \t]*[a-zA-Z0-9_]\+\)*"  skipempty skipwhite nextgroup=idlSimpDecl

  " Modules
  syn region  idlModuleContent contained start="{" end="}"  skipempty skipwhite nextgroup=idlError,idlSemiColon contains=idlUnion,idlStruct,idlEnum,idlInterface,idlComment,idlTypedef,idlConst,idlException,idlModule
  syn match   idlModuleName  contained "[a-zA-Z0-9_]\+"     skipempty skipwhite nextgroup=idlModuleContent,idlError,idlSemiColon
  syn keyword idlModule      module                         skipempty skipwhite nextgroup=idlModuleName

  " Interfaces
  syn cluster idlCommentable contains=idlComment
  syn cluster idlContentCluster contains=idlUnion,idlStruct,idlEnum,idlROAttr,idlAttr,idlOp,idlOneWayOp,idlException,idlConst,idlTypedef,idlAttributes,idlErrorSquareBracket,idlErrorBracket,idlInterfaceSections

  syn region  idlInterfaceContent contained start="{" end="}"   skipempty skipwhite nextgroup=idlError,idlSemiColon contains=@idlContentCluster,@idlCommentable
  syn match   idlInheritFrom2 contained ","                     skipempty skipwhite nextgroup=idlInheritFrom
  syn match   idlInheritFrom contained "[a-zA-Z0-9_]\+[ \t]*\(::[ \t]*[a-zA-Z0-9_]\+\)*" skipempty skipwhite nextgroup=idlInheritFrom2,idlInterfaceContent
  syn match   idlInherit contained ":"                            skipempty skipwhite nextgroup=idlInheritFrom
  syn match   idlInterfaceName contained "[a-zA-Z0-9_]\+"       skipempty skipwhite nextgroup=idlInterfaceContent,idlInherit,idlError,idlSemiColon
  syn keyword idlInterface     interface dispinterface          skipempty skipwhite nextgroup=idlInterfaceName
  syn keyword idlInterfaceSections contained properties methods skipempty skipwhite nextgroup=idlSectionColon,idlError
  syn match   idlSectionColon contained ":"


  syn match   idlLibraryName  contained  "[a-zA-Z0-9_]\+"       skipempty skipwhite nextgroup=idlLibraryContent,idlError,idlSemiColon
  syn keyword idlLibrary      library                           skipempty skipwhite nextgroup=idlLibraryName
  syn region  idlLibraryContent contained start="{" end="}"     skipempty skipwhite nextgroup=idlError,idlSemiColon contains=@idlCommentable,idlAttributes,idlErrorSquareBracket,idlErrorBracket,idlImportlib,idlCoclass,idlTypedef,idlInterface

  syn keyword idlImportlib contained importlib                  skipempty skipwhite nextgroup=idlStringArg
  syn region idlStringArg contained start="(" end=")"           contains=idlString nextgroup=idlError,idlSemiColon,idlErrorBrace,idlErrorSquareBracket

  syn keyword idlCoclass coclass contained                      skipempty skipwhite nextgroup=idlCoclassName
  syn match   idlCoclassName "[a-zA-Z0-9_]\+" contained         skipempty skipwhite nextgroup=idlCoclassDefinition,idlError,idlSemiColon

  syn region idlCoclassDefinition contained start="{" end="}"   contains=idlCoclassAttributes,idlInterface,idlErrorBracket,idlErrorSquareBracket skipempty skipwhite nextgroup=idlError,idlSemiColon
  syn region idlCoclassAttributes contained start=+\[+ end=+]+  skipempty skipwhite nextgroup=idlInterface contains=idlErrorBracket,idlErrorBrace,idlCoclassAttribute
  syn keyword idlCoclassAttribute contained default source
  "syn keyword idlInterface       interface                      skipempty skipwhite nextgroup=idlInterfaceStubName

  syn match idlImportString       +"\f\+"+                      skipempty skipwhite nextgroup=idlError,idlSemiColon
  syn keyword idlImport           import                        skipempty skipwhite nextgroup=idlImportString

  syn region  idlAttributes start="\[" end="\]"                 contains=idlAttribute,idlAttributeParam,idlErrorBracket,idlErrorBrace,idlComment
  syn keyword idlAttribute contained propput propget propputref id helpstring object uuid pointer_default
  if !exists('idl_no_ms_extensions')
  syn keyword idlAttribute contained nonextensible dual version aggregatable restricted hidden noncreatable oleautomation
  endif
  syn region idlAttributeParam contained start="(" end=")"      contains=idlString,idlUuid,idlLiteral,idlErrorBrace,idlErrorSquareBracket
  " skipwhite nextgroup=idlArraySize,idlParmList contains=idlArraySize,idlLiteral
  syn match idlErrorBrace contained "}"
  syn match idlErrorBracket contained ")"
  syn match idlErrorSquareBracket contained "\]"

  syn match idlUuid         contained +[0-9a-zA-Z]\{8}-\([0-9a-zA-Z]\{4}-\)\{3}[0-9a-zA-Z]\{12}+

  " Raises
  syn keyword idlRaises     contained raises               skipempty skipwhite nextgroup=idlRaises,idlContext,idlError,idlSemiColon

  " Context
  syn keyword idlContext    contained context              skipempty skipwhite nextgroup=idlRaises,idlContext,idlError,idlSemiColon

  " Operation
  syn match   idlParmList   contained ","                  skipempty skipwhite nextgroup=idlOpParms
  syn region  idlArraySize  contained start="\[" end="\]"  skipempty skipwhite nextgroup=idlArraySize,idlParmList contains=idlArraySize,idlLiteral
  syn match   idlParmName   contained "[a-zA-Z0-9_]\+"     skipempty skipwhite nextgroup=idlParmList,idlArraySize
  syn keyword idlParmInt    contained short long           skipempty skipwhite nextgroup=idlParmName
  syn keyword idlParmType   contained unsigned             skipempty skipwhite nextgroup=idlParmInt
  syn region  idlD3         contained start="<" end=">"    skipempty skipwhite nextgroup=idlParmName contains=idlString,idlLiteral
  syn keyword idlParmType   contained string               skipempty skipwhite nextgroup=idlD3,idlParmName
  syn keyword idlParmType   contained void float double char boolean octet any    skipempty skipwhite nextgroup=idlParmName
  syn match   idlParmType   contained "[a-zA-Z0-9_]\+[ \t]*\(::[ \t]*[a-zA-Z0-9_]\+\)*" skipempty skipwhite nextgroup=idlParmName
  syn keyword idlOpParms    contained in out inout         skipempty skipwhite nextgroup=idlParmType

  if !exists('idl_no_ms_extensions')
  syn keyword idlOpParms    contained retval optional      skipempty skipwhite nextgroup=idlParmType
    syn match idlOpParms contained +\<\(iid_is\|defaultvalue\)\s*([^)]*)+ skipempty skipwhite nextgroup=idlParamType

    syn keyword idlVariantType  contained BSTR VARIANT VARIANT_BOOL long short unsigned double CURRENCY DATE
    syn region idlSafeArray contained matchgroup=idlVariantType start=+SAFEARRAY(\s*+ end=+)+ contains=idlVariantType
  endif

  syn region  idlOpContents contained start="(" end=")"    skipempty skipwhite nextgroup=idlRaises,idlContext,idlError,idlSemiColon contains=idlOpParms,idlSafeArray,idlVariantType,@idlCommentable
  syn match   idlOpName   contained "[a-zA-Z0-9_]\+"       skipempty skipwhite nextgroup=idlOpContents
  syn keyword idlOpInt    contained short long             skipempty skipwhite nextgroup=idlOpName
  syn region  idlD2       contained start="<" end=">"      skipempty skipwhite nextgroup=idlOpName contains=idlString,idlLiteral
  syn keyword idlOp       contained unsigned               skipempty skipwhite nextgroup=idlOpInt
  syn keyword idlOp       contained string                 skipempty skipwhite nextgroup=idlD2,idlOpName
  syn keyword idlOp       contained void float double char boolean octet any  skipempty skipwhite nextgroup=idlOpName
  syn match   idlOp       contained "[a-zA-Z0-9_]\+[ \t]*\(::[ \t]*[a-zA-Z0-9_]\+\)*" skipempty skipwhite nextgroup=idlOpName
  syn keyword idlOp       contained void                   skipempty skipwhite nextgroup=idlOpName
  syn keyword idlOneWayOp contained oneway                 skipempty skipwhite nextgroup=idOp

  " Enum
  syn region  idlEnumContents contained start="{" end="}"  skipempty skipwhite nextgroup=idlError,idlSemiColon,idlSimpDecl contains=idlId,idlAttributes,@idlCommentable
  syn match   idlEnumName contained "[a-zA-Z0-9_]\+"       skipempty skipwhite nextgroup=idlEnumContents
  syn keyword idlEnum     enum                             skipempty skipwhite nextgroup=idlEnumName,idlEnumContents

  " Typedef
  syn keyword idlTypedef typedef                          skipempty skipwhite nextgroup=idlTypedefOtherTypeQualifier,idlDefBaseType,idlDefBaseTypeInt,idlDefSeqType,idlDefv1Enum,idlDefEnum,idlDefOtherType,idlDefAttributes,idlError

  if !exists('idl_no_extensions')
    syn keyword idlTypedefOtherTypeQualifier contained struct enum interface nextgroup=idlDefBaseType,idlDefBaseTypeInt,idlDefSeqType,idlDefv1Enum,idlDefEnum,idlDefOtherType,idlDefAttributes,idlError skipwhite

    syn region  idlDefAttributes        contained start="\[" end="\]" contains=idlAttribute,idlAttributeParam,idlErrorBracket,idlErrorBrace skipempty skipwhite nextgroup=idlDefBaseType,idlDefBaseTypeInt,idlDefSeqType,idlDefv1Enum,idlDefEnum,idlDefOtherType,idlError

    syn keyword idlDefBaseType      contained float double char boolean octet any  skipempty skipwhite nextgroup=idlTypedefDecl,idlError
    syn keyword idlDefBaseTypeInt   contained short long                           skipempty skipwhite nextgroup=idlTypedefDecl,idlError
    syn match idlDefOtherType       contained +\<\k\+\>+ skipempty                 nextgroup=idlTypedefDecl,idlError
    " syn keyword idlDefSeqType     contained sequence                             skipempty skipwhite nextgroup=idlD4

    " Enum typedef
    syn keyword idlDefEnum          contained enum skipempty                       skipwhite nextgroup=idlDefEnumName,idlDefEnumContents
    syn match   idlDefEnumName      contained "[a-zA-Z0-9_]\+"                     skipempty skipwhite nextgroup=idlDefEnumContents,idlTypedefDecl
    syn region  idlDefEnumContents  contained start="{" end="}"                    skipempty skipwhite nextgroup=idlError,idlTypedefDecl contains=idlId,idlAttributes

    syn match   idlTypedefDecl      contained "[a-zA-Z0-9_]\+"                     skipempty skipwhite nextgroup=idlError,idlSemiColon
  endif

  " Struct
  syn region  idlStructContent   contained start="{" end="}"   skipempty skipwhite nextgroup=idlError,idlSemiColon,idlSimpDecl contains=idlBaseType,idlBaseTypeInt,idlSeqType,@idlCommentable,idlEnum,idlUnion
  syn match   idlStructName      contained "[a-zA-Z0-9_]\+"    skipempty skipwhite nextgroup=idlStructContent
  syn keyword idlStruct          struct                        skipempty skipwhite nextgroup=idlStructName

  " Exception
  syn keyword idlException       exception                     skipempty skipwhite nextgroup=idlStructName

  " Union
  syn match   idlColon            contained ":"                skipempty skipwhite nextgroup=idlCase,idlSeqType,idlBaseType,idlBaseTypeInt
  syn region  idlCaseLabel        contained start="" skip="::" end=":"me=e-1 skipempty skipwhite nextgroup=idlColon contains=idlLiteral,idlString
  syn keyword idlCase             contained case               skipempty skipwhite nextgroup=idlCaseLabel
  syn keyword idlCase             contained default            skipempty skipwhite nextgroup=idlColon
  syn region  idlUnionContent     contained start="{" end="}"  skipempty skipwhite nextgroup=idlError,idlSemiColon,idlSimpDecl contains=idlCase
  syn region  idlSwitchType       contained start="(" end=")"  skipempty skipwhite nextgroup=idlUnionContent
  syn keyword idlUnionSwitch      contained switch             skipempty skipwhite nextgroup=idlSwitchType
  syn match   idlUnionName        contained "[a-zA-Z0-9_]\+"   skipempty skipwhite nextgroup=idlUnionSwitch
  syn keyword idlUnion            union                        skipempty skipwhite nextgroup=idlUnionName

  if !exists('idl_no_extensions')
    syn sync match  idlInterfaceSync grouphere idlInterfaceContent "\<\(disp\)\=interface\>\s\+\k\+\s*:\s*\k\+\_s*{" skipempty skipwhite nextgroup=idlError,idlSemiColon contains=@idlContentCluster,@idlCommentable
    syn sync maxlines=1000 minlines=100
  else
    syn sync lines=200
  endif
  " syn sync fromstart

  if !exists("did_idl_syntax_inits")
    let did_idl_syntax_inits = 1
    " The default methods for highlighting.  Can be overridden later

    hi def link idlInclude             Include
    hi def link idlPreProc             PreProc
    hi def link idlPreCondit           PreCondit
    hi def link idlDefine              Macro
    hi def link idlIncluded            String
    hi def link idlString              String
    hi def link idlComment             Comment
    hi def link idlTodo                Todo
    hi def link idlLiteral             Number
    hi def link idlUuid                Number
    hi def link idlType                Type
    hi def link idlVariantType         idlType

    hi def link idlModule              Keyword
    hi def link idlInterface           Keyword
    hi def link idlEnum                Keyword
    hi def link idlStruct              Keyword
    hi def link idlUnion               Keyword
    hi def link idlTypedef             Keyword
    hi def link idlException           Keyword
    hi def link idlTypedefOtherTypeQualifier keyword

    hi def link idlModuleName          Typedef
    hi def link idlInterfaceName       Typedef
    hi def link idlEnumName            Typedef
    hi def link idlStructName          Typedef
    hi def link idlUnionName           Typedef

    hi def link idlBaseTypeInt         idlType
    hi def link idlBaseType            idlType
    hi def link idlSeqType             idlType
    hi def link idlD1                  Paren
    hi def link idlD2                  Paren
    hi def link idlD3                  Paren
    hi def link idlD4                  Paren
    "hi def link idlArraySize          Paren
    "hi def link idlArraySize1         Paren
    hi def link idlModuleContent       Paren
    hi def link idlUnionContent        Paren
    hi def link idlStructContent       Paren
    hi def link idlEnumContents        Paren
    hi def link idlInterfaceContent    Paren

    hi def link idlSimpDecl            Identifier
    hi def link idlROAttr              StorageClass
    hi def link idlAttr                Keyword
    hi def link idlConst               StorageClass

    hi def link idlOneWayOp            StorageClass
    hi def link idlOp                  idlType
    hi def link idlParmType            idlType
    hi def link idlOpName              Function
    hi def link idlOpParms             SpecialComment
    hi def link idlParmName            Identifier
    hi def link idlInheritFrom         Identifier
    hi def link idlAttribute           SpecialComment

    hi def link idlId                  Constant
    "hi def link idlCase               Keyword
    hi def link idlCaseLabel           Constant

    hi def link idlErrorBracket        Error
    hi def link idlErrorBrace          Error
    hi def link idlErrorSquareBracket  Error

    hi def link idlImport              Keyword
    hi def link idlImportString        idlString
    hi def link idlCoclassAttribute    StorageClass
    hi def link idlLibrary             Keyword
    hi def link idlImportlib           Keyword
    hi def link idlCoclass             Keyword
    hi def link idlLibraryName         Typedef
    hi def link idlCoclassName         Typedef
    " hi def link idlLibraryContent guifg=red
    hi def link idlTypedefDecl         Typedef
    hi def link idlDefEnum             Keyword
    hi def link idlDefv1Enum           Keyword
    hi def link idlDefEnumName         Typedef
    hi def link idlDefEnumContents     Paren
    hi def link idlDefBaseTypeInt      idlType
    hi def link idlDefBaseType         idlType
    hi def link idlDefSeqType          idlType
    hi def link idlInterfaceSections   Label

    if exists("idlsyntax_showerror")
      if exists("idlsyntax_showerror_soft")
        hi default idlError guibg=#d0ffd0
      else
        hi def link idlError Error
      endif
    endif
  endif

  let b:current_syntax = "idl"
finally
  let &cpo = s:cpo_save
  unlet s:cpo_save
endtry
" vim: sw=2 et
