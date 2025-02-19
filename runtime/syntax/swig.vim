" Vim syntax file
" Language:	SWIG
" Maintainer:	Julien Marrec <julien.marrec 'at' gmail com>
" Last Change:	2023 November 23

if exists("b:current_syntax")
  finish
endif

" Read the C++ syntax to start with
runtime! syntax/cpp.vim
unlet b:current_syntax

" SWIG extentions
syn keyword swigInclude %include %import %importfile %includefile %module

syn keyword swigMostCommonDirective %alias %apply %beginfile %clear %constant %define %echo %enddef %endoffile
syn keyword swigMostCommonDirective %extend %feature %director %fragment %ignore  %inline
syn keyword swigMostCommonDirective %keyword %name %namewarn %native %newobject %parms %pragma
syn keyword swigMostCommonDirective %rename %template %typedef %typemap %types %varargs

" SWIG: Language specific macros
syn keyword swigOtherLanguageSpecific %luacode %go_import

syn keyword swigCSharp %csattributes %csconst %csconstvalue %csmethodmodifiers %csnothrowexception
syn keyword swigCSharp %dconstvalue %dmanifestconst %dmethodmodifiers

syn keyword swigJava %javaconstvalue %javaexception %javamethodmodifiers %javaconst %nojavaexception

syn keyword swigGuile %multiple_values %values_as_list %values_as_vector

syn keyword swigPHP %rinit %rshutdown %minit %mshutdown

syn keyword swigPython %pybinoperator %pybuffer_binary %pybuffer_mutable_binary %pybuffer_mutable_string %pybuffer_string
syn keyword swigPython %pythonappend %pythonbegin %pythoncode %pythondynamic %pythonnondynamic %pythonprepend

syn keyword swigRuby %markfunc %trackobjects %bang
syn keyword swigScilab %scilabconst

" SWIG: Insertion
syn keyword swigInsertSection %insert %begin %runtime %header %wrapper %init

" SWIG: Other directives
syn keyword swigCstring %cstring_bounded_mutable %cstring_bounded_output %cstring_chunk_output %cstring_input_binary %cstring_mutable
syn keyword swigCstring %cstring_output_allocate %cstring_output_allocate_size %cstring_output_maxsize %cstring_output_withsize
syn keyword swigCWstring %cwstring_bounded_mutable %cwstring_bounded_output %cwstring_chunk_output %cwstring_input_binary %cwstring_mutable
syn keyword swigCWstring %cwstring_output_allocate %cwstring_output_allocate_size %cwstring_output_maxsize %cwstring_output_withsize
syn keyword swigCMalloc %malloc %calloc %realloc %free %sizeof %allocators

syn keyword swigExceptionHandling %catches %raise %allowexception %exceptionclass %warn %warnfilter %exception
syn keyword swigContract %contract %aggregate_check

syn keyword swigDirective %addmethods %array_class %array_functions %attribute %attribute2 %attribute2ref
syn keyword swigDirective %attribute_ref %attributeref %attributestring %attributeval %auto_ptr %callback
syn keyword swigDirective %delete_array %delobject %extend_smart_pointer %factory %fastdispatch %freefunc %immutable
syn keyword swigDirective %implicit %implicitconv %interface %interface_custom %interface_impl %intrusive_ptr %intrusive_ptr_no_wrap
syn keyword swigDirective %mutable %naturalvar %nocallback %nocopyctor %nodefaultctor %nodefaultdtor %nonaturalvar %nonspace
syn keyword swigDirective %nspace %pointer_cast %pointer_class %pointer_functions %predicate %proxycode
syn keyword swigDirective %refobject %set_output %shared_ptr %std_comp_methods
syn keyword swigDirective %std_nodefconst_type %typecheck %typemaps_string %unique_ptr %unrefobject %valuewrapper

syn match swigVerbatimStartEnd "%[{}]"

syn match swigUserDef "%\w\+"
syn match swigVerbatimMacro "^\s*%#\w\+\%( .*\)\?$"

" SWIG: typemap var and typemap macros (eg: $1, $*1_type, $&n_ltype, $self)
syn match swigTypeMapVars "\$[*&_a-zA-Z0-9]\+"

" Default highlighting
hi def link swigInclude Include
hi def link swigMostCommonDirective Structure
hi def link swigDirective Macro
hi def link swigContract swigExceptionHandling
hi def link swigExceptionHandling Exception
hi def link swigUserDef Function

hi def link swigCMalloc Statement
hi def link swigCstring Type
hi def link swigCWstring Type

hi def link swigCSharp swigOtherLanguageSpecific
hi def link swigJava swigOtherLanguageSpecific
hi def link swigGuile swigOtherLanguageSpecific
hi def link swigPHP swigOtherLanguageSpecific
hi def link swigPython swigOtherLanguageSpecific
hi def link swigRuby swigOtherLanguageSpecific
hi def link swigScilab swigOtherLanguageSpecific
hi def link swigOtherLanguageSpecific Special

hi def link swigInsertSection PreProc

hi def link swigVerbatimStartEnd Statement
hi def link swigVerbatimMacro Macro

hi def link swigTypeMapVars SpecialChar

let b:current_syntax = "swig"
" vim: ts=8
