" Vim syntax file
" Language:		Cmod
" Current Maintainer:	Stephen R. van den Berg <srb@cuci.nl>
" Last Change:		2018 Jan 23
" Version:      	2.9
" Remark: Is used to edit Cmod files for Pike development.
" Remark: Includes a highlighter for any embedded Autodoc format.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Read the C syntax to start with
runtime! syntax/c.vim
unlet b:current_syntax

if !exists("c_autodoc")
  " For embedded Autodoc documentation
  syn include @cmodAutodoc <sfile>:p:h/autodoc.vim
  unlet b:current_syntax
endif

" Supports rotating amongst several same-level preprocessor conditionals
packadd! matchit
let b:match_words = "({:}\\@1<=),^\s*#\s*\%(if\%(n\?def\)\|else\|el\%(se\)\?if\|endif\)\>"

" Cmod extensions
syn keyword cmodStatement	__INIT INIT EXIT GC_RECURSE GC_CHECK
syn keyword cmodStatement	EXTRA OPTIMIZE RETURN
syn keyword cmodStatement	ADD_EFUN ADD_EFUN2 ADD_FUNCTION
syn keyword cmodStatement	MK_STRING MK_STRING_SVALUE CONSTANT_STRLEN

syn keyword cmodStatement	SET_SVAL pop_n_elems pop_stack
syn keyword cmodStatement	SIMPLE_ARG_TYPE_ERROR Pike_sp Pike_fp MKPCHARP
syn keyword cmodStatement	SET_SVAL_TYPE REF_MAKE_CONST_STRING INC_PCHARP
syn keyword cmodStatement	PTR_FROM_INT INHERIT_FROM_PTR
syn keyword cmodStatement	DECLARE_CYCLIC BEGIN_CYCLIC END_CYCLIC
syn keyword cmodStatement	UPDATE_LOCATION UNSAFE_IS_ZERO SAFE_IS_ZERO
syn keyword cmodStatement	MKPCHARP_STR APPLY_MASTER current_storage
syn keyword cmodStatement	PIKE_MAP_VARIABLE size_shift
syn keyword cmodStatement	THREADS_ALLOW THREADS_DISALLOW

syn keyword cmodStatement	add_integer_constant ref_push_object
syn keyword cmodStatement	push_string apply_svalue free_svalue
syn keyword cmodStatement	get_inherit_storage get_storage
syn keyword cmodStatement	make_shared_binary_string push_int64
syn keyword cmodStatement	begin_shared_string end_shared_string
syn keyword cmodStatement	add_ref fast_clone_object clone_object
syn keyword cmodStatement	push_undefined push_int ref_push_string
syn keyword cmodStatement	free_string push_ulongest free_object
syn keyword cmodStatement	convert_stack_top_to_bignum push_array
syn keyword cmodStatement	push_object reduce_stack_top_bignum
syn keyword cmodStatement	push_static_text apply_current
syn keyword cmodStatement	assign_svalue free_program destruct_object
syn keyword cmodStatement	start_new_program low_inherit stack_swap
syn keyword cmodStatement	generic_error_program end_program
syn keyword cmodStatement	free_array apply_external copy_mapping
syn keyword cmodStatement	push_constant_text ref_push_mapping
syn keyword cmodStatement	mapping_insert mapping_string_insert_string
syn keyword cmodStatement	f_aggregate_mapping f_aggregate apply
syn keyword cmodStatement	push_mapping push_svalue low_mapping_lookup
syn keyword cmodStatement	assign_svalues_no_free f_add
syn keyword cmodStatement	push_empty_string stack_dup assign_lvalue
syn keyword cmodStatement	low_mapping_string_lookup allocate_mapping
syn keyword cmodStatement	copy_shared_string make_shared_binary_string0
syn keyword cmodStatement	f_call_function f_index f_utf8_to_string
syn keyword cmodStatement	finish_string_builder init_string_builder
syn keyword cmodStatement	reset_string_builder free_string_builder
syn keyword cmodStatement	string_builder_putchar get_all_args
syn keyword cmodStatement	add_shared_strings check_all_args
syn keyword cmodStatement	do_inherit add_string_constant
syn keyword cmodStatement	add_program_constant set_init_callback
syn keyword cmodStatement	simple_mapping_string_lookup
syn keyword cmodStatement	f_sprintf push_text string_has_null
syn keyword cmodStatement	end_and_resize_shared_string

syn keyword cmodStatement	args sp

syn keyword cmodStatement	free

syn keyword cmodConstant	ID_PROTECTED ID_FINAL PIKE_DEBUG
syn keyword cmodConstant	NUMBER_NUMBER
syn keyword cmodConstant	PIKE_T_INT PIKE_T_STRING PIKE_T_ARRAY
syn keyword cmodConstant	PIKE_T_MULTISET PIKE_T_OBJECT PIKE_T_MAPPING
syn keyword cmodConstant	NUMBER_UNDEFINED PIKE_T_PROGRAM PIKE_T_FUNCTION
syn keyword cmodConstant	T_OBJECT T_STRING T_ARRAY T_MAPPING

syn keyword cmodException	SET_ONERROR UNSET_ONERROR ONERROR
syn keyword cmodException	CALL_AND_UNSET_ONERROR

syn keyword cmodDebug		Pike_fatal Pike_error check_stack

syn keyword cmodAccess		public protected private INHERIT
syn keyword cmodAccess		CTYPE CVAR PIKEVAR PIKEFUN

syn keyword cmodModifier	efun export flags optflags optfunc
syn keyword cmodModifier	type rawtype errname name c_name prototype
syn keyword cmodModifier	program_flags gc_trivial PMOD_EXPORT
syn keyword cmodModifier	ATTRIBUTE noclone noinline
syn keyword cmodModifier	tOr tFuncV tInt tMix tVoid tStr tMap tPrg
syn keyword cmodModifier	tSetvar tArr tMult tMultiset
syn keyword cmodModifier	tArray tMapping tString tSetvar tVar

syn keyword cmodType		bool mapping string multiset array mixed
syn keyword cmodType		object function program auto svalue
syn keyword cmodType		bignum longest zero pike_string
syn keyword cmodType		this this_program THIS INT_TYPE INT64 INT32
syn keyword cmodType		p_wchar2 PCHARP p_wchar1 p_wchar0 MP_INT

syn keyword cmodOperator	_destruct create __hash _sizeof _indices _values
syn keyword cmodOperator	_is_type _sprintf _equal _m_delete _get_iterator
syn keyword cmodOperator	_search _types _serialize _deserialize
syn keyword cmodOperator	_size_object _random _sqrt TYPEOF SUBTYPEOF
syn keyword cmodOperator	LIKELY UNLIKELY

syn keyword cmodStructure	DECLARATIONS PIKECLASS DECLARE_STORAGE

if !exists("c_autodoc")
  syn match cmodAutodocReal display contained "\%(//\|[/ \t\v]\*\|^\*\)\@2<=!.*" contains=@cmodAutodoc containedin=cComment,cCommentL
  syn cluster cCommentGroup add=cmodAutodocReal
  syn cluster cPreProcGroup add=cmodAutodocReal
endif

" Default highlighting
hi def link cmodAccess		Statement
hi def link cmodOperator	Operator
hi def link cmodStatement	Statement
hi def link cmodConstant	Constant
hi def link cmodModifier	Type
hi def link cmodType		Type
hi def link cmodStorageClass	StorageClass
hi def link cmodStructure	Structure
hi def link cmodException	Exception
hi def link cmodDebug		Debug

let b:current_syntax = "cmod"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
